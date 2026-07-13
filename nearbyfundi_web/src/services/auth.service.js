// src/services/auth.service.js
import api from './api';

export const authService = {
    // ===== AUTHENTICATION =====
    login: (email, password) => api.post('/v1/auth/login', { email, password }),
    logout: () => api.post('/v1/auth/logout'),
    me: () => api.get('/v1/auth/me'),
    getMyPermissions: () => api.get('/v1/auth/permissions'),

    // ===== REGISTRATION =====
    register: (data) => api.post('/v1/auth/register', data),
    registerFundi: (data) => api.post('/v1/auth/register-fundi', data),

    // ===== OTP VERIFICATION =====
    verifyOTP: (email, otp) => api.post('/v1/auth/verify-otp', { email, otp }),
    verifyToken: (email, token) => api.get('/v1/verification/verify-token', {
        params: { email, token }
    }),
    resendOtp: (email) => api.post('/v1/auth/resend-otp', { email }),

    // ===== PASSWORD MANAGEMENT =====
    forgotPassword: (email) => api.post('/v1/auth/forgot-password', { email }),
    resetPassword: (email, otp, password, password_confirmation) =>
        api.post('/v1/auth/reset-password', { email, otp, password, password_confirmation }),
    changePassword: (current_password, password, password_confirmation) =>
        api.post('/v1/auth/change-password', { current_password, password, password_confirmation }),

    // ===== PROFILE MANAGEMENT =====
    updateProfile: (data) => api.put('/v1/auth/profile', data),
    updateLocale: (locale) => api.post('/v1/auth/locale', { locale }),
    updateDeviceToken: (token) => api.post('/v1/device-token', { token }),
    getDeviceToken: () => api.get('/v1/device-token'),
    deleteDeviceToken: () => api.delete('/v1/device-token'),
    deleteAccount: () => api.delete('/v1/auth/account'),

    // ===== SESSIONS =====
    getSessions: () => api.get('/v1/sessions'),
    deleteAllSessions: () => api.delete('/v1/sessions/all'),
    deleteOtherSessions: () => api.delete('/v1/sessions/others'),
    deleteSession: (id) => api.delete(`/v1/sessions/${id}`),
};