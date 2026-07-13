// src/services/report.service.js
import api from './api';

export const reportService = {
    getUsersReport: (params) => api.get('/v12/reports/users', { params }),
    getTechniciansReport: (params) => api.get('/v12/reports/technicians', { params }),
    getRequestsReport: (params) => api.get('/v12/reports/requests', { params }),
    getServicesReport: (params) => api.get('/v12/reports/services', { params }),
    getBlogReport: (params) => api.get('/v12/reports/blog', { params }),
    getPortfolioReport: (params) => api.get('/v12/reports/portfolio', { params }),
};