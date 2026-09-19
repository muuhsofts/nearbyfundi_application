// src/pages/portfolios/PortfoliosList.js
import React, { useState, useEffect, useMemo } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell, TableContainer,
    TableHead, TableRow, TablePagination, TableSortLabel, TextField,
    InputAdornment, IconButton, Chip, Menu, MenuItem, Dialog, DialogTitle,
    DialogContent, DialogActions, CircularProgress, useMediaQuery, useTheme,
    Card, CardContent, Divider, Avatar, Stack, Grid, DialogContentText, Tooltip,
} from '@mui/material';
import {
    Search as SearchIcon, Refresh as RefreshIcon, MoreVert as MoreVertIcon,
    Delete as DeleteIcon, Visibility as ViewIcon, Person as PersonIcon,
    Verified as VerifiedIcon, LocationOn as LocationIcon, Star as StarIcon,
    Image as ImageIcon, CalendarToday as CalendarIcon, Clear as ClearIcon,
    PhotoCamera as PhotoCameraIcon, Description as DescriptionIcon,
} from '@mui/icons-material';
import { portfolioService } from 'services/portfolio.service';
import { usePermissions } from 'hooks/usePermissions';
import { useLanguage } from 'context/LanguageContext';
import { showSnackbar } from 'utils/snackbar';
import { tPortfolio } from './portfolioslang';
import { format } from 'date-fns';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const getHeadCells = (t) => [
    { id: 'portfolio', label: t('portfolio.table.col.portfolio'), disableSort: true },
    { id: 'technician', label: t('portfolio.table.col.technician'), disableSort: true },
    { id: 'description', label: t('portfolio.table.col.description'), disableSort: true },
    { id: 'created_at', label: t('portfolio.table.col.created') },
    { id: 'actions', label: t('portfolio.table.col.actions'), disableSort: true },
];

