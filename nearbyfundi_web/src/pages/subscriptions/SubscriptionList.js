import React, { useState, useEffect, useCallback } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell, TableContainer,
    TableHead, TableRow, TablePagination, TableSortLabel, TextField, InputAdornment,
    IconButton, Chip, Menu, MenuItem, Dialog, DialogTitle, DialogContent,
    DialogActions, CircularProgress, useMediaQuery, useTheme, Alert,
    Grid, Card, CardContent, Tooltip, Avatar, LinearProgress,
    Divider, Badge, Fade, Slide,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    MoreVert as MoreVertIcon,
    CheckCircle as ApproveIcon,
    Cancel as RejectIcon,
    Download as DownloadIcon,
    Search as SearchIcon,
    PictureAsPdf as PdfIcon,
    Description as CsvIcon,
    TableChart as ExcelIcon,
    FilterList as FilterIcon,
    Pending as PendingIcon,
    CheckCircle as ActiveIcon,
    Cancel as ExpiredIcon,
    Block as CancelledIcon,
    TrendingUp as TrendingUpIcon,
    Person as PersonIcon,
    AttachMoney as MoneyIcon,
    CalendarToday as CalendarIcon,
    Timer as TimerIcon,
    Info as InfoIcon,
    Verified as VerifiedIcon,
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

