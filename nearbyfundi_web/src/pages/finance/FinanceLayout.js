// src/pages/finance/FinanceLayout.js
import React, { useEffect, useMemo } from 'react';
import { Box, Paper, Tabs, Tab } from '@mui/material';
import { useLocation, useNavigate, Outlet } from 'react-router-dom';
import { useLanguage } from 'context/LanguageContext';
import { tFin } from './financelang';
import appConfig from '../../config';

import { ReportProvider } from 'context/ReportContext';
import { FinanceSubscriptionProvider } from 'context/FinanceSubscriptionContext';
import { FinanceTechnicianProvider } from 'context/FinanceTechnicianContext';
import { FinanceCustomerProvider } from 'context/FinanceCustomerContext';
import { FinanceRequestProvider } from 'context/FinanceRequestContext';

const colors = appConfig.app.colors;

const getTabs = (t) => [
    { label: t('fin.layout.subscriptions'), value: '/app/finance/subscriptions' },
    { label: t('fin.layout.technicians'), value: '/app/finance/technicians' },
    { label: t('fin.layout.customers'), value: '/app/finance/customers' },
    { label: t('fin.layout.requests'), value: '/app/finance/requests' },
];

const FinanceLayoutContent = () => {
    const location = useLocation();
    const navigate = useNavigate();

    const { language } = useLanguage();
    const t = (key, replacements) => tFin(language, key, replacements);
    const TABS = useMemo(() => getTabs(t), [language]);

    useEffect(() => {
        if (location.pathname === '/app/finance' || location.pathname === '/app/finance/') {
            navigate('/app/finance/subscriptions', { replace: true });
        }
    }, [location.pathname, navigate]);

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