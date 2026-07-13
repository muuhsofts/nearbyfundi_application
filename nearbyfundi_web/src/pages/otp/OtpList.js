// src/pages/otp/OtpList.js
import React, { useState, useEffect, useCallback } from 'react';
import {
    Box, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle,
    IconButton, InputAdornment, Paper, Table, TableBody, TableCell,
    TableContainer, TableHead, TablePagination, TableRow, TextField,
    Typography, FormControl, InputLabel, Select, MenuItem, Grid, Card,
    CardContent, CircularProgress, Tooltip, useTheme, useMediaQuery,
    Divider, Alert
} from '@mui/material';
import {
    Refresh as RefreshIcon, Search as SearchIcon, DeleteSweep as CleanupIcon,
    CheckCircle as UsedIcon, Cancel as UnusedIcon, Email as EmailIcon,
    Schedule as ScheduleIcon, Computer as IpIcon, Label as TypeIcon
} from '@mui/icons-material';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';

import { otpService } from 'services/otp.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'email', label: 'Email' },
    { id: 'type', label: 'Type' },
    { id: 'otp', label: 'OTP' },
    { id: 'is_used', label: 'Used' },
    { id: 'expires_at', label: 'Expires At' },
    { id: 'created_at', label: 'Created At' },
    { id: 'ip_address', label: 'IP' },
];

