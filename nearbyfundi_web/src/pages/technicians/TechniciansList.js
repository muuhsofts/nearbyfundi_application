// src/pages/technicians/TechniciansList.js
import React, { useState, useEffect, useMemo } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell, TableContainer,
    TableHead, TableRow, TablePagination, TableSortLabel, TextField,
    InputAdornment, IconButton, Chip, CircularProgress, useMediaQuery,
    useTheme, Card, CardContent, Divider, Avatar, Stack, Grid, Alert,
} from '@mui/material';
import {
    Search as SearchIcon, Refresh as RefreshIcon, Person as PersonIcon,
    LocationOn as LocationIcon, Star as StarIcon, Verified as VerifiedIcon,
    Work as WorkIcon, Clear as ClearIcon, People as PeopleIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useTechnicianManagement } from 'hooks/useTechnician';
import { useAdminTechnicianManagement } from 'hooks/useAdminTechnicians';
import { usePermissions } from 'hooks/usePermissions';
import { useLanguage } from 'context/LanguageContext';
import { tTech } from './technicianslang';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const getHeadCells = (t) => [
    { id: 'name', label: t('tech.list.col.technician') },
    { id: 'services', label: t('tech.list.col.services') },
    { id: 'area', label: t('tech.list.col.location') },
    { id: 'rating', label: t('tech.list.col.rating') },
    { id: 'status', label: t('tech.list.col.status') },
];

