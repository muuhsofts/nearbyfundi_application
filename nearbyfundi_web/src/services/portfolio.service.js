// src/services/portfolio.service.js
import api from './api';

export const portfolioService = {
    // ===== PUBLIC - GET ALL PORTFOLIOS =====
    getPortfolios: (params) => api.get('/v3/portfolios', { params }),

    // ===== PUBLIC - Get portfolios by technician =====
    getPortfoliosByTechnician: (technicianId) =>
        api.get(`/v3/portfolios/technician/${technicianId}`),

    // ===== TECHNICIAN (Authenticated) =====
    createPortfolio: (data) => api.post('/v3/portfolios', data),
    updatePortfolio: (id, data) => api.put(`/v3/portfolios/${id}`, data),
    deletePortfolio: (id) => api.delete(`/v3/portfolios/${id}`),

    // ===== ADMIN/MANAGER =====
    deletePortfolioAdmin: (id) => api.delete(`/v3/admin/portfolios/${id}`),
};