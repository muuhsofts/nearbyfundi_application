// src/pages/technicians/TechniciansList.js
import React, { useState, useEffect } from 'react';
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
    Chip,
    CircularProgress,
    useMediaQuery,
    useTheme,
    Card,
    CardContent,
    Divider,
    Avatar,
    Stack,
    Grid,
    Alert,
    Tooltip,
} from '@mui/material';
import {
    Search as SearchIcon,
    Refresh as RefreshIcon,
    Person as PersonIcon,
    LocationOn as LocationIcon,
    Star as StarIcon,
    Verified as VerifiedIcon,
    Work as WorkIcon,
    Clear as ClearIcon,
    People as PeopleIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useTechnicianManagement } from 'hooks/useTechnician';
import { useAdminTechnicianManagement } from 'hooks/useAdminTechnicians';
import { usePermissions } from 'hooks/usePermissions';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'name', label: 'Technician' },
    { id: 'services', label: 'Services' },
    { id: 'area', label: 'Location' },
    { id: 'rating', label: 'Rating' },
    { id: 'status', label: 'Status' },
];

const TechniciansList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));
    const navigate = useNavigate();

    const { can } = usePermissions();
    const canViewAll = can('technicians.view');

    const publicContext = useTechnicianManagement();
    const adminContext = useAdminTechnicianManagement();
    const context = canViewAll ? adminContext : publicContext;
    const { technicians, loading, error, getTechnicians, clearError } = context;

    const [search, setSearch] = useState('');
    const [serviceFilter, setServiceFilter] = useState('');
    const [order, setOrder] = useState('asc');
    const [orderBy, setOrderBy] = useState('name');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [pagination, setPagination] = useState({ total: 0, per_page: 10, current_page: 1, last_page: 1 });

    const getServiceNames = (technician) => {
        if (!technician.services || !Array.isArray(technician.services)) return '';
        return technician.services.map(s => s.name).join(', ');
    };

    const getServiceCount = (technician) => {
        if (!technician.services || !Array.isArray(technician.services)) return 0;
        return technician.services.length;
    };

    const loadTechnicians = async () => {
        const params = {
            page: page + 1,
            per_page: rowsPerPage,
            search: search || undefined,
        };
        if (serviceFilter) params.service_id = serviceFilter;

        try {
            const result = await getTechnicians(params);
            if (result && result.pagination) {
                setPagination(result.pagination);
            }
        } catch (err) {
            // error handled by context
        }
    };

    useEffect(() => {
        loadTechnicians();
    }, [page, rowsPerPage, search, serviceFilter]);

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    const sortData = (data) => {
        if (!data) return [];
        const sorted = [...data];
        sorted.sort((a, b) => {
            let aValue, bValue;
            switch (orderBy) {
                case 'name':
                    aValue = a.user?.name || '';
                    bValue = b.user?.name || '';
                    break;
                case 'area':
                    aValue = a.area || '';
                    bValue = b.area || '';
                    break;
                case 'rating':
                    aValue = a.rating || 0;
                    bValue = b.rating || 0;
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
    };

    const handleRowClick = (id) => {
        navigate(`/app/technicians/${id}`);
    };

    const getImageUrl = (path) => {
        if (!path) return null;
        if (path.startsWith('http://') || path.startsWith('https://')) {
            return path;
        }
        const baseUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
        const cleanPath = path.replace(/^\/+/, '');
        return `${baseUrl}/storage/${cleanPath}`;
    };

    const getStatusChip = (technician) => {
        const isVerified = technician.verified && technician.verification_status === 'approved';
        const status = technician.verification_status || 'pending';

        if (isVerified) {
            return (
                <Chip
                    label="Verified"
                    size="small"
                    icon={<VerifiedIcon sx={{ fontSize: 14 }} />}
                    sx={{
                        fontWeight: 700,
                        bgcolor: '#d1fae5',
                        color: '#047857',
                        border: '1.5px solid #10b981',
                        height: 28,
                    }}
                />
            );
        }

        const statusMap = {
            approved: { label: 'Approved', color: '#047857', bg: '#d1fae5', border: '#10b981' },
            pending: { label: 'Pending', color: '#b45309', bg: '#fef3c7', border: '#f59e0b' },
            rejected: { label: 'Rejected', color: '#b91c1c', bg: '#fee2e2', border: '#ef4444' },
        };

        const s = statusMap[status] || statusMap.pending;
        return (
            <Chip
                label={s.label}
                size="small"
                sx={{
                    fontWeight: 700,
                    bgcolor: s.bg,
                    color: s.color,
                    border: `1.5px solid ${s.border}`,
                    height: 28,
                }}
            />
        );
    };

    if (!canViewAll) {
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
                        You do not have permission to view technicians.
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
                        <Button color="inherit" size="small" onClick={() => { clearError(); loadTechnicians(); }}>
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

    const currentData = Array.isArray(technicians) ? technicians : [];
    const sortedData = sortData(currentData);
    const totalCount = pagination.total || 0;

    return (
        <Box sx={{ width: '100%', p: { xs: 1.5, sm: 2.5 }, m: 0, bgcolor: 'background.default' }}>
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
                {/* ── HEADER ────────────────────────────────────────────── */}
                <Box
                    sx={{
                        px: { xs: 2, sm: 3 },
                        py: 2.5,
                        borderBottom: '1px solid',
                        borderColor: 'divider',
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
                                Technician Management
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                Manage technician profiles and verification
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} alignItems="center" justifyContent={{ xs: 'space-between', sm: 'flex-end' }}>
                            <Button
                                variant="contained"
                                startIcon={<RefreshIcon />}
                                onClick={loadTechnicians}
                                disabled={loading}
                                size={isMobile ? 'small' : 'medium'}
                                sx={{
                                    borderRadius: 2,
                                    fontWeight: 600,
                                    textTransform: 'none',
                                    px: 2.5,
                                    boxShadow: 'none',
                                    bgcolor: 'primary.main',
                                    '&:hover': {
                                        boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
                                    },
                                }}
                            >
                                Refresh
                            </Button>
                        </Stack>
                    </Stack>

                    {/* ── FILTERS ──────────────────────────────────────── */}
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        spacing={1.5}
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        flexWrap="wrap"
                    >
                        <TextField
                            placeholder="Search technicians..."
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

                        <TextField
                            placeholder="Filter by service..."
                            size="small"
                            value={serviceFilter}
                            onChange={(e) => setServiceFilter(e.target.value)}
                            sx={{
                                minWidth: { xs: '100%', sm: 200 },
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
                    </Stack>
                </Box>

                {/* ── SUMMARY CARDS ────────────────────────────────────── */}
                <Box sx={{ px: { xs: 2, sm: 3 }, pt: 2.5, pb: 1 }}>
                    <Grid container spacing={2}>
                        {[
                            { label: 'Total Technicians', value: totalCount, color: '#3b82f6', bg: '#eff6ff', icon: <PeopleIcon sx={{ fontSize: 18 }} /> },
                            { label: 'Verified', value: currentData.filter(t => t.verified && t.verification_status === 'approved').length, color: '#10b981', bg: '#ecfdf5', icon: <VerifiedIcon sx={{ fontSize: 18 }} /> },
                            { label: 'Pending', value: currentData.filter(t => t.verification_status === 'pending' && !t.verified).length, color: '#f59e0b', bg: '#fef3c7', icon: <PersonIcon sx={{ fontSize: 18 }} /> },
                            { label: 'Services', value: new Set(currentData.flatMap(t => t.services?.map(s => s.id) || [])).size, color: '#8b5cf6', bg: '#f3e8ff', icon: <WorkIcon sx={{ fontSize: 18 }} /> },
                        ].map((item, idx) => (
                            <Grid item xs={6} sm={3} key={idx}>
                                <Card
                                    elevation={0}
                                    sx={{
                                        borderRadius: 2,
                                        border: '1px solid',
                                        borderColor: 'divider',
                                        backgroundColor: item.bg,
                                        height: '100%',
                                    }}
                                >
                                    <CardContent sx={{ p: 2, '&:last-child': { pb: 2 } }}>
                                        <Box display="flex" alignItems="center" justifyContent="space-between">
                                            <Typography variant="caption" sx={{ color: item.color, fontWeight: 600 }}>
                                                {item.label}
                                            </Typography>
                                            {item.icon}
                                        </Box>
                                        <Typography variant="h4" sx={{ color: item.color, fontWeight: 700 }}>
                                            {item.value}
                                        </Typography>
                                    </CardContent>
                                </Card>
                            </Grid>
                        ))}
                    </Grid>
                </Box>

                {/* ── TABLE (DESKTOP) ───────────────────────────────────── */}
                {showTableView ? (
                    <TableContainer>
                        <Table sx={{ minWidth: 800 }}>
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
                                            <TableSortLabel
                                                active={orderBy === cell.id}
                                                direction={orderBy === cell.id ? order : 'asc'}
                                                onClick={() => handleRequestSort(cell.id)}
                                            >
                                                {cell.label}
                                            </TableSortLabel>
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
                                                No technicians found
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sortedData.map((technician) => (
                                        <TableRow
                                            key={technician.id}
                                            hover
                                            onClick={() => handleRowClick(technician.id)}
                                            sx={{
                                                cursor: 'pointer',
                                                '&:last-child td': { borderBottom: 0 },
                                                transition: 'background-color 0.15s',
                                            }}
                                        >
                                            <TableCell sx={{ py: 2 }}>
                                                <Stack direction="row" spacing={1.5} alignItems="center">
                                                    <Avatar
                                                        src={technician.profile_photo ? getImageUrl(technician.profile_photo) : undefined}
                                                        sx={{
                                                            width: 40,
                                                            height: 40,
                                                            bgcolor: colors.sea || '#0f766e',
                                                            fontSize: 15,
                                                            fontWeight: 700,
                                                        }}
                                                    >
                                                        {technician.user?.name?.charAt(0).toUpperCase() || 'T'}
                                                    </Avatar>
                                                    <Box>
                                                        <Stack direction="row" spacing={0.5} alignItems="center">
                                                            <Typography variant="body2" fontWeight={600} color="text.primary">
                                                                {technician.user?.name || 'Unknown'}
                                                            </Typography>
                                                            {technician.verified && technician.verification_status === 'approved' && (
                                                                <VerifiedIcon sx={{ fontSize: 14, color: '#10b981' }} />
                                                            )}
                                                        </Stack>
                                                        <Typography variant="caption" color="text.secondary">
                                                            {technician.user?.email || ''}
                                                        </Typography>
                                                    </Box>
                                                </Stack>
                                            </TableCell>

                                            <TableCell>
                                                <Stack spacing={0.5}>
                                                    <Chip
                                                        icon={<WorkIcon sx={{ fontSize: 14 }} />}
                                                        label={`${getServiceCount(technician)} service${getServiceCount(technician) !== 1 ? 's' : ''}`}
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 600,
                                                            bgcolor: 'action.hover',
                                                            height: 24,
                                                        }}
                                                    />
                                                    {getServiceNames(technician) && (
                                                        <Typography variant="caption" color="text.secondary" noWrap sx={{ maxWidth: 180 }}>
                                                            {getServiceNames(technician)}
                                                        </Typography>
                                                    )}
                                                </Stack>
                                            </TableCell>

                                            <TableCell>
                                                <Stack spacing={0.5}>
                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                        <LocationIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                                                        <Typography variant="body2" fontWeight={500}>
                                                            {technician.area || 'N/A'}
                                                        </Typography>
                                                    </Box>
                                                    {technician.experience !== undefined && technician.experience !== null && (
                                                        <Typography variant="caption" color="text.secondary">
                                                            {technician.experience} yrs experience
                                                        </Typography>
                                                    )}
                                                </Stack>
                                            </TableCell>

                                            <TableCell>
                                                {technician.rating !== undefined && technician.rating !== null ? (
                                                    <Box>
                                                        <Box display="flex" alignItems="center" gap={0.5}>
                                                            <StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />
                                                            <Typography variant="body2" fontWeight={700} color="text.primary">
                                                                {technician.rating.toFixed(1)}
                                                            </Typography>
                                                        </Box>
                                                        {technician.hourly_rate && (
                                                            <Typography variant="caption" color="text.secondary">
                                                                {technician.hourly_rate} TZS/hr
                                                            </Typography>
                                                        )}
                                                    </Box>
                                                ) : (
                                                    <Typography variant="body2" color="text.secondary">
                                                        No rating
                                                    </Typography>
                                                )}
                                            </TableCell>

                                            <TableCell>
                                                {getStatusChip(technician)}
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                ) : (
                    /* ── MOBILE CARDS ──────────────────────────────────── */
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
                                    No technicians found
                                </Typography>
                            </Paper>
                        ) : (
                            <Stack spacing={2}>
                                {sortedData.map((technician) => (
                                    <Card
                                        key={technician.id}
                                        elevation={0}
                                        sx={{
                                            borderRadius: 3,
                                            border: '1px solid',
                                            borderColor: 'divider',
                                            overflow: 'hidden',
                                            cursor: 'pointer',
                                            transition: 'box-shadow 0.2s',
                                            '&:hover': {
                                                boxShadow: 2,
                                            },
                                        }}
                                        onClick={() => handleRowClick(technician.id)}
                                    >
                                        <CardContent sx={{ p: 2.5 }}>
                                            <Stack direction="row" spacing={2} alignItems="center" mb={2}>
                                                <Avatar
                                                    src={technician.profile_photo ? getImageUrl(technician.profile_photo) : undefined}
                                                    sx={{
                                                        width: 52,
                                                        height: 52,
                                                        bgcolor: colors.sea || '#0f766e',
                                                        fontSize: 18,
                                                        fontWeight: 700,
                                                    }}
                                                >
                                                    {technician.user?.name?.charAt(0).toUpperCase() || 'T'}
                                                </Avatar>
                                                <Box flex={1}>
                                                    <Stack direction="row" spacing={0.5} alignItems="center">
                                                        <Typography variant="h6" fontWeight={700} fontSize="1rem">
                                                            {technician.user?.name || 'Unknown'}
                                                        </Typography>
                                                        {technician.verified && technician.verification_status === 'approved' && (
                                                            <VerifiedIcon sx={{ fontSize: 16, color: '#10b981' }} />
                                                        )}
                                                    </Stack>
                                                    <Typography variant="caption" color="text.secondary">
                                                        {technician.user?.email || ''}
                                                    </Typography>
                                                </Box>
                                                {getStatusChip(technician)}
                                            </Stack>

                                            <Divider sx={{ mb: 2 }} />

                                            <Grid container spacing={1.5}>
                                                <Grid item xs={6}>
                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                        <LocationIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                                                        <Typography variant="body2" fontWeight={500}>
                                                            {technician.area || 'N/A'}
                                                        </Typography>
                                                    </Box>
                                                </Grid>
                                                <Grid item xs={6}>
                                                    {technician.rating !== undefined && technician.rating !== null && (
                                                        <Box display="flex" alignItems="center" gap={0.5}>
                                                            <StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />
                                                            <Typography variant="body2" fontWeight={700}>
                                                                {technician.rating.toFixed(1)}
                                                            </Typography>
                                                        </Box>
                                                    )}
                                                </Grid>
                                                <Grid item xs={12}>
                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                        <WorkIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                                                        <Typography variant="body2">
                                                            {getServiceCount(technician)} service{getServiceCount(technician) !== 1 ? 's' : ''}
                                                            {getServiceNames(technician) && `: ${getServiceNames(technician)}`}
                                                        </Typography>
                                                    </Box>
                                                </Grid>
                                                {technician.hourly_rate && (
                                                    <Grid item xs={12}>
                                                        <Typography variant="body2" fontWeight={600} color={colors.sea || '#0f766e'}>
                                                            {technician.hourly_rate} TZS/hr
                                                        </Typography>
                                                    </Grid>
                                                )}
                                            </Grid>
                                        </CardContent>
                                    </Card>
                                ))}
                            </Stack>
                        )}
                    </Box>
                )}

                {/* ── PAGINATION ────────────────────────────────────────── */}
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
        </Box>
    );
};

export default TechniciansList;