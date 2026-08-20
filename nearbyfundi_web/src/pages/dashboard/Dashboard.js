// src/pages/dashboard/Dashboard.js
import React, { useState, useEffect } from 'react';
import { Box, Grid, Paper, IconButton, CircularProgress, Button, Typography, useTheme } from '@mui/material';
import { Refresh as RefreshIcon } from '@mui/icons-material';
import {
    People as PeopleIcon,
    Build as BuildIcon,
    Person as PersonIcon,
    Assignment as RequestIcon,
    AttachMoney as MoneyIcon,   // <-- new icon for revenue
} from '@mui/icons-material';
import { useDashboardManagement } from 'hooks/useDashboard';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import DashboardFilters from './components/DashboardFilters';
import {
    StatCard,
    StatusDistribution,
    // ServicesBarChart,          // removed
    WeeklyRequestsChart,
    UserTrendChart,
    TopTechniciansChart,
    // TechnicianEngagementTable, // removed
    PostsTrendChart,
    RequestsByAreaChart,
    // TechnicianStatusChart,    // removed
    RecentRequestsList,
    QuickStats,
    UsersByRole,
    WeeklyRevenueChart,          // new component
} from './dashboard_components';

const Dashboard = () => {
    const theme = useTheme();
    const { can } = usePermissions();
    const [period, setPeriod] = useState('');
    const [date, setDate] = useState(null);
    const [loading, setLoading] = useState(false);

    const {
        analytics,
        summary,
        loading: contextLoading,
        error,
        getDashboardAnalytics,
        getDashboardSummary,
        clearError,
    } = useDashboardManagement();

    const canViewDashboard = can('dashboard.view');

    useEffect(() => {
        if (canViewDashboard) fetchDashboardData();
    }, [canViewDashboard]);

    const fetchDashboardData = async () => {
        setLoading(true);
        try {
            const params = {};
            if (period) {
                params.period = period;
                if (date) {
                    if (period === 'daily') params.date = date.toISOString().split('T')[0];
                    else if (period === 'monthly') params.date = date.toISOString().slice(0, 7);
                    else if (period === 'yearly') params.date = date.getFullYear().toString();
                }
            }
            await Promise.all([getDashboardAnalytics(params), getDashboardSummary()]);
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Failed to load dashboard data' });
        } finally {
            setLoading(false);
        }
    };

    const handleRefresh = () => fetchDashboardData();

    if (!canViewDashboard) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="80vh">
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <Typography variant="h5" color="error">Access Denied</Typography>
                    <Typography color="text.secondary">You do not have permission to view the dashboard.</Typography>
                </Paper>
            </Box>
        );
    }

    if (error) {
        return (
            <Box p={3}>
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <Typography color="error">{error}</Typography>
                    <Button variant="contained" onClick={clearError} sx={{ mt: 2 }}>Retry</Button>
                </Paper>
            </Box>
        );
    }

    const isLoading = loading || contextLoading;
    const users = analytics?.users || {};
    const technicians = analytics?.technicians || {};
    const customers = analytics?.customers || {};
    const services = analytics?.services || {};
    const requests = analytics?.service_requests || {};
    const statsData = summary || {};
    const totalRevenue = analytics?.total_revenue || 0;

    return (
        <Box sx={{ p: { xs: 2, sm: 3 } }}>
            <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
                <Typography variant="h4" fontWeight="700">📊 Dashboard</Typography>
                <IconButton onClick={handleRefresh} disabled={isLoading}>
                    <RefreshIcon />
                </IconButton>
            </Box>

            <DashboardFilters
                period={period}
                setPeriod={setPeriod}
                date={date}
                setDate={setDate}
                refetch={fetchDashboardData}
            />

            {isLoading ? (
                <Box display="flex" justifyContent="center" py={8}>
                    <CircularProgress />
                </Box>
            ) : (
                <>
                    <Grid container spacing={3} sx={{ mb: 4 }}>
                        <Grid item xs={12} sm={6} md={3}>
                            <StatCard title="Total Users" value={users.total || 0} icon={<PeopleIcon />} color={theme.palette.primary.main}
                                      subtitle={`${users.active || 0} active / ${users.inactive || 0} inactive`} />
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <StatCard title="Technicians" value={technicians.total || 0} icon={<BuildIcon />} color={theme.palette.info.main}
                                      subtitle={`${technicians.verified || 0} verified / ${technicians.online || 0} online`} />
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <StatCard title="Customers" value={customers.total || 0} icon={<PersonIcon />} color={theme.palette.success.main}
                                      subtitle={`${customers.active || 0} active customers`} />
                        </Grid>
                        <Grid item xs={12} sm={6} md={3}>
                            <StatCard title="Total Requests" value={requests.total || 0} icon={<RequestIcon />} color={theme.palette.warning.main}
                                      subtitle={`Pending: ${requests?.status_breakdown?.pending || 0}`} />
                        </Grid>
                    </Grid>

                    {/* New Revenue Stat Card */}
                    <Grid container spacing={3} sx={{ mb: 4 }}>
                        <Grid item xs={12} sm={6} md={3}>
                            <StatCard title="Total Revenue" value={`Tshs-${totalRevenue.toFixed(2)}`} icon={<MoneyIcon />} color={theme.palette.success.main} />
                        </Grid>
                    </Grid>

                    <Grid container spacing={3} sx={{ mb: 4 }}>
                        <Grid item xs={12} md={6}>
                            <Paper sx={{ p: 3, borderRadius: 3, height: '100%' }}>
                                <WeeklyRequestsChart data={analytics?.weekly_requests} />
                            </Paper>
                        </Grid>
                        <Grid item xs={12} md={6}>
                            <Paper sx={{ p: 3, borderRadius: 3, height: '100%' }}>
                                <UserTrendChart data={analytics?.user_trend} />
                            </Paper>
                        </Grid>
                    </Grid>

                    {/* Replacing ServicesBarChart with WeeklyRevenueChart */}
                    <Grid container spacing={3} sx={{ mb: 4 }}>
                        <Grid item xs={12} md={6}>
                            <Paper sx={{ p: 3, borderRadius: 3, height: '100%' }}>
                                <WeeklyRevenueChart data={analytics?.weekly_revenue} />
                            </Paper>
                        </Grid>
                        <Grid item xs={12} md={6}>
                            <Paper sx={{ p: 3, borderRadius: 3, height: '100%' }}>
                                <TopTechniciansChart data={analytics?.top_technicians} />
                            </Paper>
                        </Grid>
                    </Grid>

                    <Grid container spacing={3} sx={{ mb: 4 }}>
                        <Grid item xs={12} md={6}>
                            {/* TechnicianEngagementTable removed */}
                            <Paper sx={{ p: 3, borderRadius: 3, height: '100%' }}>
                                <PostsTrendChart data={analytics?.posts_trend} />
                            </Paper>
                        </Grid>
                        <Grid item xs={12} md={6}>
                            {/*<Paper sx={{ p: 3, borderRadius: 3, height: '100%' }}>*/}
                            {/*    <RequestsByAreaChart data={analytics?.requests_by_area} />*/}
                            {/*</Paper>*/}
                        </Grid>
                    </Grid>

                    <Grid container spacing={3} sx={{ mb: 4 }}>
                        <Grid item xs={12} md={6}>
                            <StatusDistribution data={requests?.by_status || statsData?.requests_by_status || []} title="Request Status Distribution" />
                        </Grid>
                        {/* TechnicianStatusChart removed */}
                    </Grid>

                    <Grid container spacing={3} sx={{ mb: 4 }}>
                        {/*<Grid item xs={12}>*/}
                        {/*    <QuickStats users={users} technicians={technicians} services={services} requests={requests} />*/}
                        {/*</Grid>*/}
                    </Grid>



                    {requests.recent && requests.recent.length > 0 && (
                        <RecentRequestsList requests={requests.recent} />
                    )}
                </>
            )}
        </Box>
    );
};

export default Dashboard;