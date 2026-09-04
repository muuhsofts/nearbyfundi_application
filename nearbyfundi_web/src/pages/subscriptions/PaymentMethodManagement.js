// src/pages/subscriptions/PaymentMethodManagement.jsx
import React, { useState } from 'react';
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
    IconButton,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Switch,
    FormControlLabel,
    CircularProgress,
    Alert,
    Chip,
    Avatar,
    Grid,
    Card,
    CardContent,
    Tooltip,
    Stack,
    InputAdornment,
    Divider,
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Refresh as RefreshIcon,
    Phone as PhoneIcon,
    CheckCircle as ActiveIcon,
    Cancel as InactiveIcon,
    Warning as WarningIcon,
    Clear as ClearIcon,
    Close as CloseIcon,
    Search as SearchIcon,
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

    const [deleteDialog, setDeleteDialog] = useState({
        open: false,
        methodId: null,
        methodName: '',
        deleting: false,
    });

    if (!canManage) {
        return (
            <Box p={3}>
                <Alert severity="error" variant="filled" sx={{ borderRadius: 2 }}>
                    You need permission to manage payment methods.
                </Alert>
            </Box>
        );
    }

    const filteredMethods = paymentMethods.filter(
        (method) =>
            method.name?.toLowerCase().includes(search.toLowerCase()) ||
            method.account_name?.toLowerCase().includes(search.toLowerCase()) ||
            method.phone_number?.includes(search)
    );

    const stats = {
        total: paymentMethods.length,
        active: paymentMethods.filter((m) => m.is_active).length,
        inactive: paymentMethods.filter((m) => !m.is_active).length,
    };

    const openDeleteDialog = (methodId, methodName) => {
        setDeleteDialog({ open: true, methodId, methodName, deleting: false });
    };

    const closeDeleteDialog = () => {
        setDeleteDialog({ open: false, methodId: null, methodName: '', deleting: false });
    };

    const confirmDelete = async () => {
        setDeleteDialog((prev) => ({ ...prev, deleting: true }));
        try {
            await handleDelete(deleteDialog.methodId);
            closeDeleteDialog();
        } catch (error) {
            setDeleteDialog((prev) => ({ ...prev, deleting: false }));
        }
    };

    return (
        <Box sx={{ width: '100%', p: { xs: 1.5, sm: 2.5 }, bgcolor: 'background.default' }}>
            {/* Stats Cards */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                <Grid item xs={4}>
                    <Card
                        elevation={0}
                        sx={{
                            borderRadius: 3,
                            border: '1px solid',
                            borderColor: 'divider',
                            background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)',
                            height: '100%',
                        }}
                    >
                        <CardContent sx={{ p: 2.25 }}>
                            <Typography variant="overline" fontWeight={700} color="text.secondary" letterSpacing={1}>
                                Total Methods
                            </Typography>
                            <Typography variant="h4" fontWeight={800} color="#0369a1" sx={{ mt: 0.5, lineHeight: 1.1 }}>
                                {stats.total}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={4}>
                    <Card
                        elevation={0}
                        sx={{
                            borderRadius: 3,
                            border: '1px solid',
                            borderColor: 'divider',
                            background: 'linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%)',
                            height: '100%',
                        }}
                    >
                        <CardContent sx={{ p: 2.25 }}>
                            <Typography variant="overline" fontWeight={700} color="text.secondary" letterSpacing={1}>
                                Active
                            </Typography>
                            <Typography variant="h4" fontWeight={800} color="#047857" sx={{ mt: 0.5, lineHeight: 1.1 }}>
                                {stats.active}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={4}>
                    <Card
                        elevation={0}
                        sx={{
                            borderRadius: 3,
                            border: '1px solid',
                            borderColor: 'divider',
                            background: 'linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%)',
                            height: '100%',
                        }}
                    >
                        <CardContent sx={{ p: 2.25 }}>
                            <Typography variant="overline" fontWeight={700} color="text.secondary" letterSpacing={1}>
                                Inactive
                            </Typography>
                            <Typography variant="h4" fontWeight={800} color="#b91c1c" sx={{ mt: 0.5, lineHeight: 1.1 }}>
                                {stats.inactive}
                            </Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* Main Panel */}
            <Paper
                elevation={0}
                sx={{
                    borderRadius: 3,
                    overflow: 'hidden',
                    border: '1px solid',
                    borderColor: 'divider',
                    bgcolor: 'background.paper',
                }}
            >
                {/* Header */}
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
                    >
                        <Box>
                            <Typography variant="h5" fontWeight={800} color="text.primary">
                                Payment Methods
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                Manage payment options available to users
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} alignItems="center" flexWrap="wrap">
                            <TextField
                                placeholder="Search methods…"
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
                                    minWidth: { xs: '100%', sm: 220 },
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
                                variant="contained"
                                startIcon={<AddIcon />}
                                onClick={openCreate}
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
                                Add Method
                            </Button>
                            <IconButton
                                onClick={refresh}
                                sx={{
                                    border: '1px solid',
                                    borderColor: 'divider',
                                    borderRadius: 2,
                                    color: 'text.secondary',
                                    '&:hover': { bgcolor: 'action.hover', color: 'text.primary' },
                                }}
                            >
                                <RefreshIcon />
                            </IconButton>
                        </Stack>
                    </Stack>
                </Box>

                {/* Table */}
                {loading ? (
                    <Box sx={{ py: 8, textAlign: 'center' }}>
                        <CircularProgress size={36} thickness={4} />
                    </Box>
                ) : error ? (
                    <Box sx={{ p: 3 }}>
                        <Alert severity="error" variant="filled" sx={{ borderRadius: 2 }}>
                            {error}
                        </Alert>
                    </Box>
                ) : (
                    <TableContainer>
                        <Table>
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
                                    <TableCell>Logo</TableCell>
                                    <TableCell>Name</TableCell>
                                    <TableCell>Phone</TableCell>
                                    <TableCell>Account</TableCell>
                                    <TableCell>Status</TableCell>
                                    <TableCell>Order</TableCell>
                                    <TableCell align="right">Actions</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {filteredMethods.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center" sx={{ py: 8 }}>
                                            <Typography color="text.secondary" fontWeight={500}>
                                                {search
                                                    ? 'No payment methods match your search'
                                                    : 'No payment methods found'}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    filteredMethods.map((method) => (
                                        <TableRow
                                            key={method.id}
                                            hover
                                            sx={{
                                                '&:last-child td': { borderBottom: 0 },
                                                transition: 'background-color 0.15s',
                                            }}
                                        >
                                            <TableCell sx={{ py: 1.5 }}>
                                                {method.logo ? (
                                                    <Avatar
                                                        src={method.logo}
                                                        sx={{ width: 42, height: 42, borderRadius: 2 }}
                                                    />
                                                ) : (
                                                    <Avatar
                                                        sx={{
                                                            width: 42,
                                                            height: 42,
                                                            borderRadius: 2,
                                                            bgcolor: 'action.hover',
                                                        }}
                                                    >
                                                        <PhoneIcon sx={{ color: 'text.secondary' }} />
                                                    </Avatar>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontWeight={600}>
                                                    {method.name}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Stack direction="row" spacing={0.75} alignItems="center">
                                                    <PhoneIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                                                    <Typography variant="body2" fontWeight={500}>
                                                        {method.phone_number}
                                                    </Typography>
                                                </Stack>
                                            </TableCell>
                                            <TableCell>
                                                {method.account_name ? (
                                                    <Typography variant="body2" fontWeight={500}>
                                                        {method.account_name}
                                                    </Typography>
                                                ) : (
                                                    <Typography variant="caption" color="text.secondary">
                                                        —
                                                    </Typography>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                {method.is_active ? (
                                                    <Chip
                                                        icon={<ActiveIcon sx={{ fontSize: 16 }} />}
                                                        label="Active"
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 700,
                                                            bgcolor: '#d1fae5',
                                                            color: '#047857',
                                                            border: '1.5px solid #10b981',
                                                            height: 28,
                                                            '& .MuiChip-icon': { color: '#047857' },
                                                        }}
                                                    />
                                                ) : (
                                                    <Chip
                                                        icon={<InactiveIcon sx={{ fontSize: 16 }} />}
                                                        label="Inactive"
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 700,
                                                            bgcolor: '#f3f4f6',
                                                            color: '#4b5563',
                                                            border: '1.5px solid #9ca3af',
                                                            height: 28,
                                                            '& .MuiChip-icon': { color: '#4b5563' },
                                                        }}
                                                    />
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontWeight={500}>
                                                    {method.display_order}
                                                </Typography>
                                            </TableCell>
                                            <TableCell align="right">
                                                <Tooltip title="Edit">
                                                    <IconButton
                                                        size="small"
                                                        onClick={() => openEdit(method)}
                                                        sx={{
                                                            color: 'text.secondary',
                                                            '&:hover': {
                                                                bgcolor: 'action.hover',
                                                                color: 'text.primary',
                                                            },
                                                        }}
                                                    >
                                                        <EditIcon fontSize="small" />
                                                    </IconButton>
                                                </Tooltip>
                                                <Tooltip title="Delete">
                                                    <IconButton
                                                        size="small"
                                                        color="error"
                                                        onClick={() => openDeleteDialog(method.id, method.name)}
                                                        sx={{
                                                            '&:hover': { bgcolor: 'error.lighter' },
                                                        }}
                                                    >
                                                        <DeleteIcon fontSize="small" />
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
            <Dialog
                open={openModal}
                onClose={closeModal}
                maxWidth="sm"
                fullWidth
                PaperProps={{ sx: { borderRadius: 3 } }}
            >
                <DialogTitle
                    sx={{
                        px: 3,
                        pt: 2.5,
                        pb: 1.5,
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'flex-start',
                    }}
                >
                    <Box>
                        <Typography variant="h6" fontWeight={800}>
                            {editing ? 'Edit Payment Method' : 'Create New Payment Method'}
                        </Typography>
                        <Typography variant="body2" color="text.secondary" fontWeight={500}>
                            {editing ? 'Update payment method details' : 'Add a new payment option'}
                        </Typography>
                    </Box>
                    <IconButton
                        onClick={closeModal}
                        size="small"
                        sx={{
                            color: 'text.secondary',
                            mt: -0.5,
                            '&:hover': { bgcolor: 'action.hover', color: 'text.primary' },
                        }}
                    >
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>

                <Divider />

                <DialogContent sx={{ px: 3, py: 2.5 }}>
                    <Stack spacing={2.25}>
                        <TextField
                            label="Name *"
                            fullWidth
                            size="small"
                            value={form.name || ''}
                            onChange={(e) => handleChange('name', e.target.value)}
                            required
                            sx={{
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
                            label="Phone Number *"
                            fullWidth
                            size="small"
                            value={form.phone_number || ''}
                            onChange={(e) => handleChange('phone_number', e.target.value)}
                            required
                            sx={{
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
                            label="Account Name"
                            fullWidth
                            size="small"
                            value={form.account_name || ''}
                            onChange={(e) => handleChange('account_name', e.target.value)}
                            sx={{
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
                            label="Display Order"
                            fullWidth
                            size="small"
                            type="number"
                            value={form.display_order || 0}
                            onChange={(e) => handleChange('display_order', parseInt(e.target.value) || 0)}
                            sx={{
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    bgcolor: 'action.hover',
                                    '& fieldset': { borderColor: 'transparent' },
                                    '&:hover fieldset': { borderColor: 'divider' },
                                    '&.Mui-focused fieldset': { borderColor: 'primary.main' },
                                },
                            }}
                        />
                        <FormControlLabel
                            control={
                                <Switch
                                    checked={form.is_active}
                                    onChange={(e) => handleChange('is_active', e.target.checked)}
                                    color="success"
                                />
                            }
                            label={<Typography fontWeight={600}>Active</Typography>}
                        />
                        <Box>
                            <Button
                                variant="outlined"
                                component="label"
                                startIcon={file ? null : <AddIcon />}
                                sx={{
                                    borderRadius: 2,
                                    fontWeight: 600,
                                    textTransform: 'none',
                                    borderColor: 'divider',
                                    color: 'text.primary',
                                    '&:hover': { borderColor: 'text.primary', bgcolor: 'action.hover' },
                                }}
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
                                <Typography
                                    variant="caption"
                                    sx={{ ml: 1.5, color: 'success.main', fontWeight: 600 }}
                                >
                                    ✓ {file.name} selected
                                </Typography>
                            )}
                        </Box>
                    </Stack>
                </DialogContent>

                <Divider />

                <DialogActions sx={{ px: 3, py: 2, gap: 1.5 }}>
                    <Button
                        onClick={closeModal}
                        sx={{ fontWeight: 600, textTransform: 'none', color: 'text.secondary' }}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleSave}
                        variant="contained"
                        disabled={!form.name || !form.phone_number}
                        sx={{
                            minWidth: 110,
                            borderRadius: 2,
                            fontWeight: 700,
                            textTransform: 'none',
                            boxShadow: 'none',
                            bgcolor: colors.sea || '#0f766e',
                            '&:hover': {
                                bgcolor: colors.dark || '#0d5c56',
                                boxShadow: '0 4px 12px rgba(15,118,110,0.35)',
                            },
                        }}
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
                PaperProps={{ sx: { borderRadius: 3 } }}
            >
                <DialogTitle
                    sx={{
                        bgcolor: '#fef2f2',
                        color: '#991b1b',
                        display: 'flex',
                        alignItems: 'center',
                        gap: 1.5,
                        py: 2,
                    }}
                >
                    <WarningIcon sx={{ color: '#ef4444' }} />
                    <Typography variant="h6" fontWeight={700} color="#991b1b">
                        Delete Payment Method
                    </Typography>
                </DialogTitle>
                <DialogContent sx={{ pt: 3 }}>
                    <Box sx={{ textAlign: 'center', py: 1 }}>
                        <Box
                            sx={{
                                width: 72,
                                height: 72,
                                borderRadius: '50%',
                                bgcolor: '#fef2f2',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                mx: 'auto',
                                mb: 2,
                            }}
                        >
                            <DeleteIcon sx={{ fontSize: 36, color: '#ef4444' }} />
                        </Box>
                        <Typography variant="h6" fontWeight={700} gutterBottom>
                            Are you sure?
                        </Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                            You are about to delete the payment method:
                        </Typography>
                        <Typography
                            variant="body1"
                            fontWeight={700}
                            sx={{
                                color: '#b91c1c',
                                bgcolor: '#fee2e2',
                                py: 1,
                                px: 2,
                                borderRadius: 2,
                                display: 'inline-block',
                                border: '1px solid #fecaca',
                            }}
                        >
                            "{deleteDialog.methodName}"
                        </Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
                            This action cannot be undone.
                            <Box
                                component="span"
                                sx={{ display: 'block', mt: 1, color: '#b91c1c', fontWeight: 600 }}
                            >
                                ⚠️ All data related to this payment method will be permanently removed.
                            </Box>
                        </Typography>
                    </Box>
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2.5, gap: 1.5 }}>
                    <Button
                        onClick={closeDeleteDialog}
                        disabled={deleteDialog.deleting}
                        sx={{ fontWeight: 600, textTransform: 'none' }}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={confirmDelete}
                        variant="contained"
                        color="error"
                        disabled={deleteDialog.deleting}
                        startIcon={
                            deleteDialog.deleting ? (
                                <CircularProgress size={16} color="inherit" />
                            ) : null
                        }
                        sx={{ fontWeight: 700, textTransform: 'none', borderRadius: 2 }}
                    >
                        {deleteDialog.deleting ? 'Deleting…' : 'Delete'}
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default PaymentMethodManagement;