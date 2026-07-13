// src/pages/requests/RequestsList.js
import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Grid,
    Card,
    CardContent,
    Avatar,
    Chip,
    IconButton,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    TextField,
    InputAdornment,
    CircularProgress,
    Alert,
    Stack,
    Pagination,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    useMediaQuery,
    useTheme,
    Divider,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TablePagination,
    TableSortLabel,
    Tooltip,
} from '@mui/material';
import {
    Close as CloseIcon,
    Search as SearchIcon,
    Refresh as RefreshIcon,
    Person as PersonIcon,
    LocationOn as LocationIcon,
    Build as BuildIcon,
    Visibility as ViewIcon,
    Delete as DeleteIcon,
    CheckCircle as CheckCircleIcon,
    Cancel as CancelIcon,
    Pending as PendingIcon,
    HourglassEmpty as HourglassIcon,
    Schedule as ScheduleIcon,
    Phone as PhoneIcon,
    Email as EmailIcon,
} from '@mui/icons-material';
import { requestService } from 'services/request.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import { format } from 'date-fns';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const RequestsList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const [requests, setRequests] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [pagination, setPagination] = useState({ total: 0, per_page: 20, current_page: 1, last_page: 1 });

    const { can } = usePermissions();
    const canView = can('requests.view');
    const canDelete = can('requests.delete');

    const [search, setSearch] = useState('');
    const [statusFilter, setStatusFilter] = useState('');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(20);
    const [order, setOrder] = useState('desc');
    const [orderBy, setOrderBy] = useState('created_at');
    const [selectedRequest, setSelectedRequest] = useState(null);
    const [openViewDialog, setOpenViewDialog] = useState(false);
    const [confirmDialog, setConfirmDialog] = useState({
        open: false,
        title: '',
        message: '',
        action: null,
    });

    const loadRequests = async () => {
        if (!canView) return;

        setLoading(true);
        setError(null);
        try {
            const response = await requestService.getRequests({
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
                status: statusFilter || undefined,
            });

            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    setRequests(data.data);
                    setPagination({
                        total: data.total || 0,
                        per_page: data.per_page || rowsPerPage,
                        current_page: data.current_page || 1,
                        last_page: data.last_page || 1,
                    });
                } else if (Array.isArray(data)) {
                    setRequests(data);
                } else {
                    setRequests([]);
                }
            } else {
                setRequests([]);
            }
        } catch (err) {
            console.error('Requests error:', err);
            setError(err.message || 'Failed to load requests');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canView) {
            loadRequests();
        }
    }, [page, rowsPerPage, search, statusFilter, canView]);

    const handleRefresh = () => {
        loadRequests();
    };

    const handleViewRequest = (request) => {
        setSelectedRequest(request);
        setOpenViewDialog(true);
    };

    const handleCloseDialog = () => {
        setOpenViewDialog(false);
        setSelectedRequest(null);
    };

    const handleDeleteRequest = async (id) => {
        try {
            await requestService.deleteRequest(id);
            showSnackbar({ type: 'success', message: 'Request deleted successfully' });
            await loadRequests();
            return true;
        } catch (err) {
            console.error('Delete error:', err);
            const errorMessage = err.response?.data?.message || 'Failed to delete request';
            showSnackbar({ type: 'error', message: errorMessage });
            throw err;
        }
    };

    const openConfirmDialog = (title, message, actionFn) => {
        setConfirmDialog({ open: true, title, message, action: actionFn });
    };

    const handleConfirm = async () => {
        if (!confirmDialog.action) return;
        const action = confirmDialog.action;
        setConfirmDialog(prev => ({ ...prev, open: false }));

        try {
            await action();
        } catch (err) {
            console.error('Confirm action failed:', err);
        }
    };

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    const getStatusChip = (status) => {
        const statusMap = {
            'pending': { color: 'warning', icon: <PendingIcon sx={{ fontSize: 16 }} />, label: 'Pending' },
            'accepted': { color: 'success', icon: <CheckCircleIcon sx={{ fontSize: 16 }} />, label: 'Accepted' },
            'rejected': { color: 'error', icon: <CancelIcon sx={{ fontSize: 16 }} />, label: 'Rejected' },
            'cancelled': { color: 'default', icon: <CancelIcon sx={{ fontSize: 16 }} />, label: 'Cancelled' },
            'in_progress': { color: 'info', icon: <HourglassIcon sx={{ fontSize: 16 }} />, label: 'In Progress' },
            'completed': { color: 'success', icon: <CheckCircleIcon sx={{ fontSize: 16 }} />, label: 'Completed' },
        };
        const config = statusMap[status] || statusMap['pending'];
        return (
            <Chip
                icon={config.icon}
                label={config.label}
                size="small"
                sx={{
                    backgroundColor: config.color === 'warning' ? '#fef3c7' :
                        config.color === 'success' ? '#d1fae5' :
                            config.color === 'error' ? '#fee2e2' :
                                config.color === 'info' ? '#dbeafe' :
                                    config.color === 'default' ? colors.sky : colors.sky,
                    color: config.color === 'warning' ? '#92400e' :
                        config.color === 'success' ? '#065f46' :
                            config.color === 'error' ? '#991b1b' :
                                config.color === 'info' ? '#1e40af' :
                                    config.color === 'default' ? colors.rain : colors.rain,
                    borderColor: colors.middle,
                }}
            />
        );
    };

    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        try {
            return format(new Date(dateStr), 'MMM d, yyyy h:mm a');
        } catch {
            return '-';
        }
    };

    if (!canView) {
        return (
            <Box p={3}>
                <Paper sx={{ p: 3, textAlign: 'center', backgroundColor: colors.light }}>
                    <Typography color="error">You do not have permission to view requests.</Typography>
                </Paper>
            </Box>
        );
    }

    if (error) {
        return (
            <Box p={3}>
                <Alert
                    severity="error"
                    action={
                        <Button color="inherit" size="small" onClick={() => { setError(null); loadRequests(); }}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    return (
        <Box sx={{ width: '100%', p: { xs: 1, sm: 2 } }}>
            <Paper sx={{
                width: '100%',
                borderRadius: { xs: 1, sm: 2 },
                overflow: 'hidden',
                boxShadow: { xs: 0, sm: 1 },
                p: { xs: 2, sm: 3 },
                backgroundColor: colors.light,
                border: `1px solid ${colors.middle}`,
            }}>
                {/* Header */}
                <Box display="flex" justifyContent="space-between" alignItems="center" mb={3} flexWrap="wrap" gap={2}>
                    <Typography variant="h5" fontWeight="600" sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem' }, color: colors.dark }}>
                        Service Requests
                    </Typography>
                    <Box display="flex" gap={2} alignItems="center" flexWrap="wrap">
                        <TextField
                            placeholder="Search requests..."
                            size="small"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            InputProps={{
                                startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>,
                            }}
                            sx={{
                                minWidth: 200,
                                '& .MuiInputBase-root': {
                                    backgroundColor: colors.sky,
                                    borderRadius: 2,
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle,
                                },
                            }}
                        />
                        <FormControl size="small" sx={{ minWidth: 130 }}>
                            <InputLabel sx={{ color: colors.rain }}>Status</InputLabel>
                            <Select
                                value={statusFilter}
                                label="Status"
                                onChange={(e) => setStatusFilter(e.target.value)}
                                sx={{
                                    '& .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.middle,
                                    },
                                    '& .MuiInputBase-root': {
                                        backgroundColor: colors.sky,
                                    },
                                }}
                            >
                                <MenuItem value="">All</MenuItem>
                                <MenuItem value="pending">Pending</MenuItem>
                                <MenuItem value="accepted">Accepted</MenuItem>
                                <MenuItem value="rejected">Rejected</MenuItem>
                                <MenuItem value="cancelled">Cancelled</MenuItem>
                                <MenuItem value="in_progress">In Progress</MenuItem>
                                <MenuItem value="completed">Completed</MenuItem>
                            </Select>
                        </FormControl>
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={handleRefresh}
                            size="small"
                            sx={{
                                borderColor: colors.middle,
                                color: colors.sea,
                                '&:hover': {
                                    borderColor: colors.sea,
                                    backgroundColor: colors.wave,
                                }
                            }}
                        >
                            Refresh
                        </Button>
                    </Box>
                </Box>

                {/* Loading */}
                {loading && !requests.length ? (
                    <Box display="flex" justifyContent="center" py={8}>
                        <CircularProgress sx={{ color: colors.sea }} />
                    </Box>
                ) : requests.length === 0 ? (
                    <Box textAlign="center" py={8}>
                        <Typography sx={{ color: colors.rain }}>
                            No requests found.
                        </Typography>
                    </Box>
                ) : (
                    <>
                        {/* Table View (Desktop) */}
                        {showTableView ? (
                            <TableContainer sx={{ width: '100%', overflowX: 'auto' }}>
                                <Table sx={{ width: '100%', minWidth: 800 }}>
                                    <TableHead>
                                        <TableRow sx={{ backgroundColor: colors.sky }}>
                                            <TableCell sx={{ fontWeight: 'bold', color: colors.dark }}>Customer</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: colors.dark }}>Technician</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: colors.dark }}>Service</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: colors.dark }}>Status</TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: colors.dark }}>
                                                <TableSortLabel
                                                    active={orderBy === 'created_at'}
                                                    direction={orderBy === 'created_at' ? order : 'asc'}
                                                    onClick={() => handleRequestSort('created_at')}
                                                    sx={{ color: colors.dark }}
                                                >
                                                    Created
                                                </TableSortLabel>
                                            </TableCell>
                                            <TableCell sx={{ fontWeight: 'bold', color: colors.dark }} align="center">Actions</TableCell>
                                        </TableRow>
                                    </TableHead>
                                    <TableBody>
                                        {requests.map((request) => (
                                            <TableRow key={request.id} hover>
                                                <TableCell>
                                                    <Box display="flex" alignItems="center" gap={1}>
                                                        <Avatar sx={{ width: 32, height: 32, bgcolor: colors.sea }}>
                                                            {request.customer?.name?.charAt(0).toUpperCase() || <PersonIcon />}
                                                        </Avatar>
                                                        <Box>
                                                            <Typography variant="body2" fontWeight="500" sx={{ color: colors.dark }}>
                                                                {request.customer?.name || 'Unknown'}
                                                            </Typography>
                                                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                                                {request.customer?.phone || 'No phone'}
                                                            </Typography>
                                                        </Box>
                                                    </Box>
                                                </TableCell>
                                                <TableCell>
                                                    <Box display="flex" alignItems="center" gap={1}>
                                                        <Avatar
                                                            src={request.technician?.profile_photo || undefined}
                                                            sx={{ width: 32, height: 32, bgcolor: colors.sea }}
                                                        >
                                                            {request.technician?.name?.charAt(0).toUpperCase() || <PersonIcon />}
                                                        </Avatar>
                                                        <Box>
                                                            <Typography variant="body2" fontWeight="500" sx={{ color: colors.dark }}>
                                                                {request.technician?.name || 'Unknown'}
                                                            </Typography>
                                                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                                                {request.technician?.area || 'No area'}
                                                            </Typography>
                                                        </Box>
                                                    </Box>
                                                </TableCell>
                                                <TableCell>
                                                    <Chip
                                                        icon={<BuildIcon sx={{ fontSize: 16, color: colors.sea }} />}
                                                        label={request.service?.name || 'N/A'}
                                                        size="small"
                                                        variant="outlined"
                                                        sx={{ borderColor: colors.middle }}
                                                    />
                                                </TableCell>
                                                <TableCell>
                                                    {getStatusChip(request.status)}
                                                </TableCell>
                                                <TableCell>
                                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                                        {formatDate(request.created_at)}
                                                    </Typography>
                                                </TableCell>
                                                <TableCell align="center">
                                                    <IconButton
                                                        size="small"
                                                        onClick={() => handleViewRequest(request)}
                                                        sx={{ color: colors.sea }}
                                                        title="View Request"
                                                    >
                                                        <ViewIcon />
                                                    </IconButton>
                                                    {canDelete && (
                                                        <IconButton
                                                            size="small"
                                                            onClick={() => openConfirmDialog(
                                                                'Delete Request',
                                                                `Are you sure you want to delete this request?`,
                                                                () => handleDeleteRequest(request.id)
                                                            )}
                                                            sx={{ color: 'error.main' }}
                                                            title="Delete Request"
                                                        >
                                                            <DeleteIcon />
                                                        </IconButton>
                                                    )}
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </TableContainer>
                        ) : (
                            // Mobile Card View
                            <Grid container spacing={2}>
                                {requests.map((request) => (
                                    <Grid item xs={12} key={request.id}>
                                        <Card sx={{
                                            borderRadius: 2,
                                            border: `1px solid ${colors.middle}`,
                                        }}>
                                            <CardContent sx={{ p: 2 }}>
                                                <Box display="flex" justifyContent="space-between" alignItems="flex-start" mb={2}>
                                                    <Box>
                                                        <Typography variant="subtitle2" sx={{ color: colors.rain }}>
                                                            Request #{request.id}
                                                        </Typography>
                                                        <Typography variant="body2" sx={{ color: colors.rain }}>
                                                            {formatDate(request.created_at)}
                                                        </Typography>
                                                    </Box>
                                                    {getStatusChip(request.status)}
                                                </Box>

                                                <Divider sx={{ my: 1.5, borderColor: colors.middle }} />

                                                <Grid container spacing={1}>
                                                    <Grid item xs={6}>
                                                        <Typography variant="caption" sx={{ color: colors.rain }}>
                                                            Customer
                                                        </Typography>
                                                        <Box display="flex" alignItems="center" gap={1} mt={0.5}>
                                                            <Avatar sx={{ width: 24, height: 24, bgcolor: colors.sea, fontSize: 12 }}>
                                                                {request.customer?.name?.charAt(0).toUpperCase() || <PersonIcon />}
                                                            </Avatar>
                                                            <Typography variant="body2" noWrap sx={{ color: colors.black }}>
                                                                {request.customer?.name || 'Unknown'}
                                                            </Typography>
                                                        </Box>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        <Typography variant="caption" sx={{ color: colors.rain }}>
                                                            Technician
                                                        </Typography>
                                                        <Box display="flex" alignItems="center" gap={1} mt={0.5}>
                                                            <Avatar
                                                                src={request.technician?.profile_photo || undefined}
                                                                sx={{ width: 24, height: 24, bgcolor: colors.sea, fontSize: 12 }}
                                                            >
                                                                {request.technician?.name?.charAt(0).toUpperCase() || <PersonIcon />}
                                                            </Avatar>
                                                            <Typography variant="body2" noWrap sx={{ color: colors.black }}>
                                                                {request.technician?.name || 'Unknown'}
                                                            </Typography>
                                                        </Box>
                                                    </Grid>
                                                </Grid>

                                                <Box mt={1}>
                                                    <Chip
                                                        icon={<BuildIcon sx={{ fontSize: 14, color: colors.sea }} />}
                                                        label={request.service?.name || 'N/A'}
                                                        size="small"
                                                        variant="outlined"
                                                        sx={{ borderColor: colors.middle }}
                                                    />
                                                </Box>

                                                <Box mt={2} display="flex" justifyContent="flex-end" gap={1}>
                                                    <Button
                                                        size="small"
                                                        variant="outlined"
                                                        startIcon={<ViewIcon />}
                                                        onClick={() => handleViewRequest(request)}
                                                        sx={{
                                                            borderColor: colors.middle,
                                                            color: colors.sea,
                                                            '&:hover': {
                                                                borderColor: colors.sea,
                                                                backgroundColor: colors.wave,
                                                            }
                                                        }}
                                                    >
                                                        View
                                                    </Button>
                                                    {canDelete && (
                                                        <Button
                                                            size="small"
                                                            variant="outlined"
                                                            color="error"
                                                            startIcon={<DeleteIcon />}
                                                            onClick={() => openConfirmDialog(
                                                                'Delete Request',
                                                                `Are you sure you want to delete this request?`,
                                                                () => handleDeleteRequest(request.id)
                                                            )}
                                                        >
                                                            Delete
                                                        </Button>
                                                    )}
                                                </Box>
                                            </CardContent>
                                        </Card>
                                    </Grid>
                                ))}
                            </Grid>
                        )}

                        {/* Pagination */}
                        <Box display="flex" justifyContent="center" alignItems="center" mt={3} gap={2} flexWrap="wrap">
                            <Pagination
                                count={pagination.last_page || 1}
                                page={pagination.current_page || 1}
                                onChange={(e, value) => setPage(value - 1)}
                                sx={{
                                    '& .MuiPaginationItem-root': {
                                        color: colors.black,
                                    },
                                    '& .Mui-selected': {
                                        backgroundColor: colors.sea,
                                        color: colors.light,
                                    },
                                }}
                                size={isMobile ? "small" : "medium"}
                            />
                            <FormControl size="small" sx={{ minWidth: 100 }}>
                                <InputLabel sx={{ color: colors.rain }}>Per Page</InputLabel>
                                <Select
                                    value={rowsPerPage}
                                    label="Per Page"
                                    onChange={(e) => {
                                        setRowsPerPage(e.target.value);
                                        setPage(0);
                                    }}
                                    sx={{
                                        '& .MuiOutlinedInput-notchedOutline': {
                                            borderColor: colors.middle,
                                        },
                                    }}
                                >
                                    <MenuItem value={10}>10</MenuItem>
                                    <MenuItem value={20}>20</MenuItem>
                                    <MenuItem value={50}>50</MenuItem>
                                    <MenuItem value={100}>100</MenuItem>
                                </Select>
                            </FormControl>
                            <Typography variant="body2" sx={{ color: colors.rain }}>
                                {pagination.total || 0} total requests
                            </Typography>
                        </Box>
                    </>
                )}

                {/* Request Detail Dialog */}
                <Dialog
                    open={openViewDialog}
                    onClose={handleCloseDialog}
                    maxWidth="md"
                    fullWidth
                    fullScreen={isMobile}
                    PaperProps={{
                        sx: {
                            borderRadius: 2,
                            backgroundColor: colors.light,
                        }
                    }}
                >
                    {selectedRequest && (
                        <>
                            <DialogTitle sx={{ color: colors.dark }}>
                                <Box display="flex" justifyContent="space-between" alignItems="flex-start">
                                    <Box>
                                        <Typography variant="h6" sx={{ color: colors.dark }}>
                                            Request Details
                                        </Typography>
                                        <Box display="flex" alignItems="center" gap={1} mt={1}>
                                            {getStatusChip(selectedRequest.status)}
                                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                                {formatDate(selectedRequest.created_at)}
                                            </Typography>
                                        </Box>
                                    </Box>
                                    <IconButton onClick={handleCloseDialog} sx={{ color: colors.rain }}>
                                        <CloseIcon />
                                    </IconButton>
                                </Box>
                            </DialogTitle>
                            <DialogContent dividers sx={{ borderColor: colors.middle }}>
                                {/* Description */}
                                <Box mb={3}>
                                    <Typography variant="subtitle2" gutterBottom sx={{ color: colors.dark }}>
                                        Description
                                    </Typography>
                                    <Paper variant="outlined" sx={{ p: 2, backgroundColor: colors.sky }}>
                                        <Typography variant="body2" sx={{ color: colors.black }}>
                                            {selectedRequest.description || 'No description provided'}
                                        </Typography>
                                    </Paper>
                                </Box>

                                <Grid container spacing={2}>
                                    {/* Customer Details */}
                                    <Grid item xs={12} md={6}>
                                        <Typography variant="subtitle2" gutterBottom sx={{ color: colors.dark }}>
                                            Customer
                                        </Typography>
                                        <Paper variant="outlined" sx={{ p: 2, borderColor: colors.middle }}>
                                            <Stack spacing={1}>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <Avatar sx={{ bgcolor: colors.sea }}>
                                                        {selectedRequest.customer?.name?.charAt(0).toUpperCase() || <PersonIcon />}
                                                    </Avatar>
                                                    <Box>
                                                        <Typography variant="body2" fontWeight="500" sx={{ color: colors.dark }}>
                                                            {selectedRequest.customer?.name || 'Unknown'}
                                                        </Typography>
                                                        <Typography variant="caption" sx={{ color: colors.rain }}>
                                                            ID: {selectedRequest.customer?.id || 'N/A'}
                                                        </Typography>
                                                    </Box>
                                                </Box>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <EmailIcon fontSize="small" sx={{ color: colors.rain }} />
                                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                                        {selectedRequest.customer?.email || 'N/A'}
                                                    </Typography>
                                                </Box>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <PhoneIcon fontSize="small" sx={{ color: colors.rain }} />
                                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                                        {selectedRequest.customer?.phone || 'N/A'}
                                                    </Typography>
                                                </Box>
                                            </Stack>
                                        </Paper>
                                    </Grid>

                                    {/* Technician Details */}
                                    <Grid item xs={12} md={6}>
                                        <Typography variant="subtitle2" gutterBottom sx={{ color: colors.dark }}>
                                            Technician
                                        </Typography>
                                        <Paper variant="outlined" sx={{ p: 2, borderColor: colors.middle }}>
                                            <Stack spacing={1}>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <Avatar
                                                        src={selectedRequest.technician?.profile_photo || undefined}
                                                        sx={{ bgcolor: colors.sea }}
                                                    >
                                                        {selectedRequest.technician?.name?.charAt(0).toUpperCase() || <PersonIcon />}
                                                    </Avatar>
                                                    <Box>
                                                        <Typography variant="body2" fontWeight="500" sx={{ color: colors.dark }}>
                                                            {selectedRequest.technician?.name || 'Unknown'}
                                                        </Typography>
                                                        <Typography variant="caption" sx={{ color: colors.rain }}>
                                                            ID: {selectedRequest.technician?.id || 'N/A'}
                                                        </Typography>
                                                    </Box>
                                                </Box>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <LocationIcon fontSize="small" sx={{ color: colors.rain }} />
                                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                                        {selectedRequest.technician?.area || 'N/A'}
                                                    </Typography>
                                                </Box>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <BuildIcon fontSize="small" sx={{ color: colors.rain }} />
                                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                                        {selectedRequest.service?.name || 'N/A'}
                                                    </Typography>
                                                </Box>
                                            </Stack>
                                        </Paper>
                                    </Grid>
                                </Grid>

                                {/* Activity Logs */}
                                {selectedRequest.logs && selectedRequest.logs.length > 0 && (
                                    <Box mt={3}>
                                        <Typography variant="subtitle2" gutterBottom sx={{ color: colors.dark }}>
                                            Activity Log
                                        </Typography>
                                        <Paper variant="outlined" sx={{ p: 2, maxHeight: 200, overflow: 'auto', borderColor: colors.middle }}>
                                            <Stack spacing={1}>
                                                {selectedRequest.logs.map((log) => (
                                                    <Box key={log.id} display="flex" gap={2} alignItems="center" flexWrap="wrap">
                                                        <Typography variant="caption" sx={{ color: colors.rain, minWidth: 120 }}>
                                                            {formatDate(log.created_at)}
                                                        </Typography>
                                                        <Chip
                                                            label={log.action}
                                                            size="small"
                                                            variant="outlined"
                                                            sx={{ borderColor: colors.middle }}
                                                        />
                                                        <Typography variant="caption" sx={{ color: colors.rain }}>
                                                            by {log.user?.name || 'System'}
                                                        </Typography>
                                                        {log.notes && (
                                                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                                                - {log.notes}
                                                            </Typography>
                                                        )}
                                                    </Box>
                                                ))}
                                            </Stack>
                                        </Paper>
                                    </Box>
                                )}
                            </DialogContent>
                            <DialogActions>
                                <Button
                                    onClick={handleCloseDialog}
                                    variant="contained"
                                    sx={{
                                        backgroundColor: colors.sea,
                                        '&:hover': { backgroundColor: colors.dark },
                                    }}
                                >
                                    Close
                                </Button>
                            </DialogActions>
                        </>
                    )}
                </Dialog>

                {/* Confirmation Dialog */}
                <Dialog
                    open={confirmDialog.open}
                    onClose={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                    fullWidth
                    maxWidth="xs"
                    PaperProps={{
                        sx: {
                            borderRadius: 2,
                            backgroundColor: colors.light,
                        }
                    }}
                >
                    <DialogTitle sx={{ pb: 1, color: colors.dark }}>{confirmDialog.title}</DialogTitle>
                    <DialogContent>
                        <Typography sx={{ color: colors.black }}>{confirmDialog.message}</Typography>
                    </DialogContent>
                    <DialogActions sx={{ p: 2, pt: 0 }}>
                        <Button
                            onClick={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                            sx={{ color: colors.rain }}
                        >
                            Cancel
                        </Button>
                        <Button
                            onClick={handleConfirm}
                            variant="contained"
                            sx={{
                                backgroundColor: 'error.main',
                                '&:hover': { backgroundColor: 'error.dark' },
                            }}
                        >
                            Confirm
                        </Button>
                    </DialogActions>
                </Dialog>
            </Paper>
        </Box>
    );
};

export default RequestsList;