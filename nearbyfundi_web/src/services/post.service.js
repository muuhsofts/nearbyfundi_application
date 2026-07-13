// src/services/post.service.js
import api from './api';

export const postService = {
    // ===== PUBLIC =====
    getAllPosts: (params) => api.get('/v1/posts', { params }),
    getPost: (id) => api.get(`/v1/posts/${id}`),

    // ===== TECHNICIAN (Authenticated) =====
    createPost: (data) => api.post('/v5/posts', data),
    updatePost: (id, data) => api.put(`/v5/posts/${id}`, data),
    deletePost: (id) => api.delete(`/v5/posts/${id}`),
    getMyPosts: (params) => api.get('/v5/my-posts', { params }),

    // ===== ADMIN/MANAGER =====
    getAllPostsAdmin: (params) => api.get('/v5/admin/posts/all', { params }),
};