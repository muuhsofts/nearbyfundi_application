// src/pages/subscriptions/SubscriptionList.jsx
import React, { useState, useEffect, useCallback } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell, TableContainer,
    TableHead, TableRow, TablePagination, TableSortLabel, TextField, InputAdornment,
    IconButton, Chip, Menu, MenuItem, Dialog, DialogTitle, DialogContent,
    DialogActions, CircularProgress, useMediaQuery, useTheme, Alert,
    Grid, Card, CardContent, Tooltip, Avatar, LinearProgress,
    Divider, Badge, Stack,
} from '@mui/material';
import {
    Refresh as RefreshIcon, MoreVert as MoreVertIcon,
    CheckCircle as ApproveIcon, Cancel as RejectIcon,
    Download as DownloadIcon, Search as SearchIcon,
    PictureAsPdf as PdfIcon, Description as CsvIcon, TableChart as ExcelIcon,
    FilterList as FilterIcon, Pending as PendingIcon,
    CheckCircle as ActiveIcon, Cancel as ExpiredIcon, Block as CancelledIcon,
    CalendarToday as CalendarIcon, Info as InfoIcon, Verified as VerifiedIcon,
    Clear as ClearIcon, Close as CloseIcon,
} from '@mui/icons-material';
import { usePermissions } from 'hooks/usePermissions';
import { subscriptionService } from 'services/subscription.service';
import { showSnackbar } from 'utils/snackbar';
import api from 'services/api';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'user', label: 'User' },
    { id: 'plan', label: 'Plan' },
    { id: 'amount', label: 'Amount' },
    { id: 'status', label: 'Status' },
    { id: 'payment_method', label: 'Payment Method' },
    { id: 'payment_ref', label: 'Reference' },
    { id: 'created_at', label: 'Date' },
    { id: 'expiry_date', label: 'Expiry' },
    { id: 'actions', label: 'Actions', disableSort: true },
];

const statusStyles = {
    pending: { color: '#b45309', bg: '#fef3c7', border: '#f59e0b', label: 'Pending', icon: <PendingIcon sx={{ fontSize: 16 }} /> },
    active: { color: '#047857', bg: '#d1fae5', border: '#10b981', label: 'Active', icon: <ActiveIcon sx={{ fontSize: 16 }} /> },
    expired: { color: '#b91c1c', bg: '#fee2e2', border: '#ef4444', label: 'Expired', icon: <ExpiredIcon sx={{ fontSize: 16 }} /> },
    cancelled: { color: '#4b5563', bg: '#f3f4f6', border: '#9ca3af', label: 'Cancelled', icon: <CancelledIcon sx={{ fontSize: 16 }} /> },
};

