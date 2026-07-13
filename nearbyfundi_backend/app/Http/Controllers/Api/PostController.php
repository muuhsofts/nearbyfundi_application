<?php

namespace App\Http\Controllers\Api;

use App\Models\Post;
use App\Traits\Auditable;
use Illuminate\Http\Request;

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

        return $this->successResponse($post);
    }

    /**
     * TECHNICIAN: Create a new post.
     */
    public function store(Request $request)
    {
        $user = $request->user();
        $technician = $user->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can create posts.');
        }

        $data = $request->validate([
            'title'   => 'required|string|max:255',
            'content' => 'required|string',
            'image'   => 'nullable|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        $post = new Post($data);
        $post->technician_id = $technician->id;

        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('posts', 'public');
            $post->image = $path;
        }

        $post->save();

        $this->logAudit('create_post', 'blog', $post->id, "Technician created post: {$post->title}");

        return $this->created($post->load('technician.user'), 'Post created successfully.');
    }

    /**
     * TECHNICIAN or ADMIN/MANAGER: Update a post.
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
            'title'   => 'sometimes|string|max:255',
            'content' => 'sometimes|string',
            'image'   => 'nullable|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        if ($request->hasFile('image')) {
            if ($post->image && file_exists(public_path($post->image))) {
                unlink(public_path($post->image));
            }
            $data['image'] = $request->file('image')->store('posts', 'public');
        }

        $old = $post->toArray();
        $post->update($data);
        $new = $post->fresh()->toArray();

        $this->logAudit('update_post', 'blog', $id, "Post #{$id} updated", $old, $new);

        return $this->successResponse($post, 'Post updated.');
    }

    /**
     * TECHNICIAN or ADMIN/MANAGER: Delete a post.
     */
    public function destroy(Request $request, $id)
    {
        $post = Post::findOrFail($id);
        $user = $request->user();

        $isTech = $user->technician && $user->technician->id == $post->technician_id;
        if (!($isTech || $user->hasAnyRole(['ADMINISTRATOR', 'MANAGER']))) {
            return $this->forbidden('Unauthorized.');
        }

        if ($post->image && file_exists(public_path($post->image))) {
            unlink(public_path($post->image));
        }

        $post->delete();
        $this->logAudit('delete_post', 'blog', $id, "Post #{$id} deleted");

        return $this->successResponse(null, 'Post deleted.');
    }

    // ---------------------- NEW: Technician-specific methods ----------------------

    /**
     * TECHNICIAN: Get all posts belonging to the authenticated technician,
     * with full comments and likes (including user details).
     */
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

        return $this->successResponse($posts);
    }

    /**
     * ADMIN/MANAGER: Get all posts with full details (comments & likes).
     * This is a more detailed version of index().
     */
    public function allWithDetails(Request $request)
    {
        // Only admins and managers can see all posts with full details
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

        return $this->successResponse($posts);
    }
}