// src/contexts/PortfolioContext.js
import { createDataContext } from './createDataContext';
import { portfolioService } from 'services/portfolio.service';

const adapter = {
    getAll: async (params) => {
        try {
            const response = await portfolioService.getPortfolios(params);
            console.log('Portfolios API response:', response);

            if (response?.data?.status === 'success') {
                const data = response.data.data;
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
                return { data: Array.isArray(data) ? data : [data] };
            }
            return { data: [] };
        } catch (error) {
            console.error('Portfolios API error:', error);
            throw error;
        }
    },
    getOne: null,
    create: (data) => portfolioService.createPortfolio(data),
    update: (id, data) => portfolioService.updatePortfolio(id, data),
    delete: (id) => portfolioService.deletePortfolio(id),
};

export const { Provider: PortfolioProvider, useResource: usePortfolios } = createDataContext(adapter, 'Portfolio');