const PortfoliosList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const { language } = useLanguage();
    const t = (key, replacements) => tPortfolio(language, key, replacements);
    const headCells = useMemo(() => getHeadCells(t), [language]);

    const { can } = usePermissions();
    const canView = can('portfolios.view');
    const canDelete = can('portfolios.delete');

    const [portfolios, setPortfolios] = useState([]);
    const [loading, setLoading] = useState(false);
    const [pagination, setPagination] = useState({ total: 0, per_page: 10, current_page: 1, last_page: 1 });

    const [search, setSearch] = useState('');
    const [technicianFilter, setTechnicianFilter] = useState('all');
    const [technicians, setTechnicians] = useState([]);
    const [loadingTechnicians, setLoadingTechnicians] = useState(false);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [order, setOrder] = useState('desc');
    const [orderBy, setOrderBy] = useState('created_at');

    const [selectedPortfolio, setSelectedPortfolio] = useState(null);
    const [openViewDialog, setOpenViewDialog] = useState(false);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedPortfolioForMenu, setSelectedPortfolioForMenu] = useState(null);

    const [confirmDialog, setConfirmDialog] = useState({
        open: false, title: '', message: '', action: null,
    });

    // ── EXISTING LOGIC: Load technicians ────────────────────────────────
    const loadTechnicians = async () => {
        setLoadingTechnicians(true);
        try {
            const response = await portfolioService.getTechnicians?.({ per_page: 100, status: 'active' });
            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) setTechnicians(data.data);
                else if (Array.isArray(data)) setTechnicians(data);
                else setTechnicians([]);
            }
        } catch (err) {
            console.error('Error loading technicians:', err);
        } finally {
            setLoadingTechnicians(false);
        }
    };

    useEffect(() => { loadTechnicians(); }, []);

    // ── EXISTING LOGIC: Load portfolios ──────────────────────────────────
    const loadPortfolios = async () => {
        if (!canView) return;
        setLoading(true);
        try {
            const params = {
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
            };
            const response = await portfolioService.getPortfolios(params);

            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    let filteredData = data.data;
                    if (technicianFilter !== 'all') {
                        filteredData = filteredData.filter(
                            portfolio => portfolio.technician?.id === parseInt(technicianFilter)
                        );
                    }
                    setPortfolios(filteredData);
                    setPagination({
                        total: data.total || 0,
                        per_page: data.per_page || rowsPerPage,
                        current_page: data.current_page || 1,
                        last_page: data.last_page || 1,
                    });
                } else if (Array.isArray(data)) {
                    let filteredData = data;
                    if (technicianFilter !== 'all') {
                        filteredData = data.filter(
                            portfolio => portfolio.technician?.id === parseInt(technicianFilter)
                        );
                    }
                    setPortfolios(filteredData);
                    setPagination({
                        total: filteredData.length,
                        per_page: rowsPerPage,
                        current_page: 1,
                        last_page: 1,
                    });
                } else {
                    setPortfolios([]);
                }
            } else {
                setPortfolios([]);
            }
        } catch (err) {
            console.error('Portfolios error:', err);
            showSnackbar({ type: 'error', message: err.message || t('portfolio.toast.loadFailed') });
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canView) loadPortfolios();
    }, [page, rowsPerPage, search, technicianFilter, canView]);

    const refreshAll = () => { loadPortfolios(); };

    // ── EXISTING LOGIC: View portfolio ───────────────────────────────────
    const handleViewPortfolio = async (portfolio) => {
        try {
            const response = await portfolioService.getPortfolio?.(portfolio.id);
            if (response?.data?.status === 'success') setSelectedPortfolio(response.data.data);
            else setSelectedPortfolio(portfolio);
        } catch (err) {
            console.error('Error fetching portfolio details:', err);
            setSelectedPortfolio(portfolio);
        }
        setOpenViewDialog(true);
    };

    const handleCloseDialog = () => {
        setOpenViewDialog(false);
        setSelectedPortfolio(null);
    };

    // ── EXISTING LOGIC: Delete portfolio ─────────────────────────────────
    const handleDeletePortfolio = async (id) => {
        try {
            await portfolioService.deletePortfolio(id);
            showSnackbar({ type: 'success', message: t('portfolio.toast.deleteSuccess') });
            await loadPortfolios();
            return true;
        } catch (err) {
            console.error('Delete error:', err);
            const errorMessage = err.response?.data?.message || t('portfolio.toast.deleteFailed');
            showSnackbar({ type: 'error', message: errorMessage });
            throw err;
        }
    };

    // ── EXISTING LOGIC: Confirm dialog ──────────────────────────────────
    const openConfirmDialog = (title, message, actionFn) => {
        setConfirmDialog({ open: true, title, message, action: actionFn });
    };

    const handleConfirm = async () => {
        if (!confirmDialog.action) return;
        const action = confirmDialog.action;
        setConfirmDialog(prev => ({ ...prev, open: false }));
        try { await action(); } catch (err) { console.error('Confirm action failed:', err); }
    };

    // ── EXISTING LOGIC: Sorting ─────────────────────────────────────────
    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    // ── Client-side sorting ─────────────────────────────────────────────
    const sortedPortfolios = useMemo(() => {
        const sorted = [...portfolios];
        sorted.sort((a, b) => {
            let aValue, bValue;
            switch (orderBy) {
                case 'created_at': aValue = a.created_at || ''; bValue = b.created_at || ''; break;
                default: aValue = a[orderBy] || ''; bValue = b[orderBy] || '';
            }
            if (typeof aValue === 'string') { aValue = aValue.toLowerCase(); bValue = bValue.toLowerCase(); }
            if (aValue < bValue) return order === 'asc' ? -1 : 1;
            if (aValue > bValue) return order === 'asc' ? 1 : -1;
            return 0;
        });
        return sorted;
    }, [portfolios, orderBy, order]);

    // ── EXISTING HELPERS ─────────────────────────────────────────────────
    const getInitials = (name) => {
        if (!name) return '?';
        return name.split(' ').map(word => word[0]).join('').toUpperCase().substring(0, 2);
    };

    const getImageUrl = (image) => {
        if (!image) return null;
        if (image.startsWith('http://') || image.startsWith('https://')) return image;
        const baseUrl = process.env.REACT_APP_API_URL || 'http://192.168.100.144:8000';
        const cleanPath = image.replace(/^\/+/, '');
        return `${baseUrl}/storage/${cleanPath}`;
    };

    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        try { return format(new Date(dateStr), 'MMM d, yyyy'); } catch { return '-'; }
    };

    const formatDateFull = (dateStr) => {
        if (!dateStr) return '-';
        try { return format(new Date(dateStr), 'MMM d, yyyy h:mm a'); } catch { return '-'; }
    };

    const truncateText = (text, maxLength = 60) => {
        if (!text) return '';
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
    };

    // ── UI: Action menu handlers ────────────────────────────────────────
    const handleMenuOpen = (event, portfolio) => {
        setSelectedPortfolioForMenu(portfolio);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => {
        setActionMenu(null);
        setSelectedPortfolioForMenu(null);
    };

    const handleAction = async (actionType) => {
        if (!selectedPortfolioForMenu) return;
        handleMenuClose();
        switch (actionType) {
            case 'view':
                handleViewPortfolio(selectedPortfolioForMenu);
                break;
            case 'delete':
                openConfirmDialog(
                    t('portfolio.delete.title'),
                    t('portfolio.delete.message'),
                    () => handleDeletePortfolio(selectedPortfolioForMenu.id)
                );
                break;
            default: break;
        }
    };

    // ── Summary stats ──────────────────────────────────────────────────
    const totalPortfolios = pagination.total || 0;
    const uniqueTechnicians = new Set(portfolios.map(p => p.technician?.id).filter(Boolean)).size;

    // ── Permission check ──────────────────────────────────────────────
    if (!canView) {
        return (
            <Box p={3}>
                <Paper elevation={0} sx={{ p: 4, textAlign: 'center', borderRadius: 3, border: '1px solid', borderColor: 'divider' }}>
                    <Typography color="error" fontWeight={600}>{t('portfolio.accessDenied')}</Typography>
                </Paper>
            </Box>
        );
    }

    // ── RENDER ──────────────────────────────────────────────────────────
    return (
        <Box sx={{ width: '100%', p: { xs: 1.5, sm: 2.5 }, m: 0, bgcolor: 'background.default' }}>
            <Paper elevation={0} sx={{
                width: '100%', borderRadius: 3, overflow: 'hidden',
                border: '1px solid', borderColor: 'divider', bgcolor: 'background.paper',
            }}>
                {/* ── HEADER ────────────────────────────────────────── */}
                <Box sx={{ px: { xs: 2, sm: 3 }, py: 2.5, borderBottom: '1px solid', borderColor: 'divider' }}>
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        justifyContent="space-between"
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        spacing={2} mb={2.5}
                    >
                        <Box>
                            <Typography variant="h5" fontWeight={800} color="text.primary">
                                {t('portfolio.header.title')}
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                {t('portfolio.header.subtitle')}
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} alignItems="center" justifyContent={{ xs: 'space-between', sm: 'flex-end' }}>
                            <Button
                                variant="contained" startIcon={<RefreshIcon />}
                                onClick={refreshAll} disabled={loading}
                                size={isMobile ? 'small' : 'medium'}
                                sx={{
                                    borderRadius: 2, fontWeight: 600, textTransform: 'none', px: 2.5,
                                    boxShadow: 'none', bgcolor: 'primary.main',
                                    '&:hover': { boxShadow: '0 4px 12px rgba(0,0,0,0.15)' },
                                }}
                            >
                                {t('portfolio.common.refresh')}
                            </Button>
                        </Stack>
                    </Stack>

                    {/* ── FILTERS ─────────────────────────────────── */}
                    <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}
                           alignItems={{ xs: 'stretch', sm: 'center' }} flexWrap="wrap">
                        <TextField
                            select label={t('portfolio.filter.technician')} size="small"
                            value={technicianFilter}
                            onChange={(e) => { setTechnicianFilter(e.target.value); setPage(0); }}
                            sx={{
                                minWidth: { xs: '100%', sm: 180 }, flexGrow: { xs: 1, sm: 0 },
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2, bgcolor: 'action.hover',
                                    '& fieldset': { borderColor: 'transparent' },
                                    '&:hover fieldset': { borderColor: 'divider' },
                                    '&.Mui-focused fieldset': { borderColor: 'primary.main' },
                                },
                            }}
                        >
                            <MenuItem value="all">{t('portfolio.common.all')}</MenuItem>
                            {technicians.map((tech) => (
                                <MenuItem key={tech.id} value={tech.id}>
                                    {tech.user?.name || tech.name || t('portfolio.common.unknown')}
                                </MenuItem>
                            ))}
                        </TextField>

                        <TextField
                            placeholder={t('portfolio.filter.searchPlaceholder')}
                            size="small" value={search}
                            onChange={(e) => { setSearch(e.target.value); setPage(0); }}
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
                    </Stack>
                </Box>

                {/* ── SUMMARY CARDS ────────────────────────────────── */}
                <Box sx={{ px: { xs: 2, sm: 3 }, pt: 2.5, pb: 1 }}>
                    <Grid container spacing={2}>
                        {[
                            { label: t('portfolio.stats.totalPortfolios'), value: totalPortfolios, color: '#8b5cf6', bg: '#f3e8ff', icon: <ImageIcon sx={{ fontSize: 18 }} /> },
                            { label: t('portfolio.stats.technicians'), value: uniqueTechnicians, color: '#3b82f6', bg: '#eff6ff', icon: <PersonIcon sx={{ fontSize: 18 }} /> },
                            { label: t('portfolio.stats.activeItems'), value: portfolios.filter(p => p.status !== 'archived').length, color: '#10b981', bg: '#ecfdf5', icon: <DescriptionIcon sx={{ fontSize: 18 }} /> },
                            { label: t('portfolio.stats.recent'), value: portfolios.filter(p => p.created_at && new Date(p.created_at) > new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)).length, color: '#f59e0b', bg: '#fef3c7', icon: <CalendarIcon sx={{ fontSize: 18 }} /> },
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

                {/* ── TABLE (DESKTOP) ──────────────────────────────── */}
                {showTableView ? (
                    <TableContainer>
                        <Table sx={{ minWidth: 900 }}>
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
                                            {!cell.disableSort ? (
                                                <TableSortLabel
                                                    active={orderBy === cell.id}
                                                    direction={orderBy === cell.id ? order : 'asc'}
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
                                {loading ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                            <CircularProgress size={36} thickness={4} />
                                        </TableCell>
                                    </TableRow>
                                ) : sortedPortfolios.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                            <Typography color="text.secondary" fontWeight={500}>
                                                {t('portfolio.table.noFound')}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sortedPortfolios.map((portfolio) => {
                                        const imageUrl = portfolio.image ? getImageUrl(portfolio.image) : null;
                                        return (
                                            <TableRow key={portfolio.id} hover sx={{ '&:last-child td': { borderBottom: 0 }, transition: 'background-color 0.15s' }}>
                                                {/* Portfolio */}
                                                <TableCell sx={{ py: 2 }}>
                                                    <Stack direction="row" spacing={1.5} alignItems="center">
                                                        {imageUrl ? (
                                                            <Box sx={{
                                                                width: 48, height: 48, borderRadius: 1.5, overflow: 'hidden',
                                                                flexShrink: 0, bgcolor: 'action.hover',
                                                                border: '1px solid', borderColor: 'divider',
                                                            }}>
                                                                <img src={imageUrl} alt=""
                                                                     style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                                                     onError={(e) => { e.target.style.display = 'none'; }} />
                                                            </Box>
                                                        ) : (
                                                            <Box sx={{
                                                                width: 48, height: 48, borderRadius: 1.5, bgcolor: 'action.hover',
                                                                border: '1px solid', borderColor: 'divider',
                                                                display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                                                            }}>
                                                                <PhotoCameraIcon sx={{ color: 'text.disabled', fontSize: 24 }} />
                                                            </Box>
                                                        )}
                                                        <Box>
                                                            <Typography variant="body2" fontWeight={600} color="text.primary">
                                                                {t('portfolio.table.itemLabel', { id: portfolio.id })}
                                                            </Typography>
                                                            {portfolio.technician?.name && (
                                                                <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                                                                    {portfolio.technician.name}
                                                                </Typography>
                                                            )}
                                                        </Box>
                                                    </Stack>
                                                </TableCell>

                                                {/* Technician */}
                                                <TableCell>
                                                    <Stack direction="row" spacing={1} alignItems="center">
                                                        <Avatar
                                                            src={portfolio.technician?.profile_photo ? getImageUrl(portfolio.technician.profile_photo) : undefined}
                                                            sx={{
                                                                width: 32, height: 32,
                                                                bgcolor: colors.sea || '#0f766e',
                                                                fontSize: 12, fontWeight: 600,
                                                            }}
                                                        >
                                                            {getInitials(portfolio.technician?.user?.name || portfolio.technician?.name)}
                                                        </Avatar>
                                                        <Box>
                                                            <Typography variant="body2" fontWeight={500}>
                                                                {portfolio.technician?.user?.name || portfolio.technician?.name || t('portfolio.common.emDash')}
                                                            </Typography>
                                                            {portfolio.technician?.verified && (
                                                                <VerifiedIcon sx={{ fontSize: 12, color: '#10b981', display: 'block' }} />
                                                            )}
                                                        </Box>
                                                    </Stack>
                                                </TableCell>

                                                {/* Description */}
                                                <TableCell>
                                                    <Typography variant="body2" color="text.secondary">
                                                        {truncateText(portfolio.description || t('portfolio.common.noDescription'), 50)}
                                                    </Typography>
                                                </TableCell>

                                                {/* Created */}
                                                <TableCell>
                                                    <Typography variant="body2" fontWeight={500} color="text.secondary">
                                                        {formatDate(portfolio.created_at)}
                                                    </Typography>
                                                </TableCell>

                                                {/* Actions */}
                                                <TableCell align="center">
                                                    <IconButton
                                                        size="small"
                                                        onClick={(e) => handleMenuOpen(e, portfolio)}
                                                        sx={{
                                                            color: 'text.secondary',
                                                            '&:hover': { bgcolor: 'action.hover', color: 'text.primary' },
                                                        }}
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
                    /* ── MOBILE/TABLET CARDS ──────────────────────── */
                    <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
                        {loading ? (
                            <Box display="flex" justifyContent="center" py={6}>
                                <CircularProgress size={36} thickness={4} />
                            </Box>
                        ) : sortedPortfolios.length === 0 ? (
                            <Paper variant="outlined" sx={{ p: 5, textAlign: 'center', borderRadius: 3, borderStyle: 'dashed' }}>
                                <Typography color="text.secondary" fontWeight={500}>
                                    {t('portfolio.table.noFound')}
                                </Typography>
                            </Paper>
                        ) : (
                            <Grid container spacing={2}>
                                {sortedPortfolios.map((portfolio) => {
                                    const imageUrl = portfolio.image ? getImageUrl(portfolio.image) : null;
                                    return (
                                        <Grid item xs={12} sm={6} key={portfolio.id}>
                                            <Card elevation={0} sx={{
                                                borderRadius: 3, border: '1px solid', borderColor: 'divider',
                                                overflow: 'hidden', height: '100%',
                                                display: 'flex', flexDirection: 'column',
                                                transition: 'box-shadow 0.2s',
                                                '&:hover': { boxShadow: 2 },
                                            }}>
                                                {/* Image Header */}
                                                {imageUrl ? (
                                                    <Box sx={{
                                                        width: '100%', height: 160, overflow: 'hidden',
                                                        bgcolor: 'action.hover', position: 'relative',
                                                    }}>
                                                        <img src={imageUrl} alt="Portfolio"
                                                             style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                                             onError={(e) => { e.target.style.display = 'none'; }} />
                                                        {portfolio.technician?.verified && (
                                                            <Box sx={{ position: 'absolute', top: 8, left: 8 }}>
                                                                <VerifiedIcon sx={{ fontSize: 20, color: '#10b981' }} />
                                                            </Box>
                                                        )}
                                                    </Box>
                                                ) : (
                                                    <Box sx={{
                                                        width: '100%', height: 160, bgcolor: 'action.hover',
                                                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                                                        flexDirection: 'column',
                                                        borderBottom: '1px solid', borderColor: 'divider',
                                                        position: 'relative',
                                                    }}>
                                                        <PhotoCameraIcon sx={{ color: 'text.disabled', fontSize: 48 }} />
                                                        <Typography variant="caption" color="text.disabled" sx={{ mt: 1 }}>
                                                            {t('portfolio.common.noImage')}
                                                        </Typography>
                                                        {portfolio.technician?.verified && (
                                                            <Box sx={{ position: 'absolute', top: 8, left: 8 }}>
                                                                <VerifiedIcon sx={{ fontSize: 20, color: '#10b981' }} />
                                                            </Box>
                                                        )}
                                                    </Box>
                                                )}

                                                <CardContent sx={{ p: 2.5, flex: 1, display: 'flex', flexDirection: 'column' }}>
                                                    <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={1.5}>
                                                        <Stack direction="row" spacing={1.5} alignItems="center">
                                                            <Avatar
                                                                src={portfolio.technician?.profile_photo ? getImageUrl(portfolio.technician.profile_photo) : undefined}
                                                                sx={{
                                                                    width: 36, height: 36,
                                                                    bgcolor: colors.sea || '#0f766e',
                                                                    fontSize: 13, fontWeight: 600,
                                                                }}
                                                            >
                                                                {getInitials(portfolio.technician?.user?.name || portfolio.technician?.name)}
                                                            </Avatar>
                                                            <Box>
                                                                <Typography variant="body2" fontWeight={600}>
                                                                    {portfolio.technician?.user?.name || portfolio.technician?.name || t('portfolio.common.emDash')}
                                                                </Typography>
                                                                {portfolio.technician?.area && (
                                                                    <Typography variant="caption" color="text.secondary" sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                                                        <LocationIcon sx={{ fontSize: 12 }} />
                                                                        {portfolio.technician.area}
                                                                    </Typography>
                                                                )}
                                                            </Box>
                                                        </Stack>
                                                        <IconButton
                                                            size="small"
                                                            onClick={(e) => handleMenuOpen(e, portfolio)}
                                                            sx={{ color: 'text.secondary', mt: -0.5 }}
                                                        >
                                                            <MoreVertIcon fontSize="small" />
                                                        </IconButton>
                                                    </Stack>

                                                    <Typography variant="body2" color="text.secondary" sx={{
                                                        mb: 2, flex: 1,
                                                        display: '-webkit-box', WebkitLineClamp: 3,
                                                        WebkitBoxOrient: 'vertical', overflow: 'hidden',
                                                    }}>
                                                        {portfolio.description || t('portfolio.common.noDescriptionProvided')}
                                                    </Typography>

                                                    <Divider sx={{ mb: 2 }} />

                                                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                                                        <Stack direction="row" spacing={1}>
                                                            {portfolio.technician?.rating > 0 && (
                                                                <Chip
                                                                    icon={<StarIcon sx={{ fontSize: 14 }} />}
                                                                    label={portfolio.technician.rating.toFixed(1)}
                                                                    size="small"
                                                                    sx={{
                                                                        fontWeight: 700, bgcolor: '#fef3c7', color: '#b45309',
                                                                        border: '1px solid #fcd34d', height: 26,
                                                                        '& .MuiChip-icon': { color: '#f59e0b' },
                                                                    }}
                                                                />
                                                            )}
                                                        </Stack>
                                                        <Typography variant="caption" color="text.secondary" fontWeight={500}>
                                                            {formatDate(portfolio.created_at)}
                                                        </Typography>
                                                    </Stack>

                                                    <Button
                                                        variant="outlined" fullWidth startIcon={<ViewIcon />}
                                                        onClick={() => handleViewPortfolio(portfolio)}
                                                        sx={{
                                                            mt: 2, borderRadius: 2, textTransform: 'none', fontWeight: 600,
                                                            borderColor: 'divider', color: colors.sea || '#0f766e',
                                                            '&:hover': { borderColor: colors.sea || '#0f766e', bgcolor: 'action.hover' },
                                                        }}
                                                    >
                                                        {t('portfolio.common.view')}
                                                    </Button>
                                                </CardContent>
                                            </Card>
                                        </Grid>
                                    );
                                })}
                            </Grid>
                        )}
                    </Box>
                )}

                {/* ── PAGINATION ─────────────────────────────────── */}
                <Box sx={{ borderTop: '1px solid', borderColor: 'divider', bgcolor: 'action.hover' }}>
                    <TablePagination
                        rowsPerPageOptions={[5, 10, 25, 50]}
                        component="div"
                        count={pagination.total || 0}
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

            {/* ── ACTION MENU ─────────────────────────────────────── */}
            <Menu
                anchorEl={actionMenu}
                open={Boolean(actionMenu)}
                onClose={handleMenuClose}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                PaperProps={{ elevation: 8, sx: { borderRadius: 2, minWidth: 180, mt: 0.5 } }}
            >
                <MenuItem onClick={() => handleAction('view')} sx={{ fontWeight: 500 }}>
                    <ViewIcon sx={{ mr: 1.5, fontSize: 20, color: colors.sea || '#0f766e' }} />
                    {t('portfolio.menu.viewPortfolio')}
                </MenuItem>
                {canDelete && (
                    <MenuItem onClick={() => handleAction('delete')} sx={{ color: 'error.main', fontWeight: 500 }}>
                        <DeleteIcon sx={{ mr: 1.5, fontSize: 20 }} />
                        {t('portfolio.menu.delete')}
                    </MenuItem>
                )}
            </Menu>

            {/* ── PORTFOLIO DETAIL DIALOG ─────────────────────────── */}
            <Dialog
                open={openViewDialog}
                onClose={handleCloseDialog}
                maxWidth="md" fullWidth
                PaperProps={{
                    sx: { borderRadius: 3, border: '1px solid', borderColor: 'divider', maxHeight: '90vh' },
                }}
            >
                {selectedPortfolio && (
                    <>
                        <DialogTitle sx={{ pb: 1.5, borderBottom: '1px solid', borderColor: 'divider' }}>
                            <Box display="flex" justifyContent="space-between" alignItems="flex-start">
                                <Box flex={1} minWidth={0}>
                                    <Typography variant="h6" fontWeight={700} color="text.primary">
                                        {t('portfolio.dialog.title')}
                                    </Typography>
                                    <Stack direction="row" spacing={2} alignItems="center" mt={1} flexWrap="wrap">
                                        <Stack direction="row" spacing={1} alignItems="center">
                                            <Avatar
                                                src={selectedPortfolio.technician?.profile_photo ? getImageUrl(selectedPortfolio.technician.profile_photo) : undefined}
                                                sx={{
                                                    width: 28, height: 28,
                                                    bgcolor: colors.sea || '#0f766e',
                                                    fontSize: 11, fontWeight: 600,
                                                }}
                                            >
                                                {getInitials(selectedPortfolio.technician?.user?.name || selectedPortfolio.technician?.name)}
                                            </Avatar>
                                            <Typography variant="body2" fontWeight={500}>
                                                {selectedPortfolio.technician?.user?.name || selectedPortfolio.technician?.name || t('portfolio.common.unknown')}
                                            </Typography>
                                            {selectedPortfolio.technician?.verified && (
                                                <VerifiedIcon sx={{ fontSize: 14, color: '#10b981' }} />
                                            )}
                                        </Stack>
                                        {selectedPortfolio.technician?.area && (
                                            <Chip
                                                icon={<LocationIcon sx={{ fontSize: 14 }} />}
                                                label={selectedPortfolio.technician.area}
                                                size="small"
                                                variant="outlined"
                                                sx={{ borderColor: 'divider' }}
                                            />
                                        )}
                                        <Typography variant="caption" color="text.secondary">
                                            <CalendarIcon sx={{ fontSize: 14, mr: 0.5, verticalAlign: 'middle' }} />
                                            {formatDateFull(selectedPortfolio.created_at)}
                                        </Typography>
                                    </Stack>
                                </Box>
                                <IconButton onClick={handleCloseDialog} size="small" sx={{ color: 'text.secondary' }}>
                                    <ClearIcon />
                                </IconButton>
                            </Box>
                        </DialogTitle>

                        <DialogContent sx={{ p: 3 }}>
                            {selectedPortfolio.image && (
                                <Box sx={{
                                    width: '100%', maxHeight: 400, bgcolor: 'action.hover',
                                    borderRadius: 2, overflow: 'hidden', mb: 3,
                                    border: '1px solid', borderColor: 'divider',
                                    display: 'flex', justifyContent: 'center', alignItems: 'center', p: 1,
                                }}>
                                    <img src={getImageUrl(selectedPortfolio.image)} alt="Portfolio"
                                         style={{ maxWidth: '100%', maxHeight: '380px', width: 'auto', height: 'auto', objectFit: 'contain' }}
                                         onError={(e) => { e.target.style.display = 'none'; }} />
                                </Box>
                            )}

                            {selectedPortfolio.description && (
                                <Box mb={3}>
                                    <Typography variant="subtitle2" fontWeight={600} gutterBottom color="text.primary">
                                        {t('portfolio.dialog.description')}
                                    </Typography>
                                    <Paper variant="outlined" sx={{ p: 2.5, bgcolor: 'action.hover', borderColor: 'divider', borderRadius: 2 }}>
                                        <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                                            {selectedPortfolio.description}
                                        </Typography>
                                    </Paper>
                                </Box>
                            )}

                            <Divider sx={{ mb: 3, borderColor: 'divider' }} />

                            <Grid container spacing={2}>
                                <Grid item xs={12} sm={6}>
                                    <Typography variant="subtitle2" fontWeight={600} gutterBottom color="text.primary">
                                        {t('portfolio.dialog.technicianInfo')}
                                    </Typography>
                                    <Stack spacing={1}>
                                        <Box display="flex" alignItems="center" gap={1}>
                                            <PersonIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                                            <Typography variant="body2">
                                                {selectedPortfolio.technician?.user?.name || selectedPortfolio.technician?.name || t('portfolio.common.unknown')}
                                            </Typography>
                                        </Box>
                                        {selectedPortfolio.technician?.area && (
                                            <Box display="flex" alignItems="center" gap={1}>
                                                <LocationIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                                                <Typography variant="body2">{selectedPortfolio.technician.area}</Typography>
                                            </Box>
                                        )}
                                        {selectedPortfolio.technician?.rating > 0 && (
                                            <Box display="flex" alignItems="center" gap={0.5}>
                                                <StarIcon sx={{ color: '#f59e0b', fontSize: 16 }} />
                                                <Typography variant="body2" fontWeight={500}>
                                                    {selectedPortfolio.technician.rating.toFixed(1)}
                                                </Typography>
                                            </Box>
                                        )}
                                    </Stack>
                                </Grid>
                                <Grid item xs={12} sm={6}>
                                    <Typography variant="subtitle2" fontWeight={600} gutterBottom color="text.primary">
                                        {t('portfolio.dialog.details')}
                                    </Typography>
                                    <Stack spacing={1}>
                                        <Box display="flex" alignItems="center" gap={1}>
                                            <CalendarIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                                            <Typography variant="body2">
                                                {t('portfolio.dialog.created', { date: formatDateFull(selectedPortfolio.created_at) })}
                                            </Typography>
                                        </Box>
                                        <Box display="flex" alignItems="center" gap={1}>
                                            <ImageIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                                            <Typography variant="body2">
                                                {t('portfolio.dialog.portfolioLabel', { id: selectedPortfolio.id })}
                                            </Typography>
                                        </Box>
                                    </Stack>
                                </Grid>
                            </Grid>
                        </DialogContent>

                        <DialogActions sx={{ p: 2.5, borderTop: '1px solid', borderColor: 'divider' }}>
                            <Button
                                onClick={handleCloseDialog}
                                variant="contained"
                                sx={{
                                    borderRadius: 2, fontWeight: 700, textTransform: 'none', px: 4,
                                    bgcolor: colors.sea || '#0f766e',
                                    '&:hover': { bgcolor: colors.dark || '#0d5c56' },
                                }}
                            >
                                {t('portfolio.common.close')}
                            </Button>
                        </DialogActions>
                    </>
                )}
            </Dialog>

            {/* ── CONFIRMATION DIALOG ─────────────────────────────── */}
            <Dialog
                open={confirmDialog.open}
                onClose={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                fullWidth maxWidth="xs"
                PaperProps={{ sx: { borderRadius: 3 } }}
            >
                <DialogTitle sx={{ fontWeight: 700, pb: 1 }}>{confirmDialog.title}</DialogTitle>
                <DialogContent>
                    <DialogContentText color="text.secondary">{confirmDialog.message}</DialogContentText>
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2.5, pt: 1 }}>
                    <Button
                        onClick={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                        sx={{ fontWeight: 600, textTransform: 'none' }}
                    >
                        {t('portfolio.common.cancel')}
                    </Button>
                    <Button
                        onClick={handleConfirm}
                        variant="contained" color="error"
                        sx={{ fontWeight: 700, textTransform: 'none', borderRadius: 2 }}
                    >
                        {t('portfolio.common.confirm')}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default PortfoliosList;