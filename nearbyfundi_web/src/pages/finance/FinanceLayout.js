import React from 'react';
import { Box, Paper, Tabs, Tab } from '@mui/material';
import { useLocation, useNavigate, Outlet } from 'react-router-dom';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const TABS = [
    { label: 'Subscriptions', value: '/app/finance/subscriptions' },
    { label: 'Technicians', value: '/app/finance/technicians' },
    { label: 'Customers', value: '/app/finance/customers' },
];

const FinanceLayout = () => {
    const location = useLocation();
    const navigate = useNavigate();

    const currentTab =
        TABS.find((t) => location.pathname.startsWith(t.value))?.value || TABS[0].value;

    return (
        <Box
            sx={{
                width: '100%',
                maxWidth: '100%',
                mx: 0,
                px: 0,                 // no extra padding – Layout already gives some
                overflowX: 'hidden',
            }}
        >
            <Paper
                sx={{
                    borderRadius: 2,
                    border: `1px solid ${colors.middle}`,
                    mb: 2,
                    width: '100%',
                }}
            >
                <Tabs
                    value={currentTab}
                    onChange={(e, val) => navigate(val)}
                    variant="scrollable"
                    scrollButtons="auto"
                    sx={{ px: 1 }}
                >
                    {TABS.map((tab) => (
                        <Tab
                            key={tab.value}
                            label={tab.label}
                            value={tab.value}
                            sx={{ fontWeight: 600 }}
                        />
                    ))}
                </Tabs>
            </Paper>

            <Box sx={{ width: '100%', p: 0, m: 0 }}>
                <Outlet />
            </Box>
        </Box>
    );
};

export default FinanceLayout;