// src/pages/sms/SmsLogsList.jsx
import React, { useState, useEffect, useMemo } from 'react';
import {
    Box,
    Paper,
    Typography,
    Button,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TablePagination,
    TableSortLabel,
    TextField,
    InputAdornment,
    IconButton,
    Menu,
    MenuItem,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    CircularProgress,
    Chip,
    Card,
    CardContent,
    Grid,
    Divider,
    Alert,
    Tooltip,
    LinearProgress,
    FormControl,
    InputLabel,
    Select,
    useMediaQuery,
    useTheme,
    Stack,
    Avatar,
} from '@mui/material';
import {
    Search as SearchIcon,
    Refresh as RefreshIcon,
    MoreVert as MoreVertIcon,
    Delete as DeleteIcon,
    Person as PersonIcon,
    Phone as PhoneIcon,
    CheckCircle as CheckCircleIcon,
    Error as ErrorIcon,
    Pending as PendingIcon,
    Send as SendIcon,
    Replay as ReplayIcon,
    Clear as ClearIcon,
    Visibility as VisibilityIcon,
    VisibilityOff as VisibilityOffIcon,
    Message as MessageIcon,
    TrendingUp as TrendingUpIcon,
} from '@mui/icons-material';
import { useSmsManagement } from 'hooks/useSms';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';
import SendSmsDialog from './SendSmsDialog';
import UserSelector from './UserSelector';

const colors = appConfig.app.colors;

// Strong, high-contrast status styles
const statusStyles = {
    sent: {
        color: '#047857',
        bg: '#d1fae5',
        border: '#10b981',
        label: 'Sent',
        icon: <CheckCircleIcon sx={{ fontSize: 16 }} />,
    },
    failed: {
        color: '#b91c1c',
        bg: '#fee2e2',
        border: '#ef4444',
        label: 'Failed',
        icon: <ErrorIcon sx={{ fontSize: 16 }} />,
    },
    pending: {
        color: '#b45309',
        bg: '#fef3c7',
        border: '#f59e0b',
        label: 'Pending',
        icon: <PendingIcon sx={{ fontSize: 16 }} />,
    },
    queued: {
        color: '#1d4ed8',
        bg: '#dbeafe',
        border: '#3b82f6',
        label: 'Queued',
        icon: <PendingIcon sx={{ fontSize: 16 }} />,
    },
};

const headCells = [
    { id: 'user', label: 'User', disableSort: true },
    { id: 'recipient', label: 'Recipient' },
    { id: 'message', label: 'Message', disableSort: true },
    { id: 'status', label: 'Status' },
    { id: 'created_at', label: 'Sent At' },
    { id: 'actions', label: 'Actions', disableSort: true },
];

