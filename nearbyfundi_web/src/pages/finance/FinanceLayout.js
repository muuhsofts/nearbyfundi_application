// src/pages/finance/FinanceLayout.js
import React, { useEffect } from 'react';
import { Box, Paper, Tabs, Tab } from '@mui/material';
import { useLocation, useNavigate, Outlet } from 'react-router-dom';
import appConfig from '../../config';

// Primary Report Provider
import { ReportProvider } from 'context/ReportContext';

// Import your module-specific Finance Providers
// Adjust these import paths to match your context file locations
import { FinanceSubscriptionProvider } from 'context/FinanceSubscriptionContext';
import { FinanceTechnicianProvider } from 'context/FinanceTechnicianContext';
import { FinanceCustomerProvider } from 'context/FinanceCustomerContext';
import { FinanceRequestProvider } from 'context/FinanceRequestContext';

const colors = appConfig.app.colors;

const TABS = [
    { label: 'Subscriptions', value: '/app/finance/subscriptions' },
    { label: 'Technicians', value: '/app/finance/technicians' },
    { label: 'Customers', value: '/app/finance/customers' },
    { label: 'Requests', value: '/app/finance/requests' },
];

const FinanceLayoutContent = () => {
    const location = useLocation();
    const navigate = useNavigate();

    // Auto-redirect base /app/finance route to first tab
    useEffect(() => {
        if (location.pathname === '/app/finance' || location.pathname === '/app/finance/') {
            navigate('/app/finance/subscriptions', { replace: true });
        }
    }, [location.pathname, navigate]);

    // Active tab matching (returns false if no tab matches to prevent MUI console error)
    const currentTab = TABS.find((tab) => location.pathname.startsWith(tab.value))?.value || false;

    return (
        <Box sx={{ width: '100%', maxWidth: '100%', mx: 0, px: 0, overflowX: 'hidden' }}>
            <Paper
                elevation={0}
                sx={{
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    mb: 3,
                    width: '100%',
                    bgcolor: '#fff',
                }}
            >
                <Tabs
                    value={currentTab}
                    onChange={(e, val) => navigate(val)}
                    variant="scrollable"
                    scrollButtons="auto"
                    allowScrollButtonsMobile
                    sx={{
                        px: 1,
                        minHeight: 48,
                        '& .MuiTab-root': {
                            fontWeight: 600,
                            textTransform: 'none',
                            minHeight: 48,
                        },
                    }}
                >
                    {TABS.map((tab) => (
                        <Tab key={tab.value} label={tab.label} value={tab.value} />
                    ))}
                </Tabs>
            </Paper>

            <Box sx={{ width: '100%', p: 0, m: 0 }}>
                <Outlet />
            </Box>
        </Box>
    );
};

// Provider composer helper for Finance module
const FINANCE_PROVIDERS = [
    ReportProvider,
    FinanceSubscriptionProvider,
    FinanceTechnicianProvider,
    FinanceCustomerProvider,
    FinanceRequestProvider,
];

const FinanceProviders = ({ children }) =>
    FINANCE_PROVIDERS.reduceRight(
        (acc, Provider) => (Provider ? <Provider>{acc}</Provider> : acc),
        children
    );

const FinanceLayout = () => {
    return (
        <FinanceProviders>
            <FinanceLayoutContent />
        </FinanceProviders>
    );
};

export default FinanceLayout;