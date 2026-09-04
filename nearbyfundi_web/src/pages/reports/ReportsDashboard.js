// src/pages/reports/ReportsDashboard.jsx
import React, { useState, useEffect } from 'react';
import {
    Box, Paper, Typography, Tabs, Tab, TextField, InputAdornment,
    Button, FormControl, InputLabel, Select, MenuItem, CircularProgress,
    Alert, alpha, Chip, Avatar, Stack, LinearProgress, TableCell, TableRow, Tooltip,
} from '@mui/material';
import {
    People as PeopleIcon, Build as BuildIcon, Assignment as RequestIcon,
    Category as CategoryIcon, Comment as CommentIcon, Photo as PhotoIcon,
    Search as SearchIcon, Refresh as RefreshIcon, Download as DownloadIcon,
    Verified as VerifiedIcon, Star as StarIcon, Person as PersonIcon,
    CheckCircle as CheckCircleIcon, Cancel as CancelIcon, TrendingUp as TrendingUpIcon,
    Subscriptions as SubscriptionIcon, Payment as PaymentIcon, AttachMoney as MoneyIcon,
    CalendarToday as CalendarIcon, Timer as TimerIcon, Pending as PendingIcon,
    Clear as ClearIcon,
} from '@mui/icons-material';

import { reportService } from 'services/report.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import * as XLSX from 'xlsx';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

import {
    ReportFilters, StatusChip, TabPanel, ReportTable,
    ReportExportMenu, TrendChart, SummaryCards, BlogStats,
} from './components';

import appConfig from '../../config';

const colors = appConfig.app.colors;

const formatDate = (dateStr) => {
    if (!dateStr) return '—';
    try {
        return new Date(dateStr).toLocaleDateString('en-US', {
            year: 'numeric', month: 'short', day: 'numeric',
            hour: '2-digit', minute: '2-digit',
        });
    } catch { return '—'; }
};

const formatCurrency = (amount) => {
    if (!amount) return '0';
    return `TZS ${parseFloat(amount).toLocaleString()}`;
};

const getStatusColor = (status) => {
    const map = {
        pending: '#f59e0b', active: '#10b981', expired: '#ef4444',
        cancelled: '#6b7280', approved: '#10b981', rejected: '#ef4444',
        paid: '#10b981', unpaid: '#f59e0b',
    };
    return map[status] || '#6b7280';
};

const getStatusLabel = (status) => {
    const map = {
        pending: 'Pending', active: 'Active', expired: 'Expired',
        cancelled: 'Cancelled', approved: 'Approved', rejected: 'Rejected',
        paid: 'Paid', unpaid: 'Unpaid',
    };
    return map[status] || status || 'Unknown';
};

