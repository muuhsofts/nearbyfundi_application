// src/services/finance.service.js
import api from './api';

export const financeService = {
    getSummary: (params) => api.get('/v21/finance/summary', { params }),
    getTrends: (params) => api.get('/v21/finance/trends', { params }),
    getTable: (params) => api.get('/v21/finance/table', { params }),
    exportReport: (params) => api.get('/v21/finance/export', { params, responseType: 'blob' }),
};