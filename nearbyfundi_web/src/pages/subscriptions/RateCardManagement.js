import React, { useState } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell, TableContainer,
    TableHead, TableRow, IconButton, Dialog, DialogTitle, DialogContent,
    DialogActions, TextField, Switch, FormControlLabel, CircularProgress,
    Alert, Chip, Grid, Card, CardContent, Tooltip, Avatar,
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Refresh as RefreshIcon,
    AttachMoney as MoneyIcon,
    CalendarToday as CalendarIcon,
    CurrencyExchange as CurrencyIcon,
    CheckCircle as ActiveIcon,
    Cancel as InactiveIcon,
    Warning as WarningIcon,
} from '@mui/icons-material';
import { usePermissions } from 'hooks/usePermissions';
import { useRateCardForm } from 'hooks/useRateCardForm';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const RateCardManagement = () => {
    const { can } = usePermissions();
    const canManage = can('subscriptions.manage');

    const {
        rateCards,
        loading,
        error,
        openModal,
        editing,
        form,
        openCreate,
        openEdit,
        closeModal,
        handleChange,
        handleSave,
        handleDelete,
        refresh,
    } = useRateCardForm();

    const [search, setSearch] = useState('');

    // Delete confirmation dialog state
    const [deleteDialog, setDeleteDialog] = useState({
        open: false,
        cardId: null,
        cardName: '',
        deleting: false,
    });

    if (!canManage) {
        return <Box p={3}><Alert severity="error">You need permission to manage rate cards.</Alert></Box>;
    }

    // Filter rate cards by search
    const filteredCards = rateCards.filter(card =>
        card.name?.toLowerCase().includes(search.toLowerCase()) ||
        card.description?.toLowerCase().includes(search.toLowerCase())
    );

    // Stats
    const stats = {
        total: rateCards.length,
        active: rateCards.filter(c => c.is_active).length,
        inactive: rateCards.filter(c => !c.is_active).length,
    };

    // Open delete confirmation dialog
    const openDeleteDialog = (cardId, cardName) => {
        setDeleteDialog({
            open: true,
            cardId,
            cardName,
            deleting: false,
        });
    };

    // Close delete confirmation dialog
    const closeDeleteDialog = () => {
        setDeleteDialog({
            open: false,
            cardId: null,
            cardName: '',
            deleting: false,
        });
    };

    // Confirm delete
    const confirmDelete = async () => {
        setDeleteDialog(prev => ({ ...prev, deleting: true }));
        try {
            await handleDelete(deleteDialog.cardId);
            closeDeleteDialog();
        } catch (error) {
            setDeleteDialog(prev => ({ ...prev, deleting: false }));
        }
    };

    return (
        <Box p={{ xs: 1, sm: 2 }}>
            {/* Stats Cards */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid item xs={4}>
                    <Card sx={{ borderLeft: '4px solid #3b82f6', bgcolor: '#eff6ff' }}>
                        <CardContent>
                            <Typography variant="caption" color="textSecondary">Total Rate Cards</Typography>
                            <Typography variant="h5" fontWeight="600" color="#1e40af">{stats.total}</Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={4}>
                    <Card sx={{ borderLeft: '4px solid #10b981', bgcolor: '#ecfdf5' }}>
                        <CardContent>
                            <Typography variant="caption" color="textSecondary">Active</Typography>
                            <Typography variant="h5" fontWeight="600" color="#065f46">{stats.active}</Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={4}>
                    <Card sx={{ borderLeft: '4px solid #ef4444', bgcolor: '#fef2f2' }}>
                        <CardContent>
                            <Typography variant="caption" color="textSecondary">Inactive</Typography>
                            <Typography variant="h5" fontWeight="600" color="#991b1b">{stats.inactive}</Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            <Paper sx={{ borderRadius: 2, overflow: 'hidden', border: `1px solid ${colors.middle}` }}>
                {/* Header */}
                <Box sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                    <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={2}>
                        <Typography variant="h5" fontWeight="600" sx={{ color: colors.dark }}>
                            Rate Cards
                        </Typography>
                        <Box display="flex" gap={1} flexWrap="wrap">
                            <TextField
                                placeholder="Search..."
                                size="small"
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                                sx={{ minWidth: 200 }}
                            />
                            <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
                                Add
                            </Button>
                            <IconButton onClick={refresh}><RefreshIcon /></IconButton>
                        </Box>
                    </Box>
                </Box>

                {/* Table */}
                {loading ? (
                    <Box sx={{ p: 4, textAlign: 'center' }}>
                        <CircularProgress />
                    </Box>
                ) : error ? (
                    <Box sx={{ p: 3 }}>
                        <Alert severity="error">{error}</Alert>
                    </Box>
                ) : (
                    <TableContainer>
                        <Table>
                            <TableHead sx={{ backgroundColor: colors.sky }}>
                                <TableRow>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Name</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Price</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Duration</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Currency</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Status</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Order</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }} align="right">Actions</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {filteredCards.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                                            <Typography color="textSecondary">
                                                {search ? 'No rate cards match your search' : 'No rate cards found'}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    filteredCards.map(card => (
                                        <TableRow key={card.id} hover>
                                            <TableCell>
                                                <Typography fontWeight="500">{card.name}</Typography>
                                                {card.description && (
                                                    <Typography variant="caption" color="textSecondary">
                                                        {card.description}
                                                    </Typography>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Typography fontWeight="600" color="#004472">
                                                    {card.price}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>{card.duration_days} days</TableCell>
                                            <TableCell>
                                                <Chip label={card.currency} size="small" variant="outlined" />
                                            </TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={card.is_active ? 'Active' : 'Inactive'}
                                                    color={card.is_active ? 'success' : 'default'}
                                                    size="small"
                                                    icon={card.is_active ? <ActiveIcon /> : <InactiveIcon />}
                                                />
                                            </TableCell>
                                            <TableCell>{card.display_order}</TableCell>
                                            <TableCell align="right">
                                                <Tooltip title="Edit">
                                                    <IconButton size="small" onClick={() => openEdit(card)}>
                                                        <EditIcon />
                                                    </IconButton>
                                                </Tooltip>
                                                <Tooltip title="Delete">
                                                    <IconButton
                                                        size="small"
                                                        color="error"
                                                        onClick={() => openDeleteDialog(card.id, card.name)}
                                                    >
                                                        <DeleteIcon />
                                                    </IconButton>
                                                </Tooltip>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                )}
            </Paper>

            {/* Form Modal */}
            <Dialog open={openModal} onClose={closeModal} maxWidth="sm" fullWidth>
                <DialogTitle sx={{ bgcolor: colors.sky }}>
                    <Typography variant="h6">
                        {editing ? 'Edit Rate Card' : 'Create New Rate Card'}
                    </Typography>
                </DialogTitle>
                <DialogContent sx={{ pt: 3 }}>
                    <Grid container spacing={2}>
                        <Grid item xs={12}>
                            <TextField
                                label="Name *"
                                fullWidth
                                value={form.name || ''}
                                onChange={(e) => handleChange('name', e.target.value)}
                                required
                            />
                        </Grid>
                        <Grid item xs={6}>
                            <TextField
                                label="Price *"
                                fullWidth
                                type="number"
                                value={form.price || ''}
                                onChange={(e) => handleChange('price', parseFloat(e.target.value) || 0)}
                                InputProps={{ startAdornment: <Typography>$</Typography> }}
                            />
                        </Grid>
                        <Grid item xs={6}>
                            <TextField
                                label="Currency *"
                                fullWidth
                                value={form.currency || 'TZS'}
                                onChange={(e) => handleChange('currency', e.target.value)}
                            />
                        </Grid>
                        <Grid item xs={12}>
                            <TextField
                                label="Duration (days) *"
                                fullWidth
                                type="number"
                                value={form.duration_days || 1}
                                onChange={(e) => handleChange('duration_days', parseInt(e.target.value) || 1)}
                            />
                        </Grid>
                        <Grid item xs={12}>
                            <TextField
                                label="Description"
                                fullWidth
                                multiline
                                rows={2}
                                value={form.description || ''}
                                onChange={(e) => handleChange('description', e.target.value)}
                            />
                        </Grid>
                        <Grid item xs={12}>
                            <TextField
                                label="Display Order"
                                fullWidth
                                type="number"
                                value={form.display_order || 0}
                                onChange={(e) => handleChange('display_order', parseInt(e.target.value) || 0)}
                            />
                        </Grid>
                        <Grid item xs={12}>
                            <FormControlLabel
                                control={
                                    <Switch
                                        checked={form.is_active}
                                        onChange={(e) => handleChange('is_active', e.target.checked)}
                                        color="success"
                                    />
                                }
                                label="Active"
                            />
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions sx={{ p: 2, borderTop: `1px solid ${colors.middle}` }}>
                    <Button onClick={closeModal}>Cancel</Button>
                    <Button
                        onClick={handleSave}
                        variant="contained"
                        color="primary"
                        disabled={!form.name || !form.price}
                    >
                        {editing ? 'Update' : 'Create'}
                    </Button>
                </DialogActions>
            </Dialog>

            {/* ========================================== */}
            {/* DELETE CONFIRMATION DIALOG */}
            {/* ========================================== */}
            <Dialog
                open={deleteDialog.open}
                onClose={closeDeleteDialog}
                maxWidth="xs"
                fullWidth
            >
                <DialogTitle sx={{
                    bgcolor: '#fef2f2',
                    color: '#991b1b',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 1,
                }}>
                    <WarningIcon sx={{ color: '#ef4444' }} />
                    <Typography variant="h6" fontWeight="600" color="#991b1b">
                        Delete Rate Card
                    </Typography>
                </DialogTitle>
                <DialogContent sx={{ pt: 3 }}>
                    <Box sx={{ textAlign: 'center', py: 2 }}>
                        <Box
                            sx={{
                                width: 80,
                                height: 80,
                                borderRadius: '50%',
                                bgcolor: '#fef2f2',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                mx: 'auto',
                                mb: 2,
                            }}
                        >
                            <DeleteIcon sx={{ fontSize: 40, color: '#ef4444' }} />
                        </Box>
                        <Typography variant="h6" fontWeight="600" gutterBottom>
                            Are you sure?
                        </Typography>
                        <Typography variant="body2" color="textSecondary" sx={{ mb: 1 }}>
                            You are about to delete the rate card:
                        </Typography>
                        <Typography
                            variant="body1"
                            fontWeight="600"
                            sx={{
                                color: '#991b1b',
                                bgcolor: '#fef2f2',
                                py: 1,
                                px: 2,
                                borderRadius: 1,
                                display: 'inline-block',
                            }}
                        >
                            "{deleteDialog.cardName}"
                        </Typography>
                        <Typography variant="body2" color="textSecondary" sx={{ mt: 2 }}>
                            This action cannot be undone.
                            {deleteDialog.cardName && (
                                <span style={{ display: 'block', marginTop: 8, color: '#991b1b', fontWeight: 500 }}>
                                    ⚠️ All data related to this rate card will be permanently removed.
                                </span>
                            )}
                        </Typography>
                    </Box>
                </DialogContent>
                <DialogActions sx={{ p: 2, borderTop: `1px solid ${colors.middle}` }}>
                    <Button
                        onClick={closeDeleteDialog}
                        disabled={deleteDialog.deleting}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={confirmDelete}
                        variant="contained"
                        color="error"
                        disabled={deleteDialog.deleting}
                        startIcon={deleteDialog.deleting ? <CircularProgress size={16} color="inherit" /> : null}
                    >
                        {deleteDialog.deleting ? 'Deleting...' : 'Delete'}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default RateCardManagement;