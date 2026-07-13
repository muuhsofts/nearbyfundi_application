// src/pages/audit/AuditList.js
import React, { useState, useEffect, useCallback } from 'react';
import {
    Box, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle,
    IconButton, InputAdornment, Menu, MenuItem, Paper, Table,
    TableBody, TableCell, TableContainer, TableHead, TablePagination,
    TableRow, TextField, Typography, FormControl, InputLabel, Select,
    Grid, Card, CardContent, CircularProgress, useTheme, useMediaQuery,
    Divider, Tooltip, Alert
} from '@mui/material';
import {
    Refresh as RefreshIcon, Search as SearchIcon, MoreVert as MoreVertIcon,
    Visibility as ViewIcon, Person as PersonIcon,
    AccessTime as TimeIcon, Public as IpIcon, Http as MethodIcon,
    Link as UrlIcon, DeviceHub as UserAgentIcon,
    DataUsage as DataIcon
} from '@mui/icons-material';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDateFns } from '@mui/x-date-pickers/AdapterDateFns';

import { auditService } from 'services/audit.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'created_at', label: 'Date & Time' },
    { id: 'user', label: 'User' },
    { id: 'action', label: 'Action' },
    { id: 'module', label: 'Module' },
    { id: 'description', label: 'Description' },
    { id: 'ip_address', label: 'IP' },
    { id: 'request_method', label: 'Method' },
    { id: 'actions', label: 'Actions', disableSort: true },
];

