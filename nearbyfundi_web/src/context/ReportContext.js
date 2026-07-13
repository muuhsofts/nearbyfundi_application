// src/contexts/ReportContext.js
import React, { createContext, useContext, useState, useCallback } from 'react';
import { reportService } from 'services/report.service';

const ReportContext = createContext();

export const ReportProvider = ({ children }) => {
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [data, setData] = useState(null);

    const fetchReport = useCallback(async (serviceMethod, params) => {
        setLoading(true);
        setError(null);
        try {
            const res = await serviceMethod(params);
            if (res?.data?.status === 'success') {
                setData(res.data.data);
                return res.data.data;
            }
            throw new Error(res?.data?.message || 'Failed to fetch');
        } catch (err) {
            setError(err.message);
            return null;
        } finally {
            setLoading(false);
        }
    }, []);

    const fetchUsersReport = useCallback((params) => fetchReport(reportService.getUsersReport, params), [fetchReport]);
    const fetchTechniciansReport = useCallback((params) => fetchReport(reportService.getTechniciansReport, params), [fetchReport]);
    const fetchRequestsReport = useCallback((params) => fetchReport(reportService.getRequestsReport, params), [fetchReport]);
    const fetchServicesReport = useCallback((params) => fetchReport(reportService.getServicesReport, params), [fetchReport]);
    const fetchBlogReport = useCallback((params) => fetchReport(reportService.getBlogReport, params), [fetchReport]);
    const fetchPortfolioReport = useCallback((params) => fetchReport(reportService.getPortfolioReport, params), [fetchReport]);

    const value = {
        loading,
        error,
        data,
        fetchUsersReport,
        fetchTechniciansReport,
        fetchRequestsReport,
        fetchServicesReport,
        fetchBlogReport,
        fetchPortfolioReport,
    };

    return <ReportContext.Provider value={value}>{children}</ReportContext.Provider>;
};

export const useReport = () => {
    const ctx = useContext(ReportContext);
    if (!ctx) throw new Error('useReport must be used within ReportProvider');
    return ctx;
};