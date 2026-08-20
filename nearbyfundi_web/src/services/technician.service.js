// src/services/technician.service.js
import api from './api';

export const technicianService = {
    // ===== PUBLIC =====
    getTechnicians: (params) => api.get('/v1/technicians', { params }),
    getTechnician: (id) => api.get(`/v1/technicians/${id}`),
    getNearby: (params) => api.get('/v1/technicians/nearby', { params }),
    getNearbyByPlace: (params) => api.get('/v1/technicians/nearby-by-place', { params }),

    // ===== ADMIN =====
    getAdminTechnicians: (params) => api.get('/v20/admin/technicians', { params }),

    // ✅ NEW: Approve technician (admin only)
    approveTechnician: (id) => api.post(`/v19/admin/technicians/${id}/approve`),
};