const SmsLogsList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const {
        logs,
        loading,
        error,
        pagination,
        getSmsLogs,
        getUserSmsLogs,
        getSmsStats,
        sendSms,
        resendSms,
        deleteSmsLog,
        clearError,
    } = useSmsManagement();

    const { can } = usePermissions();

    const [search, setSearch] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [selectedUserId, setSelectedUserId] = useState(null);
    const [order, setOrder] = useState('desc');
    const [orderBy, setOrderBy] = useState('created_at');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedLog, setSelectedLog] = useState(null);
    const [showMessage, setShowMessage] = useState({});

    const [sendDialogOpen, setSendDialogOpen] = useState(false);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });
    const [userSelectorOpen, setUserSelectorOpen] = useState(false);

    const [smsStats, setSmsStats] = useState({
        total: 0,
        sent: 0,
        failed: 0,
        pending: 0,
        success_rate: 0,
        failed_percentage: 0,
    });
    const [loadingStats, setLoadingStats] = useState(false);

    const canView = can('sms.view');
    const canSend = can('sms.send');
    const canDelete = can('sms.delete');
    const canResend = can('sms.resend');

    useEffect(() => {
        if (canView) loadLogs();
    }, [page, rowsPerPage, search, statusFilter, selectedUserId]);

    useEffect(() => {
        if (canView) loadStats();
    }, []);

    const loadLogs = async () => {
        const params = {
            page: page + 1,
            per_page: rowsPerPage,
            search: search || undefined,
            status: statusFilter !== 'all' ? statusFilter : undefined,
        };
        try {
            if (selectedUserId) {
                await getUserSmsLogs(selectedUserId, params);
            } else {
                await getSmsLogs(params);
            }
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Failed to load SMS logs' });
        }
    };

    const loadStats = async () => {
        setLoadingStats(true);
        try {
            const stats = await getSmsStats({ range: 'all', status: 'all' });
            setSmsStats(stats || {
                total: 0, sent: 0, failed: 0, pending: 0, success_rate: 0, failed_percentage: 0,
            });
        } catch (err) {
            console.error('Failed to load SMS stats:', err);
            setSmsStats({ total: 0, sent: 0, failed: 0, pending: 0, success_rate: 0, failed_percentage: 0 });
        } finally {
            setLoadingStats(false);
        }
    };

    const sortedData = useMemo(() => {
        if (!Array.isArray(logs)) return [];
        const sorted = [...logs];
        sorted.sort((a, b) => {
            let aValue, bValue;
            switch (orderBy) {
                case 'recipient':
                    aValue = a.recipient || '';
                    bValue = b.recipient || '';
                    break;
                case 'status':
                    aValue = a.status || '';
                    bValue = b.status || '';
                    break;
                case 'created_at':
                    aValue = a.created_at || '';
                    bValue = b.created_at || '';
                    break;
                default:
                    aValue = a[orderBy] || '';
                    bValue = b[orderBy] || '';
            }
            if (typeof aValue === 'string') {
                aValue = aValue.toLowerCase();
                bValue = bValue.toLowerCase();
            }
            if (aValue < bValue) return order === 'asc' ? -1 : 1;
            if (aValue > bValue) return order === 'asc' ? 1 : -1;
            return 0;
        });
        return sorted;
    }, [logs, orderBy, order]);

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    const handleMenuOpen = (event, log) => {
        setSelectedLog(log);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => setActionMenu(null);

    const openConfirmDialog = (title, message, actionFn) => {
        setConfirmDialog({ open: true, title, message, action: actionFn });
    };

    const handleAction = async (actionType) => {
        if (!selectedLog) return;
        handleMenuClose();

        if (actionType === 'resend') {
            openConfirmDialog(
                'Resend SMS',
                `Are you sure you want to resend this SMS to ${selectedLog.recipient}?`,
                async () => {
                    try {
                        await resendSms(selectedLog.id);
                        showSnackbar({ type: 'success', message: 'SMS resent successfully' });
                        await loadLogs();
                        await loadStats();
                    } catch (err) {
                        showSnackbar({ type: 'error', message: 'Failed to resend SMS' });
                    }
                }
            );
        } else if (actionType === 'delete') {
            openConfirmDialog(
                'Delete SMS Log',
                'Are you sure you want to delete this SMS log?',
                async () => {
                    try {
                        await deleteSmsLog(selectedLog.id);
                        showSnackbar({ type: 'success', message: 'SMS log deleted successfully' });
                        await loadLogs();
                        await loadStats();
                    } catch (err) {
                        showSnackbar({ type: 'error', message: 'Failed to delete SMS log' });
                    }
                }
            );
        }
    };

    const handleConfirm = async () => {
        if (!confirmDialog.action) return;
        const action = confirmDialog.action;
        setConfirmDialog((prev) => ({ ...prev, open: false }));
        try {
            await action();
        } catch (err) {
            // already handled
        }
    };

    const formatDate = (dateStr) => {
        if (!dateStr) return '—';
        try {
            return new Date(dateStr).toLocaleString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
            });
        } catch {
            return '—';
        }
    };

    const getStatusChip = (status) => {
        const s = statusStyles[status] || {
            color: '#374151',
            bg: '#f3f4f6',
            border: '#9ca3af',
            label: status || 'Unknown',
            icon: null,
        };
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
                    '& .MuiChip-label': { px: 1 },
                }}
            />
        );
    };

    const toggleMessageVisibility = (logId) => {
        setShowMessage((prev) => ({ ...prev, [logId]: !prev[logId] }));
    };

    const getMessagePreview = (message, logId) => {
        if (!message) return '—';
        if (showMessage[logId]) return message;
        return message.length > 55 ? `${message.substring(0, 55)}…` : message;
    };

    const getUserDisplay = (log) => {
        if (log.user) {
            return (
                <Stack direction="row" spacing={1.5} alignItems="center">
                    <Avatar
                        sx={{
                            width: 36,
                            height: 36,
                            bgcolor: colors.sea || '#0f766e',
                            fontSize: 14,
                            fontWeight: 700,
                        }}
                    >
                        {(log.user.name || 'U').charAt(0).toUpperCase()}
                    </Avatar>
                    <Box>
                        <Typography variant="body2" fontWeight={600} color="text.primary">
                            {log.user.name || 'Unknown User'}
                        </Typography>
                        {log.user.email && (
                            <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                                {log.user.email}
                            </Typography>
                        )}
                    </Box>
                </Stack>
            );
        }
        return (
            <Stack direction="row" spacing={1.5} alignItems="center">
                <Avatar sx={{ width: 36, height: 36, bgcolor: '#64748b', fontSize: 14, fontWeight: 700 }}>
                    S
                </Avatar>
                <Typography variant="body2" fontWeight={600} color="text.secondary">
                    System
                </Typography>
            </Stack>
        );
    };

    const totalCount = pagination?.total || logs?.length || 0;

    // ── Permission / Error states ───────────────────────────────────────────
    if (!canView) {
        return (
            <Box p={3}>
                <Paper
                    elevation={0}
                    sx={{
                        p: 4,
                        textAlign: 'center',
                        borderRadius: 3,
                        border: '1px solid',
                        borderColor: 'divider',
                    }}
                >
                    <Typography color="error" fontWeight={600}>
                        You do not have permission to view SMS logs.
                    </Typography>
                </Paper>
            </Box>
        );
    }

    if (error) {
        return (
            <Box p={3}>
                <Alert
                    severity="error"
                    variant="filled"
                    action={
                        <Button color="inherit" size="small" onClick={() => { clearError(); loadLogs(); }}>
                            Retry
                        </Button>
                    }
                    sx={{ borderRadius: 2 }}
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    // ── Main Render ────────────────────────────────────────────────────────
    return (
        <Box sx={{ width: '100%', p: { xs: 1.5, sm: 2.5 }, m: 0, bgcolor: 'background.default' }}>
            {/* ── Stats Cards ─────────────────────────────────────────────── */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                {/* Total */}
                <Grid item xs={12} sm={6} md={3}>
                    <Card
                        elevation={0}
                        sx={{
                            borderRadius: 3,
                            border: '1px solid',
                            borderColor: 'divider',
                            background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)',
                            height: '100%',
                        }}
                    >
                        <CardContent sx={{ p: 2.5 }}>
                            <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                                <Box>
                                    <Typography variant="overline" fontWeight={700} color="text.secondary" letterSpacing={1}>
                                        Total Messages
                                    </Typography>
                                    <Typography variant="h3" fontWeight={800} color="#0369a1" sx={{ mt: 0.5, lineHeight: 1.1 }}>
                                        {loadingStats ? '—' : smsStats.total}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary" fontWeight={500}>
                                        All time
                                    </Typography>
                                </Box>
                                <Avatar sx={{ bgcolor: '#0ea5e9', width: 44, height: 44 }}>
                                    <MessageIcon />
                                </Avatar>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                {/* Sent */}
                <Grid item xs={12} sm={6} md={3}>
                    <Card
                        elevation={0}
                        sx={{
                            borderRadius: 3,
                            border: '1px solid',
                            borderColor: 'divider',
                            background: 'linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%)',
                            height: '100%',
                        }}
                    >
                        <CardContent sx={{ p: 2.5 }}>
                            <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                                <Box>
                                    <Typography variant="overline" fontWeight={700} color="text.secondary" letterSpacing={1}>
                                        Sent Successfully
                                    </Typography>
                                    <Typography variant="h3" fontWeight={800} color="#047857" sx={{ mt: 0.5, lineHeight: 1.1 }}>
                                        {loadingStats ? '—' : smsStats.sent}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary" fontWeight={500}>
                                        {smsStats.success_rate || 0}% success rate
                                    </Typography>
                                </Box>
                                <Avatar sx={{ bgcolor: '#10b981', width: 44, height: 44 }}>
                                    <CheckCircleIcon />
                                </Avatar>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                {/* Failed */}
                <Grid item xs={12} sm={6} md={3}>
                    <Card
                        elevation={0}
                        sx={{
                            borderRadius: 3,
                            border: '1px solid',
                            borderColor: 'divider',
                            background: 'linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%)',
                            height: '100%',
                        }}
                    >
                        <CardContent sx={{ p: 2.5 }}>
                            <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                                <Box>
                                    <Typography variant="overline" fontWeight={700} color="text.secondary" letterSpacing={1}>
                                        Failed
                                    </Typography>
                                    <Typography variant="h3" fontWeight={800} color="#b91c1c" sx={{ mt: 0.5, lineHeight: 1.1 }}>
                                        {loadingStats ? '—' : smsStats.failed}
                                    </Typography>
                                    <Typography variant="caption" color="text.secondary" fontWeight={500}>
                                        {smsStats.failed_percentage || 0}% of total
                                    </Typography>
                                </Box>
                                <Avatar sx={{ bgcolor: '#ef4444', width: 44, height: 44 }}>
                                    <ErrorIcon />
                                </Avatar>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                {/* Success Rate */}
                <Grid item xs={12} sm={6} md={3}>
                    <Card
                        elevation={0}
                        sx={{
                            borderRadius: 3,
                            border: '1px solid',
                            borderColor: 'divider',
                            background: 'linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%)',
                            height: '100%',
                        }}
                    >
                        <CardContent sx={{ p: 2.5 }}>
                            <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={1}>
                                <Box>
                                    <Typography variant="overline" fontWeight={700} color="text.secondary" letterSpacing={1}>
                                        Success Rate
                                    </Typography>
                                    <Typography variant="h3" fontWeight={800} color="#15803d" sx={{ mt: 0.5, lineHeight: 1.1 }}>
                                        {loadingStats ? '—' : `${smsStats.success_rate || 0}%`}
                                    </Typography>
                                </Box>
                                <Avatar sx={{ bgcolor: '#22c55e', width: 44, height: 44 }}>
                                    <TrendingUpIcon />
                                </Avatar>
                            </Stack>
                            <LinearProgress
                                variant="determinate"
                                value={smsStats.success_rate || 0}
                                sx={{
                                    height: 8,
                                    borderRadius: 4,
                                    bgcolor: 'rgba(0,0,0,0.08)',
                                    '& .MuiLinearProgress-bar': {
                                        borderRadius: 4,
                                        bgcolor: (smsStats.success_rate || 0) >= 80 ? '#22c55e' : '#f59e0b',
                                    },
                                }}
                            />
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* ── Main Panel ──────────────────────────────────────────────── */}
            <Paper
                elevation={0}
                sx={{
                    width: '100%',
                    borderRadius: 3,
                    overflow: 'hidden',
                    border: '1px solid',
                    borderColor: 'divider',
                    bgcolor: 'background.paper',
                }}
            >
                {/* Header */}
                <Box
                    sx={{
                        px: { xs: 2, sm: 3 },
                        py: 2.5,
                        borderBottom: '1px solid',
                        borderColor: 'divider',
                        bgcolor: 'background.paper',
                    }}
                >
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        justifyContent="space-between"
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        spacing={2}
                        mb={2.5}
                    >
                        <Box>
                            <Typography variant="h5" fontWeight={800} color="text.primary">
                                SMS Logs
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                Track every message sent from the system
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} justifyContent={{ xs: 'flex-end', sm: 'flex-start' }}>
                            {canSend && (
                                <Button
                                    variant="contained"
                                    startIcon={<SendIcon />}
                                    onClick={() => setSendDialogOpen(true)}
                                    size={isMobile ? 'small' : 'medium'}
                                    sx={{
                                        borderRadius: 2,
                                        fontWeight: 700,
                                        textTransform: 'none',
                                        px: 2.5,
                                        boxShadow: 'none',
                                        bgcolor: colors.salat || '#10b981',
                                        '&:hover': {
                                            bgcolor: colors.dark || '#047857',
                                            boxShadow: '0 4px 12px rgba(16,185,129,0.35)',
                                        },
                                    }}
                                >
                                    Send SMS
                                </Button>
                            )}
                            <Button
                                variant="outlined"
                                startIcon={<RefreshIcon />}
                                onClick={() => { loadLogs(); loadStats(); }}
                                size={isMobile ? 'small' : 'medium'}
                                sx={{
                                    borderRadius: 2,
                                    fontWeight: 600,
                                    textTransform: 'none',
                                    borderColor: 'divider',
                                    color: 'text.primary',
                                    '&:hover': {
                                        borderColor: 'text.primary',
                                        bgcolor: 'action.hover',
                                    },
                                }}
                            >
                                Refresh
                            </Button>
                        </Stack>
                    </Stack>

                    {/* Filters */}
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        spacing={1.5}
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        flexWrap="wrap"
                    >
                        <TextField
                            placeholder="Search recipient, message…"
                            size="small"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            InputProps={{
                                startAdornment: (
                                    <InputAdornment position="start">
                                        <SearchIcon fontSize="small" color="action" />
                                    </InputAdornment>
                                ),
                                endAdornment: search ? (
                                    <InputAdornment position="end">
                                        <IconButton size="small" onClick={() => setSearch('')}>
                                            <ClearIcon fontSize="small" />
                                        </IconButton>
                                    </InputAdornment>
                                ) : null,
                            }}
                            sx={{
                                minWidth: { xs: '100%', sm: 260 },
                                flexGrow: { xs: 1, sm: 0 },
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    bgcolor: 'action.hover',
                                    '& fieldset': { borderColor: 'transparent' },
                                    '&:hover fieldset': { borderColor: 'divider' },
                                    '&.Mui-focused fieldset': { borderColor: 'primary.main' },
                                },
                            }}
                        />

                        <FormControl size="small" sx={{ minWidth: { xs: '100%', sm: 150 } }}>
                            <InputLabel>Status</InputLabel>
                            <Select
                                value={statusFilter}
                                onChange={(e) => setStatusFilter(e.target.value)}
                                label="Status"
                                sx={{
                                    borderRadius: 2,
                                    bgcolor: 'action.hover',
                                    '& .MuiOutlinedInput-notchedOutline': { borderColor: 'transparent' },
                                    '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: 'divider' },
                                }}
                            >
                                <MenuItem value="all">All statuses</MenuItem>
                                <MenuItem value="sent">Sent</MenuItem>
                                <MenuItem value="pending">Pending</MenuItem>
                                <MenuItem value="failed">Failed</MenuItem>
                                <MenuItem value="queued">Queued</MenuItem>
                            </Select>
                        </FormControl>

                        <Button
                            variant={selectedUserId ? 'contained' : 'outlined'}
                            startIcon={<PersonIcon />}
                            onClick={() => setUserSelectorOpen(true)}
                            size={isMobile ? 'small' : 'medium'}
                            sx={{
                                borderRadius: 2,
                                fontWeight: 600,
                                textTransform: 'none',
                                borderColor: selectedUserId ? 'transparent' : 'divider',
                                bgcolor: selectedUserId ? (colors.sea || '#0f766e') : 'transparent',
                                color: selectedUserId ? '#fff' : 'text.primary',
                                '&:hover': {
                                    bgcolor: selectedUserId ? (colors.dark || '#0d5c56') : 'action.hover',
                                    borderColor: selectedUserId ? 'transparent' : 'text.primary',
                                },
                            }}
                        >
                            {selectedUserId ? 'User filtered' : 'Filter by user'}
                            {selectedUserId && (
                                <IconButton
                                    size="small"
                                    sx={{ ml: 0.5, color: 'inherit', p: 0.25 }}
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        setSelectedUserId(null);
                                        setPage(0);
                                    }}
                                >
                                    <ClearIcon fontSize="small" />
                                </IconButton>
                            )}
                        </Button>
                    </Stack>
                </Box>

                {/* ── Table (desktop) ─────────────────────────────────────── */}
                {showTableView ? (
                    <TableContainer>
                        <Table sx={{ minWidth: 900 }}>
                            <TableHead>
                                <TableRow
                                    sx={{
                                        bgcolor: 'action.hover',
                                        '& th': {
                                            fontWeight: 700,
                                            fontSize: '0.8125rem',
                                            color: 'text.secondary',
                                            textTransform: 'uppercase',
                                            letterSpacing: 0.6,
                                            borderBottom: '1px solid',
                                            borderColor: 'divider',
                                            py: 1.75,
                                        },
                                    }}
                                >
                                    {headCells.map((cell) => (
                                        <TableCell key={cell.id} sx={{ whiteSpace: 'nowrap' }}>
                                            {!cell.disableSort ? (
                                                <TableSortLabel
                                                    active={orderBy === cell.id}
                                                    direction={orderBy === cell.id ? order : 'asc'}
                                                    onClick={() => handleRequestSort(cell.id)}
                                                >
                                                    {cell.label}
                                                </TableSortLabel>
                                            ) : (
                                                cell.label
                                            )}
                                        </TableCell>
                                    ))}
                                </TableRow>
                            </TableHead>

                            <TableBody>
                                {loading ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                            <CircularProgress size={36} thickness={4} />
                                        </TableCell>
                                    </TableRow>
                                ) : sortedData.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                            <Typography color="text.secondary" fontWeight={500}>
                                                {selectedUserId
                                                    ? 'No SMS logs found for this user'
                                                    : 'No SMS logs found'}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sortedData.map((log) => (
                                        <TableRow
                                            key={log.id}
                                            hover
                                            sx={{
                                                '&:last-child td': { borderBottom: 0 },
                                                transition: 'background-color 0.15s',
                                            }}
                                        >
                                            <TableCell sx={{ py: 2 }}>{getUserDisplay(log)}</TableCell>

                                            <TableCell>
                                                <Stack direction="row" spacing={1} alignItems="center">
                                                    <PhoneIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                                    <Typography variant="body2" fontWeight={600}>
                                                        {log.recipient || '—'}
                                                    </Typography>
                                                </Stack>
                                            </TableCell>

                                            <TableCell>
                                                <Stack direction="row" spacing={1} alignItems="flex-start">
                                                    <Tooltip title={showMessage[log.id] ? 'Hide message' : 'Show full message'}>
                                                        <IconButton
                                                            size="small"
                                                            onClick={() => toggleMessageVisibility(log.id)}
                                                            sx={{ mt: -0.25 }}
                                                        >
                                                            {showMessage[log.id] ? (
                                                                <VisibilityOffIcon fontSize="small" />
                                                            ) : (
                                                                <VisibilityIcon fontSize="small" />
                                                            )}
                                                        </IconButton>
                                                    </Tooltip>
                                                    <Typography
                                                        variant="body2"
                                                        sx={{
                                                            maxWidth: 320,
                                                            wordBreak: 'break-word',
                                                            color: 'text.primary',
                                                            lineHeight: 1.5,
                                                        }}
                                                    >
                                                        {getMessagePreview(log.message, log.id)}
                                                    </Typography>
                                                </Stack>
                                            </TableCell>

                                            <TableCell>
                                                <Stack direction="row" spacing={0.75} alignItems="center">
                                                    {getStatusChip(log.status)}
                                                    {log.error_message && (
                                                        <Tooltip title={log.error_message}>
                                                            <ErrorIcon
                                                                sx={{
                                                                    fontSize: 18,
                                                                    color: '#ef4444',
                                                                    cursor: 'help',
                                                                }}
                                                            />
                                                        </Tooltip>
                                                    )}
                                                </Stack>
                                            </TableCell>

                                            <TableCell>
                                                <Typography variant="body2" fontWeight={500} color="text.secondary">
                                                    {formatDate(log.created_at)}
                                                </Typography>
                                            </TableCell>

                                            <TableCell align="center">
                                                <IconButton
                                                    size="small"
                                                    onClick={(e) => handleMenuOpen(e, log)}
                                                    sx={{
                                                        color: 'text.secondary',
                                                        '&:hover': { bgcolor: 'action.hover', color: 'text.primary' },
                                                    }}
                                                >
                                                    <MoreVertIcon />
                                                </IconButton>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                ) : (
                    /* ── Mobile cards ────────────────────────────────────── */
                    <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
                        {loading ? (
                            <Box display="flex" justifyContent="center" py={6}>
                                <CircularProgress size={36} thickness={4} />
                            </Box>
                        ) : sortedData.length === 0 ? (
                            <Paper
                                variant="outlined"
                                sx={{
                                    p: 5,
                                    textAlign: 'center',
                                    borderRadius: 3,
                                    borderStyle: 'dashed',
                                }}
                            >
                                <Typography color="text.secondary" fontWeight={500}>
                                    {selectedUserId
                                        ? 'No SMS logs found for this user'
                                        : 'No SMS logs found'}
                                </Typography>
                            </Paper>
                        ) : (
                            <Stack spacing={2}>
                                {sortedData.map((log) => (
                                    <Card
                                        key={log.id}
                                        elevation={0}
                                        sx={{
                                            borderRadius: 3,
                                            border: '1px solid',
                                            borderColor: 'divider',
                                            overflow: 'hidden',
                                        }}
                                    >
                                        <CardContent sx={{ p: 2.25 }}>
                                            <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={1.5}>
                                                {getUserDisplay(log)}
                                                <IconButton
                                                    size="small"
                                                    onClick={(e) => handleMenuOpen(e, log)}
                                                    sx={{ color: 'text.secondary' }}
                                                >
                                                    <MoreVertIcon fontSize="small" />
                                                </IconButton>
                                            </Stack>

                                            <Stack direction="row" spacing={1} alignItems="center" mb={1.25}>
                                                <PhoneIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                                <Typography variant="body2" fontWeight={600}>
                                                    {log.recipient || '—'}
                                                </Typography>
                                            </Stack>

                                            <Box mb={1.5}>
                                                <Button
                                                    size="small"
                                                    onClick={() => toggleMessageVisibility(log.id)}
                                                    sx={{
                                                        minWidth: 0,
                                                        p: 0,
                                                        mb: 0.5,
                                                        fontWeight: 600,
                                                        textTransform: 'none',
                                                        color: colors.sea || '#0f766e',
                                                    }}
                                                >
                                                    {showMessage[log.id] ? 'Hide message' : 'Show message'}
                                                </Button>
                                                <Typography
                                                    variant="body2"
                                                    sx={{ wordBreak: 'break-word', lineHeight: 1.5 }}
                                                >
                                                    {getMessagePreview(log.message, log.id)}
                                                </Typography>
                                            </Box>

                                            <Divider sx={{ my: 1.5 }} />

                                            <Stack
                                                direction="row"
                                                justifyContent="space-between"
                                                alignItems="center"
                                                flexWrap="wrap"
                                                gap={1}
                                            >
                                                <Stack direction="row" spacing={1} alignItems="center">
                                                    {getStatusChip(log.status)}
                                                    {log.error_message && (
                                                        <Tooltip title={log.error_message}>
                                                            <Chip
                                                                label="Error"
                                                                size="small"
                                                                icon={<ErrorIcon sx={{ fontSize: 14 }} />}
                                                                sx={{
                                                                    bgcolor: '#fee2e2',
                                                                    color: '#b91c1c',
                                                                    fontWeight: 700,
                                                                    border: '1px solid #ef4444',
                                                                    height: 26,
                                                                }}
                                                            />
                                                        </Tooltip>
                                                    )}
                                                </Stack>
                                                <Typography variant="caption" color="text.secondary" fontWeight={500}>
                                                    {formatDate(log.created_at)}
                                                </Typography>
                                            </Stack>
                                        </CardContent>
                                    </Card>
                                ))}
                            </Stack>
                        )}
                    </Box>
                )}

                {/* Pagination */}
                <Box
                    sx={{
                        borderTop: '1px solid',
                        borderColor: 'divider',
                        bgcolor: 'action.hover',
                    }}
                >
                    <TablePagination
                        rowsPerPageOptions={[5, 10, 25, 50]}
                        component="div"
                        count={totalCount}
                        rowsPerPage={rowsPerPage}
                        page={page}
                        onPageChange={(e, newPage) => setPage(newPage)}
                        onRowsPerPageChange={(e) => {
                            setRowsPerPage(parseInt(e.target.value, 10));
                            setPage(0);
                        }}
                        sx={{
                            '.MuiTablePagination-selectLabel, .MuiTablePagination-displayedRows': {
                                fontWeight: 500,
                            },
                        }}
                    />
                </Box>
            </Paper>

            {/* Action Menu */}
            <Menu
                anchorEl={actionMenu}
                open={Boolean(actionMenu)}
                onClose={handleMenuClose}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                PaperProps={{
                    elevation: 8,
                    sx: { borderRadius: 2, minWidth: 180, mt: 0.5 },
                }}
            >
                {canResend && selectedLog?.status === 'failed' && (
                    <MenuItem onClick={() => handleAction('resend')} sx={{ fontWeight: 500 }}>
                        <ReplayIcon sx={{ mr: 1.5, color: '#10b981', fontSize: 20 }} />
                        Resend SMS
                    </MenuItem>
                )}
                {canDelete && (
                    <MenuItem onClick={() => handleAction('delete')} sx={{ color: 'error.main', fontWeight: 500 }}>
                        <DeleteIcon sx={{ mr: 1.5, fontSize: 20 }} />
                        Delete Log
                    </MenuItem>
                )}
            </Menu>

            {/* Send SMS Dialog */}
            <SendSmsDialog
                open={sendDialogOpen}
                onClose={() => setSendDialogOpen(false)}
                onSend={async (data) => {
                    try {
                        await sendSms(data);
                        showSnackbar({ type: 'success', message: 'SMS sent successfully' });
                        setSendDialogOpen(false);
                        await loadLogs();
                        await loadStats();
                    } catch (err) {
                        showSnackbar({ type: 'error', message: 'Failed to send SMS' });
                    }
                }}
            />

            {/* User Selector */}
            <UserSelector
                open={userSelectorOpen}
                onClose={() => setUserSelectorOpen(false)}
                onSelect={(user) => {
                    setSelectedUserId(user.id);
                    setPage(0);
                    setUserSelectorOpen(false);
                }}
            />

            {/* Confirm Dialog */}
            <Dialog
                open={confirmDialog.open}
                onClose={() => setConfirmDialog((prev) => ({ ...prev, open: false }))}
                fullWidth
                maxWidth="xs"
                PaperProps={{ sx: { borderRadius: 3 } }}
            >
                <DialogTitle sx={{ fontWeight: 700, pb: 1 }}>{confirmDialog.title}</DialogTitle>
                <DialogContent>
                    <Typography color="text.secondary">{confirmDialog.message}</Typography>
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2.5, pt: 1 }}>
                    <Button
                        onClick={() => setConfirmDialog((prev) => ({ ...prev, open: false }))}
                        sx={{ fontWeight: 600, textTransform: 'none' }}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleConfirm}
                        variant="contained"
                        color="error"
                        sx={{ fontWeight: 700, textTransform: 'none', borderRadius: 2 }}
                    >
                        Confirm
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default SmsLogsList;