const SubscriptionList = () => {
    const theme = useTheme();
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

    const { can } = usePermissions();
    const canApprove = can('subscriptions.approve');
    const canView = can('subscriptions.view');

    const [subscriptions, setSubscriptions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [stats, setStats] = useState({ pending_count: 0, active_count: 0, expired_count: 0, cancelled_count: 0 });
    const [totalCount, setTotalCount] = useState(0);
    const [search, setSearch] = useState('');
    const [statusFilter, setStatusFilter] = useState('');
    const [order, setOrder] = useState('desc');
    const [orderBy, setOrderBy] = useState('created_at');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [dateFrom, setDateFrom] = useState('');
    const [dateTo, setDateTo] = useState('');
    const [showFilters, setShowFilters] = useState(false);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedSub, setSelectedSub] = useState(null);
    const [rejectDialog, setRejectDialog] = useState({ open: false, reason: '', subscriptionId: null });
    const [downloadingInvoice, setDownloadingInvoice] = useState(null);
    const [viewDialog, setViewDialog] = useState({ open: false, subscription: null });
    const [approveDialog, setApproveDialog] = useState({
        open: false, subscription: null, loading: false, progress: 0, status: 'idle', error: null,
    });

    const fetchSubscriptions = useCallback(async () => {
        if (!canView) return;
        setLoading(true);
        setError(null);
        try {
            const params = {
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
                status: statusFilter || undefined,
            };
            const response = await subscriptionService.getSubscriptions(params);
            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data?.data) setSubscriptions(data.data);
                else if (Array.isArray(data)) setSubscriptions(data);
                else setSubscriptions([]);
                if (data?.pagination) setTotalCount(data.pagination.total || 0);
                if (data?.filters) {
                    setStats({
                        pending_count: data.filters.pending_count || 0,
                        active_count: data.filters.active_count || 0,
                        expired_count: data.filters.expired_count || 0,
                        cancelled_count: data.filters.cancelled_count || 0,
                    });
                }
            } else {
                setError('Failed to load subscriptions');
            }
        } catch (err) {
            console.error(err);
            setError(err.message || 'Failed to load subscriptions');
            showSnackbar({ type: 'error', message: 'Failed to load subscriptions' });
        } finally {
            setLoading(false);
        }
    }, [canView, page, rowsPerPage, search, statusFilter]);

    const fetchStats = useCallback(async () => {
        try {
            const response = await subscriptionService.getSubscriptionStats();
            if (response?.data?.status === 'success' && response.data.data) {
                const data = response.data.data;
                setStats({
                    pending_count: data.pending || data.pending_count || 0,
                    active_count: data.active || data.active_count || 0,
                    expired_count: data.expired || data.expired_count || 0,
                    cancelled_count: data.cancelled || data.cancelled_count || 0,
                });
            }
        } catch (err) {
            console.error(err);
        }
    }, []);

    useEffect(() => { fetchSubscriptions(); }, [fetchSubscriptions]);
    useEffect(() => { fetchStats(); }, [fetchStats]);

    const refresh = () => { fetchSubscriptions(); fetchStats(); };

    // Approve / Reject / Invoice / View handlers remain the same as original
    const openApproveDialog = (sub) => {
        setApproveDialog({ open: true, subscription: sub, loading: false, progress: 0, status: 'idle', error: null });
        setActionMenu(null);
    };
    const closeApproveDialog = () => {
        setApproveDialog({ open: false, subscription: null, loading: false, progress: 0, status: 'idle', error: null });
    };

    const handleApproveConfirm = async () => {
        if (!approveDialog.subscription) return;
        setApproveDialog(prev => ({ ...prev, loading: true, status: 'confirming', progress: 10, error: null }));

        const steps = [
            { progress: 20, status: 'Validating subscription...' },
            { progress: 40, status: 'Processing payment confirmation...' },
            { progress: 60, status: 'Updating subscription status...' },
            { progress: 80, status: 'Generating invoice...' },
            { progress: 90, status: 'Sending notification...' },
            { progress: 100, status: 'Complete!' },
        ];
        let currentStep = 0;
        const progressInterval = setInterval(() => {
            if (currentStep < steps.length) {
                const step = steps[currentStep];
                setApproveDialog(prev => ({ ...prev, progress: step.progress, status: step.status }));
                currentStep++;
            }
        }, 500);

        try {
            await subscriptionService.approveSubscription(approveDialog.subscription.id);
            clearInterval(progressInterval);
            setApproveDialog(prev => ({ ...prev, progress: 100, status: 'done', loading: false }));
            showSnackbar({ type: 'success', message: `Subscription #${approveDialog.subscription.id} approved successfully!` });
            setTimeout(() => { closeApproveDialog(); refresh(); }, 1500);
        } catch (err) {
            clearInterval(progressInterval);
            setApproveDialog(prev => ({
                ...prev, loading: false, status: 'error',
                error: err.message || 'Approval failed. Please try again.',
            }));
            showSnackbar({ type: 'error', message: 'Approval failed: ' + (err.message || 'Unknown error') });
        }
    };

    const handleReject = async (id, reason) => {
        try {
            await subscriptionService.rejectSubscription(id, reason);
            showSnackbar({ type: 'success', message: `Subscription #${id} rejected` });
            refresh();
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Rejection failed' });
        }
        setActionMenu(null);
        setRejectDialog({ open: false, reason: '', subscriptionId: null });
    };

    const handleViewInvoice = useCallback(async (sub) => {
        if (!sub.invoice?.id) {
            showSnackbar({ type: 'warning', message: 'No invoice available' });
            return;
        }
        setDownloadingInvoice(sub.id);
        try {
            const response = await api.get(`/v16/invoices/${sub.invoice.id}/download`, { responseType: 'blob' });
            const blob = new Blob([response.data], { type: 'application/pdf' });
            const url = window.URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `invoice_${sub.invoice.number || sub.invoice.id}.pdf`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            window.URL.revokeObjectURL(url);
            showSnackbar({ type: 'success', message: 'Invoice downloaded successfully' });
        } catch (error) {
            if (sub.invoice?.pdf_url) {
                window.open(sub.invoice.pdf_url, '_blank');
                showSnackbar({ type: 'info', message: 'Invoice opened in new tab' });
            } else {
                showSnackbar({ type: 'error', message: 'Failed to download invoice' });
            }
        } finally {
            setDownloadingInvoice(null);
        }
        setActionMenu(null);
    }, []);

    const handleViewDetails = (sub) => {
        setViewDialog({ open: true, subscription: sub });
        setActionMenu(null);
    };

    const handleMenuOpen = (event, sub) => {
        setSelectedSub(sub);
        setActionMenu(event.currentTarget);
    };
    const handleMenuClose = () => setActionMenu(null);

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    // Export helpers (same logic)
    const exportCSV = () => {
        const headers = ['User', 'Plan', 'Amount', 'Status', 'Payment Method', 'Reference', 'Date', 'Expiry'];
        const rows = subscriptions.map(sub => [
            sub.user?.name || '-', sub.rate_card?.name || '-', sub.amount || '-',
            sub.status || '-', sub.payment_method || '-', sub.payment_reference || '-',
            formatDate(sub.created_at), formatDate(sub.expiry_date),
        ]);
        let csv = headers.join(',') + '\n';
        rows.forEach(row => { csv += row.join(',') + '\n'; });
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `subscriptions_${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
        window.URL.revokeObjectURL(url);
    };

    const exportPDF = () => {
        document.body.classList.add('printing');
        setTimeout(() => { window.print(); document.body.classList.remove('printing'); }, 100);
    };

    const exportExcel = () => {
        const headers = ['User', 'Plan', 'Amount', 'Status', 'Payment Method', 'Reference', 'Date', 'Expiry'];
        let html = `<html><head><meta charset="UTF-8"><title>Subscriptions Report</title></head><body>
            <h2>Subscriptions Report - ${new Date().toLocaleDateString()}</h2>
            <table border="1" cellpadding="5"><thead><tr>${headers.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>`;
        subscriptions.forEach(sub => {
            html += `<tr>
                <td>${sub.user?.name || '-'}</td><td>${sub.rate_card?.name || '-'}</td>
                <td>${sub.amount || '-'}</td><td>${sub.status || '-'}</td>
                <td>${sub.payment_method || '-'}</td><td>${sub.payment_reference || '-'}</td>
                <td>${formatDate(sub.created_at)}</td><td>${formatDate(sub.expiry_date)}</td>
            </tr>`;
        });
        html += `</tbody></table></body></html>`;
        const blob = new Blob([html], { type: 'application/vnd.ms-excel' });
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `subscriptions_${new Date().toISOString().slice(0, 10)}.xls`;
        link.click();
        window.URL.revokeObjectURL(url);
    };

    const formatDate = (dateStr) => {
        if (!dateStr) return '—';
        try { return new Date(dateStr).toLocaleDateString(); } catch { return '—'; }
    };

    const isExpired = (sub) => sub.expiry_date ? new Date(sub.expiry_date) < new Date() : false;

    const getStatusChip = (status, expiryDate) => {
        if (status === 'active' && expiryDate && new Date(expiryDate) < new Date()) status = 'expired';
        const s = statusStyles[status] || statusStyles.cancelled;
        return (
            <Chip
                icon={s.icon}
                label={s.label}
                size="small"
                sx={{
                    backgroundColor: s.bg,
                    color: s.color,
                    fontWeight: 700,
                    border: `1.5px solid ${s.border}`,
                    height: 28,
                    '& .MuiChip-icon': { color: s.color },
                }}
            />
        );
    };

    if (!canView) {
        return (
            <Box p={3}>
                <Paper elevation={0} sx={{ p: 4, textAlign: 'center', borderRadius: 3, border: '1px solid', borderColor: 'divider' }}>
                    <Typography color="error" fontWeight={600}>You do not have permission.</Typography>
                </Paper>
            </Box>
        );
    }

    const statCards = [
        { title: 'Pending', count: stats.pending_count || 0, color: '#b45309', bg: 'linear-gradient(135deg, #fef3c7 0%, #fde68a 100%)' },
        { title: 'Active', count: stats.active_count || 0, color: '#047857', bg: 'linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%)' },
        { title: 'Expired', count: stats.expired_count || 0, color: '#b91c1c', bg: 'linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%)' },
        { title: 'Cancelled', count: stats.cancelled_count || 0, color: '#4b5563', bg: 'linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%)' },
    ];

    return (
        <>
            <style>{`
                @media print {
                    .MuiDrawer-root, .MuiDrawer-paper, header, .MuiAppBar-root,
                    [class*="Sidebar"], [class*="Header"], [class*="AppBar"] { display: none !important; }
                    .no-print { display: none !important; }
                    .MuiPaper-root { box-shadow: none !important; border: 1px solid #ddd !important; }
                    body { background: white !important; margin: 0 !important; padding: 20px !important; }
                    .MuiTableContainer-root { overflow: visible !important; }
                    .MuiTablePagination-root { display: none !important; }
                }
            `}</style>

            <Box sx={{ width: '100%', p: { xs: 1.5, sm: 2.5 }, bgcolor: 'background.default' }}>
                {/* Stats */}
                <Grid container spacing={2} sx={{ mb: 3 }}>
                    {statCards.map((card, i) => (
                        <Grid item xs={6} sm={3} key={i}>
                            <Card elevation={0} sx={{
                                borderRadius: 3, border: '1px solid', borderColor: 'divider',
                                background: card.bg, height: '100%',
                            }}>
                                <CardContent sx={{ p: 2.25 }}>
                                    <Typography variant="overline" fontWeight={700} color="text.secondary" letterSpacing={1}>
                                        {card.title}
                                    </Typography>
                                    <Typography variant="h3" fontWeight={800} sx={{ color: card.color, mt: 0.5, lineHeight: 1.1 }}>
                                        {card.count}
                                    </Typography>
                                </CardContent>
                            </Card>
                        </Grid>
                    ))}
                </Grid>

                <Paper elevation={0} sx={{
                    borderRadius: 3, overflow: 'hidden',
                    border: '1px solid', borderColor: 'divider', bgcolor: 'background.paper',
                }}>
                    {/* Header */}
                    <Box className="no-print" sx={{ px: { xs: 2, sm: 3 }, py: 2.5, borderBottom: '1px solid', borderColor: 'divider' }}>
                        <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" alignItems={{ xs: 'stretch', sm: 'center' }} spacing={2} mb={2.5}>
                            <Box>
                                <Typography variant="h5" fontWeight={800}>Subscriptions</Typography>
                                <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                    Manage and approve user subscriptions
                                </Typography>
                            </Box>
                            <Stack direction="row" spacing={1} flexWrap="wrap">
                                <Button size="small" variant="outlined" startIcon={<CsvIcon />} onClick={exportCSV}
                                        sx={{ borderRadius: 2, fontWeight: 600, textTransform: 'none', borderColor: 'divider' }}>
                                    CSV
                                </Button>
                                <Button size="small" variant="outlined" startIcon={<PdfIcon />} onClick={exportPDF}
                                        sx={{ borderRadius: 2, fontWeight: 600, textTransform: 'none', borderColor: 'divider' }}>
                                    PDF
                                </Button>
                                <Button size="small" variant="outlined" startIcon={<ExcelIcon />} onClick={exportExcel}
                                        sx={{ borderRadius: 2, fontWeight: 600, textTransform: 'none', borderColor: 'divider' }}>
                                    Excel
                                </Button>
                                <Button variant="contained" startIcon={<RefreshIcon />} onClick={refresh}
                                        sx={{
                                            borderRadius: 2, fontWeight: 700, textTransform: 'none', boxShadow: 'none',
                                            bgcolor: colors.sea || '#0f766e',
                                            '&:hover': { bgcolor: colors.dark || '#0d5c56', boxShadow: '0 4px 12px rgba(15,118,110,0.35)' },
                                        }}>
                                    Refresh
                                </Button>
                            </Stack>
                        </Stack>

                        {/* Filters */}
                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ xs: 'stretch', sm: 'center' }} flexWrap="wrap">
                            <TextField
                                placeholder="Search…"
                                size="small"
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                                InputProps={{
                                    startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" color="action" /></InputAdornment>,
                                    endAdornment: search ? (
                                        <InputAdornment position="end">
                                            <IconButton size="small" onClick={() => setSearch('')}><ClearIcon fontSize="small" /></IconButton>
                                        </InputAdornment>
                                    ) : null,
                                }}
                                sx={{
                                    minWidth: { xs: '100%', sm: 220 },
                                    '& .MuiOutlinedInput-root': {
                                        borderRadius: 2, bgcolor: 'action.hover',
                                        '& fieldset': { borderColor: 'transparent' },
                                        '&:hover fieldset': { borderColor: 'divider' },
                                        '&.Mui-focused fieldset': { borderColor: 'primary.main' },
                                    },
                                }}
                            />
                            <TextField
                                select label="Status" size="small" value={statusFilter}
                                onChange={(e) => setStatusFilter(e.target.value)}
                                sx={{
                                    minWidth: 140,
                                    '& .MuiOutlinedInput-root': {
                                        borderRadius: 2, bgcolor: 'action.hover',
                                        '& fieldset': { borderColor: 'transparent' },
                                        '&:hover fieldset': { borderColor: 'divider' },
                                    },
                                }}
                            >
                                <MenuItem value="">All</MenuItem>
                                <MenuItem value="pending">Pending</MenuItem>
                                <MenuItem value="active">Active</MenuItem>
                                <MenuItem value="expired">Expired</MenuItem>
                                <MenuItem value="cancelled">Cancelled</MenuItem>
                            </TextField>
                            <Button
                                size="small"
                                variant={showFilters ? 'contained' : 'outlined'}
                                startIcon={<FilterIcon />}
                                onClick={() => setShowFilters(!showFilters)}
                                sx={{ borderRadius: 2, fontWeight: 600, textTransform: 'none' }}
                            >
                                Filters
                            </Button>
                        </Stack>

                        {showFilters && (
                            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ mt: 2, pt: 2, borderTop: '1px solid', borderColor: 'divider' }}>
                                <TextField label="Date From" type="date" size="small" value={dateFrom}
                                           onChange={(e) => setDateFrom(e.target.value)} InputLabelProps={{ shrink: true }}
                                           sx={{ minWidth: 160, '& .MuiOutlinedInput-root': { borderRadius: 2 } }} />
                                <TextField label="Date To" type="date" size="small" value={dateTo}
                                           onChange={(e) => setDateTo(e.target.value)} InputLabelProps={{ shrink: true }}
                                           sx={{ minWidth: 160, '& .MuiOutlinedInput-root': { borderRadius: 2 } }} />
                                <Button size="small" variant="contained" onClick={refresh} sx={{ borderRadius: 2, fontWeight: 600, textTransform: 'none' }}>
                                    Apply
                                </Button>
                                <Button size="small" onClick={() => { setDateFrom(''); setDateTo(''); refresh(); }}
                                        sx={{ fontWeight: 600, textTransform: 'none' }}>
                                    Clear
                                </Button>
                            </Stack>
                        )}
                    </Box>

                    {/* Table / Cards – same structure as before but with updated styling */}
                    {loading ? (
                        <Box sx={{ py: 8, textAlign: 'center' }}><CircularProgress size={36} thickness={4} /></Box>
                    ) : error ? (
                        <Box sx={{ p: 3 }}><Alert severity="error" variant="filled" sx={{ borderRadius: 2 }}>{error}</Alert></Box>
                    ) : showTableView ? (
                        <TableContainer>
                            <Table sx={{ minWidth: 1000 }}>
                                <TableHead>
                                    <TableRow sx={{
                                        bgcolor: 'action.hover',
                                        '& th': {
                                            fontWeight: 700, fontSize: '0.8125rem', color: 'text.secondary',
                                            textTransform: 'uppercase', letterSpacing: 0.6,
                                            borderBottom: '1px solid', borderColor: 'divider', py: 1.75,
                                        },
                                    }}>
                                        {headCells.map((cell) => (
                                            <TableCell key={cell.id}>
                                                {!cell.disableSort ? (
                                                    <TableSortLabel active={orderBy === cell.id} direction={order}
                                                                    onClick={() => handleRequestSort(cell.id)}>
                                                        {cell.label}
                                                    </TableSortLabel>
                                                ) : cell.label}
                                            </TableCell>
                                        ))}
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {subscriptions.length === 0 ? (
                                        <TableRow>
                                            <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                                <Typography color="text.secondary" fontWeight={500}>No subscriptions found</Typography>
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        subscriptions.map((sub) => {
                                            const expired = isExpired(sub);
                                            const actualStatus = expired && sub.status === 'active' ? 'expired' : sub.status;
                                            return (
                                                <TableRow key={sub.id} hover sx={{ '&:last-child td': { borderBottom: 0 } }}>
                                                    <TableCell sx={{ py: 2 }}>
                                                        <Stack direction="row" spacing={1.5} alignItems="center">
                                                            <Avatar sx={{
                                                                width: 36, height: 36,
                                                                bgcolor: colors.sea || '#0f766e', fontSize: 14, fontWeight: 700,
                                                            }}>
                                                                {sub.user?.name?.[0]?.toUpperCase() || 'U'}
                                                            </Avatar>
                                                            <Box>
                                                                <Typography variant="body2" fontWeight={600}>{sub.user?.name || '—'}</Typography>
                                                                <Typography variant="caption" color="text.secondary">{sub.user?.email || ''}</Typography>
                                                            </Box>
                                                        </Stack>
                                                    </TableCell>
                                                    <TableCell><Typography variant="body2" fontWeight={500}>{sub.rate_card?.name || '—'}</Typography></TableCell>
                                                    <TableCell>
                                                        <Typography variant="body2" fontWeight={700} color={colors.sea || '#0f766e'}>
                                                            {sub.amount || '—'}
                                                        </Typography>
                                                    </TableCell>
                                                    <TableCell>{getStatusChip(actualStatus, sub.expiry_date)}</TableCell>
                                                    <TableCell><Typography variant="body2">{sub.payment_method || '—'}</Typography></TableCell>
                                                    <TableCell>
                                                        <Typography variant="caption" fontFamily="monospace" fontWeight={500}>
                                                            {sub.payment_reference || '—'}
                                                        </Typography>
                                                    </TableCell>
                                                    <TableCell><Typography variant="body2" color="text.secondary">{formatDate(sub.created_at)}</Typography></TableCell>
                                                    <TableCell>
                                                        <Stack direction="row" spacing={0.5} alignItems="center">
                                                            <CalendarIcon sx={{ fontSize: 14, color: 'text.secondary' }} />
                                                            <Typography variant="caption" fontWeight={500}>{formatDate(sub.expiry_date)}</Typography>
                                                            {sub.expiry_date && (
                                                                <Badge color={new Date(sub.expiry_date) < new Date() ? 'error' : 'success'} variant="dot" sx={{ ml: 0.5 }} />
                                                            )}
                                                        </Stack>
                                                    </TableCell>
                                                    <TableCell align="center">
                                                        {downloadingInvoice === sub.id ? (
                                                            <CircularProgress size={22} />
                                                        ) : (
                                                            <IconButton size="small" onClick={(e) => handleMenuOpen(e, sub)}
                                                                        sx={{ color: 'text.secondary', '&:hover': { bgcolor: 'action.hover', color: 'text.primary' } }}>
                                                                <MoreVertIcon />
                                                            </IconButton>
                                                        )}
                                                    </TableCell>
                                                </TableRow>
                                            );
                                        })
                                    )}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    ) : (
                        /* Mobile cards – same data, updated styling */
                        <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
                            {subscriptions.length === 0 ? (
                                <Paper variant="outlined" sx={{ p: 5, textAlign: 'center', borderRadius: 3, borderStyle: 'dashed' }}>
                                    <Typography color="text.secondary" fontWeight={500}>No subscriptions found</Typography>
                                </Paper>
                            ) : (
                                <Stack spacing={2}>
                                    {subscriptions.map(sub => {
                                        const expired = isExpired(sub);
                                        const actualStatus = expired && sub.status === 'active' ? 'expired' : sub.status;
                                        return (
                                            <Card key={sub.id} elevation={0} sx={{ borderRadius: 3, border: '1px solid', borderColor: 'divider' }}>
                                                <CardContent sx={{ p: 2.25 }}>
                                                    <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={1.5}>
                                                        <Stack direction="row" spacing={1.5} alignItems="center">
                                                            <Avatar sx={{ width: 40, height: 40, bgcolor: colors.sea || '#0f766e', fontWeight: 700 }}>
                                                                {sub.user?.name?.[0]?.toUpperCase() || 'U'}
                                                            </Avatar>
                                                            <Box>
                                                                <Typography variant="body1" fontWeight={700}>{sub.user?.name || '—'}</Typography>
                                                                <Typography variant="caption" color="text.secondary">{sub.user?.email || ''}</Typography>
                                                            </Box>
                                                        </Stack>
                                                        {getStatusChip(actualStatus, sub.expiry_date)}
                                                    </Stack>
                                                    <Divider sx={{ my: 1.5 }} />
                                                    <Grid container spacing={1.5}>
                                                        <Grid item xs={6}>
                                                            <Typography variant="caption" color="text.secondary">Plan</Typography>
                                                            <Typography variant="body2" fontWeight={600}>{sub.rate_card?.name || '—'}</Typography>
                                                        </Grid>
                                                        <Grid item xs={6}>
                                                            <Typography variant="caption" color="text.secondary">Amount</Typography>
                                                            <Typography variant="body2" fontWeight={700} color={colors.sea || '#0f766e'}>{sub.amount || '—'}</Typography>
                                                        </Grid>
                                                        <Grid item xs={6}>
                                                            <Typography variant="caption" color="text.secondary">Payment</Typography>
                                                            <Typography variant="body2">{sub.payment_method || '—'}</Typography>
                                                        </Grid>
                                                        <Grid item xs={6}>
                                                            <Typography variant="caption" color="text.secondary">Expiry</Typography>
                                                            <Typography variant="body2">{formatDate(sub.expiry_date)}</Typography>
                                                        </Grid>
                                                    </Grid>
                                                    <Stack direction="row" spacing={1} mt={2} flexWrap="wrap">
                                                        {canApprove && sub.status === 'pending' && (
                                                            <>
                                                                <Button size="small" variant="contained" color="success" onClick={() => openApproveDialog(sub)}
                                                                        sx={{ borderRadius: 2, fontWeight: 600, textTransform: 'none' }}>
                                                                    Approve
                                                                </Button>
                                                                <Button size="small" variant="contained" color="error"
                                                                        onClick={() => setRejectDialog({ open: true, reason: '', subscriptionId: sub.id })}
                                                                        sx={{ borderRadius: 2, fontWeight: 600, textTransform: 'none' }}>
                                                                    Reject
                                                                </Button>
                                                            </>
                                                        )}
                                                        {sub.invoice && (
                                                            <Button size="small" startIcon={downloadingInvoice === sub.id ? <CircularProgress size={14} /> : <DownloadIcon />}
                                                                    onClick={() => handleViewInvoice(sub)} disabled={downloadingInvoice === sub.id}
                                                                    sx={{ fontWeight: 600, textTransform: 'none' }}>
                                                                Invoice
                                                            </Button>
                                                        )}
                                                        <Button size="small" variant="outlined" onClick={() => handleViewDetails(sub)}
                                                                sx={{ borderRadius: 2, fontWeight: 600, textTransform: 'none' }}>
                                                            Details
                                                        </Button>
                                                    </Stack>
                                                </CardContent>
                                            </Card>
                                        );
                                    })}
                                </Stack>
                            )}
                        </Box>
                    )}

                    <Box className="no-print" sx={{ borderTop: '1px solid', borderColor: 'divider', bgcolor: 'action.hover' }}>
                        <TablePagination
                            rowsPerPageOptions={[5, 10, 25, 50]}
                            component="div"
                            count={totalCount}
                            rowsPerPage={rowsPerPage}
                            page={page}
                            onPageChange={(e, newPage) => setPage(newPage)}
                            onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
                            sx={{ '.MuiTablePagination-selectLabel, .MuiTablePagination-displayedRows': { fontWeight: 500 } }}
                        />
                    </Box>
                </Paper>

                {/* Action Menu, Reject Dialog, Approve Dialog, View Dialog – keep original logic, only visual polish */}
                <Menu
                    anchorEl={actionMenu}
                    open={Boolean(actionMenu)}
                    onClose={handleMenuClose}
                    anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                    transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                    PaperProps={{ elevation: 8, sx: { borderRadius: 2, minWidth: 180, mt: 0.5 } }}
                >
                    {selectedSub?.status === 'pending' && canApprove && (
                        <>
                            <MenuItem onClick={() => openApproveDialog(selectedSub)} sx={{ fontWeight: 500 }}>
                                <ApproveIcon sx={{ mr: 1.5, color: 'success.main', fontSize: 20 }} /> Approve
                            </MenuItem>
                            <MenuItem onClick={() => {
                                setRejectDialog({ open: true, reason: '', subscriptionId: selectedSub.id });
                                handleMenuClose();
                            }} sx={{ fontWeight: 500 }}>
                                <RejectIcon sx={{ mr: 1.5, color: 'error.main', fontSize: 20 }} /> Reject
                            </MenuItem>
                            <Divider />
                        </>
                    )}
                    <MenuItem onClick={() => handleViewDetails(selectedSub)} sx={{ fontWeight: 500 }}>
                        <InfoIcon sx={{ mr: 1.5, fontSize: 20 }} /> View Details
                    </MenuItem>
                    {selectedSub?.invoice && (
                        <MenuItem onClick={() => handleViewInvoice(selectedSub)} sx={{ fontWeight: 500 }}>
                            <DownloadIcon sx={{ mr: 1.5, fontSize: 20 }} /> Download Invoice
                        </MenuItem>
                    )}
                </Menu>

                {/* Reject Dialog */}
                <Dialog open={rejectDialog.open} onClose={() => setRejectDialog({ open: false, reason: '', subscriptionId: null })}
                        PaperProps={{ sx: { borderRadius: 3 } }}>
                    <DialogTitle sx={{ fontWeight: 700, pb: 1 }}>
                        <Stack direction="row" spacing={1} alignItems="center">
                            <RejectIcon color="error" /> Reject Subscription
                        </Stack>
                    </DialogTitle>
                    <DialogContent>
                        <TextField
                            autoFocus margin="dense" label="Reason (optional)" fullWidth multiline rows={3}
                            value={rejectDialog.reason || ''}
                            onChange={(e) => setRejectDialog(prev => ({ ...prev, reason: e.target.value }))}
                            placeholder="Enter reason for rejection…"
                            sx={{ '& .MuiOutlinedInput-root': { borderRadius: 2 } }}
                        />
                    </DialogContent>
                    <DialogActions sx={{ px: 3, pb: 2.5 }}>
                        <Button onClick={() => setRejectDialog({ open: false, reason: '', subscriptionId: null })}
                                sx={{ fontWeight: 600, textTransform: 'none' }}>Cancel</Button>
                        <Button
                            onClick={() => rejectDialog.subscriptionId && handleReject(rejectDialog.subscriptionId, rejectDialog.reason)}
                            color="error" variant="contained"
                            sx={{ fontWeight: 700, textTransform: 'none', borderRadius: 2 }}>
                            Reject
                        </Button>
                    </DialogActions>
                </Dialog>

                {/* Approve Dialog – keep all progress logic, only polish visuals */}
                <Dialog
                    open={approveDialog.open}
                    onClose={approveDialog.loading ? null : closeApproveDialog}
                    maxWidth="sm" fullWidth
                    PaperProps={{
                        sx: {
                            borderRadius: 3, overflow: 'hidden',
                            border: approveDialog.status === 'done' ? '2px solid #10b981' :
                                approveDialog.status === 'error' ? '2px solid #ef4444' : 'none',
                        },
                    }}
                >
                    <DialogTitle sx={{ pb: 1 }}>
                        <Stack direction="row" spacing={1.5} alignItems="center">
                            <Avatar sx={{
                                bgcolor: approveDialog.status === 'done' ? '#10b981' :
                                    approveDialog.status === 'error' ? '#ef4444' : '#f59e0b',
                                width: 44, height: 44,
                            }}>
                                {approveDialog.status === 'done' ? <VerifiedIcon /> :
                                    approveDialog.status === 'error' ? <RejectIcon /> : <ApproveIcon />}
                            </Avatar>
                            <Box>
                                <Typography variant="h6" fontWeight={800}>
                                    {approveDialog.status === 'done' ? 'Approved Successfully!' :
                                        approveDialog.status === 'error' ? 'Approval Failed' : 'Confirm Approval'}
                                </Typography>
                                {approveDialog.subscription && (
                                    <Typography variant="body2" color="text.secondary">
                                        Subscription #{approveDialog.subscription.id}
                                    </Typography>
                                )}
                            </Box>
                        </Stack>
                    </DialogTitle>
                    <DialogContent>
                        {/* Keep all original content blocks for idle / confirming / done / error */}
                        {approveDialog.status === 'idle' && (
                            <Box sx={{ py: 1 }}>
                                <Alert severity="info" sx={{ mb: 2, borderRadius: 2 }}>
                                    You are about to approve this subscription. The user will gain access immediately.
                                </Alert>
                                <Paper elevation={0} sx={{ p: 2, mb: 2, borderRadius: 2, bgcolor: 'action.hover', border: '1px solid', borderColor: 'divider' }}>
                                    <Stack direction="row" spacing={2} alignItems="center">
                                        <Avatar sx={{ width: 48, height: 48, bgcolor: colors.sea || '#0f766e', fontWeight: 700 }}>
                                            {approveDialog.subscription?.user?.name?.[0]?.toUpperCase() || 'U'}
                                        </Avatar>
                                        <Box>
                                            <Typography variant="subtitle1" fontWeight={700}>
                                                {approveDialog.subscription?.user?.name || 'Unknown User'}
                                            </Typography>
                                            <Typography variant="body2" color="text.secondary">
                                                {approveDialog.subscription?.user?.email || 'No email'}
                                            </Typography>
                                        </Box>
                                    </Stack>
                                </Paper>
                                <Grid container spacing={2}>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="text.secondary">Plan</Typography>
                                        <Typography variant="body2" fontWeight={600}>{approveDialog.subscription?.rate_card?.name || '—'}</Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="text.secondary">Amount</Typography>
                                        <Typography variant="body2" fontWeight={700} color={colors.sea || '#0f766e'}>
                                            {approveDialog.subscription?.amount || '—'}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="text.secondary">Payment Method</Typography>
                                        <Typography variant="body2">{approveDialog.subscription?.payment_method || '—'}</Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="text.secondary">Reference</Typography>
                                        <Typography variant="body2" fontFamily="monospace">{approveDialog.subscription?.payment_reference || '—'}</Typography>
                                    </Grid>
                                </Grid>
                            </Box>
                        )}
                        {(approveDialog.status === 'confirming' || approveDialog.status === 'approving') && (
                            <Box sx={{ py: 3, textAlign: 'center' }}>
                                <CircularProgress size={60} thickness={4} value={approveDialog.progress} variant="determinate" sx={{ color: '#10b981', mb: 2 }} />
                                <Typography variant="h5" fontWeight={800} color="#10b981">{approveDialog.progress}%</Typography>
                                <LinearProgress variant="determinate" value={approveDialog.progress} sx={{
                                    height: 8, borderRadius: 4, my: 2, bgcolor: '#e5e7eb',
                                    '& .MuiLinearProgress-bar': { bgcolor: '#10b981', borderRadius: 4 },
                                }} />
                                <Typography variant="body2" color="text.secondary">{approveDialog.status || 'Processing…'}</Typography>
                            </Box>
                        )}
                        {approveDialog.status === 'done' && (
                            <Box sx={{ py: 3, textAlign: 'center' }}>
                                <Box sx={{
                                    width: 80, height: 80, borderRadius: '50%', bgcolor: '#d1fae5',
                                    display: 'flex', alignItems: 'center', justifyContent: 'center', mx: 'auto', mb: 2,
                                }}>
                                    <VerifiedIcon sx={{ fontSize: 48, color: '#10b981' }} />
                                </Box>
                                <Typography variant="h6" fontWeight={800} color="#10b981">Subscription Approved!</Typography>
                                <Typography variant="body2" color="text.secondary">
                                    {approveDialog.subscription?.user?.name || 'User'} can now access all features.
                                </Typography>
                            </Box>
                        )}
                        {approveDialog.status === 'error' && (
                            <Alert severity="error" sx={{ borderRadius: 2 }}>
                                {approveDialog.error || 'An error occurred while approving the subscription.'}
                            </Alert>
                        )}
                    </DialogContent>
                    <DialogActions sx={{ px: 3, pb: 2.5 }}>
                        {approveDialog.status === 'idle' && (
                            <>
                                <Button onClick={closeApproveDialog} disabled={approveDialog.loading} sx={{ fontWeight: 600, textTransform: 'none' }}>Cancel</Button>
                                <Button onClick={handleApproveConfirm} variant="contained" color="success" disabled={approveDialog.loading}
                                        startIcon={<ApproveIcon />} sx={{ borderRadius: 2, fontWeight: 700, textTransform: 'none', px: 3 }}>
                                    Confirm Approve
                                </Button>
                            </>
                        )}
                        {approveDialog.status === 'done' && (
                            <Button onClick={closeApproveDialog} variant="contained" color="success"
                                    sx={{ borderRadius: 2, fontWeight: 700, textTransform: 'none', px: 4 }}>Done</Button>
                        )}
                        {approveDialog.status === 'error' && (
                            <>
                                <Button onClick={closeApproveDialog} sx={{ fontWeight: 600, textTransform: 'none' }}>Cancel</Button>
                                <Button onClick={handleApproveConfirm} variant="contained" color="success" startIcon={<RefreshIcon />}
                                        sx={{ borderRadius: 2, fontWeight: 700, textTransform: 'none' }}>Retry</Button>
                            </>
                        )}
                    </DialogActions>
                </Dialog>

                {/* View Details Dialog */}
                <Dialog open={viewDialog.open} onClose={() => setViewDialog({ open: false, subscription: null })}
                        maxWidth="md" fullWidth PaperProps={{ sx: { borderRadius: 3 } }}>
                    <DialogTitle sx={{ fontWeight: 700, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <Stack direction="row" spacing={1} alignItems="center">
                            <InfoIcon color="primary" /> Subscription Details
                        </Stack>
                        <IconButton size="small" onClick={() => setViewDialog({ open: false, subscription: null })}>
                            <CloseIcon />
                        </IconButton>
                    </DialogTitle>
                    <DialogContent>
                        {viewDialog.subscription && (
                            <Grid container spacing={2} sx={{ mt: 0.5 }}>
                                <Grid item xs={12}>
                                    <Typography variant="caption" color="text.secondary">User</Typography>
                                    <Typography variant="body1" fontWeight={600}>{viewDialog.subscription.user?.name || '—'}</Typography>
                                    <Typography variant="body2" color="text.secondary">{viewDialog.subscription.user?.email || ''}</Typography>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">Plan</Typography>
                                    <Typography variant="body1" fontWeight={500}>{viewDialog.subscription.rate_card?.name || '—'}</Typography>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">Amount</Typography>
                                    <Typography variant="body1" fontWeight={700} color={colors.sea || '#0f766e'}>
                                        {viewDialog.subscription.amount || '—'}
                                    </Typography>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">Status</Typography>
                                    <Box mt={0.5}>{getStatusChip(viewDialog.subscription.status, viewDialog.subscription.expiry_date)}</Box>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">Payment Method</Typography>
                                    <Typography variant="body1">{viewDialog.subscription.payment_method || '—'}</Typography>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">Reference</Typography>
                                    <Typography variant="body1" fontFamily="monospace">{viewDialog.subscription.payment_reference || '—'}</Typography>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">Created</Typography>
                                    <Typography variant="body1">{formatDate(viewDialog.subscription.created_at)}</Typography>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">Start Date</Typography>
                                    <Typography variant="body1">{formatDate(viewDialog.subscription.start_date)}</Typography>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="caption" color="text.secondary">Expiry Date</Typography>
                                    <Typography variant="body1">{formatDate(viewDialog.subscription.expiry_date)}</Typography>
                                </Grid>
                                {viewDialog.subscription.admin_notes && (
                                    <Grid item xs={12}>
                                        <Typography variant="caption" color="text.secondary">Admin Notes</Typography>
                                        <Typography variant="body2" fontStyle="italic">{viewDialog.subscription.admin_notes}</Typography>
                                    </Grid>
                                )}
                                {viewDialog.subscription.invoice && (
                                    <Grid item xs={12}>
                                        <Divider sx={{ my: 1 }} />
                                        <Typography variant="subtitle2" fontWeight={700} mb={1}>Invoice</Typography>
                                        <Stack direction="row" spacing={2} flexWrap="wrap">
                                            <Typography variant="body2"><strong>Number:</strong> {viewDialog.subscription.invoice.number}</Typography>
                                            <Typography variant="body2"><strong>Status:</strong> {viewDialog.subscription.invoice.status_label}</Typography>
                                            <Typography variant="body2"><strong>Amount:</strong> {viewDialog.subscription.invoice.amount}</Typography>
                                        </Stack>
                                        {viewDialog.subscription.invoice.pdf_url && (
                                            <Button size="small" variant="outlined" startIcon={<DownloadIcon />}
                                                    onClick={() => handleViewInvoice(viewDialog.subscription)}
                                                    sx={{ mt: 1.5, borderRadius: 2, fontWeight: 600, textTransform: 'none' }}>
                                                Download Invoice
                                            </Button>
                                        )}
                                    </Grid>
                                )}
                            </Grid>
                        )}
                    </DialogContent>
                    <DialogActions sx={{ px: 3, pb: 2.5 }}>
                        <Button onClick={() => setViewDialog({ open: false, subscription: null })}
                                variant="contained" sx={{
                            borderRadius: 2, fontWeight: 700, textTransform: 'none',
                            bgcolor: colors.sea || '#0f766e',
                            '&:hover': { bgcolor: colors.dark || '#0d5c56' },
                        }}>
                            Close
                        </Button>
                    </DialogActions>
                </Dialog>
            </Box>
        </>
    );
};

export default SubscriptionList;