const SubscriptionList = () => {
    const theme = useTheme();
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const { can } = usePermissions();
    const canApprove = can('subscriptions.approve');
    const canView = can('subscriptions.view');

    // State
    const [subscriptions, setSubscriptions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [stats, setStats] = useState({
        pending_count: 0,
        active_count: 0,
        expired_count: 0,
        cancelled_count: 0,
    });
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
    const [rejectDialog, setRejectDialog] = useState({
        open: false,
        reason: '',
        subscriptionId: null,
    });
    const [downloadingInvoice, setDownloadingInvoice] = useState(null);
    const [viewDialog, setViewDialog] = useState({
        open: false,
        subscription: null,
    });

    // ✅ Approve Dialog State
    const [approveDialog, setApproveDialog] = useState({
        open: false,
        subscription: null,
        loading: false,
        progress: 0,
        status: 'idle', // idle, confirming, approving, done, error
        error: null,
    });

    // ============================================================
    // FETCH DATA
    // ============================================================

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

                if (data?.data) {
                    setSubscriptions(data.data);
                } else if (Array.isArray(data)) {
                    setSubscriptions(data);
                } else {
                    setSubscriptions([]);
                }

                if (data?.pagination) {
                    setTotalCount(data.pagination.total || 0);
                }

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
            console.error('Error fetching subscriptions:', err);
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
            console.error('Error fetching stats:', err);
        }
    }, []);

    useEffect(() => {
        fetchSubscriptions();
    }, [fetchSubscriptions]);

    useEffect(() => {
        fetchStats();
    }, [fetchStats]);

    const refresh = () => {
        fetchSubscriptions();
        fetchStats();
    };

    // ============================================================
    // APPROVE HANDLER WITH MODAL
    // ============================================================

    const openApproveDialog = (sub) => {
        setApproveDialog({
            open: true,
            subscription: sub,
            loading: false,
            progress: 0,
            status: 'idle',
            error: null,
        });
        setActionMenu(null);
    };

    const closeApproveDialog = () => {
        setApproveDialog({
            open: false,
            subscription: null,
            loading: false,
            progress: 0,
            status: 'idle',
            error: null,
        });
    };

    const handleApproveConfirm = async () => {
        if (!approveDialog.subscription) return;

        setApproveDialog(prev => ({
            ...prev,
            loading: true,
            status: 'confirming',
            progress: 10,
            error: null,
        }));

        // Simulate progress steps
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
                setApproveDialog(prev => ({
                    ...prev,
                    progress: step.progress,
                    status: step.status,
                }));
                currentStep++;
            }
        }, 500);

        try {
            // Make the actual API call
            await subscriptionService.approveSubscription(approveDialog.subscription.id);

            clearInterval(progressInterval);

            setApproveDialog(prev => ({
                ...prev,
                progress: 100,
                status: 'done',
                loading: false,
            }));

            showSnackbar({
                type: 'success',
                message: `Subscription #${approveDialog.subscription.id} approved successfully!`
            });

            // Refresh data after a delay
            setTimeout(() => {
                closeApproveDialog();
                refresh();
            }, 1500);

        } catch (err) {
            clearInterval(progressInterval);
            setApproveDialog(prev => ({
                ...prev,
                loading: false,
                status: 'error',
                error: err.message || 'Approval failed. Please try again.',
            }));
            showSnackbar({
                type: 'error',
                message: 'Approval failed: ' + (err.message || 'Unknown error')
            });
        }
    };

    // ============================================================
    // OTHER HANDLERS
    // ============================================================

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
            const response = await api.get(`/v16/invoices/${sub.invoice.id}/download`, {
                responseType: 'blob',
            });

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
            console.error('Invoice download error:', error);
            if (sub.invoice?.pdf_url) {
                try {
                    window.open(sub.invoice.pdf_url, '_blank');
                    showSnackbar({ type: 'info', message: 'Invoice opened in new tab' });
                } catch (fallbackError) {
                    showSnackbar({ type: 'error', message: 'Failed to download invoice' });
                }
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

    // ============================================================
    // EXPORT FUNCTIONS
    // ============================================================

    const exportCSV = () => {
        const headers = ['User', 'Plan', 'Amount', 'Status', 'Payment Method', 'Reference', 'Date', 'Expiry'];
        const rows = subscriptions.map(sub => [
            sub.user?.name || '-',
            sub.rate_card?.name || '-',
            sub.amount || '-',
            sub.status || '-',
            sub.payment_method || '-',
            sub.payment_reference || '-',
            formatDate(sub.created_at),
            formatDate(sub.expiry_date),
        ]);

        let csv = headers.join(',') + '\n';
        rows.forEach(row => {
            csv += row.join(',') + '\n';
        });

        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `subscriptions_${new Date().toISOString().slice(0,10)}.csv`;
        link.click();
        window.URL.revokeObjectURL(url);
    };

    const exportPDF = () => {
        document.body.classList.add('printing');
        setTimeout(() => {
            window.print();
            document.body.classList.remove('printing');
        }, 100);
    };

    const exportExcel = () => {
        const headers = ['User', 'Plan', 'Amount', 'Status', 'Payment Method', 'Reference', 'Date', 'Expiry'];
        let html = `
            <html>
            <head><meta charset="UTF-8"><title>Subscriptions Report</title></head>
            <body>
            <h2>Subscriptions Report - ${new Date().toLocaleDateString()}</h2>
            <table border="1" cellpadding="5">
            <thead><tr>${headers.map(h => `<th>${h}</th>`).join('')}</tr></thead>
            <tbody>
        `;
        subscriptions.forEach(sub => {
            html += `<tr>
                <td>${sub.user?.name || '-'}</td>
                <td>${sub.rate_card?.name || '-'}</td>
                <td>${sub.amount || '-'}</td>
                <td>${sub.status || '-'}</td>
                <td>${sub.payment_method || '-'}</td>
                <td>${sub.payment_reference || '-'}</td>
                <td>${formatDate(sub.created_at)}</td>
                <td>${formatDate(sub.expiry_date)}</td>
            </tr>`;
        });
        html += `</tbody></table></body></html>`;

        const blob = new Blob([html], { type: 'application/vnd.ms-excel' });
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `subscriptions_${new Date().toISOString().slice(0,10)}.xls`;
        link.click();
        window.URL.revokeObjectURL(url);
    };

    // ============================================================
    // HELPERS
    // ============================================================

    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        try { return new Date(dateStr).toLocaleDateString(); } catch { return '-'; }
    };

    const isExpired = (sub) => {
        if (!sub.expiry_date) return false;
        return new Date(sub.expiry_date) < new Date();
    };

    const getStatusChip = (status, expiryDate) => {
        if (status === 'active' && expiryDate && new Date(expiryDate) < new Date()) {
            status = 'expired';
        }

        const map = {
            pending: { color: '#f59e0b', bg: '#fef3c7', label: 'Pending', icon: <PendingIcon sx={{ fontSize: 14 }} /> },
            active: { color: '#10b981', bg: '#d1fae5', label: 'Active', icon: <ActiveIcon sx={{ fontSize: 14 }} /> },
            expired: { color: '#ef4444', bg: '#fee2e2', label: 'Expired', icon: <ExpiredIcon sx={{ fontSize: 14 }} /> },
            cancelled: { color: '#6b7280', bg: '#f3f4f6', label: 'Cancelled', icon: <CancelledIcon sx={{ fontSize: 14 }} /> },
        };
        const s = map[status] || { color: '#6b7280', bg: '#f3f4f6', label: status, icon: null };
        return (
            <Chip
                icon={s.icon}
                label={s.label}
                sx={{
                    backgroundColor: s.bg,
                    color: s.color,
                    fontWeight: 600,
                    '& .MuiChip-icon': { color: s.color },
                }}
                size="small"
            />
        );
    };

    // ============================================================
    // STATS CARDS
    // ============================================================

    const statCards = [
        {
            title: 'Pending',
            count: stats.pending_count || 0,
            icon: <PendingIcon sx={{ color: 'white', fontSize: 24 }} />,
            color: '#f59e0b',
            bgColor: '#fffbeb',
            borderColor: '#f59e0b',
            gradient: 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)',
        },
        {
            title: 'Active',
            count: stats.active_count || 0,
            icon: <ActiveIcon sx={{ color: 'white', fontSize: 24 }} />,
            color: '#10b981',
            bgColor: '#ecfdf5',
            borderColor: '#10b981',
            gradient: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
        },
        {
            title: 'Expired',
            count: stats.expired_count || 0,
            icon: <ExpiredIcon sx={{ color: 'white', fontSize: 24 }} />,
            color: '#ef4444',
            bgColor: '#fef2f2',
            borderColor: '#ef4444',
            gradient: 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
        },
        {
            title: 'Cancelled',
            count: stats.cancelled_count || 0,
            icon: <CancelledIcon sx={{ color: 'white', fontSize: 24 }} />,
            color: '#6b7280',
            bgColor: '#f9fafb',
            borderColor: '#6b7280',
            gradient: 'linear-gradient(135deg, #6b7280 0%, #4b5563 100%)',
        },
    ];

    if (!canView) {
        return (
            <Box p={3}>
                <Paper sx={{ p: 3, textAlign: 'center' }}>
                    <Typography color="error">You do not have permission.</Typography>
                </Paper>
            </Box>
        );
    }

    return (
        <>
            <style>{`
                @media print {
                    .MuiDrawer-root,
                    .MuiDrawer-paper,
                    header,
                    .MuiAppBar-root,
                    [class*="Sidebar"],
                    [class*="Header"],
                    [class*="AppBar"] {
                        display: none !important;
                    }
                    .no-print {
                        display: none !important;
                    }
                    .MuiPaper-root {
                        box-shadow: none !important;
                        border: 1px solid #ddd !important;
                    }
                    body {
                        background: white !important;
                        margin: 0 !important;
                        padding: 20px !important;
                    }
                    .MuiTableContainer-root {
                        overflow: visible !important;
                    }
                    .MuiTablePagination-root {
                        display: none !important;
                    }
                }
                @keyframes pulse {
                    0% { transform: scale(1); }
                    50% { transform: scale(1.05); }
                    100% { transform: scale(1); }
                }
                .pulse {
                    animation: pulse 2s ease-in-out infinite;
                }
                @keyframes progressGlow {
                    0% { box-shadow: 0 0 10px rgba(16, 185, 129, 0.3); }
                    50% { box-shadow: 0 0 30px rgba(16, 185, 129, 0.6); }
                    100% { box-shadow: 0 0 10px rgba(16, 185, 129, 0.3); }
                }
            `}</style>

            <Box sx={{ width: '100%', p: { xs: 1, sm: 2 } }}>
                {/* Stats Cards */}
                <Grid container spacing={2} sx={{ mb: 3 }}>
                    {statCards.map((card, index) => (
                        <Grid item xs={6} sm={3} key={index}>
                            <Slide direction="up" in={true} timeout={500 + index * 100}>
                                <Card
                                    sx={{
                                        bgcolor: card.bgColor,
                                        borderLeft: `4px solid ${card.borderColor}`,
                                        transition: 'all 0.3s ease',
                                        '&:hover': {
                                            transform: 'translateY(-6px)',
                                            boxShadow: '0 12px 24px rgba(0,0,0,0.12)',
                                        },
                                        position: 'relative',
                                        overflow: 'hidden',
                                    }}
                                >
                                    <Box
                                        sx={{
                                            position: 'absolute',
                                            right: -30,
                                            top: -30,
                                            width: 120,
                                            height: 120,
                                            borderRadius: '50%',
                                            background: card.gradient,
                                            opacity: 0.08,
                                        }}
                                    />
                                    <Box
                                        sx={{
                                            position: 'absolute',
                                            right: 20,
                                            bottom: -10,
                                            width: 40,
                                            height: 40,
                                            borderRadius: '50%',
                                            background: card.gradient,
                                            opacity: 0.05,
                                        }}
                                    />
                                    <CardContent sx={{ position: 'relative', zIndex: 1 }}>
                                        <Box display="flex" alignItems="center" justifyContent="space-between">
                                            <Box>
                                                <Typography
                                                    variant="caption"
                                                    sx={{
                                                        color: card.color,
                                                        fontWeight: 600,
                                                        textTransform: 'uppercase',
                                                        letterSpacing: '0.5px',
                                                        fontSize: '11px',
                                                    }}
                                                >
                                                    {card.title}
                                                </Typography>
                                                <Typography
                                                    variant="h4"
                                                    sx={{
                                                        color: card.color,
                                                        fontWeight: 700,
                                                        fontSize: { xs: '28px', sm: '32px' },
                                                        lineHeight: 1.2,
                                                        mt: 0.5,
                                                    }}
                                                >
                                                    {card.count}
                                                </Typography>
                                            </Box>
                                            <Avatar
                                                sx={{
                                                    background: card.gradient,
                                                    width: 48,
                                                    height: 48,
                                                    boxShadow: `0 4px 12px ${card.color}40`,
                                                }}
                                            >
                                                {card.icon}
                                            </Avatar>
                                        </Box>
                                        <LinearProgress
                                            variant="determinate"
                                            value={Math.min((card.count / (statCards.reduce((sum, c) => sum + c.count, 0) || 1)) * 100, 100)}
                                            sx={{
                                                mt: 2,
                                                height: 3,
                                                borderRadius: 2,
                                                bgcolor: '#e5e7eb',
                                                '& .MuiLinearProgress-bar': {
                                                    bgcolor: card.color,
                                                    borderRadius: 2,
                                                },
                                            }}
                                        />
                                    </CardContent>
                                </Card>
                            </Slide>
                        </Grid>
                    ))}
                </Grid>

                {/* Main Paper */}
                <Paper sx={{ borderRadius: 2, overflow: 'hidden', border: `1px solid ${colors.middle}` }}>
                    {/* Header */}
                    <Box className="no-print" sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                        <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={2}>
                            <Typography variant="h5" fontWeight="600" sx={{ color: colors.dark }}>
                                Subscriptions
                            </Typography>
                            <Box display="flex" gap={1} flexWrap="wrap">
                                <Tooltip title="Export as CSV">
                                    <Button size="small" variant="outlined" startIcon={<CsvIcon />} onClick={exportCSV}>
                                        CSV
                                    </Button>
                                </Tooltip>
                                <Tooltip title="Export as PDF">
                                    <Button size="small" variant="outlined" startIcon={<PdfIcon />} onClick={exportPDF}>
                                        PDF
                                    </Button>
                                </Tooltip>
                                <Tooltip title="Export as Excel">
                                    <Button size="small" variant="outlined" startIcon={<ExcelIcon />} onClick={exportExcel}>
                                        Excel
                                    </Button>
                                </Tooltip>
                                <Button variant="contained" startIcon={<RefreshIcon />} onClick={refresh}>
                                    Refresh
                                </Button>
                            </Box>
                        </Box>
                    </Box>

                    {/* Filters */}
                    <Box className="no-print" sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}`, bgcolor: colors.sky }}>
                        <Box display="flex" gap={2} flexWrap="wrap" alignItems="center">
                            <TextField
                                label="Search"
                                size="small"
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                                InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon /></InputAdornment> }}
                                sx={{ minWidth: 200, flexGrow: 1 }}
                            />
                            <TextField
                                select
                                label="Status"
                                size="small"
                                value={statusFilter}
                                onChange={(e) => setStatusFilter(e.target.value)}
                                sx={{ minWidth: 140 }}
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
                            >
                                Filters
                            </Button>
                        </Box>

                        {showFilters && (
                            <Fade in={showFilters}>
                                <Box display="flex" gap={2} flexWrap="wrap" alignItems="center" sx={{ mt: 2, pt: 2, borderTop: `1px solid ${colors.middle}` }}>
                                    <TextField
                                        label="Date From"
                                        type="date"
                                        size="small"
                                        value={dateFrom}
                                        onChange={(e) => setDateFrom(e.target.value)}
                                        InputLabelProps={{ shrink: true }}
                                        sx={{ minWidth: 160 }}
                                    />
                                    <TextField
                                        label="Date To"
                                        type="date"
                                        size="small"
                                        value={dateTo}
                                        onChange={(e) => setDateTo(e.target.value)}
                                        InputLabelProps={{ shrink: true }}
                                        sx={{ minWidth: 160 }}
                                    />
                                    <Button size="small" variant="contained" color="primary" onClick={refresh}>
                                        Apply Date Filter
                                    </Button>
                                    <Button
                                        size="small"
                                        variant="text"
                                        onClick={() => {
                                            setDateFrom('');
                                            setDateTo('');
                                            refresh();
                                        }}
                                    >
                                        Clear
                                    </Button>
                                </Box>
                            </Fade>
                        )}
                    </Box>

                    {/* Table */}
                    {loading ? (
                        <Box sx={{ p: 4, textAlign: 'center' }}>
                            <CircularProgress />
                        </Box>
                    ) : error ? (
                        <Box sx={{ p: 3 }}>
                            <Alert severity="error">{error}</Alert>
                        </Box>
                    ) : showTableView ? (
                        <TableContainer>
                            <Table>
                                <TableHead sx={{ backgroundColor: colors.sky }}>
                                    <TableRow>
                                        {headCells.map((cell) => (
                                            <TableCell key={cell.id} sx={{ fontWeight: 'bold', whiteSpace: 'nowrap' }}>
                                                {!cell.disableSort ? (
                                                    <TableSortLabel
                                                        active={orderBy === cell.id}
                                                        direction={order}
                                                        onClick={() => handleRequestSort(cell.id)}
                                                    >
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
                                            <TableCell colSpan={headCells.length} align="center" sx={{ py: 4 }}>
                                                <Typography color="textSecondary">No subscriptions found</Typography>
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        subscriptions.map((sub) => {
                                            const expired = isExpired(sub);
                                            const actualStatus = expired && sub.status === 'active' ? 'expired' : sub.status;
                                            return (
                                                <TableRow key={sub.id} hover>
                                                    <TableCell>
                                                        <Box display="flex" alignItems="center" gap={1}>
                                                            <Avatar sx={{ width: 32, height: 32, bgcolor: colors.primary }}>
                                                                {sub.user?.name?.[0] || 'U'}
                                                            </Avatar>
                                                            <Box>
                                                                <Typography variant="body2" fontWeight={500}>
                                                                    {sub.user?.name || '-'}
                                                                </Typography>
                                                                <Typography variant="caption" color="textSecondary">
                                                                    {sub.user?.email || ''}
                                                                </Typography>
                                                            </Box>
                                                        </Box>
                                                    </TableCell>
                                                    <TableCell>{sub.rate_card?.name || '-'}</TableCell>
                                                    <TableCell>
                                                        <Typography fontWeight={600} color={colors.primary}>
                                                            {sub.amount || '-'}
                                                        </Typography>
                                                    </TableCell>
                                                    <TableCell>{getStatusChip(actualStatus, sub.expiry_date)}</TableCell>
                                                    <TableCell>{sub.payment_method || '-'}</TableCell>
                                                    <TableCell>
                                                        <Typography variant="caption" sx={{ fontFamily: 'monospace' }}>
                                                            {sub.payment_reference || '-'}
                                                        </Typography>
                                                    </TableCell>
                                                    <TableCell>{formatDate(sub.created_at)}</TableCell>
                                                    <TableCell>
                                                        <Box display="flex" alignItems="center" gap={0.5}>
                                                            <CalendarIcon sx={{ fontSize: 14, color: 'text.secondary' }} />
                                                            <Typography variant="caption">
                                                                {formatDate(sub.expiry_date)}
                                                            </Typography>
                                                            {sub.expiry_date && (
                                                                <Badge
                                                                    color={new Date(sub.expiry_date) < new Date() ? 'error' : 'success'}
                                                                    variant="dot"
                                                                    sx={{ ml: 0.5 }}
                                                                />
                                                            )}
                                                        </Box>
                                                    </TableCell>
                                                    <TableCell align="center">
                                                        {downloadingInvoice === sub.id ? (
                                                            <CircularProgress size={24} />
                                                        ) : (
                                                            <IconButton size="small" onClick={(e) => handleMenuOpen(e, sub)}>
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
                        <Box sx={{ p: 2 }}>
                            {subscriptions.length === 0 ? (
                                <Typography sx={{ py: 2, textAlign: 'center', color: colors.rain }}>No subscriptions found</Typography>
                            ) : (
                                subscriptions.map(sub => {
                                    const expired = isExpired(sub);
                                    const actualStatus = expired && sub.status === 'active' ? 'expired' : sub.status;
                                    return (
                                        <Card key={sub.id} sx={{ mb: 2 }}>
                                            <CardContent>
                                                <Box display="flex" justifyContent="space-between" alignItems="flex-start">
                                                    <Box>
                                                        <Typography variant="subtitle1">
                                                            <strong>{sub.user?.name || '-'}</strong>
                                                        </Typography>
                                                        <Typography variant="caption" color="textSecondary">
                                                            {sub.user?.email || ''}
                                                        </Typography>
                                                    </Box>
                                                    {getStatusChip(actualStatus, sub.expiry_date)}
                                                </Box>
                                                <Divider sx={{ my: 1 }} />
                                                <Grid container spacing={1}>
                                                    <Grid item xs={6}>
                                                        <Typography variant="caption" color="textSecondary">Plan</Typography>
                                                        <Typography variant="body2">{sub.rate_card?.name || '-'}</Typography>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="caption" color="textSecondary">Amount</Typography>
                                                        <Typography variant="body2" fontWeight={600} color={colors.primary}>
                                                            {sub.amount || '-'}
                                                        </Typography>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="caption" color="textSecondary">Payment Method</Typography>
                                                        <Typography variant="body2">{sub.payment_method || '-'}</Typography>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="caption" color="textSecondary">Reference</Typography>
                                                        <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                                                            {sub.payment_reference || '-'}
                                                        </Typography>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="caption" color="textSecondary">Date</Typography>
                                                        <Typography variant="body2">{formatDate(sub.created_at)}</Typography>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="caption" color="textSecondary">Expiry</Typography>
                                                        <Typography variant="body2">{formatDate(sub.expiry_date)}</Typography>
                                                    </Grid>
                                                </Grid>
                                                <Box mt={2} display="flex" gap={1} flexWrap="wrap">
                                                    {canApprove && sub.status === 'pending' && (
                                                        <>
                                                            <Button
                                                                size="small"
                                                                variant="contained"
                                                                color="success"
                                                                onClick={() => openApproveDialog(sub)}
                                                            >
                                                                Approve
                                                            </Button>
                                                            <Button size="small" variant="contained" color="error" onClick={() => {
                                                                setRejectDialog({ open: true, reason: '', subscriptionId: sub.id });
                                                            }}>
                                                                Reject
                                                            </Button>
                                                        </>
                                                    )}
                                                    {sub.invoice && (
                                                        <Button
                                                            size="small"
                                                            startIcon={downloadingInvoice === sub.id ? <CircularProgress size={16} /> : <DownloadIcon />}
                                                            onClick={() => handleViewInvoice(sub)}
                                                            disabled={downloadingInvoice === sub.id}
                                                        >
                                                            Invoice
                                                        </Button>
                                                    )}
                                                    <Button size="small" variant="outlined" onClick={() => handleViewDetails(sub)}>
                                                        View Details
                                                    </Button>
                                                </Box>
                                            </CardContent>
                                        </Card>
                                    );
                                })
                            )}
                        </Box>
                    )}

                    <TablePagination
                        className="no-print"
                        rowsPerPageOptions={[5, 10, 25, 50]}
                        component="div"
                        count={totalCount}
                        rowsPerPage={rowsPerPage}
                        page={page}
                        onPageChange={(e, newPage) => setPage(newPage)}
                        onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
                    />
                </Paper>

                {/* Action Menu */}
                <Menu anchorEl={actionMenu} open={Boolean(actionMenu)} onClose={handleMenuClose}>
                    {selectedSub?.status === 'pending' && canApprove && (
                        <>
                            <MenuItem onClick={() => openApproveDialog(selectedSub)}>
                                <ApproveIcon sx={{ mr: 1, color: 'success.main' }} /> Approve
                            </MenuItem>
                            <MenuItem onClick={() => {
                                setRejectDialog({ open: true, reason: '', subscriptionId: selectedSub.id });
                                handleMenuClose();
                            }}>
                                <RejectIcon sx={{ mr: 1, color: 'error.main' }} /> Reject
                            </MenuItem>
                            <Divider />
                        </>
                    )}
                    <MenuItem onClick={() => handleViewDetails(selectedSub)}>
                        <InfoIcon sx={{ mr: 1 }} /> View Details
                    </MenuItem>
                    {selectedSub?.invoice && (
                        <MenuItem onClick={() => handleViewInvoice(selectedSub)}>
                            <DownloadIcon sx={{ mr: 1 }} /> Download Invoice
                        </MenuItem>
                    )}
                </Menu>

                {/* Reject Dialog */}
                <Dialog open={rejectDialog.open} onClose={() => setRejectDialog({ open: false, reason: '', subscriptionId: null })}>
                    <DialogTitle>
                        <Box display="flex" alignItems="center" gap={1}>
                            <RejectIcon color="error" />
                            <Typography variant="h6">Reject Subscription</Typography>
                        </Box>
                    </DialogTitle>
                    <DialogContent>
                        <TextField
                            autoFocus
                            margin="dense"
                            label="Reason (optional)"
                            fullWidth
                            multiline
                            rows={3}
                            value={rejectDialog.reason || ''}
                            onChange={(e) => setRejectDialog(prev => ({ ...prev, reason: e.target.value }))}
                            placeholder="Enter reason for rejection..."
                        />
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setRejectDialog({ open: false, reason: '', subscriptionId: null })}>Cancel</Button>
                        <Button
                            onClick={() => {
                                if (rejectDialog.subscriptionId) {
                                    handleReject(rejectDialog.subscriptionId, rejectDialog.reason);
                                }
                            }}
                            color="error"
                            variant="contained"
                        >
                            Reject
                        </Button>
                    </DialogActions>
                </Dialog>

                {/* ✅ Approve Dialog with Progress - User Name Displayed */}
                <Dialog
                    open={approveDialog.open}
                    onClose={approveDialog.loading ? null : closeApproveDialog}
                    maxWidth="sm"
                    fullWidth
                    PaperProps={{
                        sx: {
                            borderRadius: 3,
                            overflow: 'hidden',
                            border: approveDialog.status === 'done' ? '2px solid #10b981' :
                                approveDialog.status === 'error' ? '2px solid #ef4444' : 'none',
                        }
                    }}
                >
                    <DialogTitle sx={{ pb: 1 }}>
                        <Box display="flex" alignItems="center" gap={1.5}>
                            <Avatar
                                sx={{
                                    bgcolor: approveDialog.status === 'done' ? '#10b981' :
                                        approveDialog.status === 'error' ? '#ef4444' : '#f59e0b',
                                    width: 40,
                                    height: 40,
                                }}
                            >
                                {approveDialog.status === 'done' ? <VerifiedIcon /> :
                                    approveDialog.status === 'error' ? <RejectIcon /> :
                                        <ApproveIcon />}
                            </Avatar>
                            <Box>
                                <Typography variant="h6" fontWeight="bold">
                                    {approveDialog.status === 'done' ? 'Approved Successfully!' :
                                        approveDialog.status === 'error' ? 'Approval Failed' :
                                            'Confirm Approval'}
                                </Typography>
                                {approveDialog.subscription && (
                                    <Typography variant="body2" color="textSecondary">
                                        Subscription #{approveDialog.subscription.id}
                                    </Typography>
                                )}
                            </Box>
                        </Box>
                    </DialogTitle>

                    <DialogContent>
                        {approveDialog.status === 'idle' && (
                            <Box sx={{ py: 2 }}>
                                <Alert
                                    severity="info"
                                    sx={{ mb: 2, borderRadius: 2 }}
                                >
                                    You are about to approve this subscription. The user will gain access immediately.
                                </Alert>

                                {/* ✅ User/Technician Card */}
                                <Paper
                                    elevation={0}
                                    sx={{
                                        p: 2,
                                        mb: 2,
                                        borderRadius: 2,
                                        backgroundColor: colors.sky,
                                        border: `1px solid ${colors.middle}`,
                                    }}
                                >
                                    <Box display="flex" alignItems="center" gap={2}>
                                        <Avatar
                                            sx={{
                                                width: 48,
                                                height: 48,
                                                bgcolor: colors.primary,
                                                color: 'white',
                                                fontWeight: 'bold',
                                            }}
                                        >
                                            {approveDialog.subscription?.user?.name?.[0]?.toUpperCase() || 'U'}
                                        </Avatar>
                                        <Box>
                                            <Typography variant="subtitle1" fontWeight="bold">
                                                {approveDialog.subscription?.user?.name || 'Unknown User'}
                                            </Typography>
                                            <Typography variant="body2" color="textSecondary">
                                                {approveDialog.subscription?.user?.email || 'No email'}
                                            </Typography>
                                            {approveDialog.subscription?.user?.phone && (
                                                <Typography variant="caption" color="textSecondary">
                                                    📞 {approveDialog.subscription.user.phone}
                                                </Typography>
                                            )}
                                        </Box>
                                    </Box>
                                </Paper>

                                {/* ✅ Subscription Details */}
                                <Grid container spacing={2}>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="textSecondary">Plan</Typography>
                                        <Typography variant="body2" fontWeight={500}>
                                            {approveDialog.subscription?.rate_card?.name || '-'}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="textSecondary">Amount</Typography>
                                        <Typography variant="body2" fontWeight={600} color={colors.primary}>
                                            {approveDialog.subscription?.amount || '-'}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="textSecondary">Payment Method</Typography>
                                        <Typography variant="body2">{approveDialog.subscription?.payment_method || '-'}</Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="textSecondary">Reference</Typography>
                                        <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                                            {approveDialog.subscription?.payment_reference || '-'}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="textSecondary">Created</Typography>
                                        <Typography variant="body2">{formatDate(approveDialog.subscription?.created_at)}</Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="caption" color="textSecondary">Status</Typography>
                                        <Chip
                                            label="Pending Approval"
                                            size="small"
                                            sx={{
                                                backgroundColor: '#fef3c7',
                                                color: '#f59e0b',
                                                fontWeight: 600,
                                            }}
                                        />
                                    </Grid>
                                </Grid>
                            </Box>
                        )}

                        {(approveDialog.status === 'confirming' || approveDialog.status === 'approving') && (
                            <Box sx={{ py: 3 }}>
                                <Box display="flex" justifyContent="center" mb={3}>
                                    <CircularProgress
                                        size={60}
                                        thickness={4}
                                        value={approveDialog.progress}
                                        variant="determinate"
                                        sx={{ color: '#10b981' }}
                                    />
                                </Box>
                                <Box display="flex" justifyContent="center" mb={1}>
                                    <Typography variant="h5" fontWeight="bold" color="#10b981">
                                        {approveDialog.progress}%
                                    </Typography>
                                </Box>
                                <LinearProgress
                                    variant="determinate"
                                    value={approveDialog.progress}
                                    sx={{
                                        height: 8,
                                        borderRadius: 4,
                                        mb: 2,
                                        backgroundColor: '#e5e7eb',
                                        '& .MuiLinearProgress-bar': {
                                            backgroundColor: '#10b981',
                                            borderRadius: 4,
                                        }
                                    }}
                                />
                                <Typography variant="body2" color="textSecondary" textAlign="center">
                                    {approveDialog.status || 'Processing...'}
                                </Typography>
                                <Typography variant="caption" color="textSecondary" textAlign="center" display="block" sx={{ mt: 1 }}>
                                    {approveDialog.subscription?.user?.name || 'User'}
                                </Typography>
                            </Box>
                        )}

                        {approveDialog.status === 'done' && (
                            <Box sx={{ py: 2, textAlign: 'center' }}>
                                <Box
                                    sx={{
                                        width: 80,
                                        height: 80,
                                        borderRadius: '50%',
                                        backgroundColor: '#d1fae5',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        margin: '0 auto 16px',
                                    }}
                                >
                                    <VerifiedIcon sx={{ fontSize: 48, color: '#10b981' }} />
                                </Box>
                                <Typography variant="h6" fontWeight="bold" color="#10b981">
                                    Subscription Approved!
                                </Typography>
                                <Typography variant="body2" color="textSecondary">
                                    {approveDialog.subscription?.user?.name || 'User'} can now access all features.
                                </Typography>
                            </Box>
                        )}

                        {approveDialog.status === 'error' && (
                            <Box sx={{ py: 2 }}>
                                <Alert severity="error" sx={{ borderRadius: 2 }}>
                                    {approveDialog.error || 'An error occurred while approving the subscription.'}
                                </Alert>
                            </Box>
                        )}
                    </DialogContent>

                    <DialogActions sx={{ p: 3, pt: 0 }}>
                        {approveDialog.status === 'idle' && (
                            <>
                                <Button onClick={closeApproveDialog} disabled={approveDialog.loading}>
                                    Cancel
                                </Button>
                                <Button
                                    onClick={handleApproveConfirm}
                                    variant="contained"
                                    color="success"
                                    disabled={approveDialog.loading}
                                    startIcon={<ApproveIcon />}
                                    sx={{
                                        borderRadius: 2,
                                        px: 3,
                                    }}
                                >
                                    Confirm Approve
                                </Button>
                            </>
                        )}

                        {approveDialog.status === 'done' && (
                            <Button
                                onClick={closeApproveDialog}
                                variant="contained"
                                color="success"
                                sx={{ borderRadius: 2, px: 4 }}
                            >
                                Done
                            </Button>
                        )}

                        {approveDialog.status === 'error' && (
                            <>
                                <Button onClick={closeApproveDialog}>
                                    Cancel
                                </Button>
                                <Button
                                    onClick={handleApproveConfirm}
                                    variant="contained"
                                    color="success"
                                    startIcon={<RefreshIcon />}
                                    sx={{ borderRadius: 2 }}
                                >
                                    Retry
                                </Button>
                            </>
                        )}

                        {(approveDialog.status === 'confirming' || approveDialog.status === 'approving') && (
                            <Typography variant="caption" color="textSecondary">
                                Please wait...
                            </Typography>
                        )}
                    </DialogActions>
                </Dialog>

                {/* View Details Dialog */}
                <Dialog
                    open={viewDialog.open}
                    onClose={() => setViewDialog({ open: false, subscription: null })}
                    maxWidth="md"
                    fullWidth
                >
                    <DialogTitle>
                        <Box display="flex" alignItems="center" gap={1}>
                            <InfoIcon color="primary" />
                            <Typography variant="h6">Subscription Details</Typography>
                        </Box>
                    </DialogTitle>
                    <DialogContent>
                        {viewDialog.subscription && (
                            <Box>
                                <Grid container spacing={2}>
                                    <Grid item xs={12}>
                                        <Typography variant="subtitle2" color="textSecondary">User</Typography>
                                        <Typography variant="body1" fontWeight={500}>
                                            {viewDialog.subscription.user?.name || '-'}
                                        </Typography>
                                        <Typography variant="body2" color="textSecondary">
                                            {viewDialog.subscription.user?.email || ''}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="textSecondary">Plan</Typography>
                                        <Typography variant="body1">{viewDialog.subscription.rate_card?.name || '-'}</Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="textSecondary">Amount</Typography>
                                        <Typography variant="body1" fontWeight={600} color={colors.primary}>
                                            {viewDialog.subscription.amount || '-'}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="textSecondary">Status</Typography>
                                        {getStatusChip(viewDialog.subscription.status, viewDialog.subscription.expiry_date)}
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="textSecondary">Payment Method</Typography>
                                        <Typography variant="body1">{viewDialog.subscription.payment_method || '-'}</Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="textSecondary">Reference</Typography>
                                        <Typography variant="body1" sx={{ fontFamily: 'monospace' }}>
                                            {viewDialog.subscription.payment_reference || '-'}
                                        </Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="textSecondary">Created At</Typography>
                                        <Typography variant="body1">{formatDate(viewDialog.subscription.created_at)}</Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="textSecondary">Start Date</Typography>
                                        <Typography variant="body1">{formatDate(viewDialog.subscription.start_date)}</Typography>
                                    </Grid>
                                    <Grid item xs={6}>
                                        <Typography variant="subtitle2" color="textSecondary">Expiry Date</Typography>
                                        <Typography variant="body1">{formatDate(viewDialog.subscription.expiry_date)}</Typography>
                                    </Grid>
                                    <Grid item xs={12}>
                                        <Typography variant="subtitle2" color="textSecondary">Admin Notes</Typography>
                                        <Typography variant="body2" sx={{ fontStyle: 'italic' }}>
                                            {viewDialog.subscription.admin_notes || 'No notes'}
                                        </Typography>
                                    </Grid>
                                    {viewDialog.subscription.invoice && (
                                        <Grid item xs={12}>
                                            <Divider sx={{ my: 1 }} />
                                            <Typography variant="subtitle1" fontWeight={600}>Invoice</Typography>
                                            <Box display="flex" gap={2} mt={1}>
                                                <Typography variant="body2">
                                                    <strong>Number:</strong> {viewDialog.subscription.invoice.number}
                                                </Typography>
                                                <Typography variant="body2">
                                                    <strong>Status:</strong> {viewDialog.subscription.invoice.status_label}
                                                </Typography>
                                                <Typography variant="body2">
                                                    <strong>Amount:</strong> {viewDialog.subscription.invoice.amount}
                                                </Typography>
                                            </Box>
                                            {viewDialog.subscription.invoice.pdf_url && (
                                                <Button
                                                    size="small"
                                                    variant="outlined"
                                                    startIcon={<DownloadIcon />}
                                                    onClick={() => handleViewInvoice(viewDialog.subscription)}
                                                    sx={{ mt: 1 }}
                                                >
                                                    Download Invoice
                                                </Button>
                                            )}
                                        </Grid>
                                    )}
                                </Grid>
                            </Box>
                        )}
                    </DialogContent>
                    <DialogActions>
                        <Button onClick={() => setViewDialog({ open: false, subscription: null })}>Close</Button>
                    </DialogActions>
                </Dialog>
            </Box>
        </>
    );
};

export default SubscriptionList;