const TechniciansList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));
    const navigate = useNavigate();

    const { language } = useLanguage();
    const t = (key, replacements) => tTech(language, key, replacements);
    const headCells = useMemo(() => getHeadCells(t), [language]);

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
            if (result && result.pagination) setPagination(result.pagination);
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
                case 'name': aValue = a.user?.name || ''; bValue = b.user?.name || ''; break;
                case 'area': aValue = a.area || ''; bValue = b.area || ''; break;
                case 'rating': aValue = a.rating || 0; bValue = b.rating || 0; break;
                default: aValue = a[orderBy] || ''; bValue = b[orderBy] || '';
            }
            if (typeof aValue === 'string') { aValue = aValue.toLowerCase(); bValue = bValue.toLowerCase(); }
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
        if (path.startsWith('http://') || path.startsWith('https://')) return path;
        const baseUrl = process.env.REACT_APP_API_URL || 'http://192.168.100.144:8000';
        const cleanPath = path.replace(/^\/+/, '');
        return `${baseUrl}/storage/${cleanPath}`;
    };

    const getStatusChip = (technician) => {
        const isVerified = technician.verified && technician.verification_status === 'approved';
        const status = technician.verification_status || 'pending';

        if (isVerified) {
            return (
                <Chip
                    label={t('tech.status.verified')}
                    size="small"
                    icon={<VerifiedIcon sx={{ fontSize: 14 }} />}
                    sx={{
                        fontWeight: 700, bgcolor: '#d1fae5', color: '#047857',
                        border: '1.5px solid #10b981', height: 28,
                    }}
                />
            );
        }

        const statusMap = {
            approved: { label: t('tech.status.approved'), color: '#047857', bg: '#d1fae5', border: '#10b981' },
            pending: { label: t('tech.status.pending'), color: '#b45309', bg: '#fef3c7', border: '#f59e0b' },
            rejected: { label: t('tech.status.rejected'), color: '#b91c1c', bg: '#fee2e2', border: '#ef4444' },
        };

        const s = statusMap[status] || statusMap.pending;
        return (
            <Chip
                label={s.label}
                size="small"
                sx={{
                    fontWeight: 700, bgcolor: s.bg, color: s.color,
                    border: `1.5px solid ${s.border}`, height: 28,
                }}
            />
        );
    };

    if (!canViewAll) {
        return (
            <Box p={3}>
                <Paper elevation={0} sx={{ p: 4, textAlign: 'center', borderRadius: 3, border: '1px solid', borderColor: 'divider' }}>
                    <Typography color="error" fontWeight={600}>
                        {t('tech.list.accessDenied')}
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
                            {t('tech.common.retry') || 'Retry'}
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
            <Paper elevation={0} sx={{
                width: '100%', borderRadius: 3, overflow: 'hidden',
                border: '1px solid', borderColor: 'divider', bgcolor: 'background.paper',
            }}>
                {/* ── HEADER ───────────────────────────────────── */}
                <Box sx={{ px: { xs: 2, sm: 3 }, py: 2.5, borderBottom: '1px solid', borderColor: 'divider' }}>
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        justifyContent="space-between"
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        spacing={2} mb={2.5}
                    >
                        <Box>
                            <Typography variant="h5" fontWeight={800} color="text.primary">
                                {t('tech.list.title')}
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                {t('tech.list.subtitle')}
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} alignItems="center" justifyContent={{ xs: 'space-between', sm: 'flex-end' }}>
                            <Button
                                variant="contained" startIcon={<RefreshIcon />}
                                onClick={loadTechnicians} disabled={loading}
                                size={isMobile ? 'small' : 'medium'}
                                sx={{
                                    borderRadius: 2, fontWeight: 600, textTransform: 'none', px: 2.5,
                                    boxShadow: 'none', bgcolor: 'primary.main',
                                    '&:hover': { boxShadow: '0 4px 12px rgba(0,0,0,0.15)' },
                                }}
                            >
                                {t('tech.common.refresh')}
                            </Button>
                        </Stack>
                    </Stack>

                    {/* ── FILTERS ─────────────────────────────────── */}
                    <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}
                           alignItems={{ xs: 'stretch', sm: 'center' }} flexWrap="wrap">
                        <TextField
                            placeholder={t('tech.list.searchPlaceholder')}
                            size="small" value={search}
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
                                minWidth: { xs: '100%', sm: 260 }, flexGrow: { xs: 1, sm: 0 },
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2, bgcolor: 'action.hover',
                                    '& fieldset': { borderColor: 'transparent' },
                                    '&:hover fieldset': { borderColor: 'divider' },
                                    '&.Mui-focused fieldset': { borderColor: 'primary.main' },
                                },
                            }}
                        />

                        <TextField
                            placeholder={t('tech.list.serviceFilterPlaceholder')}
                            size="small" value={serviceFilter}
                            onChange={(e) => setServiceFilter(e.target.value)}
                            sx={{
                                minWidth: { xs: '100%', sm: 200 }, flexGrow: { xs: 1, sm: 0 },
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2, bgcolor: 'action.hover',
                                    '& fieldset': { borderColor: 'transparent' },
                                    '&:hover fieldset': { borderColor: 'divider' },
                                    '&.Mui-focused fieldset': { borderColor: 'primary.main' },
                                },
                            }}
                        />
                    </Stack>
                </Box>

                {/* ── SUMMARY CARDS ─────────────────────────────── */}
                <Box sx={{ px: { xs: 2, sm: 3 }, pt: 2.5, pb: 1 }}>
                    <Grid container spacing={2}>
                        {[
                            { label: t('tech.list.stat.total'), value: totalCount, color: '#3b82f6', bg: '#eff6ff', icon: <PeopleIcon sx={{ fontSize: 18 }} /> },
                            { label: t('tech.list.stat.verified'), value: currentData.filter(tc => tc.verified && tc.verification_status === 'approved').length, color: '#10b981', bg: '#ecfdf5', icon: <VerifiedIcon sx={{ fontSize: 18 }} /> },
                            { label: t('tech.list.stat.pending'), value: currentData.filter(tc => tc.verification_status === 'pending' && !tc.verified).length, color: '#f59e0b', bg: '#fef3c7', icon: <PersonIcon sx={{ fontSize: 18 }} /> },
                            { label: t('tech.list.stat.services'), value: new Set(currentData.flatMap(tc => tc.services?.map(s => s.id) || [])).size, color: '#8b5cf6', bg: '#f3e8ff', icon: <WorkIcon sx={{ fontSize: 18 }} /> },
                        ].map((item, idx) => (
                            <Grid item xs={6} sm={3} key={idx}>
                                <Card elevation={0} sx={{
                                    borderRadius: 2, border: '1px solid', borderColor: 'divider',
                                    backgroundColor: item.bg, height: '100%',
                                }}>
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

                {/* ── TABLE (DESKTOP) ──────────────────────────── */}
                {showTableView ? (
                    <TableContainer>
                        <Table sx={{ minWidth: 800 }}>
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
                                                {t('tech.list.noFound')}
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
                                                            width: 40, height: 40,
                                                            bgcolor: colors.sea || '#0f766e',
                                                            fontSize: 15, fontWeight: 700,
                                                        }}
                                                    >
                                                        {technician.user?.name?.charAt(0).toUpperCase() || 'T'}
                                                    </Avatar>
                                                    <Box>
                                                        <Stack direction="row" spacing={0.5} alignItems="center">
                                                            <Typography variant="body2" fontWeight={600} color="text.primary">
                                                                {technician.user?.name || t('tech.common.unknown')}
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
                                                        label={t('tech.list.serviceCount', {
                                                            n: getServiceCount(technician),
                                                            s: getServiceCount(technician) !== 1 ? 's' : '',
                                                        })}
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
                                                            {technician.area || t('tech.common.na')}
                                                        </Typography>
                                                    </Box>
                                                    {technician.experience !== undefined && technician.experience !== null && (
                                                        <Typography variant="caption" color="text.secondary">
                                                            {t('tech.list.yearsExperience', { n: technician.experience })}
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
                                                                {t('tech.list.ratePerHour', { rate: technician.hourly_rate })}
                                                            </Typography>
                                                        )}
                                                    </Box>
                                                ) : (
                                                    <Typography variant="body2" color="text.secondary">
                                                        {t('tech.list.noRating')}
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
                    /* ── MOBILE CARDS ─────────────────────────── */
                    <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
                        {loading ? (
                            <Box display="flex" justifyContent="center" py={6}>
                                <CircularProgress size={36} thickness={4} />
                            </Box>
                        ) : sortedData.length === 0 ? (
                            <Paper variant="outlined" sx={{ p: 5, textAlign: 'center', borderRadius: 3, borderStyle: 'dashed' }}>
                                <Typography color="text.secondary" fontWeight={500}>
                                    {t('tech.list.noFound')}
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
                                            border: '1px solid', borderColor: 'divider',
                                            overflow: 'hidden', cursor: 'pointer',
                                            transition: 'box-shadow 0.2s',
                                            '&:hover': { boxShadow: 2 },
                                        }}
                                        onClick={() => handleRowClick(technician.id)}
                                    >
                                        <CardContent sx={{ p: 2.5 }}>
                                            <Stack direction="row" spacing={2} alignItems="center" mb={2}>
                                                <Avatar
                                                    src={technician.profile_photo ? getImageUrl(technician.profile_photo) : undefined}
                                                    sx={{
                                                        width: 52, height: 52,
                                                        bgcolor: colors.sea || '#0f766e',
                                                        fontSize: 18, fontWeight: 700,
                                                    }}
                                                >
                                                    {technician.user?.name?.charAt(0).toUpperCase() || 'T'}
                                                </Avatar>
                                                <Box flex={1}>
                                                    <Stack direction="row" spacing={0.5} alignItems="center">
                                                        <Typography variant="h6" fontWeight={700} fontSize="1rem">
                                                            {technician.user?.name || t('tech.common.unknown')}
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
                                                            {technician.area || t('tech.common.na')}
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
                                                            {t('tech.list.serviceCount', {
                                                                n: getServiceCount(technician),
                                                                s: getServiceCount(technician) !== 1 ? 's' : '',
                                                            })}
                                                            {getServiceNames(technician) && `: ${getServiceNames(technician)}`}
                                                        </Typography>
                                                    </Box>
                                                </Grid>
                                                {technician.hourly_rate && (
                                                    <Grid item xs={12}>
                                                        <Typography variant="body2" fontWeight={600} color={colors.sea || '#0f766e'}>
                                                            {t('tech.list.ratePerHour', { rate: technician.hourly_rate })}
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

                {/* ── PAGINATION ──────────────────────────────── */}
                <Box sx={{ borderTop: '1px solid', borderColor: 'divider', bgcolor: 'action.hover' }}>
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