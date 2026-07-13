// src/contexts/TechnicianContext.js
import { createDataContext } from './createDataContext';
import { technicianService } from 'services/technician.service';

const adapter = {
    getAll: async (params) => {
        try {
            const response = await technicianService.getTechnicians(params);
            console.log('Technicians API response:', response);

            // The API returns { status: "success", message: "...", data: { data: [...], pagination: {...} } }
            if (response?.data?.status === 'success') {
                const data = response.data.data;
                // If it has data and pagination structure (paginated response)
                if (data && data.data) {
                    return {
                        data: data.data,
                        pagination: {
                            total: data.total,
                            per_page: data.per_page,
                            current_page: data.current_page,
                            last_page: data.last_page,
                        }
                    };
                }
                // If it's a direct array
                if (Array.isArray(data)) {
                    return { data: data };
                }
                // If it's a single object
                if (data) {
                    return { data: [data] };
                }
            }
            return { data: [] };
        } catch (error) {
            console.error('Technicians API error:', error);
            throw error;
        }
    },
    getOne: async (id) => {
        try {
            const response = await technicianService.getTechnician(id);
            if (response?.data?.status === 'success') {
                return { data: response.data.data };
            }
            return { data: null };
        } catch (error) {
            console.error('Technician API error:', error);
            throw error;
        }
    },
};

export const { Provider: TechnicianProvider, useResource: useTechnicians } = createDataContext(adapter, 'Technician');