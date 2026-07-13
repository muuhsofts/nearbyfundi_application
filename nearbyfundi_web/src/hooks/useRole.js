
// src/hooks/useRole.js
import { useRoles } from 'context/RoleContext';
import { useCallback } from 'react';

export const useRoleManagement = () => {
    const {
        items,
        item,
        loading,
        error,
        fetchAll,
        fetchOne,
        create,
        update,
        delete: remove,
        clearError
    } = useRoles();

    const getRoles = useCallback(async (params) => {
        try {
            console.log('useRole - getRoles called with params:', params);
            const result = await fetchAll(params);
            console.log('useRole - getRoles result:', result);
            return result;
        } catch (err) {
            console.error('useRole - getRoles error:', err);
            throw err;
        }
    }, [fetchAll]);

    const getRole = useCallback(async (id) => {
        return await fetchOne(id);
    }, [fetchOne]);

    const createRole = useCallback(async (data) => {
        const result = await create(data);
        await fetchAll();
        return result;
    }, [create, fetchAll]);

    const updateRole = useCallback(async (id, data) => {
        const result = await update(id, data);
        await fetchAll();
        return result;
    }, [update, fetchAll]);

    const deleteRole = useCallback(async (id) => {
        const result = await remove(id);
        await fetchAll();
        return result;
    }, [remove, fetchAll]);

    return {
        roles: items,
        role: item,
        loading,
        error,
        getRoles,
        getRole,
        createRole,
        updateRole,
        deleteRole,
        clearError,
    };
};