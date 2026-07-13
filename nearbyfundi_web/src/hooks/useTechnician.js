// src/hooks/useTechnician.js
import { useTechnicians } from 'context/TechnicianContext';
import { useCallback } from 'react';

export const useTechnicianManagement = () => {
    const {
        items,
        item,
        loading,
        error,
        fetchAll,
        fetchOne,
        clearError
    } = useTechnicians();

    const getTechnicians = useCallback(async (params) => {
        return await fetchAll(params);
    }, [fetchAll]);

    const getTechnician = useCallback(async (id) => {
        return await fetchOne(id);
    }, [fetchOne]);

    return {
        technicians: items,
        technician: item,
        loading,
        error,
        getTechnicians,
        getTechnician,
        clearError,
    };
};