export default function OtpList() {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const { can } = usePermissions();
    const canView = can('otp.view');
    const canCleanup = can('otp.cleanup');

    const [otps, setOtps] = useState([]);
    const [total, setTotal] = useState(0);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [stats, setStats] = useState(null);

    const [email, setEmail] = useState('');
    const [typeFilter, setTypeFilter] = useState('all');
    const [usedFilter, setUsedFilter] = useState('all');
    const [expiredFilter, setExpiredFilter] = useState(false);
    const [startDate, setStartDate] = useState(null);
    const [endDate, setEndDate] = useState(null);

    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    const [confirmDialog, setConfirmDialog] = useState({
        open: false,
        title: '',
        message: '',
        action: null,
    });

    const fetchOtps = useCallback(async () => {
        if (!canView) return;
        setLoading(true);
        setError(null);
        try {
            const params = {
                page: page + 1,
                per_page: rowsPerPage,
                email: email || undefined,
                type: typeFilter !== 'all' ? typeFilter : undefined,
                is_used: usedFilter !== 'all' ? usedFilter === 'true' : undefined,
                expired: expiredFilter ? 'true' : undefined,
                start_date: startDate ? startDate.toISOString().split('T')[0] : undefined,
                end_date: endDate ? endDate.toISOString().split('T')[0] : undefined,
            };
            const response = await otpService.getOtps(params);
            console.log('OTP response:', response);

            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    setOtps(data.data);
                    setTotal(data.total || 0);
                    setStats(data.stats || null);
                } else if (Array.isArray(data)) {
                    setOtps(data);
                    setTotal(data.length || 0);
                } else {
                    setOtps([]);
                    setTotal(0);
                    setStats(null);
                }
            } else {
                setOtps([]);
                setTotal(0);
                setStats(null);
                if (response?.data?.message) {
                    setError(response.data.message);
                }
            }
        } catch (error) {
            console.error('OTP error:', error);
            setError(error.message || 'Failed to load OTP records');
            showSnackbar({ type: 'error', message: 'Failed to load OTP records' });
            setOtps([]);
            setTotal(0);
            setStats(null);
        } finally {
            setLoading(false);
        }
    }, [page, rowsPerPage, email, typeFilter, usedFilter, expiredFilter, startDate, endDate, canView]);

    useEffect(() => {
        if (canView) {
            fetchOtps();
        }
    }, [fetchOtps, canView]);

    const handleCleanupExpired = () => {
        setConfirmDialog({
            open: true,
            title: 'Cleanup Expired OTPs',
            message: 'This will permanently delete all expired and unused OTP records. Are you sure?',
            action: async () => {
                try {
                    const response = await otpService.cleanup();
                    if (response?.data?.status === 'success') {
                        showSnackbar({ type: 'success', message: response.data.message || 'Cleanup completed' });
                        fetchOtps();
                    } else {
                        throw new Error(response?.data?.message || 'Cleanup failed');
                    }
                } catch (err) {
                    showSnackbar({ type: 'error', message: err.message });
                }
            }
        });
    };

    const handleConfirm = async () => {
        if (!confirmDialog.action) return;
        setConfirmDialog(prev => ({ ...prev, open: false }));
        try {
            await confirmDialog.action();
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Action failed' });
        }
    };

    if (!canView) {
        return (
            <Box sx={{ p: 2 }}>
                <Paper sx={{
                    p: 4,
                    textAlign: 'center',
                    backgroundColor: colors.light,
                    border: `1px solid ${colors.middle}`,
                    borderRadius: 2
                }}>
                    <Typography variant="h5" color="error" gutterBottom>
                        Access Denied
                    </Typography>
                    <Typography color="text.secondary">
                        You do not have permission to view OTP records.
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
                    action={
                        <Button color="inherit" size="small" onClick={() => { setError(null); fetchOtps(); }}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    const typeOptions = [
        { value: 'all', label: 'All Types' },
        { value: 'registration', label: 'Registration' },
        { value: 'password_reset', label: 'Password Reset' },
        { value: 'email_verification', label: 'Email Verification' },
        { value: 'login', label: 'Login' },
    ];

    const usedOptions = [
        { value: 'all', label: 'All' },
        { value: 'true', label: 'Used' },
        { value: 'false', label: 'Unused' },
    ];

    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        try {
            return new Date(dateStr).toLocaleString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch {
            return '-';
        }
    };

    const OtpCard = ({ otp }) => {
        const isExpired = new Date(otp.expires_at) < new Date();
        return (
            <Card sx={{
                mb: 2,
                borderRadius: 2,
                overflow: 'hidden',
                border: `1px solid ${colors.middle}`,
            }}>
                <CardContent sx={{ p: 2, '&:last-child': { pb: 2 }, backgroundColor: colors.light }}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 1.5 }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, flexWrap: 'wrap' }}>
                            <EmailIcon fontSize="small" sx={{ color: colors.rain }} />
                            <Typography variant="body1" fontWeight="medium" sx={{ wordBreak: 'break-all', color: colors.dark }}>
                                {otp.email}
                            </Typography>
                        </Box>
                        <Chip
                            label={otp.is_used ? "Used" : "Unused"}
                            size="small"
                            icon={otp.is_used ? <UsedIcon sx={{ fontSize: 14 }} /> : <UnusedIcon sx={{ fontSize: 14 }} />}
                            sx={{
                                backgroundColor: otp.is_used ? colors.salat : colors.sky,
                                color: otp.is_used ? colors.light : colors.rain,
                            }}
                        />
                    </Box>

                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1.5 }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <TypeIcon fontSize="small" sx={{ color: colors.rain }} />
                            <Typography variant="body2" sx={{ color: colors.black }}>{otp.type}</Typography>
                        </Box>
                        <Typography variant="body2" fontWeight="bold" fontFamily="monospace" sx={{ color: colors.sea }}>
                            {otp.otp}
                        </Typography>
                    </Box>

                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                        <ScheduleIcon fontSize="small" sx={{ color: colors.rain }} />
                        <Typography variant="caption" sx={{ color: isExpired ? 'error.main' : colors.rain }}>
                            Expires: {formatDate(otp.expires_at)}
                            {isExpired && " (Expired)"}
                        </Typography>
                    </Box>

                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mt: 1 }}>
                        <Typography variant="caption" sx={{ color: colors.rain }}>
                            Created: {formatDate(otp.created_at)}
                        </Typography>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                            <IpIcon fontSize="small" sx={{ fontSize: 14, color: colors.rain }} />
                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                {otp.ip_address || '-'}
                            </Typography>
                        </Box>
                    </Box>
                </CardContent>
            </Card>
        );
    };

    return (
        <LocalizationProvider dateAdapter={AdapterDateFns}>
            <Box sx={{ width: '100%', p: { xs: 1, sm: 2 }, m: 0 }}>
                <Paper sx={{
                    width: '100%',
                    borderRadius: { xs: 1, sm: 2 },
                    overflow: 'hidden',
                    boxShadow: { xs: 0, sm: 1 },
                    backgroundColor: colors.light,
                    border: `1px solid ${colors.middle}`,
                }}>
                    {/* Header and Stats */}
                    <Box sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                        <Typography variant="h5" fontWeight="600" gutterBottom sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem' }, color: colors.dark }}>
                            OTP Management
                        </Typography>

                        {/* Stats Cards */}
                        {stats && (
                            <Grid container spacing={2} sx={{ mb: 3 }}>
                                <Grid item xs={6} sm={4} md={2.4}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>Total OTPs</Typography>
                                            <Typography variant="h5" fontWeight="bold" sx={{ color: colors.dark }}>{stats.total ?? 0}</Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={6} sm={4} md={2.4}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>Used</Typography>
                                            <Typography variant="h5" fontWeight="bold" sx={{ color: colors.salat }}>{stats.used ?? 0}</Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={6} sm={4} md={2.4}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>Unused</Typography>
                                            <Typography variant="h5" fontWeight="bold" sx={{ color: '#f59e0b' }}>{stats.unused ?? 0}</Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={6} sm={4} md={2.4}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>Expired</Typography>
                                            <Typography variant="h5" fontWeight="bold" sx={{ color: 'error.main' }}>{stats.expired ?? 0}</Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={12} sm={8} md={2.4}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                        height: '100%'
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>By Type</Typography>
                                            <Typography variant="caption" component="div" sx={{ mt: 0.5, color: colors.black }}>
                                                {stats.by_type?.map(t => `${t.type}: ${t.count}`).join(', ') || 'N/A'}
                                            </Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                            </Grid>
                        )}

                        {/* Filters */}
                        <Box sx={{ mb: 2 }}>
                            <Grid container spacing={2}>
                                <Grid item xs={12} sm={6} md={2}>
                                    <TextField
                                        fullWidth
                                        size="small"
                                        label="Email"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        InputProps={{
                                            startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" sx={{ color: colors.rain }} /></InputAdornment>
                                        }}
                                        sx={{
                                            '& .MuiInputBase-root': {
                                                backgroundColor: colors.sky,
                                                borderRadius: 2,
                                            },
                                            '& .MuiOutlinedInput-notchedOutline': {
                                                borderColor: colors.middle,
                                            },
                                        }}
                                    />
                                </Grid>
                                <Grid item xs={12} sm={6} md={2}>
                                    <FormControl fullWidth size="small">
                                        <InputLabel sx={{ color: colors.rain }}>Type</InputLabel>
                                        <Select
                                            value={typeFilter}
                                            label="Type"
                                            onChange={(e) => setTypeFilter(e.target.value)}
                                            sx={{
                                                '& .MuiOutlinedInput-notchedOutline': {
                                                    borderColor: colors.middle,
                                                },
                                                '& .MuiInputBase-root': {
                                                    backgroundColor: colors.sky,
                                                },
                                            }}
                                        >
                                            {typeOptions.map(opt => <MenuItem key={opt.value} value={opt.value}>{opt.label}</MenuItem>)}
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid item xs={12} sm={6} md={2}>
                                    <FormControl fullWidth size="small">
                                        <InputLabel sx={{ color: colors.rain }}>Used Status</InputLabel>
                                        <Select
                                            value={usedFilter}
                                            label="Used Status"
                                            onChange={(e) => setUsedFilter(e.target.value)}
                                            sx={{
                                                '& .MuiOutlinedInput-notchedOutline': {
                                                    borderColor: colors.middle,
                                                },
                                                '& .MuiInputBase-root': {
                                                    backgroundColor: colors.sky,
                                                },
                                            }}
                                        >
                                            {usedOptions.map(opt => <MenuItem key={opt.value} value={opt.value}>{opt.label}</MenuItem>)}
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid item xs={12} sm={6} md={2}>
                                    <FormControl fullWidth size="small">
                                        <InputLabel sx={{ color: colors.rain }}>Expired Only</InputLabel>
                                        <Select
                                            value={expiredFilter}
                                            label="Expired Only"
                                            onChange={(e) => setExpiredFilter(e.target.value === 'true')}
                                            sx={{
                                                '& .MuiOutlinedInput-notchedOutline': {
                                                    borderColor: colors.middle,
                                                },
                                                '& .MuiInputBase-root': {
                                                    backgroundColor: colors.sky,
                                                },
                                            }}
                                        >
                                            <MenuItem value="false">All</MenuItem>
                                            <MenuItem value="true">Expired Only</MenuItem>
                                        </Select>
                                    </FormControl>
                                </Grid>
                                <Grid item xs={12} sm={6} md={1.5}>
                                    <DatePicker
                                        label="Start Date"
                                        value={startDate}
                                        onChange={setStartDate}
                                        slotProps={{
                                            textField: {
                                                size: 'small',
                                                fullWidth: true,
                                                sx: {
                                                    '& .MuiInputBase-root': {
                                                        backgroundColor: colors.sky,
                                                        borderRadius: 2,
                                                    },
                                                    '& .MuiOutlinedInput-notchedOutline': {
                                                        borderColor: colors.middle,
                                                    },
                                                }
                                            }
                                        }}
                                    />
                                </Grid>
                                <Grid item xs={12} sm={6} md={1.5}>
                                    <DatePicker
                                        label="End Date"
                                        value={endDate}
                                        onChange={setEndDate}
                                        slotProps={{
                                            textField: {
                                                size: 'small',
                                                fullWidth: true,
                                                sx: {
                                                    '& .MuiInputBase-root': {
                                                        backgroundColor: colors.sky,
                                                        borderRadius: 2,
                                                    },
                                                    '& .MuiOutlinedInput-notchedOutline': {
                                                        borderColor: colors.middle,
                                                    },
                                                }
                                            }
                                        }}
                                    />
                                </Grid>
                                <Grid item xs={6} sm={6} md={1}>
                                    <Button
                                        variant="outlined"
                                        startIcon={<RefreshIcon />}
                                        onClick={fetchOtps}
                                        fullWidth
                                        sx={{
                                            height: '40px',
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
                                </Grid>
                            </Grid>
                        </Box>

                        {/* Cleanup Buttons */}
                        {canCleanup && (
                            <Box display="flex" gap={1} justifyContent={{ xs: 'center', sm: 'flex-end' }} flexWrap="wrap" mb={2}>
                                <Tooltip title="Delete expired & unused OTPs">
                                    <Button
                                        variant="contained"
                                        startIcon={<CleanupIcon />}
                                        onClick={handleCleanupExpired}
                                        size={isMobile ? "small" : "medium"}
                                        sx={{
                                            borderRadius: 2,
                                            backgroundColor: '#f59e0b',
                                            '&:hover': { backgroundColor: '#d97706' }
                                        }}
                                    >
                                        Cleanup Expired
                                    </Button>
                                </Tooltip>
                            </Box>
                        )}
                    </Box>

                    {/* Records */}
                    {showTableView ? (
                        <TableContainer sx={{ width: '100%', overflowX: 'auto' }}>
                            <Table sx={{ width: '100%', minWidth: 800 }}>
                                <TableHead>
                                    <TableRow sx={{ backgroundColor: colors.sky }}>
                                        {headCells.map((cell) => (
                                            <TableCell key={cell.id} sx={{ fontWeight: 'bold', color: colors.dark }}>
                                                {cell.label}
                                            </TableCell>
                                        ))}
                                    </TableRow>
                                </TableHead>
                                <TableBody>
                                    {loading ? (
                                        <TableRow>
                                            <TableCell colSpan={headCells.length} align="center">
                                                <CircularProgress size={32} sx={{ color: colors.sea, my: 3 }} />
                                            </TableCell>
                                        </TableRow>
                                    ) : otps.length === 0 ? (
                                        <TableRow>
                                            <TableCell colSpan={headCells.length} align="center">
                                                <Typography sx={{ py: 3, color: colors.rain }}>
                                                    No OTP records found
                                                </Typography>
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        otps.map((otp) => (
                                            <TableRow key={otp.id} hover>
                                                <TableCell sx={{ color: colors.black }}>{otp.email}</TableCell>
                                                <TableCell>
                                                    <Chip
                                                        label={otp.type}
                                                        size="small"
                                                        sx={{
                                                            backgroundColor: colors.wave,
                                                            color: colors.sea,
                                                        }}
                                                    />
                                                </TableCell>
                                                <TableCell>
                                                    <code style={{ color: colors.sea, fontWeight: 'bold' }}>{otp.otp}</code>
                                                </TableCell>
                                                <TableCell>
                                                    {otp.is_used ? (
                                                        <Chip
                                                            icon={<UsedIcon sx={{ fontSize: 14 }} />}
                                                            label="Used"
                                                            size="small"
                                                            sx={{
                                                                backgroundColor: colors.salat,
                                                                color: colors.light,
                                                            }}
                                                        />
                                                    ) : (
                                                        <Chip
                                                            icon={<UnusedIcon sx={{ fontSize: 14 }} />}
                                                            label="Unused"
                                                            size="small"
                                                            sx={{
                                                                backgroundColor: colors.sky,
                                                                color: colors.rain,
                                                            }}
                                                        />
                                                    )}
                                                </TableCell>
                                                <TableCell sx={{ color: colors.black }}>{formatDate(otp.expires_at)}</TableCell>
                                                <TableCell sx={{ color: colors.black }}>{formatDate(otp.created_at)}</TableCell>
                                                <TableCell sx={{ color: colors.black }}>{otp.ip_address || '-'}</TableCell>
                                            </TableRow>
                                        ))
                                    )}
                                </TableBody>
                            </Table>
                        </TableContainer>
                    ) : (
                        <Box sx={{ p: { xs: 2, sm: 3 } }}>
                            {loading ? (
                                <Box display="flex" justifyContent="center" py={4}>
                                    <CircularProgress sx={{ color: colors.sea }} />
                                </Box>
                            ) : otps.length === 0 ? (
                                <Paper variant="outlined" sx={{ p: 4, textAlign: 'center', borderColor: colors.middle }}>
                                    <Typography sx={{ color: colors.rain }}>No OTP records found</Typography>
                                </Paper>
                            ) : (
                                otps.map((otp) => <OtpCard key={otp.id} otp={otp} />)
                            )}
                        </Box>
                    )}

                    {/* Pagination */}
                    <Box sx={{ borderTop: `1px solid ${colors.middle}`, py: { xs: 1, sm: 0 } }}>
                        <TablePagination
                            rowsPerPageOptions={[5, 10, 25, 50, 100]}
                            component="div"
                            count={total}
                            rowsPerPage={rowsPerPage}
                            page={page}
                            onPageChange={(e, newPage) => setPage(newPage)}
                            onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
                            sx={{
                                '.MuiTablePagination-selectLabel, .MuiTablePagination-displayedRows': {
                                    fontSize: { xs: '0.75rem', sm: '0.875rem' },
                                    color: colors.black,
                                },
                                '.MuiTablePagination-actions': {
                                    color: colors.sea,
                                    ml: { xs: 0, sm: 1 }
                                }
                            }}
                        />
                    </Box>
                </Paper>

                {/* Confirmation Dialog */}
                <Dialog
                    open={confirmDialog.open}
                    onClose={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                    fullWidth
                    maxWidth="xs"
                    PaperProps={{
                        sx: {
                            m: { xs: 2, sm: 0 },
                            borderRadius: { xs: 2, sm: 1 },
                            backgroundColor: colors.light,
                        }
                    }}
                >
                    <DialogTitle sx={{ color: colors.dark }}>{confirmDialog.title}</DialogTitle>
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
            </Box>
        </LocalizationProvider>
    );
}