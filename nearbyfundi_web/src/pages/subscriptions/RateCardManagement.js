// src/pages/subscriptions/RateCardManagement.jsx
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
    CheckCircle as ActiveIcon,
    Cancel as InactiveIcon,
    Warning as WarningIcon,
    Clear as ClearIcon,
    Close as CloseIcon,
    Search as SearchIcon,
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

    const [deleteDialog, setDeleteDialog] = useState({
        open: false,
        cardId: null,
        cardName: '',
        deleting: false,
    });

    if (!canManage) {
        return (
            <Box p={3}>
                <Alert severity="error" variant="filled" sx={{ borderRadius: 2 }}>
                    You need permission to manage rate cards.
                </Alert>
            </Box>
        );
    }

    const filteredCards = rateCards.filter(
        (card) =>
            card.name?.toLowerCase().includes(search.toLowerCase()) ||
            card.description?.toLowerCase().includes(search.toLowerCase())
    );

    const stats = {
        total: rateCards.length,
        active: rateCards.filter((c) => c.is_active).length,
        inactive: rateCards.filter((c) => !c.is_active).length,
    };

    const openDeleteDialog = (cardId, cardName) => {
        setDeleteDialog({ open: true, cardId, cardName, deleting: false });
    };

    const closeDeleteDialog = () => {
        setDeleteDialog({ open: false, cardId: null, cardName: '', deleting: false });
    };

    const confirmDelete = async () => {
        setDeleteDialog((prev) => ({ ...prev, deleting: true }));
        try {
            await handleDelete(deleteDialog.cardId);
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
                                Total Rate Cards
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
                                Rate Cards
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                Manage subscription plans and pricing
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} alignItems="center" flexWrap="wrap">
                            <TextField
                                placeholder="Search rate cards…"
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
                                Add Rate Card
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
                                    <TableCell>Name</TableCell>
                                    <TableCell>Price</TableCell>
                                    <TableCell>Duration</TableCell>
                                    <TableCell>Currency</TableCell>
                                    <TableCell>Status</TableCell>
                                    <TableCell>Order</TableCell>
                                    <TableCell align="right">Actions</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {filteredCards.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={7} align="center" sx={{ py: 8 }}>
                                            <Typography color="text.secondary" fontWeight={500}>
                                                {search
                                                    ? 'No rate cards match your search'
                                                    : 'No rate cards found'}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    filteredCards.map((card) => (
                                        <TableRow
                                            key={card.id}
                                            hover
                                            sx={{
                                                '&:last-child td': { borderBottom: 0 },
                                                transition: 'background-color 0.15s',
                                            }}
                                        >
                                            <TableCell sx={{ py: 2 }}>
                                                <Typography variant="body2" fontWeight={600}>
                                                    {card.name}
                                                </Typography>
                                                {card.description && (
                                                    <Typography
                                                        variant="caption"
                                                        color="text.secondary"
                                                        sx={{ display: 'block', mt: 0.25 }}
                                                    >
                                                        {card.description}
                                                    </Typography>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Typography
                                                    variant="body2"
                                                    fontWeight={700}
                                                    color={colors.sea || '#0f766e'}
                                                >
                                                    {card.price}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" fontWeight={500}>
                                                    {card.duration_days} days
                                                </Typography>
                                            </TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={card.currency}
                                                    size="small"
                                                    sx={{
                                                        fontWeight: 700,
                                                        bgcolor: 'action.hover',
                                                        border: '1px solid',
                                                        borderColor: 'divider',
                                                        height: 26,
                                                    }}
                                                />
                                            </TableCell>
                                            <TableCell>
                                                {card.is_active ? (
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
                                                    {card.display_order}
                                                </Typography>
                                            </TableCell>
                                            <TableCell align="right">
                                                <Tooltip title="Edit">
                                                    <IconButton
                                                        size="small"
                                                        onClick={() => openEdit(card)}
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
                                                        onClick={() => openDeleteDialog(card.id, card.name)}
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
                            {editing ? 'Edit Rate Card' : 'Create New Rate Card'}
                        </Typography>
                        <Typography variant="body2" color="text.secondary" fontWeight={500}>
                            {editing ? 'Update plan details' : 'Define a new subscription plan'}
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
                        <Stack direction="row" spacing={2}>
                            <TextField
                                label="Price *"
                                fullWidth
                                size="small"
                                type="number"
                                value={form.price || ''}
                                onChange={(e) => handleChange('price', parseFloat(e.target.value) || 0)}
                                InputProps={{
                                    startAdornment: (
                                        <InputAdornment position="start">
                                            <Typography fontWeight={600}>$</Typography>
                                        </InputAdornment>
                                    ),
                                }}
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
                                label="Currency *"
                                fullWidth
                                size="small"
                                value={form.currency || 'TZS'}
                                onChange={(e) => handleChange('currency', e.target.value)}
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
                        </Stack>
                        <TextField
                            label="Duration (days) *"
                            fullWidth
                            size="small"
                            type="number"
                            value={form.duration_days || 1}
                            onChange={(e) => handleChange('duration_days', parseInt(e.target.value) || 1)}
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
                            label="Description"
                            fullWidth
                            size="small"
                            multiline
                            rows={2}
                            value={form.description || ''}
                            onChange={(e) => handleChange('description', e.target.value)}
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
                        disabled={!form.name || !form.price}
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
                        Delete Rate Card
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
                            You are about to delete the rate card:
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
                            "{deleteDialog.cardName}"
                        </Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
                            This action cannot be undone.
                            <Box component="span" sx={{ display: 'block', mt: 1, color: '#b91c1c', fontWeight: 600 }}>
                                ⚠️ All data related to this rate card will be permanently removed.
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

export default RateCardManagement;