// src/services/post.service.js
import api from './api';

/**
 * Build a FormData payload for create/update, supporting multiple images
 * and `keep_images[]` on update (Laravel expects method spoofing).
 */
const buildPostFormData = (data = {}, isUpdate = false) => {
    const form = new FormData();
    if (isUpdate) form.append('_method', 'PUT');

    if (data.title !== undefined) form.append('title', data.title ?? '');
    if (data.content !== undefined) form.append('content', data.content ?? '');
    if (data.youtube_url !== undefined) {
        form.append('youtube_url', data.youtube_url ?? '');
    }

    // Keep existing images (update only) — list of URLs from the server.
    if (isUpdate && Array.isArray(data.keep_images)) {
        data.keep_images.forEach((url) => {
            if (url) form.append('keep_images[]', String(url));
        });
    }

    // New images: `data.images` may be a list of Files/Blobs.
    // Fallback to single `image` (File/Blob) for backward compatibility.
    const newFiles = Array.isArray(data.images)
        ? data.images
        : data.image
            ? [data.image]
            : [];

    newFiles.forEach((file) => {
        if (file instanceof File || file instanceof Blob) {
            form.append('images[]', file);
        }
    });

    return form;
};

const isFormData = (v) =>
    typeof FormData !== 'undefined' && v instanceof FormData;

export const postService = {
    // ===== PUBLIC =====
    getAllPosts: (params) => api.get('/v1/posts', { params }),
    getPost: (id) => api.get(`/v1/posts/${id}`),

    // ===== LIKES & COMMENTS =====
    likePost: (postId) => api.post(`/v5/posts/${postId}/like`),
    commentOnPost: (postId, comment) =>
        api.post(`/v5/posts/${postId}/comments`, { comment }),
    deleteComment: (id) => api.delete(`/v5/comments/${id}`),

    // ===== TECHNICIAN (Authenticated) =====
    getMyPosts: (params) => api.get('/v5/my-posts', { params }),

    createPost: (data) =>
        api.post(
            '/v5/posts',
            isFormData(data) ? data : buildPostFormData(data, false),
            // Let axios set multipart boundaries automatically:
            // omit explicit Content-Type.
            { headers: { 'Content-Type': undefined } }
        ),

    updatePost: (id, data) =>
        api.post(
            `/v5/posts/${id}`,
            isFormData(data) ? data : buildPostFormData(data, true),
            { headers: { 'Content-Type': undefined } }
        ),

    deletePost: (id) => api.delete(`/v5/posts/${id}`),

    // ===== ADMIN/MANAGER =====
    getAllPostsAdmin: (params) => api.get('/v5/admin/posts/all', { params }),
};