// src/pages/categories/CategoriesList.js
import React, { useState, useEffect } from 'react';
import {
    Box, Paper, Typography, Button, TextField, InputAdornment,
    IconButton, Dialog, DialogTitle, DialogContent, DialogActions,
    Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
    TablePagination, CircularProgress, Alert, Chip,
} from '@mui/material';
import {
    Add as AddIcon, Search as SearchIcon, Refresh as RefreshIcon,
    Edit as EditIcon, Delete as DeleteIcon,
} from '@mui/icons-material';
import { serviceService } from 'services/service.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import CategoryFormModal from './CategoryFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const CategoriesList = () => {
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
                // ✅ The backend returns pagination.total inside data.pagination.total
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

    const handleDelete = async (id, name) => {
        setConfirmDialog({
            open: true,
            title: 'Delete Category',
            message: `Are you sure you want to delete "${name}"? This will not delete its associated services, but will remove the assignment.`,
            action: async () => {
                try {
                    await serviceService.deleteCategory(id);
                    showSnackbar({ type: 'success', message: 'Category deleted' });
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
                <Paper sx={{ p: 3, textAlign: 'center' }}>
                    <Typography color="error">You do not have permission to view categories.</Typography>
                </Paper>
            </Box>
        );
    }

    return (
        <Box sx={{ p: { xs: 1, sm: 2 } }}>
            <Paper sx={{ p: 2, borderRadius: 2, border: `1px solid ${colors.middle}` }}>
                <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" mb={2}>
                    <Typography variant="h5" fontWeight="600" color={colors.dark}>
                        Service Categories
                    </Typography>
                    {canCreate && (
                        <Button
                            variant="contained"
                            startIcon={<AddIcon />}
                            onClick={() => { setEditingCategory(null); setOpenModal(true); }}
                            sx={{ backgroundColor: colors.salat, '&:hover': { backgroundColor: colors.dark } }}
                        >
                            Add Category
                        </Button>
                    )}
                </Box>

                <Box display="flex" gap={2} mb={2} alignItems="center">
                    <TextField
                        label="Search Categories"
                        size="small"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        InputProps={{
                            startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>
                        }}
                        sx={{ minWidth: 250, flexGrow: 0 }}
                    />
                    <Button
                        variant="outlined"
                        startIcon={<RefreshIcon />}
                        onClick={loadCategories}
                        sx={{ borderColor: colors.middle, color: colors.sea }}
                    >
                        Refresh
                    </Button>
                </Box>

                {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

                <TableContainer>
                    <Table>
                        <TableHead sx={{ backgroundColor: colors.sky }}>
                            <TableRow>
                                <TableCell sx={{ fontWeight: 'bold', width: 60 }}>#</TableCell>
                                <TableCell sx={{ fontWeight: 'bold' }}>Category Name</TableCell>
                                <TableCell sx={{ fontWeight: 'bold' }}>Swahili Name</TableCell>
                                <TableCell sx={{ fontWeight: 'bold' }}>Slug</TableCell>
                                <TableCell sx={{ fontWeight: 'bold' }} align="center">Services</TableCell>
                                <TableCell sx={{ fontWeight: 'bold' }} align="center">Actions</TableCell>
                            </TableRow>
                        </TableHead>
                        <TableBody>
                            {loading ? (
                                <TableRow><TableCell colSpan={6} align="center"><CircularProgress /></TableCell></TableRow>
                            ) : categories.length === 0 ? (
                                <TableRow><TableCell colSpan={6} align="center">No categories found</TableCell></TableRow>
                            ) : (
                                categories.map((cat, index) => {
                                    // ✅ Compute sequential row number
                                    const rowNumber = page * rowsPerPage + index + 1;
                                    return (
                                        <TableRow key={cat.service_categoryID}>
                                            <TableCell>{rowNumber}</TableCell>
                                            <TableCell>{cat.category_name}</TableCell>
                                            <TableCell>{cat.swahili_name || '-'}</TableCell>
                                            <TableCell><Chip label={cat.slug} size="small" /></TableCell>
                                            <TableCell align="center">{cat.services_count || 0}</TableCell>
                                            <TableCell align="center">
                                                {canEdit && (
                                                    <IconButton size="small" onClick={() => { setEditingCategory(cat); setOpenModal(true); }}>
                                                        <EditIcon fontSize="small" />
                                                    </IconButton>
                                                )}
                                                {canDelete && (
                                                    <IconButton size="small" color="error" onClick={() => handleDelete(cat.service_categoryID, cat.category_name)}>
                                                        <DeleteIcon fontSize="small" />
                                                    </IconButton>
                                                )}
                                            </TableCell>
                                        </TableRow>
                                    );
                                })
                            )}
                        </TableBody>
                    </Table>
                </TableContainer>

                <TablePagination
                    rowsPerPageOptions={[5, 10, 25, 50]}
                    component="div"
                    count={total}
                    rowsPerPage={rowsPerPage}
                    page={page}
                    onPageChange={(e, newPage) => setPage(newPage)}
                    onRowsPerPageChange={(e) => { setRowsPerPage(parseInt(e.target.value, 10)); setPage(0); }}
                />
            </Paper>

            <CategoryFormModal
                open={openModal}
                onClose={() => { setOpenModal(false); setEditingCategory(null); loadCategories(); }}
                category={editingCategory}
            />

            <Dialog open={confirmDialog.open} onClose={() => setConfirmDialog(prev => ({ ...prev, open: false }))}>
                <DialogTitle>{confirmDialog.title}</DialogTitle>
                <DialogContent><Typography>{confirmDialog.message}</Typography></DialogContent>
                <DialogActions>
                    <Button onClick={() => setConfirmDialog(prev => ({ ...prev, open: false }))}>Cancel</Button>
                    <Button onClick={handleConfirm} color="error" variant="contained">Delete</Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default CategoriesList;