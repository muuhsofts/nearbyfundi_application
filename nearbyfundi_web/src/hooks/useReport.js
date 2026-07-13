// src/hooks/useReport.js
import { useReport } from 'context/ReportContext';
import { useCallback } from 'react';

export const useReportManagement = () => {
    const {
        loading,
        error,
        data,
        fetchUsersReport,
        fetchTechniciansReport,
        fetchRequestsReport,
        fetchServicesReport,
        fetchBlogReport,
        fetchPortfolioReport,
    } = useReport();

    const getUsersReport = useCallback(async (params) => fetchUsersReport(params), [fetchUsersReport]);
    const getTechniciansReport = useCallback(async (params) => fetchTechniciansReport(params), [fetchTechniciansReport]);
    const getRequestsReport = useCallback(async (params) => fetchRequestsReport(params), [fetchRequestsReport]);
    const getServicesReport = useCallback(async (params) => fetchServicesReport(params), [fetchServicesReport]);
    const getBlogReport = useCallback(async (params) => fetchBlogReport(params), [fetchBlogReport]);
    const getPortfolioReport = useCallback(async (params) => fetchPortfolioReport(params), [fetchPortfolioReport]);

    return {
        reportData: data,
        loading,
        error,
        getUsersReport,
        getTechniciansReport,
        getRequestsReport,
        getServicesReport,
        getBlogReport,
        getPortfolioReport,
    };
};