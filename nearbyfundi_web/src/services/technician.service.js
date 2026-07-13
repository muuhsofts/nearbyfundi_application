// src/services/technician.service.js
import api from './api';

export const technicianService = {
    // ===== PUBLIC - View Technicians =====
    getTechnicians: (params) => api.get('/v1/technicians', { params }),
    getTechnician: (id) => api.get(`/v1/technicians/${id}`),
    getNearby: (params) => api.get('/v1/technicians/nearby', { params }),
    getNearbyByPlace: (params) => api.get('/v1/technicians/nearby-by-place', { params }),
};