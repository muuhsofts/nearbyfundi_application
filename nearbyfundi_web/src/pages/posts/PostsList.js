// src/pages/posts/PostsList.js
import React, { useState, useEffect, useMemo } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell, TableContainer,
    TableHead, TableRow, TablePagination, TableSortLabel, TextField,
    InputAdornment, IconButton, Chip, Menu, MenuItem, Dialog, DialogTitle,
    DialogContent, DialogActions, CircularProgress, useMediaQuery, useTheme,
    Card, CardContent, Divider, Avatar, Stack, Grid, DialogContentText,
} from '@mui/material';
import {
    Search as SearchIcon, Refresh as RefreshIcon, MoreVert as MoreVertIcon,
    Delete as DeleteIcon, Visibility as ViewIcon, Favorite as FavoriteIcon,
    Comment as CommentIcon, Person as PersonIcon, LocationOn as LocationIcon,
    Verified as VerifiedIcon, Star as StarIcon, CalendarToday as CalendarIcon,
    Clear as ClearIcon, PhotoCamera as PhotoCameraIcon, Description as DescriptionIcon,
} from '@mui/icons-material';
import { postService } from 'services/post.service';
import { technicianService } from 'services/technician.service';
import { usePermissions } from 'hooks/usePermissions';
import { useLanguage } from 'context/LanguageContext';
import { showSnackbar } from 'utils/snackbar';
import { tPost } from './postslang';
import { format } from 'date-fns';
import appConfig from '../../config';

const colors = appConfig.app.colors;

// Status styles (labels resolved via t())
const getStatusStyles = (t) => ({
    published: { color: '#047857', bg: '#d1fae5', border: '#10b981', label: t('post.status.published') },
    draft: { color: '#4b5563', bg: '#f3f4f6', border: '#9ca3af', label: t('post.status.draft') },
    pending: { color: '#b45309', bg: '#fef3c7', border: '#f59e0b', label: t('post.status.pending') },
    archived: { color: '#6b7280', bg: '#e5e7eb', border: '#9ca3af', label: t('post.status.archived') },
});

const getHeadCells = (t) => [
    { id: 'post', label: t('post.table.col.post'), disableSort: true },
    { id: 'technician', label: t('post.table.col.technician'), disableSort: true },
    { id: 'likes', label: t('post.table.col.likes') },
    { id: 'comments', label: t('post.table.col.comments') },
    { id: 'status', label: t('post.table.col.status') },
    { id: 'created_at', label: t('post.table.col.created') },
    { id: 'actions', label: t('post.table.col.actions'), disableSort: true },
];

