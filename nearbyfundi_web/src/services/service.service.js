// src/services/service.service.js
import api from './api';

export const serviceService = {
    // Public
    getPublicServices: () => api.get('/v1/services'),

    // Admin
    getServices: (params) => api.get('/v11/services', { params }),
    getService: (id) => api.get(`/v11/services/${id}`),
    createService: (data) => api.post('/v11/services', data),
    updateService: (id, data) => api.put(`/v11/services/${id}`, data),
    deleteService: (id) => api.delete(`/v11/services/${id}`),
};