const ReportsDashboard = () => {
    const { can } = usePermissions();
    const canViewReports = can('reports.view');

    const [tabValue, setTabValue] = useState(0);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [search, setSearch] = useState('');
    const [filterStatus, setFilterStatus] = useState('');
    const [filterVerified, setFilterVerified] = useState('');
    const [filterArea, setFilterArea] = useState('');
    const [filterRole, setFilterRole] = useState('');
    const [filterPaymentMethod, setFilterPaymentMethod] = useState('');
    const [period, setPeriod] = useState('');
    const [periodDate, setPeriodDate] = useState(null);

    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [reportData, setReportData] = useState(null);
    const [exportMenuAnchor, setExportMenuAnchor] = useState(null);

    // Incremental number (no real IDs)
    const getRowNumber = (index) => page * rowsPerPage + index + 1;

    const getListData = () => {
        if (!reportData) return [];
        let data = [];
        switch (tabValue) {
            case 0: case 1: case 2: data = reportData?.data?.data; break;
            case 3: data = reportData?.data; break;
            case 4: data = []; break;
            case 5: data = reportData?.technicians_with_most_portfolios; break;
            case 6: data = reportData?.data?.data; break;
            default: data = [];
        }
        return Array.isArray(data) ? data : [];
    };

    const getTotalCount = () => {
        if (!reportData) return 0;
        if (tabValue <= 2 || tabValue === 6) return reportData?.data?.total || 0;
        if (tabValue === 3 || tabValue === 5) return getListData().length;
        return 0;
    };

    const fetchReportData = async () => {
        if (!canViewReports) return;
        setLoading(true);
        setError(null);

        const params = {
            page: page + 1,
            per_page: rowsPerPage,
            period: period || undefined,
            date: periodDate ? periodDate.toISOString().split('T')[0] : undefined,
        };
        if (search) params.search = search;
        if (filterStatus) params.status = filterStatus;
        if (filterVerified) params.verified = filterVerified;
        if (filterArea) params.area = filterArea;
        if (filterRole) params.role = filterRole;
        if (filterPaymentMethod) params.payment_method = filterPaymentMethod;

        try {
            let response;
            switch (tabValue) {
                case 0: response = await reportService.getUsersReport(params); break;
                case 1: response = await reportService.getTechniciansReport(params); break;
                case 2: response = await reportService.getRequestsReport(params); break;
                case 3: response = await reportService.getServicesReport(params); break;
                case 4: response = await reportService.getBlogReport(params); break;
                case 5: response = await reportService.getPortfolioReport(params); break;
                case 6: response = await reportService.getSubscriptionsReport(params); break;
                default: return;
            }
            if (response?.data?.status === 'success') {
                setReportData(response.data.data);
            } else {
                setReportData(null);
            }
        } catch (err) {
            setError(err.message || 'Failed to load report data');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canViewReports) fetchReportData();
        // eslint-disable-next-line
    }, [tabValue, page, rowsPerPage, search, filterStatus, filterVerified,
        filterArea, filterRole, filterPaymentMethod, period, periodDate, canViewReports]);

    const handleRefresh = () => {
        fetchReportData();
        showSnackbar({ type: 'success', message: 'Report refreshed' });
    };

    const handleTabChange = (_, newValue) => {
        setTabValue(newValue);
        setPage(0);
    };

    // ---------- Export helpers (same logic) ----------
    const getCurrentTabLabel = () => {
        const labels = ['Users', 'Technicians', 'Requests', 'Services', 'Blog', 'Portfolio', 'Subscriptions'];
        return labels[tabValue] || 'Report';
    };

    const getExportData = () => {
        const list = getListData();
        if (tabValue === 0) return list.map((u, i) => [getRowNumber(i), u.name || 'N/A', u.email || 'N/A', u.phone || 'N/A', u.roles?.map(r => r.name).join(', ') || 'N/A', u.status || 'inactive', formatDate(u.created_at)]);
        if (tabValue === 1) return list.map((t, i) => [getRowNumber(i), t.user?.name || 'N/A', t.user?.email || 'N/A', t.area || 'N/A', t.rating || 0, t.verified ? 'Yes' : 'No', formatDate(t.created_at)]);
        if (tabValue === 2) return list.map((r, i) => [getRowNumber(i), r.customer?.name || 'N/A', r.technician?.user?.name || 'N/A', r.service?.name || 'N/A', r.status || 'N/A', formatDate(r.created_at)]);
        if (tabValue === 3) return list.map((s, i) => [getRowNumber(i), s.name || 'N/A', s.requests_count || 0]);
        if (tabValue === 4) {
            const stats = reportData?.stats || {};
            return [['Total Posts', stats.total_posts || 0], ['Total Comments', stats.total_comments || 0], ['Total Likes', stats.total_likes || 0], ['Avg Comments/Post', stats.avg_comments_per_post || 0]];
        }
        if (tabValue === 5) return list.map((item, i) => [getRowNumber(i), item.technician?.user?.name || 'Unknown', item.count || 0]);
        if (tabValue === 6) return list.map((s, i) => [getRowNumber(i), s.user?.name || 'N/A', s.rate_card?.name || 'N/A', s.amount || 'N/A', s.status || 'N/A', s.payment_method || 'N/A', formatDate(s.created_at), formatDate(s.expiry_date)]);
        return [];
    };

    const getExportHeaders = () => {
        switch (tabValue) {
            case 0: return ['#', 'Name', 'Email', 'Phone', 'Role', 'Status', 'Created'];
            case 1: return ['#', 'Technician', 'Email', 'Area', 'Rating', 'Verified', 'Created'];
            case 2: return ['#', 'Customer', 'Technician', 'Service', 'Status', 'Created'];
            case 3: return ['#', 'Service Name', 'Total Requests'];
            case 4: return ['Metric', 'Value'];
            case 5: return ['#', 'Technician', 'Portfolio Items'];
            case 6: return ['#', 'User', 'Plan', 'Amount', 'Status', 'Payment Method', 'Created', 'Expiry'];
            default: return [];
        }
    };

    const exportToCSV = () => {
        const headers = getExportHeaders();
        const rows = getExportData();
        if (!rows.length) return showSnackbar({ type: 'warning', message: 'No data to export' });
        const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = `${getCurrentTabLabel()}_Report_${new Date().toISOString().split('T')[0]}.csv`;
        link.click();
        showSnackbar({ type: 'success', message: 'CSV exported' });
        setExportMenuAnchor(null);
    };

    const exportToExcel = () => {
        const headers = getExportHeaders();
        const rows = getExportData();
        if (!rows.length) return showSnackbar({ type: 'warning', message: 'No data to export' });
        const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
        const wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, getCurrentTabLabel());
        XLSX.writeFile(wb, `${getCurrentTabLabel()}_Report_${new Date().toISOString().split('T')[0]}.xlsx`);
        showSnackbar({ type: 'success', message: 'Excel exported' });
        setExportMenuAnchor(null);
    };

    const exportToPDF = () => {
        const headers = getExportHeaders();
        const rows = getExportData();
        if (!rows.length) return showSnackbar({ type: 'warning', message: 'No data to export' });
        const doc = new jsPDF('landscape', 'pt', 'a4');
        doc.setFillColor('#0f766e');
        doc.rect(0, 0, doc.internal.pageSize.getWidth(), 55, 'F');
        doc.setTextColor('#fff');
        doc.setFontSize(18);
        doc.text(`${getCurrentTabLabel()} Report`, 40, 35);
        autoTable(doc, {
            head: [headers], body: rows, startY: 70,
            headStyles: { fillColor: '#0f766e', textColor: '#fff' },
            styles: { fontSize: 9 },
            alternateRowStyles: { fillColor: '#f8fafc' },
        });
        doc.save(`${getCurrentTabLabel()}_Report_${new Date().toISOString().split('T')[0]}.pdf`);
        showSnackbar({ type: 'success', message: 'PDF exported' });
        setExportMenuAnchor(null);
    };

    if (!canViewReports) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="70vh">
                <Paper elevation={0} sx={{ p: 5, textAlign: 'center', borderRadius: 3, border: '1px solid', borderColor: 'divider' }}>
                    <Typography variant="h5" color="error" fontWeight={700}>Access Denied</Typography>
                </Paper>
            </Box>
        );
    }

    if (error) {
        return (
            <Box p={3}>
                <Alert severity="error" variant="filled" sx={{ borderRadius: 2 }}
                       action={<Button color="inherit" size="small" onClick={() => { setError(null); fetchReportData(); }}>Retry</Button>}>
                    {error}
                </Alert>
            </Box>
        );
    }

    return (
        <Box sx={{ p: { xs: 1.5, sm: 2.5 }, bgcolor: '#f8fafc', minHeight: '100vh' }}>
            {/* ========== HEADER ========== */}
            <Paper elevation={0} sx={{
                p: { xs: 2.5, sm: 3 }, borderRadius: 3, mb: 3,
                border: '1px solid', borderColor: 'divider', bgcolor: '#fff',
            }}>
                <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between"
                       alignItems={{ xs: 'stretch', sm: 'center' }} spacing={2} mb={2.5}>
                    <Box>
                        <Typography variant="h4" fontWeight={800} color="#0f172a">
                            Reports Dashboard
                        </Typography>
                        <Typography variant="body2" color="text.secondary" fontWeight={500} mt={0.5}>
                            Comprehensive reports with period filters and trends
                        </Typography>
                    </Box>
                    <Stack direction="row" spacing={1.5}>
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={handleRefresh}
                            disabled={loading}
                            sx={{
                                borderRadius: 2, fontWeight: 600, textTransform: 'none',
                                borderColor: '#e2e8f0', color: '#334155',
                                '&:hover': { borderColor: '#94a3b8', bgcolor: '#f1f5f9' },
                            }}
                        >
                            Refresh
                        </Button>
                        <Button
                            variant="contained"
                            startIcon={<DownloadIcon />}
                            onClick={(e) => setExportMenuAnchor(e.currentTarget)}
                            sx={{
                                borderRadius: 2, fontWeight: 700, textTransform: 'none',
                                boxShadow: 'none', bgcolor: '#0f766e',
                                '&:hover': { bgcolor: '#0d5c56', boxShadow: '0 4px 14px rgba(15,118,110,0.3)' },
                            }}
                        >
                            Export
                        </Button>
                        <ReportExportMenu
                            anchorEl={exportMenuAnchor}
                            open={Boolean(exportMenuAnchor)}
                            onClose={() => setExportMenuAnchor(null)}
                            onExportCSV={exportToCSV}
                            onExportExcel={exportToExcel}
                            onExportPDF={exportToPDF}
                        />
                    </Stack>
                </Stack>

                <ReportFilters
                    period={period} setPeriod={setPeriod}
                    periodDate={periodDate} setPeriodDate={setPeriodDate}
                    onRefresh={handleRefresh} loading={loading}
                />
            </Paper>

            {/* ========== TABS + CONTENT ========== */}
            <Paper elevation={0} sx={{
                borderRadius: 3, overflow: 'hidden',
                border: '1px solid', borderColor: 'divider', bgcolor: '#fff',
            }}>
                <Tabs
                    value={tabValue}
                    onChange={handleTabChange}
                    variant="scrollable"
                    scrollButtons="auto"
                    sx={{
                        borderBottom: '1px solid', borderColor: 'divider',
                        bgcolor: '#f8fafc',
                        '& .MuiTab-root': {
                            fontWeight: 600, textTransform: 'none', minHeight: 56,
                            color: '#64748b', px: 2.5,
                            '&.Mui-selected': { color: '#0f766e' },
                        },
                        '& .MuiTabs-indicator': { bgcolor: '#0f766e', height: 3 },
                    }}
                >
                    <Tab icon={<PeopleIcon sx={{ fontSize: 20 }} />} iconPosition="start" label="Users" />
                    <Tab icon={<BuildIcon sx={{ fontSize: 20 }} />} iconPosition="start" label="Technicians" />
                    <Tab icon={<RequestIcon sx={{ fontSize: 20 }} />} iconPosition="start" label="Requests" />
                    <Tab icon={<CategoryIcon sx={{ fontSize: 20 }} />} iconPosition="start" label="Services" />
                    <Tab icon={<CommentIcon sx={{ fontSize: 20 }} />} iconPosition="start" label="Blog" />
                    <Tab icon={<PhotoIcon sx={{ fontSize: 20 }} />} iconPosition="start" label="Portfolio" />
                    <Tab icon={<SubscriptionIcon sx={{ fontSize: 20 }} />} iconPosition="start" label="Subscriptions" />
                </Tabs>

                {loading && (
                    <Box display="flex" justifyContent="center" py={8}>
                        <CircularProgress size={38} thickness={4} sx={{ color: '#0f766e' }} />
                    </Box>
                )}

                {/* ===== USERS ===== */}
                <TabPanel value={tabValue} index={0}>
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        <SummaryCards items={[
                            { title: 'Total Users', value: reportData?.stats?.total || 0, icon: <PeopleIcon />, color: '#0f766e' },
                            { title: 'Active', value: reportData?.stats?.active || 0, icon: <CheckCircleIcon />, color: '#10b981' },
                            { title: 'Inactive', value: reportData?.stats?.inactive || 0, icon: <CancelIcon />, color: '#64748b' },
                            { title: 'New (Period)', value: reportData?.trend?.length || 0, icon: <TrendingUpIcon />, color: '#0ea5e9' },
                        ]} />
                        {reportData?.trend?.length > 0 && <TrendChart data={reportData.trend} label="New Users" />}

                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} my={3} flexWrap="wrap">
                            <TextField size="small" placeholder="Search users…" value={search}
                                       onChange={(e) => setSearch(e.target.value)}
                                       InputProps={{
                                           startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" color="action" /></InputAdornment>,
                                           endAdornment: search ? <InputAdornment position="end"><ClearIcon fontSize="small" sx={{ cursor: 'pointer' }} onClick={() => setSearch('')} /></InputAdornment> : null,
                                       }}
                                       sx={{ minWidth: 240, '& .MuiOutlinedInput-root': { borderRadius: 2, bgcolor: '#f1f5f9', '& fieldset': { borderColor: 'transparent' } } }}
                            />
                            <FormControl size="small" sx={{ minWidth: 140 }}>
                                <InputLabel>Role</InputLabel>
                                <Select value={filterRole} label="Role" onChange={(e) => setFilterRole(e.target.value)}
                                        sx={{ borderRadius: 2, bgcolor: '#f1f5f9', '& .MuiOutlinedInput-notchedOutline': { borderColor: 'transparent' } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="CUSTOMER">Customer</MenuItem>
                                    <MenuItem value="FUNDI">Fundi</MenuItem>
                                    <MenuItem value="ADMINISTRATOR">Admin</MenuItem>
                                    <MenuItem value="MANAGER">Manager</MenuItem>
                                </Select>
                            </FormControl>
                            <FormControl size="small" sx={{ minWidth: 140 }}>
                                <InputLabel>Status</InputLabel>
                                <Select value={filterStatus} label="Status" onChange={(e) => setFilterStatus(e.target.value)}
                                        sx={{ borderRadius: 2, bgcolor: '#f1f5f9', '& .MuiOutlinedInput-notchedOutline': { borderColor: 'transparent' } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="active">Active</MenuItem>
                                    <MenuItem value="inactive">Inactive</MenuItem>
                                    <MenuItem value="pending">Pending</MenuItem>
                                </Select>
                            </FormControl>
                        </Stack>

                        <ReportTable
                            columns={[
                                { key: 'no', label: '#' }, { key: 'user', label: 'User' },
                                { key: 'email', label: 'Email' }, { key: 'phone', label: 'Phone' },
                                { key: 'role', label: 'Role' }, { key: 'status', label: 'Status' },
                                { key: 'created', label: 'Created' },
                            ]}
                            rows={getListData().map((user, index) => (
                                <TableRow key={user.id || index} hover>
                                    <TableCell><Typography variant="body2" fontWeight={600} color="text.secondary">{getRowNumber(index)}</Typography></TableCell>
                                    <TableCell>
                                        <Stack direction="row" spacing={1.25} alignItems="center">
                                            <Avatar sx={{ width: 36, height: 36, bgcolor: '#0f766e', fontSize: 14, fontWeight: 700 }}>
                                                {user.name?.charAt(0).toUpperCase() || <PersonIcon fontSize="small" />}
                                            </Avatar>
                                            <Typography variant="body2" fontWeight={600}>{user.name || 'N/A'}</Typography>
                                        </Stack>
                                    </TableCell>
                                    <TableCell><Typography variant="body2">{user.email || 'N/A'}</Typography></TableCell>
                                    <TableCell><Typography variant="body2">{user.phone || 'N/A'}</Typography></TableCell>
                                    <TableCell>
                                        {user.roles?.map(r => (
                                            <Chip key={r.id} label={r.name} size="small"
                                                  sx={{ mr: 0.5, fontWeight: 600, bgcolor: '#f1f5f9', border: '1px solid #e2e8f0', height: 24 }} />
                                        ))}
                                    </TableCell>
                                    <TableCell><StatusChip status={user.status || 'inactive'} /></TableCell>
                                    <TableCell><Typography variant="body2" color="text.secondary">{formatDate(user.created_at)}</Typography></TableCell>
                                </TableRow>
                            ))}
                            total={getTotalCount()} page={page} rowsPerPage={rowsPerPage}
                            onPageChange={(_, p) => setPage(p)}
                            onRowsPerPageChange={(e) => { setRowsPerPage(+e.target.value); setPage(0); }}
                            loading={loading} emptyMessage="No users found"
                        />
                    </Box>
                </TabPanel>

                {/* ===== TECHNICIANS ===== */}
                <TabPanel value={tabValue} index={1}>
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        <SummaryCards items={[
                            { title: 'Total Technicians', value: reportData?.stats?.total || 0, icon: <BuildIcon />, color: '#0f766e' },
                            { title: 'Verified', value: reportData?.stats?.verified || 0, icon: <VerifiedIcon />, color: '#10b981' },
                            { title: 'New (Period)', value: reportData?.trend?.length || 0, icon: <TrendingUpIcon />, color: '#0ea5e9' },
                        ]} />
                        {reportData?.trend?.length > 0 && <TrendChart data={reportData.trend} label="New Technicians" color="#10b981" />}

                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} my={3}>
                            <TextField size="small" placeholder="Search technicians…" value={search}
                                       onChange={(e) => setSearch(e.target.value)}
                                       InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" color="action" /></InputAdornment> }}
                                       sx={{ minWidth: 240, '& .MuiOutlinedInput-root': { borderRadius: 2, bgcolor: '#f1f5f9', '& fieldset': { borderColor: 'transparent' } } }}
                            />
                            <FormControl size="small" sx={{ minWidth: 140 }}>
                                <InputLabel>Verified</InputLabel>
                                <Select value={filterVerified} label="Verified" onChange={(e) => setFilterVerified(e.target.value)}
                                        sx={{ borderRadius: 2, bgcolor: '#f1f5f9', '& .MuiOutlinedInput-notchedOutline': { borderColor: 'transparent' } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="true">Verified</MenuItem>
                                    <MenuItem value="false">Unverified</MenuItem>
                                </Select>
                            </FormControl>
                            <TextField size="small" placeholder="Filter by area…" value={filterArea}
                                       onChange={(e) => setFilterArea(e.target.value)}
                                       sx={{ minWidth: 180, '& .MuiOutlinedInput-root': { borderRadius: 2, bgcolor: '#f1f5f9', '& fieldset': { borderColor: 'transparent' } } }}
                            />
                        </Stack>

                        <ReportTable
                            columns={[
                                { key: 'no', label: '#' }, { key: 'technician', label: 'Technician' },
                                { key: 'email', label: 'Email' }, { key: 'area', label: 'Area' },
                                { key: 'rating', label: 'Rating' }, { key: 'verified', label: 'Verified' },
                                { key: 'created', label: 'Created' },
                            ]}
                            rows={getListData().map((tech, index) => (
                                <TableRow key={tech.id || index} hover>
                                    <TableCell><Typography variant="body2" fontWeight={600} color="text.secondary">{getRowNumber(index)}</Typography></TableCell>
                                    <TableCell>
                                        <Stack direction="row" spacing={1.25} alignItems="center">
                                            <Avatar src={tech.profile_photo} sx={{ width: 36, height: 36, bgcolor: '#0f766e', fontSize: 14, fontWeight: 700 }}>
                                                {tech.user?.name?.charAt(0).toUpperCase() || <BuildIcon fontSize="small" />}
                                            </Avatar>
                                            <Stack direction="row" spacing={0.5} alignItems="center">
                                                <Typography variant="body2" fontWeight={600}>{tech.user?.name || 'N/A'}</Typography>
                                                {tech.verified && <VerifiedIcon sx={{ fontSize: 16, color: '#10b981' }} />}
                                            </Stack>
                                        </Stack>
                                    </TableCell>
                                    <TableCell><Typography variant="body2">{tech.user?.email || 'N/A'}</Typography></TableCell>
                                    <TableCell><Typography variant="body2">{tech.area || 'N/A'}</Typography></TableCell>
                                    <TableCell>
                                        <Stack direction="row" spacing={0.5} alignItems="center">
                                            <StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />
                                            <Typography variant="body2" fontWeight={600}>{tech.rating || 0}</Typography>
                                        </Stack>
                                    </TableCell>
                                    <TableCell>
                                        <Chip label={tech.verified ? 'Yes' : 'No'} size="small"
                                              sx={{
                                                  fontWeight: 700, height: 26,
                                                  bgcolor: tech.verified ? '#d1fae5' : '#f1f5f9',
                                                  color: tech.verified ? '#047857' : '#64748b',
                                                  border: `1.5px solid ${tech.verified ? '#10b981' : '#cbd5e1'}`,
                                              }} />
                                    </TableCell>
                                    <TableCell><Typography variant="body2" color="text.secondary">{formatDate(tech.created_at)}</Typography></TableCell>
                                </TableRow>
                            ))}
                            total={getTotalCount()} page={page} rowsPerPage={rowsPerPage}
                            onPageChange={(_, p) => setPage(p)}
                            onRowsPerPageChange={(e) => { setRowsPerPage(+e.target.value); setPage(0); }}
                            loading={loading} emptyMessage="No technicians found"
                        />
                    </Box>
                </TabPanel>

                {/* ===== REQUESTS ===== */}
                <TabPanel value={tabValue} index={2}>
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        <SummaryCards items={[
                            { title: 'Total Requests', value: reportData?.stats?.total || 0, icon: <RequestIcon />, color: '#0f766e' },
                            ...(reportData?.stats?.by_status || []).map(s => ({
                                title: s.status, value: s.count, icon: <CheckCircleIcon />,
                                color: getStatusColor(s.status), md: 1.5,
                            })),
                        ]} />
                        {reportData?.trend?.length > 0 && <TrendChart data={reportData.trend} label="Requests" />}

                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} my={3}>
                            <TextField size="small" placeholder="Search requests…" value={search}
                                       onChange={(e) => setSearch(e.target.value)}
                                       InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" color="action" /></InputAdornment> }}
                                       sx={{ minWidth: 240, '& .MuiOutlinedInput-root': { borderRadius: 2, bgcolor: '#f1f5f9', '& fieldset': { borderColor: 'transparent' } } }}
                            />
                            <FormControl size="small" sx={{ minWidth: 150 }}>
                                <InputLabel>Status</InputLabel>
                                <Select value={filterStatus} label="Status" onChange={(e) => setFilterStatus(e.target.value)}
                                        sx={{ borderRadius: 2, bgcolor: '#f1f5f9', '& .MuiOutlinedInput-notchedOutline': { borderColor: 'transparent' } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="pending">Pending</MenuItem>
                                    <MenuItem value="accepted">Accepted</MenuItem>
                                    <MenuItem value="in_progress">In Progress</MenuItem>
                                    <MenuItem value="completed">Completed</MenuItem>
                                    <MenuItem value="cancelled">Cancelled</MenuItem>
                                    <MenuItem value="rejected">Rejected</MenuItem>
                                </Select>
                            </FormControl>
                        </Stack>

                        <ReportTable
                            columns={[
                                { key: 'no', label: '#' }, { key: 'customer', label: 'Customer' },
                                { key: 'technician', label: 'Technician' }, { key: 'service', label: 'Service' },
                                { key: 'status', label: 'Status' }, { key: 'created', label: 'Created' },
                            ]}
                            rows={getListData().map((req, index) => (
                                <TableRow key={req.id || index} hover>
                                    <TableCell><Typography variant="body2" fontWeight={600} color="text.secondary">{getRowNumber(index)}</Typography></TableCell>
                                    <TableCell><Typography variant="body2" fontWeight={500}>{req.customer?.name || 'N/A'}</Typography></TableCell>
                                    <TableCell><Typography variant="body2">{req.technician?.user?.name || 'N/A'}</Typography></TableCell>
                                    <TableCell><Typography variant="body2">{req.service?.name || 'N/A'}</Typography></TableCell>
                                    <TableCell><StatusChip status={req.status} /></TableCell>
                                    <TableCell><Typography variant="body2" color="text.secondary">{formatDate(req.created_at)}</Typography></TableCell>
                                </TableRow>
                            ))}
                            total={getTotalCount()} page={page} rowsPerPage={rowsPerPage}
                            onPageChange={(_, p) => setPage(p)}
                            onRowsPerPageChange={(e) => { setRowsPerPage(+e.target.value); setPage(0); }}
                            loading={loading} emptyMessage="No requests found"
                        />
                    </Box>
                </TabPanel>

                {/* ===== SERVICES ===== */}
                <TabPanel value={tabValue} index={3}>
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        <SummaryCards items={[
                            { title: 'Total Services', value: reportData?.stats?.total || 0, icon: <CategoryIcon />, color: '#0f766e', md: 4 },
                            { title: 'Total Requests', value: reportData?.stats?.total_requests || 0, icon: <RequestIcon />, color: '#10b981', md: 4 },
                            { title: 'Avg Requests/Service', value: reportData?.stats?.avg_per_service || 0, icon: <TrendingUpIcon />, color: '#0ea5e9', md: 4 },
                        ]} />
                        <ReportTable
                            columns={[
                                { key: 'no', label: '#' }, { key: 'service', label: 'Service Name' },
                                { key: 'requests', label: 'Requests' }, { key: 'rank', label: 'Rank' },
                            ]}
                            rows={getListData().map((service, index) => {
                                const max = getListData().reduce((m, s) => Math.max(m, s.requests_count || 0), 0);
                                return (
                                    <TableRow key={service.id || index} hover>
                                        <TableCell><Typography variant="body2" fontWeight={600} color="text.secondary">{getRowNumber(index)}</Typography></TableCell>
                                        <TableCell>
                                            <Stack direction="row" spacing={1} alignItems="center">
                                                <CategoryIcon sx={{ fontSize: 18, color: '#0f766e' }} />
                                                <Typography variant="body2" fontWeight={600}>{service.name}</Typography>
                                            </Stack>
                                        </TableCell>
                                        <TableCell>
                                            <Stack direction="row" spacing={1.5} alignItems="center">
                                                <LinearProgress variant="determinate"
                                                                value={max > 0 ? (service.requests_count / max) * 100 : 0}
                                                                sx={{ width: 100, height: 8, borderRadius: 4, bgcolor: '#f1f5f9',
                                                                    '& .MuiLinearProgress-bar': { bgcolor: '#0f766e', borderRadius: 4 } }} />
                                                <Typography variant="body2" fontWeight={700}>{service.requests_count}</Typography>
                                            </Stack>
                                        </TableCell>
                                        <TableCell>
                                            <Chip label={`#${index + 1}`} size="small"
                                                  sx={{ fontWeight: 700, height: 26,
                                                      bgcolor: index < 3 ? '#0f766e' : '#f1f5f9',
                                                      color: index < 3 ? '#fff' : '#334155' }} />
                                        </TableCell>
                                    </TableRow>
                                );
                            })}
                            total={getTotalCount()} page={page} rowsPerPage={rowsPerPage}
                            onPageChange={(_, p) => setPage(p)}
                            onRowsPerPageChange={(e) => { setRowsPerPage(+e.target.value); setPage(0); }}
                            loading={loading} emptyMessage="No services found"
                        />
                    </Box>
                </TabPanel>

                {/* ===== BLOG ===== */}
                <TabPanel value={tabValue} index={4}>
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        <SummaryCards items={[
                            { title: 'Total Posts', value: reportData?.stats?.total_posts || 0, icon: <CommentIcon />, color: '#0f766e' },
                            { title: 'Total Comments', value: reportData?.stats?.total_comments || 0, icon: <CommentIcon />, color: '#0ea5e9' },
                            { title: 'Total Likes', value: reportData?.stats?.total_likes || 0, icon: <StarIcon />, color: '#f59e0b' },
                            { title: 'Avg Comments/Post', value: reportData?.stats?.avg_comments_per_post || 0, icon: <TrendingUpIcon />, color: '#10b981' },
                        ]} />
                        {reportData?.trend?.length > 0 && <TrendChart data={reportData.trend} label="Blog Posts" color="#10b981" />}
                        <BlogStats stats={reportData?.stats} />
                    </Box>
                </TabPanel>

                {/* ===== PORTFOLIO ===== */}
                <TabPanel value={tabValue} index={5}>
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        <SummaryCards items={[
                            { title: 'Total Portfolio Items', value: reportData?.total_portfolio_items || 0, icon: <PhotoIcon />, color: '#0f766e', md: 6 },
                            { title: 'Technicians with Portfolios', value: getListData().length, icon: <BuildIcon />, color: '#10b981', md: 6 },
                        ]} />
                        <Typography variant="h6" fontWeight={700} sx={{ mb: 2, mt: 1 }}>Technicians with Most Portfolios</Typography>
                        <ReportTable
                            columns={[
                                { key: 'no', label: '#' }, { key: 'technician', label: 'Technician' },
                                { key: 'items', label: 'Items' },
                            ]}
                            rows={getListData().map((item, index) => (
                                <TableRow key={item.technician_id || index} hover>
                                    <TableCell>
                                        <Chip label={`#${getRowNumber(index)}`} size="small"
                                              sx={{ fontWeight: 700, height: 26,
                                                  bgcolor: index < 3 ? '#0f766e' : '#f1f5f9',
                                                  color: index < 3 ? '#fff' : '#334155' }} />
                                    </TableCell>
                                    <TableCell>
                                        <Stack direction="row" spacing={1.25} alignItems="center">
                                            <Avatar sx={{ width: 34, height: 34, bgcolor: '#0f766e', fontSize: 13, fontWeight: 700 }}>
                                                {item.technician?.user?.name?.charAt(0).toUpperCase() || <BuildIcon fontSize="small" />}
                                            </Avatar>
                                            <Typography variant="body2" fontWeight={600}>{item.technician?.user?.name || 'Unknown'}</Typography>
                                        </Stack>
                                    </TableCell>
                                    <TableCell>
                                        <Chip label={item.count} size="small"
                                              sx={{ fontWeight: 700, bgcolor: '#d1fae5', color: '#047857',
                                                  border: '1.5px solid #10b981', height: 26 }} />
                                    </TableCell>
                                </TableRow>
                            ))}
                            total={getTotalCount()} page={page} rowsPerPage={rowsPerPage}
                            onPageChange={(_, p) => setPage(p)}
                            onRowsPerPageChange={(e) => { setRowsPerPage(+e.target.value); setPage(0); }}
                            loading={loading} emptyMessage="No portfolio data"
                        />
                    </Box>
                </TabPanel>

                {/* ===== SUBSCRIPTIONS ===== */}
                <TabPanel value={tabValue} index={6}>
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        <SummaryCards items={[
                            { title: 'Total Subscriptions', value: reportData?.stats?.total || 0, icon: <SubscriptionIcon />, color: '#0f766e' },
                            { title: 'Active', value: reportData?.stats?.active || 0, icon: <CheckCircleIcon />, color: '#10b981' },
                            { title: 'Pending', value: reportData?.stats?.pending || 0, icon: <PendingIcon />, color: '#f59e0b' },
                            { title: 'Expired', value: reportData?.stats?.expired || 0, icon: <TimerIcon />, color: '#ef4444' },
                            { title: 'Total Revenue', value: formatCurrency(reportData?.stats?.total_revenue), icon: <MoneyIcon />, color: '#0f766e' },
                            { title: 'New (Period)', value: reportData?.trend?.length || 0, icon: <TrendingUpIcon />, color: '#10b981' },
                        ]} />
                        {reportData?.trend?.length > 0 && <TrendChart data={reportData.trend} label="New Subscriptions" color="#0f766e" />}

                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} my={3} flexWrap="wrap">
                            <TextField size="small" placeholder="Search subscriptions…" value={search}
                                       onChange={(e) => setSearch(e.target.value)}
                                       InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" color="action" /></InputAdornment> }}
                                       sx={{ minWidth: 240, '& .MuiOutlinedInput-root': { borderRadius: 2, bgcolor: '#f1f5f9', '& fieldset': { borderColor: 'transparent' } } }}
                            />
                            <FormControl size="small" sx={{ minWidth: 140 }}>
                                <InputLabel>Status</InputLabel>
                                <Select value={filterStatus} label="Status" onChange={(e) => setFilterStatus(e.target.value)}
                                        sx={{ borderRadius: 2, bgcolor: '#f1f5f9', '& .MuiOutlinedInput-notchedOutline': { borderColor: 'transparent' } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="pending">Pending</MenuItem>
                                    <MenuItem value="active">Active</MenuItem>
                                    <MenuItem value="expired">Expired</MenuItem>
                                    <MenuItem value="cancelled">Cancelled</MenuItem>
                                </Select>
                            </FormControl>
                            <FormControl size="small" sx={{ minWidth: 160 }}>
                                <InputLabel>Payment Method</InputLabel>
                                <Select value={filterPaymentMethod} label="Payment Method" onChange={(e) => setFilterPaymentMethod(e.target.value)}
                                        sx={{ borderRadius: 2, bgcolor: '#f1f5f9', '& .MuiOutlinedInput-notchedOutline': { borderColor: 'transparent' } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="M-Pesa">M-Pesa</MenuItem>
                                    <MenuItem value="Airtel Money">Airtel Money</MenuItem>
                                    <MenuItem value="Mix by Yas">Mix by Yas</MenuItem>
                                </Select>
                            </FormControl>
                        </Stack>

                        <ReportTable
                            columns={[
                                { key: 'no', label: '#' }, { key: 'user', label: 'User' },
                                { key: 'plan', label: 'Plan' }, { key: 'amount', label: 'Amount' },
                                { key: 'status', label: 'Status' }, { key: 'payment', label: 'Payment' },
                                { key: 'created', label: 'Created' }, { key: 'expiry', label: 'Expiry' },
                            ]}
                            rows={getListData().map((sub, index) => {
                                const isExpired = sub.expiry_date && new Date(sub.expiry_date) < new Date();
                                const displayStatus = isExpired && sub.status === 'active' ? 'expired' : sub.status;
                                return (
                                    <TableRow key={sub.id || index} hover>
                                        <TableCell><Typography variant="body2" fontWeight={600} color="text.secondary">{getRowNumber(index)}</Typography></TableCell>
                                        <TableCell>
                                            <Stack direction="row" spacing={1.25} alignItems="center">
                                                <Avatar sx={{ width: 34, height: 34, bgcolor: '#0f766e', fontSize: 13, fontWeight: 700 }}>
                                                    {sub.user?.name?.charAt(0).toUpperCase() || 'U'}
                                                </Avatar>
                                                <Typography variant="body2" fontWeight={600}>{sub.user?.name || 'N/A'}</Typography>
                                            </Stack>
                                        </TableCell>
                                        <TableCell>
                                            <Chip label={sub.rate_card?.name || 'N/A'} size="small"
                                                  sx={{ fontWeight: 600, bgcolor: alpha('#0f766e', 0.1), color: '#0f766e', height: 26 }} />
                                        </TableCell>
                                        <TableCell>
                                            <Typography variant="body2" fontWeight={700} color="#0f766e">{sub.amount || 'N/A'}</Typography>
                                        </TableCell>
                                        <TableCell>
                                            <Chip label={getStatusLabel(displayStatus)} size="small"
                                                  sx={{
                                                      fontWeight: 700, height: 26,
                                                      bgcolor: alpha(getStatusColor(displayStatus), 0.12),
                                                      color: getStatusColor(displayStatus),
                                                      border: `1.5px solid ${getStatusColor(displayStatus)}`,
                                                  }} />
                                            {isExpired && sub.status === 'active' && (
                                                <Tooltip title="Auto-marked as expired">
                                                    <TimerIcon sx={{ fontSize: 14, color: '#ef4444', ml: 0.5 }} />
                                                </Tooltip>
                                            )}
                                        </TableCell>
                                        <TableCell>
                                            <Stack direction="row" spacing={0.5} alignItems="center">
                                                <PaymentIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                                                <Typography variant="body2">{sub.payment_method || 'N/A'}</Typography>
                                            </Stack>
                                        </TableCell>
                                        <TableCell><Typography variant="body2" color="text.secondary">{formatDate(sub.created_at)}</Typography></TableCell>
                                        <TableCell>
                                            <Stack direction="row" spacing={0.5} alignItems="center">
                                                <CalendarIcon sx={{ fontSize: 14, color: 'text.secondary' }} />
                                                <Typography variant="body2" color="text.secondary">{formatDate(sub.expiry_date)}</Typography>
                                            </Stack>
                                        </TableCell>
                                    </TableRow>
                                );
                            })}
                            total={getTotalCount()} page={page} rowsPerPage={rowsPerPage}
                            onPageChange={(_, p) => setPage(p)}
                            onRowsPerPageChange={(e) => { setRowsPerPage(+e.target.value); setPage(0); }}
                            loading={loading} emptyMessage="No subscriptions found"
                        />
                    </Box>
                </TabPanel>
            </Paper>
        </Box>
    );
};

export default ReportsDashboard;