const PostsList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const { language } = useLanguage();
    const t = (key, replacements) => tPost(language, key, replacements);
    const statusStyles = useMemo(() => getStatusStyles(t), [language]);
    const headCells = useMemo(() => getHeadCells(t), [language]);

    const { can } = usePermissions();
    const canView = can('posts.view');
    const canDelete = can('posts.delete');

    const [posts, setPosts] = useState([]);
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
    const [selectedPost, setSelectedPost] = useState(null);
    const [openViewDialog, setOpenViewDialog] = useState(false);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedPostForMenu, setSelectedPostForMenu] = useState(null);
    const [confirmDialog, setConfirmDialog] = useState({
        open: false, title: '', message: '', action: null,
    });
    const [imageLoaded, setImageLoaded] = useState({});

    const loadTechnicians = async () => {
        setLoadingTechnicians(true);
        try {
            const response = await technicianService.getTechnicians({ per_page: 100, status: 'active' });
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

    const loadPosts = async () => {
        if (!canView) return;
        setLoading(true);
        try {
            const params = {
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
                technician_id: technicianFilter === 'all' ? undefined : technicianFilter,
            };
            const response = await postService.getAllPosts(params);
            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    setPosts(data.data);
                    setPagination({
                        total: data.total || 0,
                        per_page: data.per_page || rowsPerPage,
                        current_page: data.current_page || 1,
                        last_page: data.last_page || 1,
                    });
                } else if (Array.isArray(data)) {
                    setPosts(data);
                    setPagination({ total: data.length, per_page: rowsPerPage, current_page: 1, last_page: 1 });
                } else {
                    setPosts([]);
                }
            } else {
                setPosts([]);
            }
        } catch (err) {
            console.error('Posts error:', err);
            showSnackbar({ type: 'error', message: err.message || t('post.toast.loadFailed') });
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canView) loadPosts();
    }, [page, rowsPerPage, search, technicianFilter, canView]);

    const refreshAll = () => { loadPosts(); };

    const handleViewPost = async (post) => {
        try {
            const response = await postService.getPost(post.id);
            if (response?.data?.status === 'success') setSelectedPost(response.data.data);
            else setSelectedPost(post);
        } catch (err) {
            console.error('Error fetching post details:', err);
            setSelectedPost(post);
        }
        setOpenViewDialog(true);
    };

    const handleCloseDialog = () => {
        setOpenViewDialog(false);
        setSelectedPost(null);
    };

    const handleDeletePost = async (id) => {
        try {
            await postService.deletePost(id);
            showSnackbar({ type: 'success', message: t('post.toast.deleteSuccess') });
            await loadPosts();
            return true;
        } catch (err) {
            console.error('Delete error:', err);
            const errorMessage = err.response?.data?.message || t('post.toast.deleteFailed');
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
        try { await action(); } catch (err) { console.error('Confirm action failed:', err); }
    };

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    const sortedPosts = useMemo(() => {
        const sorted = [...posts];
        sorted.sort((a, b) => {
            let aValue, bValue;
            switch (orderBy) {
                case 'likes': aValue = a.likes_count || 0; bValue = b.likes_count || 0; break;
                case 'comments': aValue = a.comments_count || 0; bValue = b.comments_count || 0; break;
                case 'status': aValue = a.status || 'published'; bValue = b.status || 'published'; break;
                case 'created_at': aValue = a.created_at || ''; bValue = b.created_at || ''; break;
                default: aValue = a[orderBy] || ''; bValue = b[orderBy] || '';
            }
            if (typeof aValue === 'string') { aValue = aValue.toLowerCase(); bValue = bValue.toLowerCase(); }
            if (aValue < bValue) return order === 'asc' ? -1 : 1;
            if (aValue > bValue) return order === 'asc' ? 1 : -1;
            return 0;
        });
        return sorted;
    }, [posts, orderBy, order]);

    const handleImageLoad = (id) => setImageLoaded(prev => ({ ...prev, [id]: true }));

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

    const getStatusChip = (status) => {
        const s = statusStyles[status] || statusStyles.published;
        return (
            <Chip
                label={s.label}
                size="small"
                sx={{
                    backgroundColor: s.bg, color: s.color, fontWeight: 700,
                    border: `1.5px solid ${s.border}`, height: 28,
                    '& .MuiChip-label': { px: 1.5 },
                }}
            />
        );
    };

    const handleMenuOpen = (event, post) => {
        setSelectedPostForMenu(post);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => {
        setActionMenu(null);
        setSelectedPostForMenu(null);
    };

    const handleAction = async (actionType) => {
        if (!selectedPostForMenu) return;
        handleMenuClose();
        switch (actionType) {
            case 'view':
                handleViewPost(selectedPostForMenu);
                break;
            case 'delete':
                openConfirmDialog(
                    t('post.delete.title'),
                    t('post.delete.message', { title: selectedPostForMenu.title || t('post.common.untitled') }),
                    () => handleDeletePost(selectedPostForMenu.id)
                );
                break;
            default: break;
        }
    };

    const totalPosts = pagination.total || 0;
    const totalLikes = posts.reduce((acc, p) => acc + (p.likes_count || 0), 0);
    const totalComments = posts.reduce((acc, p) => acc + (p.comments_count || 0), 0);
    const uniqueTechnicians = new Set(posts.map(p => p.technician?.id).filter(Boolean)).size;

    if (!canView) {
        return (
            <Box p={3}>
                <Paper elevation={0} sx={{
                    p: 4, textAlign: 'center', borderRadius: 3,
                    border: '1px solid', borderColor: 'divider',
                    bgcolor: 'background.paper',
                }}>
                    <Typography color="error" fontWeight={600}>{t('post.accessDenied')}</Typography>
                </Paper>
            </Box>
        );
    }

    return (
        <Box sx={{ width: '100%', p: { xs: 1.5, sm: 2.5 }, m: 0, bgcolor: 'background.default' }}>
            <Paper elevation={0} sx={{
                width: '100%', borderRadius: 3, overflow: 'hidden',
                border: '1px solid', borderColor: 'divider', bgcolor: 'background.paper',
            }}>
                {/* HEADER */}
                <Box sx={{ px: { xs: 2, sm: 3 }, py: 2.5, borderBottom: '1px solid', borderColor: 'divider' }}>
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        justifyContent="space-between"
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        spacing={2} mb={2.5}
                    >
                        <Box>
                            <Typography variant="h5" fontWeight={800} color="text.primary">
                                {t('post.header.title')}
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                {t('post.header.subtitle')}
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
                                {t('post.common.refresh')}
                            </Button>
                        </Stack>
                    </Stack>

                    {/* FILTERS */}
                    <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}
                           alignItems={{ xs: 'stretch', sm: 'center' }} flexWrap="wrap">
                        <TextField
                            select label={t('post.filter.technician')} size="small"
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
                            <MenuItem value="all">{t('post.common.all')}</MenuItem>
                            {technicians.map((tech) => (
                                <MenuItem key={tech.id} value={tech.id}>
                                    {tech.user?.name || tech.name || t('post.common.unknown')}
                                </MenuItem>
                            ))}
                        </TextField>

                        <TextField
                            placeholder={t('post.filter.searchPlaceholder')}
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

                {/* SUMMARY CARDS */}
                <Box sx={{ px: { xs: 2, sm: 3 }, pt: 2.5, pb: 1 }}>
                    <Grid container spacing={2}>
                        {[
                            { label: t('post.stats.totalPosts'), value: totalPosts, color: '#3b82f6', icon: <DescriptionIcon sx={{ fontSize: 18 }} /> },
                            { label: t('post.stats.technicians'), value: uniqueTechnicians, color: '#8b5cf6', icon: <PersonIcon sx={{ fontSize: 18 }} /> },
                            { label: t('post.stats.totalLikes'), value: totalLikes, color: '#ef4444', icon: <FavoriteIcon sx={{ fontSize: 18 }} /> },
                            { label: t('post.stats.totalComments'), value: totalComments, color: '#10b981', icon: <CommentIcon sx={{ fontSize: 18 }} /> },
                        ].map((item, idx) => (
                            <Grid item xs={6} sm={3} key={idx}>
                                <Card elevation={0} sx={{
                                    borderRadius: 2, border: '1px solid', borderColor: 'divider',
                                    bgcolor: 'background.paper', // ✅ Theme aware
                                    height: '100%',
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

                {/* TABLE */}
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
                                ) : sortedPosts.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                            <Typography color="text.secondary" fontWeight={500}>
                                                {t('post.table.noFound')}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sortedPosts.map((post) => {
                                        const imageUrl = post.image ? getImageUrl(post.image) : null;
                                        return (
                                            <TableRow key={post.id} hover sx={{ '&:last-child td': { borderBottom: 0 }, transition: 'background-color 0.15s' }}>
                                                <TableCell sx={{ py: 2 }}>
                                                    <Stack direction="row" spacing={1.5} alignItems="center">
                                                        {imageUrl ? (
                                                            <Box sx={{
                                                                width: 48, height: 48, borderRadius: 1.5, overflow: 'hidden',
                                                                flexShrink: 0, bgcolor: 'action.hover',
                                                                border: '1px solid', borderColor: 'divider',
                                                            }}>
                                                                <img src={imageUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }}
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
                                                            <Typography variant="body2" fontWeight={600} color="text.primary" noWrap sx={{ maxWidth: 180 }}>
                                                                {post.title || t('post.common.untitled')}
                                                            </Typography>
                                                            <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                                                                {post.content?.substring(0, 45)}...
                                                            </Typography>
                                                        </Box>
                                                    </Stack>
                                                </TableCell>

                                                <TableCell>
                                                    <Stack direction="row" spacing={1} alignItems="center">
                                                        <Avatar
                                                            src={post.technician?.profile_photo ? getImageUrl(post.technician.profile_photo) : undefined}
                                                            sx={{
                                                                width: 32, height: 32,
                                                                bgcolor: colors.sea || '#0f766e',
                                                                fontSize: 12, fontWeight: 600,
                                                            }}
                                                        >
                                                            {getInitials(post.technician?.user?.name || post.technician?.name)}
                                                        </Avatar>
                                                        <Box>
                                                            <Typography variant="body2" fontWeight={500}>
                                                                {post.technician?.user?.name || post.technician?.name || t('post.common.emDash')}
                                                            </Typography>
                                                            {post.technician?.verified && (
                                                                <VerifiedIcon sx={{ fontSize: 12, color: 'success.main', display: 'block' }} />
                                                            )}
                                                        </Box>
                                                    </Stack>
                                                </TableCell>

                                                <TableCell>
                                                    <Chip
                                                        icon={<FavoriteIcon sx={{ fontSize: 14 }} />}
                                                        label={post.likes_count || 0}
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 700, bgcolor: 'error.light', color: 'error.main',
                                                            border: '1px solid', borderColor: 'error.main', height: 28,
                                                            '& .MuiChip-icon': { color: 'error.main' },
                                                        }}
                                                    />
                                                </TableCell>

                                                <TableCell>
                                                    <Chip
                                                        icon={<CommentIcon sx={{ fontSize: 14 }} />}
                                                        label={post.comments_count || 0}
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 700, bgcolor: 'success.light', color: 'success.main',
                                                            border: '1px solid', borderColor: 'success.main', height: 28,
                                                            '& .MuiChip-icon': { color: 'success.main' },
                                                        }}
                                                    />
                                                </TableCell>

                                                <TableCell>{getStatusChip(post.status)}</TableCell>

                                                <TableCell>
                                                    <Typography variant="body2" fontWeight={500} color="text.secondary">
                                                        {formatDate(post.created_at)}
                                                    </Typography>
                                                </TableCell>

                                                <TableCell align="center">
                                                    <IconButton
                                                        size="small"
                                                        onClick={(e) => handleMenuOpen(e, post)}
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
                    /* MOBILE CARDS */
                    <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
                        {loading ? (
                            <Box display="flex" justifyContent="center" py={6}>
                                <CircularProgress size={36} thickness={4} />
                            </Box>
                        ) : sortedPosts.length === 0 ? (
                            <Paper variant="outlined" sx={{ p: 5, textAlign: 'center', borderRadius: 3, borderStyle: 'dashed', bgcolor: 'background.paper' }}>
                                <Typography color="text.secondary" fontWeight={500}>
                                    {t('post.table.noFound')}
                                </Typography>
                            </Paper>
                        ) : (
                            <Grid container spacing={2}>
                                {sortedPosts.map((post) => {
                                    const imageUrl = post.image ? getImageUrl(post.image) : null;
                                    return (
                                        <Grid item xs={12} sm={6} lg={4} key={post.id}>
                                            <Card elevation={0} sx={{
                                                borderRadius: 3, border: '1px solid', borderColor: 'divider',
                                                bgcolor: 'background.paper', // ✅ Theme aware
                                                overflow: 'hidden', height: '100%',
                                                display: 'flex', flexDirection: 'column',
                                                transition: 'box-shadow 0.2s',
                                                '&:hover': { boxShadow: 2 },
                                            }}>
                                                {imageUrl ? (
                                                    <Box sx={{ width: '100%', height: 160, overflow: 'hidden', bgcolor: 'action.hover', position: 'relative' }}>
                                                        <img src={imageUrl} alt={post.title || 'Post image'}
                                                             style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                                             onError={(e) => { e.target.style.display = 'none'; }} />
                                                        <Box sx={{ position: 'absolute', top: 8, right: 8 }}>
                                                            {getStatusChip(post.status)}
                                                        </Box>
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
                                                            {t('post.common.noImage')}
                                                        </Typography>
                                                        <Box sx={{ position: 'absolute', top: 8, right: 8 }}>
                                                            {getStatusChip(post.status)}
                                                        </Box>
                                                    </Box>
                                                )}

                                                <CardContent sx={{ p: 2.5, flex: 1, display: 'flex', flexDirection: 'column' }}>
                                                    <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={1}>
                                                        <Typography variant="h6" fontWeight={700} noWrap sx={{ maxWidth: '80%' }}>
                                                            {post.title || t('post.common.untitled')}
                                                        </Typography>
                                                        <IconButton size="small" onClick={(e) => handleMenuOpen(e, post)}
                                                                    sx={{ color: 'text.secondary', mt: -0.5 }}>
                                                            <MoreVertIcon fontSize="small" />
                                                        </IconButton>
                                                    </Stack>

                                                    <Typography variant="body2" color="text.secondary" sx={{
                                                        mb: 2, display: '-webkit-box', WebkitLineClamp: 2,
                                                        WebkitBoxOrient: 'vertical', overflow: 'hidden', flex: 1,
                                                    }}>
                                                        {post.content || t('post.common.noContent')}
                                                    </Typography>

                                                    <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 2 }}>
                                                        <Avatar
                                                            src={post.technician?.profile_photo ? getImageUrl(post.technician.profile_photo) : undefined}
                                                            sx={{
                                                                width: 28, height: 28,
                                                                bgcolor: colors.sea || '#0f766e',
                                                                fontSize: 11, fontWeight: 600,
                                                            }}
                                                        >
                                                            {getInitials(post.technician?.user?.name || post.technician?.name)}
                                                        </Avatar>
                                                        <Typography variant="body2" fontWeight={500}>
                                                            {post.technician?.user?.name || post.technician?.name || t('post.common.emDash')}
                                                        </Typography>
                                                        {post.technician?.verified && (
                                                            <VerifiedIcon sx={{ fontSize: 14, color: 'success.main' }} />
                                                        )}
                                                    </Stack>

                                                    <Divider sx={{ mb: 2 }} />

                                                    <Stack direction="row" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={1}>
                                                        <Stack direction="row" spacing={1}>
                                                            <Chip icon={<FavoriteIcon sx={{ fontSize: 14 }} />}
                                                                  label={post.likes_count || 0} size="small"
                                                                  sx={{
                                                                      fontWeight: 700, bgcolor: 'error.light', color: 'error.main',
                                                                      border: '1px solid', borderColor: 'error.main', height: 26,
                                                                      '& .MuiChip-icon': { color: 'error.main' },
                                                                  }} />
                                                            <Chip icon={<CommentIcon sx={{ fontSize: 14 }} />}
                                                                  label={post.comments_count || 0} size="small"
                                                                  sx={{
                                                                      fontWeight: 700, bgcolor: 'success.light', color: 'success.main',
                                                                      border: '1px solid', borderColor: 'success.main', height: 26,
                                                                      '& .MuiChip-icon': { color: 'success.main' },
                                                                  }} />
                                                        </Stack>
                                                        <Typography variant="caption" color="text.secondary" fontWeight={500}>
                                                            {formatDate(post.created_at)}
                                                        </Typography>
                                                    </Stack>

                                                    <Button
                                                        variant="outlined" fullWidth startIcon={<ViewIcon />}
                                                        onClick={() => handleViewPost(post)}
                                                        sx={{
                                                            mt: 2, borderRadius: 2, textTransform: 'none', fontWeight: 600,
                                                            borderColor: 'divider', color: colors.sea || '#0f766e',
                                                            '&:hover': { borderColor: colors.sea || '#0f766e', bgcolor: 'action.hover' },
                                                        }}
                                                    >
                                                        {t('post.common.view')}
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

                {/* PAGINATION */}
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

            {/* ACTION MENU */}
            <Menu
                anchorEl={actionMenu}
                open={Boolean(actionMenu)}
                onClose={handleMenuClose}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                PaperProps={{ elevation: 8, sx: { borderRadius: 2, minWidth: 180, mt: 0.5, bgcolor: 'background.paper' } }}
            >
                <MenuItem onClick={() => handleAction('view')} sx={{ fontWeight: 500 }}>
                    <ViewIcon sx={{ mr: 1.5, fontSize: 20, color: colors.sea || '#0f766e' }} />
                    {t('post.menu.viewPost')}
                </MenuItem>
                {canDelete && (
                    <MenuItem onClick={() => handleAction('delete')} sx={{ color: 'error.main', fontWeight: 500 }}>
                        <DeleteIcon sx={{ mr: 1.5, fontSize: 20 }} />
                        {t('post.menu.delete')}
                    </MenuItem>
                )}
            </Menu>

            {/* POST DETAIL DIALOG */}
            <Dialog
                open={openViewDialog}
                onClose={handleCloseDialog}
                maxWidth="md" fullWidth
                PaperProps={{
                    sx: { borderRadius: 3, border: '1px solid', borderColor: 'divider', maxHeight: '90vh', bgcolor: 'background.paper' },
                }}
            >
                {selectedPost && (
                    <>
                        <DialogTitle sx={{ pb: 1.5, borderBottom: '1px solid', borderColor: 'divider' }}>
                            <Box display="flex" justifyContent="space-between" alignItems="flex-start">
                                <Box flex={1} minWidth={0}>
                                    <Typography variant="h6" fontWeight={700} color="text.primary">
                                        {selectedPost.title || t('post.common.untitled')}
                                    </Typography>
                                    <Stack direction="row" spacing={2} alignItems="center" mt={1} flexWrap="wrap">
                                        <Stack direction="row" spacing={1} alignItems="center">
                                            <Avatar
                                                src={selectedPost.technician?.profile_photo ? getImageUrl(selectedPost.technician.profile_photo) : undefined}
                                                sx={{
                                                    width: 28, height: 28,
                                                    bgcolor: colors.sea || '#0f766e',
                                                    fontSize: 11, fontWeight: 600,
                                                }}
                                            >
                                                {getInitials(selectedPost.technician?.user?.name || selectedPost.technician?.name)}
                                            </Avatar>
                                            <Typography variant="body2" fontWeight={500}>
                                                {selectedPost.technician?.user?.name || selectedPost.technician?.name || t('post.common.unknown')}
                                            </Typography>
                                            {selectedPost.technician?.verified && (
                                                <VerifiedIcon sx={{ fontSize: 14, color: 'success.main' }} />
                                            )}
                                        </Stack>
                                        <Typography variant="caption" color="text.secondary">
                                            <CalendarIcon sx={{ fontSize: 14, mr: 0.5, verticalAlign: 'middle' }} />
                                            {formatDateFull(selectedPost.created_at)}
                                        </Typography>
                                        {getStatusChip(selectedPost.status)}
                                    </Stack>
                                </Box>
                                <IconButton onClick={handleCloseDialog} size="small" sx={{ color: 'text.secondary' }}>
                                    <ClearIcon />
                                </IconButton>
                            </Box>
                        </DialogTitle>

                        <DialogContent sx={{ p: 3 }}>
                            {selectedPost.image && (
                                <Box sx={{
                                    width: '100%', maxHeight: 400, bgcolor: 'action.hover',
                                    borderRadius: 2, overflow: 'hidden', mb: 3,
                                    border: '1px solid', borderColor: 'divider',
                                    display: 'flex', justifyContent: 'center', alignItems: 'center', p: 1,
                                }}>
                                    <img src={getImageUrl(selectedPost.image)} alt={selectedPost.title || 'Post image'}
                                         style={{ maxWidth: '100%', maxHeight: '380px', width: 'auto', height: 'auto', objectFit: 'contain' }}
                                         onError={(e) => { e.target.style.display = 'none'; }} />
                                </Box>
                            )}

                            <Box mb={3}>
                                <Typography variant="subtitle2" fontWeight={600} gutterBottom color="text.primary">
                                    {t('post.dialog.content')}
                                </Typography>
                                <Paper variant="outlined" sx={{ p: 2.5, bgcolor: 'action.hover', borderColor: 'divider', borderRadius: 2 }}>
                                    <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                                        {selectedPost.content || t('post.dialog.noContentProvided')}
                                    </Typography>
                                </Paper>
                            </Box>

                            <Divider sx={{ mb: 3, borderColor: 'divider' }} />

                            <Grid container spacing={2}>
                                <Grid item xs={12} sm={6}>
                                    <Typography variant="subtitle2" fontWeight={600} gutterBottom color="text.primary">
                                        {t('post.dialog.engagement')}
                                    </Typography>
                                    <Stack direction="row" spacing={3}>
                                        <Box display="flex" alignItems="center" gap={1}>
                                            <FavoriteIcon sx={{ color: 'error.main' }} />
                                            <Box>
                                                <Typography variant="h6" sx={{ fontWeight: 700, lineHeight: 1 }}>
                                                    {selectedPost.likes_count || 0}
                                                </Typography>
                                                <Typography variant="caption" color="text.secondary">
                                                    {t('post.dialog.likes')}
                                                </Typography>
                                            </Box>
                                        </Box>
                                        <Box display="flex" alignItems="center" gap={1}>
                                            <CommentIcon sx={{ color: colors.sea || '#0f766e' }} />
                                            <Box>
                                                <Typography variant="h6" sx={{ fontWeight: 700, lineHeight: 1 }}>
                                                    {selectedPost.comments_count || 0}
                                                </Typography>
                                                <Typography variant="caption" color="text.secondary">
                                                    {t('post.dialog.comments')}
                                                </Typography>
                                            </Box>
                                        </Box>
                                    </Stack>
                                </Grid>
                                {selectedPost.technician?.area && (
                                    <Grid item xs={12} sm={6}>
                                        <Typography variant="subtitle2" fontWeight={600} gutterBottom color="text.primary">
                                            {t('post.dialog.technicianInfo')}
                                        </Typography>
                                        <Box display="flex" alignItems="center" gap={1}>
                                            <LocationIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                                            <Typography variant="body2">{selectedPost.technician.area}</Typography>
                                        </Box>
                                        {selectedPost.technician?.rating > 0 && (
                                            <Box display="flex" alignItems="center" gap={0.5} mt={0.5}>
                                                <StarIcon sx={{ color: 'warning.main', fontSize: 16 }} />
                                                <Typography variant="body2" fontWeight={500}>
                                                    {selectedPost.technician.rating.toFixed(1)}
                                                </Typography>
                                            </Box>
                                        )}
                                    </Grid>
                                )}
                            </Grid>

                            {selectedPost.comments && selectedPost.comments.length > 0 && (
                                <>
                                    <Divider sx={{ my: 3, borderColor: 'divider' }} />
                                    <Box>
                                        <Typography variant="subtitle2" fontWeight={600} gutterBottom color="text.primary">
                                            {t('post.dialog.commentsCount', { n: selectedPost.comments.length })}
                                        </Typography>
                                        <Stack spacing={2}>
                                            {selectedPost.comments.map((comment, idx) => (
                                                <Paper key={idx} variant="outlined" sx={{
                                                    p: 2, borderColor: 'divider', borderRadius: 2, bgcolor: 'action.hover',
                                                }}>
                                                    <Box display="flex" alignItems="flex-start" gap={1.5}>
                                                        <Avatar
                                                            src={comment.user?.profile_photo ? getImageUrl(comment.user.profile_photo) : undefined}
                                                            sx={{
                                                                width: 32, height: 32,
                                                                bgcolor: colors.sea || '#0f766e',
                                                                fontSize: 12, fontWeight: 600,
                                                            }}
                                                        >
                                                            {getInitials(comment.user?.name || comment.name)}
                                                        </Avatar>
                                                        <Box flex={1}>
                                                            <Box display="flex" alignItems="center" gap={1.5}>
                                                                <Typography variant="body2" fontWeight={600}>
                                                                    {comment.user?.name || comment.name || t('post.common.unknown')}
                                                                </Typography>
                                                                <Typography variant="caption" color="text.secondary">
                                                                    {formatDateFull(comment.created_at)}
                                                                </Typography>
                                                            </Box>
                                                            <Typography variant="body2" sx={{ mt: 0.5 }}>
                                                                {comment.content || comment.comment}
                                                            </Typography>
                                                        </Box>
                                                    </Box>
                                                </Paper>
                                            ))}
                                        </Stack>
                                    </Box>
                                </>
                            )}
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
                                {t('post.common.close')}
                            </Button>
                        </DialogActions>
                    </>
                )}
            </Dialog>

            {/* CONFIRMATION DIALOG */}
            <Dialog
                open={confirmDialog.open}
                onClose={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                fullWidth maxWidth="xs"
                PaperProps={{ sx: { borderRadius: 3, bgcolor: 'background.paper' } }}
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
                        {t('post.common.cancel')}
                    </Button>
                    <Button
                        onClick={handleConfirm}
                        variant="contained" color="error"
                        sx={{ fontWeight: 700, textTransform: 'none', borderRadius: 2 }}
                    >
                        {t('post.common.confirm')}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default PostsList;