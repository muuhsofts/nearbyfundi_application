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

    public function index(Request $request)
    {
        $query = Post::with('technician.user')
            ->withCount(['comments', 'likes'])
            ->orderBy('created_at', 'desc');

        if ($request->filled('technician_id')) {
            $query->where('technician_id', $request->technician_id);
        }

        $posts = $query->paginate(15);
        $posts->getCollection()->transform(fn ($post) => $this->withUrls($post));

        return $this->successResponse($posts);
    }

    public function show($id)
    {
        $post = Post::with(['technician.user', 'comments.user', 'likes.user'])
            ->withCount(['comments', 'likes'])
            ->findOrFail($id);

        return $this->successResponse($this->withUrls($post));
    }

    public function store(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can create posts.');
        }

        $request->validate([
            'images'   => 'nullable|array|max:' . self::MAX_IMAGES,
            'images.*' => 'image|mimes:jpg,jpeg,png,webp|max:5120',
            'video'    => 'nullable|file|mimes:mp4,mov,avi,webm|max:20480',
        ]);

        $post = new Post();
        $post->technician_id = $technician->id;

        if ($request->hasFile('video')) {
            $post->video = $request->file('video')->store('posts', 'public');
        }

        $post->images = $this->storeImages($request);
        $post->save();

        $this->logAudit('create_post', 'blog', $post->id, "Technician created a new media post");
        $post->load('technician.user');

        return $this->created($this->withUrls($post), 'Post created successfully.');
    }

    public function update(Request $request, $id)
    {
        $post = Post::findOrFail($id);
        $user = $request->user();

        $isOwner = $user->technician && $user->technician->id == $post->technician_id;
        if (!($isOwner || $user->hasAnyRole(['ADMINISTRATOR', 'MANAGER']))) {
            return $this->forbidden('Unauthorized.');
        }

        $request->validate([
            'images'         => 'nullable|array|max:' . self::MAX_IMAGES,
            'images.*'       => 'image|mimes:jpg,jpeg,png,webp|max:5120',
            'keep_images'    => 'nullable|array',
            'keep_images.*'  => 'string',
            'images_managed' => 'nullable|boolean',
            'video'          => 'nullable|file|mimes:mp4,mov,avi,webm|max:20480',
            'remove_video'   => 'nullable|boolean',
        ]);

        // Handle Video
        if ($request->boolean('remove_video') && $post->video) {
            if (Storage::disk('public')->exists($post->video)) {
                Storage::disk('public')->delete($post->video);
            }
            $post->video = null;
        } elseif ($request->hasFile('video')) {
            if ($post->video && Storage::disk('public')->exists($post->video)) {
                Storage::disk('public')->delete($post->video);
            }
            $post->video = $request->file('video')->store('posts', 'public');
        }

        // Handle Images
        $current    = is_array($post->images) ? $post->images : [];
        $hasUploads = $request->hasFile('images');
        $isManaged  = $request->boolean('images_managed');
        $toDelete   = [];

        if ($isManaged || $hasUploads) {
            if ($isManaged) {
                $requested = array_map(fn ($p) => $this->normalizeStoragePath((string) $p), (array) $request->input('keep_images', []));
                $keep = array_values(array_intersect($current, $requested));
            } else {
                $keep = $current;
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

        foreach ($toDelete as $path) {
            if ($path && Storage::disk('public')->exists($path)) {
                Storage::disk('public')->delete($path);
            }
        }

        return $this->successResponse($this->withUrls($post->fresh()), 'Post updated.');
    }

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
            ->map(fn ($post) => $this->withUrls($post));

        return $this->successResponse($posts);
    }

    private function withUrls(Post $post): Post
    {
        $post->image_urls = $post->image_urls;
        $post->video_url = $post->video_url;
        return $post;
    }

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

    private function normalizeStoragePath(string $value): string
    {
        $marker = '/storage/';
        $pos    = strpos($value, $marker);
        $path   = $pos === false ? $value : substr($value, $pos + strlen($marker));
        return ltrim($path, '/');
    }
}