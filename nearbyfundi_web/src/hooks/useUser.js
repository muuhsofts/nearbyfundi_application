// src/hooks/useUser.js
import { useUsers } from 'context/UserContext';
import { useCallback } from 'react';

export const useUserManagement = () => {
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
        getDropdown,
        clearError
    } = useUsers();

    const getUsers = useCallback(async (params) => {
        try {
            console.log('getUsers called with params:', params);
            const result = await fetchAll(params);
            console.log('getUsers result:', result);
            return result;
        } catch (err) {
            console.error('getUsers error:', err);
            throw err;
        }
    }, [fetchAll]);

    const getUser = useCallback(async (id) => {
        return await fetchOne(id);
    }, [fetchOne]);

    const createUser = useCallback(async (data) => {
        const result = await create(data);
        await fetchAll();
        return result;
    }, [create, fetchAll]);

    const updateUser = useCallback(async (id, data) => {
        const result = await update(id, data);
        await fetchAll();
        return result;
    }, [update, fetchAll]);

    const deleteUser = useCallback(async (id) => {
        const result = await remove(id);
        await fetchAll();
        return result;
    }, [remove, fetchAll]);

    const getUsersDropdown = useCallback(async (params) => {
        return await getDropdown(params);
    }, [getDropdown]);

    return {
        users: items,
        user: item,
        loading,
        error,
        getUsers,
        getUser,
        createUser,
        updateUser,
        deleteUser,
        getUsersDropdown,
        clearError,
    };
};