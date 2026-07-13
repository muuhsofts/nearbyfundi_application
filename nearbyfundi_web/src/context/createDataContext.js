// src/contexts/createDataContext.js
import React, { createContext, useContext, useState, useCallback } from 'react';

export function createDataContext(service, resourceName) {
    const Context = createContext();

    const Provider = ({ children }) => {
        const [items, setItems] = useState([]);
        const [item, setItem] = useState(null);
        const [loading, setLoading] = useState(false);
        const [error, setError] = useState(null);

        const fetchAll = useCallback(async (params) => {
            if (!service.getAll) {
                setError('Fetch all not supported');
                return;
            }
            setLoading(true);
            setError(null);
            try {
                const res = await service.getAll(params);
                let dataArray = [];
                if (res && res.data) {
                    if (Array.isArray(res.data)) {
                        dataArray = res.data;
                    } else if (res.data.data !== undefined) {
                        dataArray = Array.isArray(res.data.data) ? res.data.data : [res.data.data];
                    } else if (typeof res.data === 'object') {
                        dataArray = [res.data];
                    }
                } else if (Array.isArray(res)) {
                    dataArray = res;
                } else if (res && typeof res === 'object') {
                    dataArray = [res];
                }
                setItems(dataArray);
            } catch (err) {
                console.error('fetchAll error:', err);
                setError(err.message || 'An error occurred');
                setItems([]);
            } finally {
                setLoading(false);
            }
        }, []);

        const fetchOne = useCallback(async (id) => {
            if (!service.getOne) {
                setError('Fetch one not supported');
                return null;
            }
            setLoading(true);
            setError(null);
            try {
                const res = await service.getOne(id);
                let data = null;
                if (res && res.data) {
                    if (res.data.data !== undefined) data = res.data.data;
                    else if (typeof res.data === 'object') data = res.data;
                }
                setItem(data);
                return data;
            } catch (err) {
                setError(err.message || 'An error occurred');
                return null;
            } finally {
                setLoading(false);
            }
        }, []);

        const create = useCallback(async (data) => {
            if (!service.create) {
                setError('Create not supported');
                return null;
            }
            setLoading(true);
            setError(null);
            try {
                const res = await service.create(data);
                let newItem = null;
                if (res && res.data) {
                    if (res.data.data !== undefined) newItem = res.data.data;
                    else if (typeof res.data === 'object') newItem = res.data;
                }
                if (service.isSingleRecord) {
                    setItems(newItem ? [newItem] : []);
                } else {
                    setItems(prev => newItem ? [newItem, ...prev] : prev);
                }
                return newItem;
            } catch (err) {
                console.error('Create error:', err);
                setError(err.message || 'An error occurred');
                return null;
            } finally {
                setLoading(false);
            }
        }, []);

        const update = useCallback(async (id, data) => {
            if (!service.update) {
                setError('Update not supported');
                return null;
            }
            setLoading(true);
            setError(null);
            try {
                const res = await service.update(id, data);
                let updatedItem = null;
                if (res && res.data) {
                    if (res.data.data !== undefined) updatedItem = res.data.data;
                    else if (typeof res.data === 'object') updatedItem = res.data;
                }
                if (updatedItem) {
                    if (service.isSingleRecord) {
                        setItems([updatedItem]);
                    } else {
                        setItems(prev => prev.map(item => item.id === id ? updatedItem : item));
                    }
                    setItem(updatedItem);
                }
                return updatedItem;
            } catch (err) {
                console.error('Update error:', err);
                setError(err.message || 'An error occurred');
                return null;
            } finally {
                setLoading(false);
            }
        }, []);

        const deleteItem = useCallback(async (id) => {
            if (!service.delete) {
                setError('Delete not supported');
                return false;
            }
            setLoading(true);
            setError(null);
            try {
                const res = await service.delete(id);
                if (res && (res.status === 200 || res.status === 204 || res.data?.status === 'success')) {
                    if (service.isSingleRecord) {
                        setItems([]);
                        setItem(null);
                    } else {
                        setItems(prev => prev.filter(item => item.id !== id));
                        if (item?.id === id) setItem(null);
                    }
                    return true;
                }
                throw new Error(res?.data?.message || 'Failed to delete');
            } catch (err) {
                setError(err.message || 'An error occurred');
                return false;
            } finally {
                setLoading(false);
            }
        }, [item]);

        const getDropdown = useCallback(async (params) => {
            if (!service.getDropdown) {
                setError('Dropdown not supported');
                return [];
            }
            try {
                const res = await service.getDropdown(params);
                let data = [];
                if (res && res.data) {
                    if (res.data.data !== undefined) data = res.data.data;
                    else if (Array.isArray(res.data)) data = res.data;
                }
                return data;
            } catch (err) {
                setError(err.message || 'Failed to fetch dropdown');
                return [];
            }
        }, []);

        const clearError = useCallback(() => setError(null), []);

        const value = {
            items,
            item,
            loading,
            error,
            fetchAll,
            fetchOne,
            create,
            update,
            delete: deleteItem,
            getDropdown,
            setItem,
            clearError,
        };

        return <Context.Provider value={value}>{children}</Context.Provider>;
    };

    const useResource = () => {
        const ctx = useContext(Context);
        if (!ctx) {
            throw new Error(`use${resourceName} must be used within a ${resourceName}Provider`);
        }
        return ctx;
    };

    return { Provider, useResource };
}