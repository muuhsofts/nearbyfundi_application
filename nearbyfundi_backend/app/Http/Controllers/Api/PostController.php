<?php

namespace App\Http\Controllers\Api;

use App\Models\Post;
use App\Traits\Auditable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class PostController extends BaseApiController
{
    use Auditable;

    /**
     * PUBLIC: List posts (newest first).
     * Supports filtering by technician_id.
     * Returns counts of comments & likes (lightweight).
     */
    public function index(Request $request)
    {
        $query = Post::with('technician.user')
            ->withCount(['comments', 'likes'])
            ->orderBy('created_at', 'desc');

        if ($request->has('technician_id')) {
            $query->where('technician_id', $request->technician_id);
        }

        $posts = $query->paginate(15);

        // Append full image URLs for frontend convenience
        $posts->getCollection()->transform(function ($post) {
            $post->image_urls = $post->image_urls;
            return $post;
        });

        return $this->successResponse($posts);
    }

    /**
     * PUBLIC: Get a single post with full comments and likes (users included).
     */
    public function show($id)
    {
        $post = Post::with([
            'technician.user',
            'comments.user',
            'likes.user'
        ])->withCount(['comments', 'likes'])
          ->findOrFail($id);

        $post->image_urls = $post->image_urls;

        return $this->successResponse($post);
    }

    /**
     * TECHNICIAN: Create a new post.
     * Supports 0, 1 or multiple images (Instagram style).
     * content comes straight from the text editor (HTML/rich text is fine).
     */
    public function store(Request $request)
    {
        $user = $request->user();
        $technician = $user->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can create posts.');
        }

        $data = $request->validate([
            'title'        => 'required|string|max:255',
            'content'      => 'required|string',               // text editor content – keep as-is
            'images'       => 'nullable|array|max:10',         // max 10 images
            'images.*'     => 'image|mimes:jpg,jpeg,png,webp|max:2048',
            'youtube_url'  => 'nullable|string|max:500',
        ]);

        $post = new Post();
        $post->technician_id = $technician->id;
        $post->title         = $data['title'];
        $post->content       = $data['content'];   // rich text from editor is stored exactly

        // YouTube
        if ($request->filled('youtube_url')) {
            $post->youtube_url   = $request->youtube_url;
            $post->youtube_embed = $this->convertToEmbedUrl($request->youtube_url);
        }

        // Multiple images
        $imagePaths = [];
        if ($request->hasFile('images')) {
            foreach ($request->file('images') as $file) {
                if ($file->isValid()) {
                    $imagePaths[] = $file->store('posts', 'public');
                }
            }
        }
        $post->images = $imagePaths;

        $post->save();

        $this->logAudit('create_post', 'blog', $post->id, "Technician created post: {$post->title}");

        $post->load('technician.user');
        $post->image_urls = $post->image_urls;

        return $this->created($post, 'Post created successfully.');
    }

    /**
     * TECHNICIAN or ADMIN/MANAGER: Update a post.
     * - You can send new images (they will replace the old ones)
     * - Or send an empty images array / omit it to keep existing images
     * - content is still taken exactly from the text editor
     */
    public function update(Request $request, $id)
    {
        $post = Post::findOrFail($id);
        $user = $request->user();

        $isTech = $user->technician && $user->technician->id == $post->technician_id;
        if (!($isTech || $user->hasAnyRole(['ADMINISTRATOR', 'MANAGER']))) {
            return $this->forbidden('Unauthorized.');
        }

        $data = $request->validate([
            'title'        => 'sometimes|string|max:255',
            'content'      => 'sometimes|string',
            'images'       => 'nullable|array|max:10',
            'images.*'     => 'image|mimes:jpg,jpeg,png,webp|max:2048',
            'youtube_url'  => 'nullable|string|max:500',
        ]);

        if ($request->has('title')) {
            $post->title = $data['title'];
        }
        if ($request->has('content')) {
            $post->content = $data['content'];   // keep text-editor content as-is
        }

        // YouTube
        if ($request->has('youtube_url')) {
            if (empty($request->youtube_url)) {
                $post->youtube_url   = null;
                $post->youtube_embed = null;
            } else {
                $post->youtube_url   = $request->youtube_url;
                $post->youtube_embed = $this->convertToEmbedUrl($request->youtube_url);
            }
        }

        // Handle images – only replace if new files are uploaded
        if ($request->hasFile('images')) {
            // Delete old physical files
            if (!empty($post->images) && is_array($post->images)) {
                foreach ($post->images as $oldPath) {
                    if ($oldPath && Storage::disk('public')->exists($oldPath)) {
                        Storage::disk('public')->delete($oldPath);
                    }
                }
            }

            $imagePaths = [];
            foreach ($request->file('images') as $file) {
                if ($file->isValid()) {
                    $imagePaths[] = $file->store('posts', 'public');
                }
            }
            $post->images = $imagePaths;
        }

        $old = $post->toArray();
        $post->save();
        $post->refresh();
        $new = $post->toArray();

        $this->logAudit('update_post', 'blog', $id, "Post #{$id} updated", $old, $new);

        $post->image_urls = $post->image_urls;

        return $this->successResponse($post, 'Post updated.');
    }

    /**
     * TECHNICIAN or ADMIN/MANAGER: Delete a post.
     * (Physical image files are automatically deleted by the model boot method)
     */
    public function destroy(Request $request, $id)
    {
        $post = Post::findOrFail($id);
        $user = $request->user();

        $isTech = $user->technician && $user->technician->id == $post->technician_id;
        if (!($isTech || $user->hasAnyRole(['ADMINISTRATOR', 'MANAGER']))) {
            return $this->forbidden('Unauthorized.');
        }

        $post->delete();   // model boot takes care of deleting image files
        $this->logAudit('delete_post', 'blog', $id, "Post #{$id} deleted");

        return $this->successResponse(null, 'Post deleted.');
    }

    // ---------------------- Technician-specific methods ----------------------

    public function myPosts(Request $request)
    {
        $user = $request->user();
        $technician = $user->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can view their own posts.');
        }

        $posts = Post::with([
            'technician.user',
            'comments.user',
            'likes.user'
        ])->withCount(['comments', 'likes'])
          ->where('technician_id', $technician->id)
          ->orderBy('created_at', 'desc')
          ->get();

        $posts->transform(function ($post) {
            $post->image_urls = $post->image_urls;
            return $post;
        });

        return $this->successResponse($posts);
    }

    public function allWithDetails(Request $request)
    {
        if (!$request->user()->hasAnyRole(['ADMINISTRATOR', 'MANAGER'])) {
            return $this->forbidden('Unauthorized.');
        }

        $query = Post::with([
            'technician.user',
            'comments.user',
            'likes.user'
        ])->withCount(['comments', 'likes'])
          ->orderBy('created_at', 'desc');

        if ($request->has('technician_id')) {
            $query->where('technician_id', $request->technician_id);
        }

        $posts = $query->paginate(15);

        $posts->getCollection()->transform(function ($post) {
            $post->image_urls = $post->image_urls;
            return $post;
        });

        return $this->successResponse($posts);
    }

    // ============================================================
    //  HELPER METHODS
    // ============================================================

    private function convertToEmbedUrl($url)
    {
        if (strpos($url, 'youtu.be') !== false) {
            $videoId = $this->extractVideoId($url);
            if ($videoId) {
                return "https://www.youtube.com/embed/{$videoId}";
            }
        }

        if (strpos($url, 'youtube.com/watch') !== false) {
            parse_str(parse_url($url, PHP_URL_QUERY), $params);
            if (isset($params['v'])) {
                return "https://www.youtube.com/embed/{$params['v']}";
            }
        }

        if (strpos($url, 'youtube.com/embed') !== false) {
            return $url;
        }

        return $url;
    }

    private function extractVideoId($url)
    {
        preg_match('/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([^&\n?#]+)/', $url, $matches);
        return $matches[1] ?? null;
    }
}