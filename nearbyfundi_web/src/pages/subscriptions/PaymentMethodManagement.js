import React, { useState } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell, TableContainer,
    TableHead, TableRow, IconButton, Dialog, DialogTitle, DialogContent,
    DialogActions, TextField, Switch, FormControlLabel, CircularProgress,
    Alert, Chip, Avatar, Grid, Card, CardContent, Tooltip,
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Refresh as RefreshIcon,
    Phone as PhoneIcon,
    AccountCircle as AccountIcon,
    CheckCircle as ActiveIcon,
    Cancel as InactiveIcon,
    Warning as WarningIcon,
} from '@mui/icons-material';
import { usePermissions } from 'hooks/usePermissions';
import { usePaymentMethodForm } from 'hooks/usePaymentMethodForm';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const PaymentMethodManagement = () => {
    const { can } = usePermissions();
    const canManage = can('subscriptions.manage');

    const {
        paymentMethods,
        loading,
        error,
        openModal,
        editing,
        form,
        file,
        openCreate,
        openEdit,
        closeModal,
        handleChange,
        handleFileChange,
        handleSave,
        handleDelete,
        refresh,
    } = usePaymentMethodForm();

    const [search, setSearch] = useState('');

    // Delete confirmation dialog state
    const [deleteDialog, setDeleteDialog] = useState({
        open: false,
        methodId: null,
        methodName: '',
        deleting: false,
    });

    if (!canManage) {
        return <Box p={3}><Alert severity="error">You need permission to manage payment methods.</Alert></Box>;
    }

    // Filter payment methods by search
    const filteredMethods = paymentMethods.filter(method =>
        method.name?.toLowerCase().includes(search.toLowerCase()) ||
        method.account_name?.toLowerCase().includes(search.toLowerCase()) ||
        method.phone_number?.includes(search)
    );

    // Stats
    const stats = {
        total: paymentMethods.length,
        active: paymentMethods.filter(m => m.is_active).length,
        inactive: paymentMethods.filter(m => !m.is_active).length,
    };

    // Open delete confirmation dialog
    const openDeleteDialog = (methodId, methodName) => {
        setDeleteDialog({
            open: true,
            methodId,
            methodName,
            deleting: false,
        });
    };

    // Close delete confirmation dialog
    const closeDeleteDialog = () => {
        setDeleteDialog({
            open: false,
            methodId: null,
            methodName: '',
            deleting: false,
        });
    };

    // Confirm delete
    const confirmDelete = async () => {
        setDeleteDialog(prev => ({ ...prev, deleting: true }));
        try {
            await handleDelete(deleteDialog.methodId);
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
                            <Typography variant="caption" color="textSecondary">Total Methods</Typography>
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
                            Payment Methods
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
                                    <TableCell sx={{ fontWeight: 'bold' }}>Logo</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Name</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Phone</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Account</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Status</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }}>Order</TableCell>
                                    <TableCell sx={{ fontWeight: 'bold' }} align="right">Actions</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {filteredMethods.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center" sx={{ py: 4 }}>
                                            <Typography color="textSecondary">
                                                {search ? 'No payment methods match your search' : 'No payment methods found'}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    filteredMethods.map(method => (
                                        <TableRow key={method.id} hover>
                                            <TableCell>
                                                {method.logo ? (
                                                    <Avatar src={method.logo} sx={{ width: 40, height: 40 }} />
                                                ) : (
                                                    <Avatar sx={{ width: 40, height: 40, bgcolor: colors.sky }}>
                                                        <PhoneIcon sx={{ color: colors.dark }} />
                                                    </Avatar>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Typography fontWeight="500">{method.name}</Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Box display="flex" alignItems="center" gap={0.5}>
                                                    <PhoneIcon sx={{ fontSize: 14, color: 'text.secondary' }} />
                                                    <Typography>{method.phone_number}</Typography>
                                                </Box>
                                            </TableCell>
                                            <TableCell>
                                                {method.account_name || (
                                                    <Typography variant="caption" color="textSecondary">-</Typography>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={method.is_active ? 'Active' : 'Inactive'}
                                                    color={method.is_active ? 'success' : 'default'}
                                                    size="small"
                                                    icon={method.is_active ? <ActiveIcon /> : <InactiveIcon />}
                                                />
                                            </TableCell>
                                            <TableCell>{method.display_order}</TableCell>
                                            <TableCell align="right">
                                                <Tooltip title="Edit">
                                                    <IconButton size="small" onClick={() => openEdit(method)}>
                                                        <EditIcon />
                                                    </IconButton>
                                                </Tooltip>
                                                <Tooltip title="Delete">
                                                    <IconButton
                                                        size="small"
                                                        color="error"
                                                        onClick={() => openDeleteDialog(method.id, method.name)}
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
                        {editing ? 'Edit Payment Method' : 'Create New Payment Method'}
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
                        <Grid item xs={12}>
                            <TextField
                                label="Phone Number *"
                                fullWidth
                                value={form.phone_number || ''}
                                onChange={(e) => handleChange('phone_number', e.target.value)}
                                required
                            />
                        </Grid>
                        <Grid item xs={12}>
                            <TextField
                                label="Account Name"
                                fullWidth
                                value={form.account_name || ''}
                                onChange={(e) => handleChange('account_name', e.target.value)}
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
                        <Grid item xs={12}>
                            <Button
                                variant="outlined"
                                component="label"
                                sx={{ mt: 1 }}
                                startIcon={file ? null : <AddIcon />}
                            >
                                {file ? file.name : 'Upload Logo'}
                                <input
                                    type="file"
                                    hidden
                                    accept="image/*"
                                    onChange={(e) => handleFileChange(e.target.files[0])}
                                />
                            </Button>
                            {file && (
                                <Typography variant="caption" sx={{ ml: 2, color: 'success.main' }}>
                                    ✓ {file.name} selected
                                </Typography>
                            )}
                        </Grid>
                    </Grid>
                </DialogContent>
                <DialogActions sx={{ p: 2, borderTop: `1px solid ${colors.middle}` }}>
                    <Button onClick={closeModal}>Cancel</Button>
                    <Button
                        onClick={handleSave}
                        variant="contained"
                        color="primary"
                        disabled={!form.name || !form.phone_number}
                    >
                        {editing ? 'Update' : 'Create'}
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Delete Confirmation Dialog */}
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
                        Delete Payment Method
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
                            You are about to delete the payment method:
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
                            "{deleteDialog.methodName}"
                        </Typography>
                        <Typography variant="body2" color="textSecondary" sx={{ mt: 2 }}>
                            This action cannot be undone.
                            <span style={{ display: 'block', marginTop: 8, color: '#991b1b', fontWeight: 500 }}>
                                ⚠️ All data related to this payment method will be permanently removed.
                            </span>
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

export default PaymentMethodManagement;