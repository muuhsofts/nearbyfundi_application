<?php

namespace App\Http\Controllers\Api;

use App\Models\Post;
use App\Traits\Auditable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class PostController extends BaseApiController
{
    use Auditable;

    private const MAX_IMAGES = 10;

    // ============================================================
    //  PUBLIC
    // ============================================================

    /** List posts, newest first. Optional filter: technician_id. */
    public function index(Request $request)
    {
        $query = Post::with('technician.user')
            ->withCount(['comments', 'likes'])
            ->orderBy('created_at', 'desc');

        if ($request->filled('technician_id')) {
            $query->where('technician_id', $request->technician_id);
        }

        $posts = $query->paginate(15);
        $posts->getCollection()->transform(fn ($post) => $this->withImageUrls($post));

        return $this->successResponse($posts);
    }

    /** Single post with comments and likes. */
    public function show($id)
    {
        $post = Post::with(['technician.user', 'comments.user', 'likes.user'])
            ->withCount(['comments', 'likes'])
            ->findOrFail($id);

        return $this->successResponse($this->withImageUrls($post));
    }

    // ============================================================
    //  TECHNICIAN
    // ============================================================

    /** Create a post with 0..10 images. */
    public function store(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can create posts.');
        }

        $data = $request->validate([
            'title'       => 'required|string|max:255',
            'content'     => 'required|string',
            'images'      => 'nullable|array|max:' . self::MAX_IMAGES,
            'images.*'    => 'image|mimes:jpg,jpeg,png,webp|max:5120',
            'youtube_url' => 'nullable|string|max:500',
        ]);

        $post                = new Post();
        $post->technician_id = $technician->id;
        $post->title         = $data['title'];
        $post->content       = $data['content'];

        if ($request->filled('youtube_url')) {
            $post->youtube_url   = $request->youtube_url;
            $post->youtube_embed = $this->convertToEmbedUrl($request->youtube_url);
        }

        $post->images = $this->storeImages($request);
        $post->save();

        $this->logAudit('create_post', 'blog', $post->id, "Technician created post: {$post->title}");

        $post->load('technician.user');

        return $this->created($this->withImageUrls($post), 'Post created successfully.');
    }

    /**
     * Update a post (owner, ADMINISTRATOR or MANAGER).
     *
     * Images:
     *  - app sends `images_managed=1` + `keep_images[]` → keep exactly those,
     *    delete the other old files, add any newly uploaded ones
     *  - app sends only new `images[]` → keep none of the old ones is NOT assumed;
     *    old ones are kept unless listed otherwise, so we treat that as "add"
     *  - app sends neither → images untouched
     */
    public function update(Request $request, $id)
    {
        $post = Post::findOrFail($id);
        $user = $request->user();

        $isOwner = $user->technician && $user->technician->id == $post->technician_id;
        if (!($isOwner || $user->hasAnyRole(['ADMINISTRATOR', 'MANAGER']))) {
            return $this->forbidden('Unauthorized.');
        }

        $data = $request->validate([
            'title'          => 'sometimes|required|string|max:255',
            'content'        => 'sometimes|required|string',
            'images'         => 'nullable|array|max:' . self::MAX_IMAGES,
            'images.*'       => 'image|mimes:jpg,jpeg,png,webp|max:5120',
            'keep_images'    => 'nullable|array',
            'keep_images.*'  => 'string',
            'images_managed' => 'nullable|boolean',
            'youtube_url'    => 'nullable|string|max:500',
        ]);

        // Snapshot BEFORE any change, so the audit log shows a real diff
        $old = $post->toArray();

        if ($request->has('title')) {
            $post->title = $data['title'];
        }
        if ($request->has('content')) {
            $post->content = $data['content'];
        }

        if ($request->has('youtube_url')) {
            if (empty($request->youtube_url)) {
                $post->youtube_url   = null;
                $post->youtube_embed = null;
            } else {
                $post->youtube_url   = $request->youtube_url;
                $post->youtube_embed = $this->convertToEmbedUrl($request->youtube_url);
            }
        }

        // ── Images ──────────────────────────────────────────────
        $current     = is_array($post->images) ? $post->images : [];
        $hasUploads  = $request->hasFile('images');
        $isManaged   = $request->boolean('images_managed');
        $toDelete    = [];

        if ($isManaged || $hasUploads) {
            if ($isManaged) {
                $requested = array_map(
                    fn ($p) => $this->normalizeStoragePath((string) $p),
                    (array) $request->input('keep_images', [])
                );
                // Only paths this post really owns can be kept
                $keep = array_values(array_intersect($current, $requested));
            } else {
                $keep = $current; // uploads only → add to existing
            }

            $incoming = $hasUploads ? count($request->file('images')) : 0;
            if (count($keep) + $incoming > self::MAX_IMAGES) {
                return $this->errorResponse('A post can have at most ' . self::MAX_IMAGES . ' images.', 422);
            }

            $newPaths = $this->storeImages($request);
            $toDelete = array_diff($current, $keep);
            $post->images = array_merge($keep, $newPaths);
        }

        $post->save();

        // Delete removed files only after the save succeeded
        foreach ($toDelete as $path) {
            if ($path && Storage::disk('public')->exists($path)) {
                Storage::disk('public')->delete($path);
            }
        }

        $post->refresh();

        $this->logAudit('update_post', 'blog', $id, "Post #{$id} updated", $old, $post->toArray());

        return $this->successResponse($this->withImageUrls($post), 'Post updated.');
    }

    /** Delete a post (owner, ADMINISTRATOR or MANAGER). Image files are removed by the model. */
    public function destroy(Request $request, $id)
    {
        $post = Post::findOrFail($id);
        $user = $request->user();

        $isOwner = $user->technician && $user->technician->id == $post->technician_id;
        if (!($isOwner || $user->hasAnyRole(['ADMINISTRATOR', 'MANAGER']))) {
            return $this->forbidden('Unauthorized.');
        }

        $post->delete();
        $this->logAudit('delete_post', 'blog', $id, "Post #{$id} deleted");

        return $this->successResponse(null, 'Post deleted.');
    }

    /** The logged-in technician's own posts. */
    public function myPosts(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can view their own posts.');
        }

        $posts = Post::with(['technician.user', 'comments.user', 'likes.user'])
            ->withCount(['comments', 'likes'])
            ->where('technician_id', $technician->id)
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(fn ($post) => $this->withImageUrls($post));

        return $this->successResponse($posts);
    }

    // ============================================================
    //  ADMIN / MANAGER
    // ============================================================

    public function allWithDetails(Request $request)
    {
        if (!$request->user()->hasAnyRole(['ADMINISTRATOR', 'MANAGER'])) {
            return $this->forbidden('Unauthorized.');
        }

        $query = Post::with(['technician.user', 'comments.user', 'likes.user'])
            ->withCount(['comments', 'likes'])
            ->orderBy('created_at', 'desc');

        if ($request->filled('technician_id')) {
            $query->where('technician_id', $request->technician_id);
        }

        $posts = $query->paginate(15);
        $posts->getCollection()->transform(fn ($post) => $this->withImageUrls($post));

        return $this->successResponse($posts);
    }

    // ============================================================
    //  HELPERS
    // ============================================================

    /** Attach the `image_urls` accessor value to the JSON output. */
    private function withImageUrls(Post $post): Post
    {
        $post->image_urls = $post->image_urls;
        return $post;
    }

    /** Store uploaded `images[]` on the public disk and return their relative paths. */
    private function storeImages(Request $request): array
    {
        $paths = [];

        if ($request->hasFile('images')) {
            foreach ($request->file('images') as $file) {
                if ($file->isValid()) {
                    $paths[] = $file->store('posts', 'public');
                }
            }
        }

        return $paths;
    }

    /** "http://host/storage/posts/a.jpg" or "/storage/posts/a.jpg" → "posts/a.jpg" */
    private function normalizeStoragePath(string $value): string
    {
        $marker = '/storage/';
        $pos    = strpos($value, $marker);
        $path   = $pos === false ? $value : substr($value, $pos + strlen($marker));

        return ltrim($path, '/');
    }

    /**
     * Turn a YouTube link, youtu.be link, Shorts link or pasted <iframe>
     * into a clean embed URL. Unknown input is returned unchanged.
     */
    private function convertToEmbedUrl(?string $input): ?string
    {
        $input = trim((string) $input);
        if ($input === '') {
            return null;
        }

        if (stripos($input, '<iframe') !== false
            && preg_match('/src=["\']([^"\']+)["\']/i', $input, $m)) {
            $input = $m[1];
        }

        $videoId = $this->extractVideoId($input);

        return $videoId ? "https://www.youtube.com/embed/{$videoId}" : $input;
    }

    private function extractVideoId(string $url): ?string
    {
        preg_match(
            '/(?:youtu\.be\/|youtube(?:-nocookie)?\.com\/(?:embed\/|v\/|shorts\/|watch\?(?:.*&)?v=))([\w-]{11})/i',
            $url,
            $matches
        );

        return $matches[1] ?? null;
    }
}