export default function AuditList() {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.between('sm', 'md'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const { can } = usePermissions();
    const canView = can('audit.view');

    const [audits, setAudits] = useState([]);
    const [total, setTotal] = useState(0);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [stats, setStats] = useState(null);
    const [statsLoading, setStatsLoading] = useState(false);

    const [modules, setModules] = useState([]);
    const [actions, setActions] = useState([]);

    const [search, setSearch] = useState('');
    const [moduleFilter, setModuleFilter] = useState('all');
    const [actionFilter, setActionFilter] = useState('all');
    const [fromDate, setFromDate] = useState(null);
    const [toDate, setToDate] = useState(null);

    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    const [viewModalOpen, setViewModalOpen] = useState(false);
    const [selectedAudit, setSelectedAudit] = useState(null);
    const [actionMenu, setActionMenu] = useState(null);

    // Load filter options (modules & actions)
    useEffect(() => {
        if (canView) {
            loadFilters();
        }
    }, [canView]);

    const loadFilters = async () => {
        try {
            setModules(['auth', 'user', 'technician', 'request', 'post', 'service', 'portfolio', 'report', 'profile']);
            setActions(['create', 'update', 'delete', 'view', 'login', 'logout', 'verify', 'reset', 'forgot_password', 'update_profile']);
        } catch (err) {
            console.error(err);
        }
    };

    const fetchAudits = useCallback(async () => {
        if (!canView) return;
        setLoading(true);
        setError(null);
        try {
            const params = {
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
                module: moduleFilter !== 'all' ? moduleFilter : undefined,
                action: actionFilter !== 'all' ? actionFilter : undefined,
                from_date: fromDate ? fromDate.toISOString().split('T')[0] : undefined,
                to_date: toDate ? toDate.toISOString().split('T')[0] : undefined,
            };
            const response = await auditService.getAuditTrails(params);

            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    setAudits(data.data);
                    setTotal(data.total || 0);
                } else if (Array.isArray(data)) {
                    setAudits(data);
                    setTotal(data.length || 0);
                } else {
                    setAudits([]);
                    setTotal(0);
                }
            } else {
                setAudits([]);
                setTotal(0);
                if (response?.data?.message) {
                    setError(response.data.message);
                }
            }
        } catch (error) {
            console.error('Audit error:', error);
            setError(error.message || 'Failed to load audit trails');
            showSnackbar({ type: 'error', message: 'Failed to load audit trails' });
        } finally {
            setLoading(false);
        }
    }, [page, rowsPerPage, search, moduleFilter, actionFilter, fromDate, toDate, canView]);

    useEffect(() => {
        if (canView) {
            fetchAudits();
        }
    }, [fetchAudits, canView]);

    const fetchStats = useCallback(async () => {
        if (!canView) return;
        setStatsLoading(true);
        try {
            const totalRecords = audits.length;
            const today = audits.filter(a => new Date(a.created_at).toDateString() === new Date().toDateString()).length;
            const thisWeek = audits.filter(a => {
                const date = new Date(a.created_at);
                const now = new Date();
                const weekStart = new Date(now.setDate(now.getDate() - now.getDay()));
                return date >= weekStart;
            }).length;

            // Group by user
            const userMap = {};
            audits.forEach(a => {
                const userName = a.user?.name || a.user_name || 'Unknown';
                const userEmail = a.user?.email || a.user_email || 'unknown@email.com';
                const key = `${userName}-${userEmail}`;
                if (!userMap[key]) {
                    userMap[key] = { user_name: userName, user_email: userEmail, count: 0 };
                }
                userMap[key].count++;
            });
            const byUser = Object.values(userMap).sort((a, b) => b.count - a.count);

            setStats({
                total: totalRecords,
                today: today,
                this_week: thisWeek,
                by_user: byUser
            });
        } catch (err) {
            console.error(err);
        } finally {
            setStatsLoading(false);
        }
    }, [audits, canView]);

    useEffect(() => {
        if (canView) {
            fetchStats();
        }
    }, [fetchStats, canView]);

    const handleMenuOpen = (event, audit) => {
        setSelectedAudit(audit);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => setActionMenu(null);

    const handleViewDetails = () => {
        setViewModalOpen(true);
        handleMenuClose();
    };

    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        try {
            return new Date(dateStr).toLocaleString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit'
            });
        } catch {
            return '-';
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
                        You do not have permission to view audit trails.
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
                        <Button color="inherit" size="small" onClick={() => { setError(null); fetchAudits(); }}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    // Audit Card Component for mobile/tablet view
    const AuditCard = ({ audit }) => {
        const userName = audit.user?.name || audit.user_name || 'Unknown';
        const userEmail = audit.user?.email || audit.user_email || 'No email';

        return (
            <Card sx={{
                mb: 2,
                borderRadius: 2,
                overflow: 'hidden',
                border: `1px solid ${colors.middle}`,
            }}>
                <CardContent sx={{ p: 2, '&:last-child': { pb: 2 }, backgroundColor: colors.light }}>
                    {/* Header: Date & Action */}
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 1.5 }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <TimeIcon fontSize="small" sx={{ color: colors.rain }} />
                            <Typography variant="body2" sx={{ color: colors.rain }}>
                                {formatDate(audit.created_at)}
                            </Typography>
                        </Box>
                        <Chip
                            label={audit.action}
                            size="small"
                            sx={{
                                backgroundColor: colors.wave,
                                color: colors.sea,
                            }}
                        />
                    </Box>

                    {/* User info */}
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1.5 }}>
                        <PersonIcon fontSize="small" sx={{ color: colors.rain }} />
                        <Typography variant="body2" fontWeight="medium" sx={{ color: colors.dark }}>
                            {userName}
                        </Typography>
                        <Typography variant="caption" sx={{ color: colors.rain }}>
                            ({userEmail})
                        </Typography>
                    </Box>

                    {/* Module & IP */}
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Typography variant="caption" sx={{ color: colors.rain }}>Module:</Typography>
                            <Typography variant="body2" sx={{ color: colors.black }}>{audit.module || '-'}</Typography>
                        </Box>
                        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                            <IpIcon fontSize="small" sx={{ fontSize: 14, color: colors.rain }} />
                            <Typography variant="caption" fontFamily="monospace" sx={{ color: colors.rain }}>{audit.ip_address}</Typography>
                        </Box>
                    </Box>

                    {/* Method */}
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                        <MethodIcon fontSize="small" sx={{ color: colors.rain }} />
                        <Typography variant="caption" sx={{ color: colors.rain }}>Method:</Typography>
                        <Chip
                            label={audit.request_method || 'N/A'}
                            size="small"
                            variant="outlined"
                            sx={{
                                height: 20,
                                fontSize: '0.7rem',
                                borderColor: colors.middle,
                            }}
                        />
                    </Box>

                    {/* Description snippet */}
                    <Divider sx={{ my: 1, borderColor: colors.middle }} />
                    <Typography variant="body2" sx={{ wordBreak: 'break-word', color: colors.black }}>
                        {audit.description || 'No description'}
                    </Typography>

                    {/* Action button */}
                    <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 1.5 }}>
                        <Button
                            size="small"
                            startIcon={<ViewIcon />}
                            onClick={(e) => handleMenuOpen(e, audit)}
                            sx={{
                                borderRadius: 2,
                                color: colors.sea,
                                '&:hover': {
                                    backgroundColor: colors.wave,
                                }
                            }}
                        >
                            View Details
                        </Button>
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
                    {/* Header */}
                    <Box sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                        <Typography variant="h5" fontWeight="600" gutterBottom sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem' }, color: colors.dark }}>
                            Audit Trails
                        </Typography>

                        {/* Filters - Responsive stack */}
                        <Grid container spacing={2} sx={{ mb: 3 }}>
                            <Grid item xs={12} sm={6} md={3}>
                                <TextField
                                    fullWidth size="small"
                                    label="Global Search"
                                    value={search}
                                    onChange={(e) => setSearch(e.target.value)}
                                    InputProps={{
                                        startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" sx={{ color: colors.rain }} /></InputAdornment>,
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
                                    <InputLabel sx={{ color: colors.rain }}>Module</InputLabel>
                                    <Select
                                        value={moduleFilter}
                                        label="Module"
                                        onChange={(e) => setModuleFilter(e.target.value)}
                                        sx={{
                                            '& .MuiOutlinedInput-notchedOutline': {
                                                borderColor: colors.middle,
                                            },
                                            '& .MuiInputBase-root': {
                                                backgroundColor: colors.sky,
                                            },
                                        }}
                                    >
                                        <MenuItem value="all">All Modules</MenuItem>
                                        {modules.map(m => <MenuItem key={m} value={m}>{m}</MenuItem>)}
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid item xs={12} sm={6} md={2}>
                                <FormControl fullWidth size="small">
                                    <InputLabel sx={{ color: colors.rain }}>Action</InputLabel>
                                    <Select
                                        value={actionFilter}
                                        label="Action"
                                        onChange={(e) => setActionFilter(e.target.value)}
                                        sx={{
                                            '& .MuiOutlinedInput-notchedOutline': {
                                                borderColor: colors.middle,
                                            },
                                            '& .MuiInputBase-root': {
                                                backgroundColor: colors.sky,
                                            },
                                        }}
                                    >
                                        <MenuItem value="all">All Actions</MenuItem>
                                        {actions.map(a => <MenuItem key={a} value={a}>{a}</MenuItem>)}
                                    </Select>
                                </FormControl>
                            </Grid>
                            <Grid item xs={12} sm={6} md={1.5}>
                                <DatePicker
                                    label="From Date"
                                    value={fromDate}
                                    onChange={setFromDate}
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
                                    label="To Date"
                                    value={toDate}
                                    onChange={setToDate}
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
                                    onClick={fetchAudits}
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

                        {/* Statistics cards - Responsive */}
                        {statsLoading ? (
                            <Box display="flex" justifyContent="center" py={2}>
                                <CircularProgress size={24} sx={{ color: colors.sea }} />
                            </Box>
                        ) : stats && (
                            <Grid container spacing={2} sx={{ mb: 2 }}>
                                <Grid item xs={6} sm={6} md={3}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>Total Records</Typography>
                                            <Typography variant="h5" fontWeight="bold" sx={{ color: colors.dark }}>{stats.total ?? 0}</Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={6} sm={6} md={3}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>Today</Typography>
                                            <Typography variant="h5" fontWeight="bold" sx={{ color: colors.dark }}>{stats.today ?? 0}</Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={6} sm={6} md={3}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>This Week</Typography>
                                            <Typography variant="h5" fontWeight="bold" sx={{ color: colors.dark }}>{stats.this_week ?? 0}</Typography>
                                        </CardContent>
                                    </Card>
                                </Grid>
                                <Grid item xs={12} sm={12} md={3}>
                                    <Card variant="outlined" sx={{
                                        borderRadius: 2,
                                        borderColor: colors.middle,
                                        height: '100%'
                                    }}>
                                        <CardContent sx={{ py: 1.5, px: 2 }}>
                                            <Typography variant="body2" sx={{ color: colors.rain }}>Top Users</Typography>
                                            <Box sx={{ mt: 0.5 }}>
                                                {stats.by_user && stats.by_user.length > 0 ? (
                                                    stats.by_user.slice(0, 3).map((u, idx) => (
                                                        <Typography key={idx} variant="caption" component="div" sx={{ color: colors.black }}>
                                                            {u.user_name}: {u.count}
                                                        </Typography>
                                                    ))
                                                ) : (
                                                    <Typography variant="caption" sx={{ color: colors.rain }}>No data</Typography>
                                                )}
                                            </Box>
                                        </CardContent>
                                    </Card>
                                </Grid>
                            </Grid>
                        )}
                    </Box>

                    {/* Records: Cards on mobile/tablet, Table on desktop */}
                    {showTableView ? (
                        <TableContainer sx={{ width: '100%', overflowX: 'auto' }}>
                            <Table sx={{ width: '100%', minWidth: 1000 }}>
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
                                            <TableCell colSpan={8} align="center">
                                                <CircularProgress size={32} sx={{ color: colors.sea, my: 3 }} />
                                            </TableCell>
                                        </TableRow>
                                    ) : audits.length === 0 ? (
                                        <TableRow>
                                            <TableCell colSpan={8} align="center">
                                                <Typography sx={{ py: 3, color: colors.rain }}>No audit records found</Typography>
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        audits.map((audit, idx) => {
                                            const userName = audit.user?.name || audit.user_name || 'Unknown';
                                            const userEmail = audit.user?.email || audit.user_email || 'No email';
                                            return (
                                                <TableRow key={`${audit.created_at}-${idx}`} hover>
                                                    <TableCell sx={{ color: colors.black }}>{formatDate(audit.created_at)}</TableCell>
                                                    <TableCell>
                                                        <strong style={{ color: colors.dark }}>{userName}</strong><br />
                                                        <small style={{ color: colors.rain }}>{userEmail}</small>
                                                    </TableCell>
                                                    <TableCell>
                                                        <Chip
                                                            label={audit.action}
                                                            size="small"
                                                            sx={{
                                                                backgroundColor: colors.wave,
                                                                color: colors.sea,
                                                            }}
                                                        />
                                                    </TableCell>
                                                    <TableCell sx={{ color: colors.black }}>{audit.module || '-'}</TableCell>
                                                    <TableCell sx={{ maxWidth: 250, wordBreak: 'break-word', color: colors.black }}>
                                                        {audit.description?.substring(0, 60) || 'No description'}
                                                        {audit.description?.length > 60 && '...'}
                                                    </TableCell>
                                                    <TableCell sx={{ color: colors.black }}>{audit.ip_address}</TableCell>
                                                    <TableCell sx={{ color: colors.black }}>{audit.request_method || 'N/A'}</TableCell>
                                                    <TableCell align="center">
                                                        <IconButton
                                                            size="small"
                                                            onClick={(e) => handleMenuOpen(e, audit)}
                                                            sx={{ color: colors.rain }}
                                                        >
                                                            <MoreVertIcon />
                                                        </IconButton>
                                                    </TableCell>
                                                </TableRow>
                                            );
                                        })
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
                            ) : audits.length === 0 ? (
                                <Paper variant="outlined" sx={{ p: 4, textAlign: 'center', borderColor: colors.middle }}>
                                    <Typography sx={{ color: colors.rain }}>No audit records found</Typography>
                                </Paper>
                            ) : (
                                audits.map((audit, idx) => <AuditCard key={`${audit.created_at}-${idx}`} audit={audit} />)
                            )}
                        </Box>
                    )}

                    {/* Pagination */}
                    <Box sx={{ borderTop: `1px solid ${colors.middle}`, py: { xs: 1, sm: 0 } }}>
                        <TablePagination
                            rowsPerPageOptions={[5, 10, 25, 50]}
                            component="div"
                            count={total}
                            rowsPerPage={rowsPerPage}
                            page={page}
                            onPageChange={(e, newPage) => setPage(newPage)}
                            onRowsPerPageChange={(e) => {
                                setRowsPerPage(parseInt(e.target.value, 10));
                                setPage(0);
                            }}
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

                {/* Action Menu */}
                <Menu
                    anchorEl={actionMenu}
                    open={Boolean(actionMenu)}
                    onClose={handleMenuClose}
                    anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                    transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                >
                    <MenuItem onClick={handleViewDetails} sx={{ color: colors.sea }}>
                        <ViewIcon sx={{ mr: 1, fontSize: 20 }} /> View Details
                    </MenuItem>
                </Menu>

                {/* Details Modal */}
                <Dialog
                    open={viewModalOpen}
                    onClose={() => setViewModalOpen(false)}
                    maxWidth="md"
                    fullWidth
                    PaperProps={{
                        sx: {
                            m: { xs: 2, sm: 0 },
                            borderRadius: { xs: 2, sm: 1 },
                            backgroundColor: colors.light,
                        }
                    }}
                >
                    <DialogTitle sx={{ pb: 1, color: colors.dark }}>Audit Trail Details</DialogTitle>
                    <DialogContent dividers sx={{ borderColor: colors.middle }}>
                        {selectedAudit && (
                            <Box component="dl" sx={{
                                display: 'grid',
                                gridTemplateColumns: { xs: '1fr', sm: '120px 1fr' },
                                gap: 1,
                                '& dt': {
                                    fontWeight: 'bold',
                                    color: colors.rain,
                                    fontSize: '0.875rem',
                                    mt: 0.5
                                },
                                '& dd': {
                                    m: 0,
                                    wordBreak: 'break-all',
                                    fontSize: '0.875rem',
                                    color: colors.black,
                                    mb: 1
                                }
                            }}>
                                <dt>Date & Time:</dt>
                                <dd>{formatDate(selectedAudit.created_at)}</dd>

                                <dt>User:</dt>
                                <dd>
                                    {selectedAudit.user?.name || selectedAudit.user_name || 'Unknown'}
                                    ({selectedAudit.user?.email || selectedAudit.user_email || 'No email'})
                                </dd>

                                <dt>Role:</dt>
                                <dd>{selectedAudit.user?.role || selectedAudit.user_role || 'N/A'}</dd>

                                <dt>Action:</dt>
                                <dd>{selectedAudit.action}</dd>

                                <dt>Module:</dt>
                                <dd>{selectedAudit.module || '-'}</dd>

                                <dt>Description:</dt>
                                <dd>{selectedAudit.description || 'No description'}</dd>

                                <dt>IP Address:</dt>
                                <dd>{selectedAudit.ip_address}</dd>

                                <dt>Request Method:</dt>
                                <dd>{selectedAudit.request_method || 'N/A'}</dd>

                                <dt>Request URL:</dt>
                                <dd style={{ wordBreak: 'break-all' }}>{selectedAudit.request_url || 'N/A'}</dd>

                                <dt>User Agent:</dt>
                                <dd style={{ wordBreak: 'break-all' }}>{selectedAudit.user_agent || 'N/A'}</dd>

                                {selectedAudit.old_data && (
                                    <>
                                        <dt>Old Data:</dt>
                                        <dd>
                                            <pre style={{
                                                whiteSpace: 'pre-wrap',
                                                margin: 0,
                                                fontSize: '0.75rem',
                                                color: colors.black,
                                                backgroundColor: colors.sky,
                                                padding: '8px',
                                                borderRadius: '4px',
                                                maxHeight: '200px',
                                                overflow: 'auto'
                                            }}>
                                                {JSON.stringify(selectedAudit.old_data, null, 2)}
                                            </pre>
                                        </dd>
                                    </>
                                )}

                                {selectedAudit.new_data && (
                                    <>
                                        <dt>New Data:</dt>
                                        <dd>
                                            <pre style={{
                                                whiteSpace: 'pre-wrap',
                                                margin: 0,
                                                fontSize: '0.75rem',
                                                color: colors.black,
                                                backgroundColor: colors.sky,
                                                padding: '8px',
                                                borderRadius: '4px',
                                                maxHeight: '200px',
                                                overflow: 'auto'
                                            }}>
                                                {JSON.stringify(selectedAudit.new_data, null, 2)}
                                            </pre>
                                        </dd>
                                    </>
                                )}
                            </Box>
                        )}
                    </DialogContent>
                    <DialogActions sx={{ p: 2 }}>
                        <Button
                            onClick={() => setViewModalOpen(false)}
                            variant="outlined"
                            sx={{
                                borderColor: colors.middle,
                                color: colors.sea,
                                '&:hover': {
                                    borderColor: colors.sea,
                                    backgroundColor: colors.wave,
                                }
                            }}
                        >
                            Close
                        </Button>
                    </DialogActions>
                </Dialog>
            </Box>
        </LocalizationProvider>
    );
}