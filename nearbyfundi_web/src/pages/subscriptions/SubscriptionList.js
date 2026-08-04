import React, { useState, useEffect, useCallback } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell, TableContainer,
    TableHead, TableRow, TablePagination, TableSortLabel, TextField, InputAdornment,
    IconButton, Chip, Menu, MenuItem, Dialog, DialogTitle, DialogContent,
    DialogActions, CircularProgress, useMediaQuery, useTheme, Alert,
    Grid, Card, CardContent, Tooltip, Avatar, LinearProgress,
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

                // Set subscriptions
                if (data?.data) {
                    setSubscriptions(data.data);
                } else if (Array.isArray(data)) {
                    setSubscriptions(data);
                } else {
                    setSubscriptions([]);
                }

                // Set pagination
                if (data?.pagination) {
                    setTotalCount(data.pagination.total || 0);
                }

                // Set stats from filters
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
    // HANDLERS
    // ============================================================

    const handleApprove = async (id) => {
        try {
            await subscriptionService.approveSubscription(id);
            showSnackbar({ type: 'success', message: `Subscription #${id} approved` });
            refresh();
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Approval failed' });
        }
        setActionMenu(null);
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

    // ============================================================
    // ✅ FIXED: INVOICE DOWNLOAD WITH AUTHENTICATION
    // ============================================================
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

            // Create a blob URL and trigger download
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
            // If blob download fails, try alternative method with pdf_url
            if (sub.invoice?.pdf_url) {
                try {
                    // Try opening the PDF URL in a new tab as fallback
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

    // ============================================================
    // ALTERNATIVE: DOWNLOAD USING PDF_URL (if available)
    // ============================================================
    const handleViewInvoiceWithUrl = (sub) => {
        if (sub.invoice?.pdf_url) {
            // Use the direct PDF URL if available
            window.open(sub.invoice.pdf_url, '_blank');
        } else {
            // Fallback to blob download
            handleViewInvoice(sub);
        }
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
        const headers = ['User', 'Plan', 'Amount', 'Status', 'Payment Method', 'Reference', 'Date'];
        const rows = subscriptions.map(sub => [
            sub.user?.name || '-',
            sub.rate_card?.name || '-',
            sub.amount || '-',
            sub.status || '-',
            sub.payment_method || '-',
            sub.payment_reference || '-',
            formatDate(sub.created_at),
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
        const headers = ['User', 'Plan', 'Amount', 'Status', 'Payment Method', 'Reference', 'Date'];
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

    const getStatusChip = (status) => {
        const map = {
            pending: { color: '#f59e0b', bg: '#fef3c7', label: 'Pending' },
            active: { color: '#10b981', bg: '#d1fae5', label: 'Active' },
            expired: { color: '#ef4444', bg: '#fee2e2', label: 'Expired' },
            cancelled: { color: '#6b7280', bg: '#f3f4f6', label: 'Cancelled' },
        };
        const s = map[status] || { color: '#6b7280', bg: '#f3f4f6', label: status };
        return <Chip label={s.label} sx={{ backgroundColor: s.bg, color: s.color }} size="small" />;
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
        },
        {
            title: 'Active',
            count: stats.active_count || 0,
            icon: <ActiveIcon sx={{ color: 'white', fontSize: 24 }} />,
            color: '#10b981',
            bgColor: '#ecfdf5',
            borderColor: '#10b981',
        },
        {
            title: 'Expired',
            count: stats.expired_count || 0,
            icon: <ExpiredIcon sx={{ color: 'white', fontSize: 24 }} />,
            color: '#ef4444',
            bgColor: '#fef2f2',
            borderColor: '#ef4444',
        },
        {
            title: 'Cancelled',
            count: stats.cancelled_count || 0,
            icon: <CancelledIcon sx={{ color: 'white', fontSize: 24 }} />,
            color: '#6b7280',
            bgColor: '#f9fafb',
            borderColor: '#6b7280',
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
            `}</style>

            <Box sx={{ width: '100%', p: { xs: 1, sm: 2 } }}>
                {/* Stats Cards */}
                <Grid container spacing={2} sx={{ mb: 3 }}>
                    {statCards.map((card, index) => (
                        <Grid item xs={6} sm={3} key={index}>
                            <Card
                                sx={{
                                    bgcolor: card.bgColor,
                                    borderLeft: `4px solid ${card.borderColor}`,
                                    transition: 'all 0.3s ease',
                                    '&:hover': {
                                        transform: 'translateY(-6px)',
                                        boxShadow: '0 12px 24px rgba(0,0,0,0.1)',
                                    },
                                    position: 'relative',
                                    overflow: 'hidden',
                                }}
                            >
                                <Box
                                    sx={{
                                        position: 'absolute',
                                        right: -20,
                                        top: -20,
                                        width: 100,
                                        height: 100,
                                        borderRadius: '50%',
                                        bgcolor: card.color,
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
                                                bgcolor: card.color,
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
                                <Button variant="outlined" startIcon={<RefreshIcon />} onClick={refresh}>
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
                                        <TableRow><TableCell colSpan={headCells.length} align="center">No subscriptions found</TableCell></TableRow>
                                    ) : (
                                        subscriptions.map((sub) => (
                                            <TableRow key={sub.id} hover>
                                                <TableCell>{sub.user?.name || '-'}</TableCell>
                                                <TableCell>{sub.rate_card?.name || '-'}</TableCell>
                                                <TableCell>{sub.amount || '-'}</TableCell>
                                                <TableCell>{getStatusChip(sub.status)}</TableCell>
                                                <TableCell>{sub.payment_method || '-'}</TableCell>
                                                <TableCell>{sub.payment_reference || '-'}</TableCell>
                                                <TableCell>{formatDate(sub.created_at)}</TableCell>
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
                                        ))
                                    )}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    ) : (
                        <Box sx={{ p: 2 }}>
                            {subscriptions.length === 0 ? (
                                <Typography sx={{ py: 2, textAlign: 'center', color: colors.rain }}>No subscriptions found</Typography>
                            ) : (
                                subscriptions.map(sub => (
                                    <Card key={sub.id} sx={{ mb: 2 }}>
                                        <CardContent>
                                            <Box display="flex" justifyContent="space-between">
                                                <Typography variant="subtitle1"><strong>{sub.user?.name}</strong></Typography>
                                                {getStatusChip(sub.status)}
                                            </Box>
                                            <Typography variant="body2">Plan: {sub.rate_card?.name}</Typography>
                                            <Typography variant="body2">Amount: {sub.amount}</Typography>
                                            <Typography variant="body2">Method: {sub.payment_method}</Typography>
                                            <Typography variant="body2">Reference: {sub.payment_reference || '-'}</Typography>
                                            <Typography variant="body2">Date: {formatDate(sub.created_at)}</Typography>
                                            <Box mt={1} display="flex" gap={1}>
                                                {canApprove && sub.status === 'pending' && (
                                                    <>
                                                        <Button size="small" variant="contained" color="success" onClick={() => handleApprove(sub.id)}>Approve</Button>
                                                        <Button size="small" variant="contained" color="error" onClick={() => {
                                                            setRejectDialog({ open: true, reason: '', subscriptionId: sub.id });
                                                        }}>Reject</Button>
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
                                            </Box>
                                        </CardContent>
                                    </Card>
                                ))
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
                            <MenuItem onClick={() => handleApprove(selectedSub.id)}>
                                <ApproveIcon sx={{ mr: 1, color: 'success.main' }} /> Approve
                            </MenuItem>
                            <MenuItem onClick={() => {
                                setRejectDialog({ open: true, reason: '', subscriptionId: selectedSub.id });
                                handleMenuClose();
                            }}>
                                <RejectIcon sx={{ mr: 1, color: 'error.main' }} /> Reject
                            </MenuItem>
                        </>
                    )}
                    {selectedSub?.invoice && (
                        <MenuItem onClick={() => handleViewInvoice(selectedSub)}>
                            <DownloadIcon sx={{ mr: 1 }} /> Download Invoice
                        </MenuItem>
                    )}
                </Menu>

                {/* Reject Dialog */}
                <Dialog open={rejectDialog.open} onClose={() => setRejectDialog({ open: false, reason: '', subscriptionId: null })}>
                    <DialogTitle>Reject Subscription</DialogTitle>
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
            </Box>
        </>
    );
};

export default SubscriptionList;