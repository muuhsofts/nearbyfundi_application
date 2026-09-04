// src/pages/categories/CategoriesList.js
import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Button,
    TextField,
    InputAdornment,
    IconButton,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TablePagination,
    TableSortLabel,
    CircularProgress,
    Alert,
    Chip,
    Stack,
    Card,
    CardContent,
    Grid,
    useMediaQuery,
    useTheme,
    alpha,
} from '@mui/material';
import {
    Add as AddIcon,
    Search as SearchIcon,
    Refresh as RefreshIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Clear as ClearIcon,
    Category as CategoryIcon,
    Label as LabelIcon,
    Description as DescriptionIcon,
} from '@mui/icons-material';
import { serviceService } from 'services/service.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import CategoryFormModal from './CategoryFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'id', label: '#', disableSort: true },
    { id: 'category_name', label: 'Category Name' },
    { id: 'swahili_name', label: 'Swahili Name' },
    { id: 'slug', label: 'Slug', disableSort: true },
    { id: 'services_count', label: 'Services' },
    { id: 'actions', label: 'Actions', disableSort: true },
];

const CategoriesList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const { can } = usePermissions();
    const canView = can('service-categories.view');
    const canCreate = can('service-categories.create');
    const canEdit = can('service-categories.update');
    const canDelete = can('service-categories.delete');

    const [categories, setCategories] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const [openModal, setOpenModal] = useState(false);
    const [editingCategory, setEditingCategory] = useState(null);

    const [search, setSearch] = useState('');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [total, setTotal] = useState(0);

    const [order, setOrder] = useState('asc');
    const [orderBy, setOrderBy] = useState('category_name');

    const [confirmDialog, setConfirmDialog] = useState({
        open: false,
        title: '',
        message: '',
        action: null,
    });

    const loadCategories = async () => {
        if (!canView) return;
        setLoading(true);
        setError(null);
        try {
            const response = await serviceService.getCategories({
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
            });
            if (response?.data?.status === 'success') {
                const data = response.data.data;
                setCategories(data.data || []);
                setTotal(data.pagination?.total || 0);
            } else {
                setCategories([]);
                setTotal(0);
            }
        } catch (err) {
            console.error('Categories error:', err);
            setError(err.message || 'Failed to load categories');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canView) loadCategories();
    }, [page, rowsPerPage, search, canView]);

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    const sortedCategories = [...categories].sort((a, b) => {
        let aValue = a[orderBy] || '';
        let bValue = b[orderBy] || '';
        if (typeof aValue === 'string') {
            aValue = aValue.toLowerCase();
            bValue = bValue.toLowerCase();
        }
        if (aValue < bValue) return order === 'asc' ? -1 : 1;
        if (aValue > bValue) return order === 'asc' ? 1 : -1;
        return 0;
    });

    const handleDelete = async (id, name) => {
        setConfirmDialog({
            open: true,
            title: 'Delete Category',
            message: `Are you sure you want to delete "${name}"? This will not delete its associated services, but will remove the assignment.`,
            action: async () => {
                try {
                    await serviceService.deleteCategory(id);
                    showSnackbar({ type: 'success', message: 'Category deleted successfully' });
                    loadCategories();
                } catch (err) {
                    const msg = err.response?.data?.message || 'Failed to delete category';
                    showSnackbar({ type: 'error', message: msg });
                }
                setConfirmDialog(prev => ({ ...prev, open: false }));
            }
        });
    };

    const handleConfirm = () => {
        if (confirmDialog.action) confirmDialog.action();
    };

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
                        You do not have permission to view categories.
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
                        <Button color="inherit" size="small" onClick={() => { setError(null); loadCategories(); }}>
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
                                Service Categories
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                Manage service categories and their translations
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} alignItems="center" justifyContent={{ xs: 'space-between', sm: 'flex-end' }}>
                            {canCreate && (
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => { setEditingCategory(null); setOpenModal(true); }}
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
                                    Add Category
                                </Button>
                            )}
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
                            placeholder="Search categories..."
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

                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={loadCategories}
                            disabled={loading}
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
                </Box>

                {/* ── SUMMARY CARDS ────────────────────────────────────── */}
                <Box sx={{ px: { xs: 2, sm: 3 }, pt: 2.5, pb: 1 }}>
                    <Grid container spacing={2}>
                        {[
                            { label: 'Total Categories', value: total, color: '#8b5cf6', bg: '#f3e8ff', icon: <CategoryIcon sx={{ fontSize: 18 }} /> },
                            { label: 'With Services', value: categories.filter(c => c.services_count > 0).length, color: '#10b981', bg: '#ecfdf5', icon: <LabelIcon sx={{ fontSize: 18 }} /> },
                            { label: 'Translated', value: categories.filter(c => c.swahili_name).length, color: '#3b82f6', bg: '#eff6ff', icon: <DescriptionIcon sx={{ fontSize: 18 }} /> },
                        ].map((item, idx) => (
                            <Grid item xs={6} sm={4} key={idx}>
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
                        <Table sx={{ minWidth: 700 }}>
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
                                ) : sortedCategories.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                            <Typography color="text.secondary" fontWeight={500}>
                                                {search ? 'No categories match your search' : 'No categories found'}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sortedCategories.map((cat, index) => {
                                        const rowNumber = page * rowsPerPage + index + 1;
                                        return (
                                            <TableRow
                                                key={cat.service_categoryID}
                                                hover
                                                sx={{
                                                    '&:last-child td': { borderBottom: 0 },
                                                    transition: 'background-color 0.15s',
                                                }}
                                            >
                                                <TableCell>
                                                    <Typography variant="body2" fontWeight={500} color="text.secondary">
                                                        {rowNumber}
                                                    </Typography>
                                                </TableCell>
                                                <TableCell>
                                                    <Typography variant="body2" fontWeight={600} color="text.primary">
                                                        {cat.category_name}
                                                    </Typography>
                                                    {cat.description && (
                                                        <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                                                            {cat.description}
                                                        </Typography>
                                                    )}
                                                </TableCell>
                                                <TableCell>
                                                    <Typography variant="body2" color="text.secondary">
                                                        {cat.swahili_name || '-'}
                                                    </Typography>
                                                </TableCell>
                                                <TableCell>
                                                    <Chip
                                                        label={cat.slug || '-'}
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 600,
                                                            bgcolor: 'action.hover',
                                                            fontSize: '0.7rem',
                                                            height: 24,
                                                        }}
                                                    />
                                                </TableCell>
                                                <TableCell>
                                                    <Chip
                                                        label={cat.services_count || 0}
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 700,
                                                            bgcolor: alpha(colors.sea, 0.08),
                                                            color: colors.sea,
                                                            minWidth: 36,
                                                        }}
                                                    />
                                                </TableCell>
                                                <TableCell align="center">
                                                    <Stack direction="row" spacing={0.5} justifyContent="center">
                                                        {canEdit && (
                                                            <IconButton
                                                                size="small"
                                                                onClick={() => { setEditingCategory(cat); setOpenModal(true); }}
                                                                sx={{
                                                                    color: 'text.secondary',
                                                                    '&:hover': {
                                                                        color: colors.sea,
                                                                        bgcolor: alpha(colors.sea, 0.08),
                                                                    },
                                                                }}
                                                            >
                                                                <EditIcon fontSize="small" />
                                                            </IconButton>
                                                        )}
                                                        {canDelete && (
                                                            <IconButton
                                                                size="small"
                                                                onClick={() => handleDelete(cat.service_categoryID, cat.category_name)}
                                                                sx={{
                                                                    color: 'text.secondary',
                                                                    '&:hover': {
                                                                        color: 'error.main',
                                                                        bgcolor: alpha('#ef4444', 0.08),
                                                                    },
                                                                }}
                                                            >
                                                                <DeleteIcon fontSize="small" />
                                                            </IconButton>
                                                        )}
                                                    </Stack>
                                                </TableCell>
                                            </TableRow>
                                        );
                                    })
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
                        ) : sortedCategories.length === 0 ? (
                            <Paper
                                variant="outlined"
                                sx={{
                                    p: 5,
                                    textAlign: 'center',
                                    borderRadius: 3,
                                    borderStyle: 'dashed',
                                }}
                            >
                                <CategoryIcon sx={{ fontSize: 56, color: 'text.disabled', mb: 2 }} />
                                <Typography color="text.secondary" fontWeight={500}>
                                    {search ? 'No categories match your search' : 'No categories found'}
                                </Typography>
                            </Paper>
                        ) : (
                            <Stack spacing={2}>
                                {sortedCategories.map((cat) => (
                                    <Card
                                        key={cat.service_categoryID}
                                        elevation={0}
                                        sx={{
                                            borderRadius: 3,
                                            border: '1px solid',
                                            borderColor: 'divider',
                                            overflow: 'hidden',
                                        }}
                                    >
                                        <CardContent sx={{ p: 2.5 }}>
                                            <Stack direction="row" justifyContent="space-between" alignItems="flex-start" mb={1.5}>
                                                <Box>
                                                    <Typography variant="h6" fontWeight={700} color="text.primary">
                                                        {cat.category_name}
                                                    </Typography>
                                                    {cat.swahili_name && (
                                                        <Typography variant="body2" color="text.secondary">
                                                            {cat.swahili_name}
                                                        </Typography>
                                                    )}
                                                </Box>
                                                <Stack direction="row" spacing={0.5}>
                                                    {canEdit && (
                                                        <IconButton
                                                            size="small"
                                                            onClick={() => { setEditingCategory(cat); setOpenModal(true); }}
                                                            sx={{ color: 'text.secondary' }}
                                                        >
                                                            <EditIcon fontSize="small" />
                                                        </IconButton>
                                                    )}
                                                    {canDelete && (
                                                        <IconButton
                                                            size="small"
                                                            onClick={() => handleDelete(cat.service_categoryID, cat.category_name)}
                                                            sx={{ color: 'text.secondary' }}
                                                        >
                                                            <DeleteIcon fontSize="small" />
                                                        </IconButton>
                                                    )}
                                                </Stack>
                                            </Stack>

                                            {cat.description && (
                                                <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                                                    {cat.description}
                                                </Typography>
                                            )}

                                            <Stack direction="row" spacing={1.5} alignItems="center">
                                                <Chip
                                                    label={`Slug: ${cat.slug || '-'}`}
                                                    size="small"
                                                    sx={{
                                                        fontWeight: 600,
                                                        bgcolor: 'action.hover',
                                                        fontSize: '0.7rem',
                                                        height: 24,
                                                    }}
                                                />
                                                <Chip
                                                    label={`${cat.services_count || 0} service${cat.services_count !== 1 ? 's' : ''}`}
                                                    size="small"
                                                    sx={{
                                                        fontWeight: 700,
                                                        bgcolor: alpha(colors.sea, 0.08),
                                                        color: colors.sea,
                                                    }}
                                                />
                                            </Stack>
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
                                fontWeight: 500,
                            },
                        }}
                    />
                </Box>
            </Paper>

            {/* ─── CATEGORY FORM MODAL ──────────────────────────────────── */}
            <CategoryFormModal
                open={openModal}
                onClose={() => { setOpenModal(false); setEditingCategory(null); loadCategories(); }}
                category={editingCategory}
            />

            {/* ─── CONFIRMATION DIALOG ─────────────────────────────────── */}
            <Dialog
                open={confirmDialog.open}
                onClose={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                fullWidth
                maxWidth="xs"
                PaperProps={{
                    sx: {
                        borderRadius: 3,
                    },
                }}
            >
                <DialogTitle sx={{ fontWeight: 700, pb: 1, color: 'text.primary' }}>
                    {confirmDialog.title}
                </DialogTitle>
                <DialogContent>
                    <Typography color="text.secondary">{confirmDialog.message}</Typography>
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2.5, pt: 1 }}>
                    <Button
                        onClick={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
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
                        Delete
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default CategoriesList;