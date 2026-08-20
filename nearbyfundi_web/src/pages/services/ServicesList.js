// src/pages/services/ServicesList.js
import React, { useState, useEffect } from 'react';
import {
    Box, Paper, Typography, Button, TextField, InputAdornment,
    IconButton, Menu, MenuItem, Dialog, DialogTitle, DialogContent,
    DialogActions, CircularProgress, useMediaQuery, useTheme,
    Card, CardContent, Avatar, Tooltip, Alert, Grid, Chip,
} from '@mui/material';
import {
    Add as AddIcon, Search as SearchIcon, Refresh as RefreshIcon,
    MoreVert as MoreVertIcon, Edit as EditIcon, Delete as DeleteIcon,
    Build as BuildIcon, People as PeopleIcon,
} from '@mui/icons-material';
import { serviceService } from 'services/service.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import ServiceFormModal from './ServiceFormModal';
import TechniciansModal from './TechniciansModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const ServicesList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

    const [groupedData, setGroupedData] = useState([]);
    const [filteredData, setFilteredData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const { can } = usePermissions();

    const [openModal, setOpenModal] = useState(false);
    const [editingService, setEditingService] = useState(null);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedService, setSelectedService] = useState(null);

    const [techniciansModal, setTechniciansModal] = useState({
        open: false,
        serviceId: null,
        serviceName: '',
    });

    const [confirmDialog, setConfirmDialog] = useState({
        open: false,
        title: '',
        message: '',
        action: null,
    });

    const [search, setSearch] = useState('');

    const canView = can('services.view');
    const canCreate = can('services.create');
    const canEdit = can('services.edit');
    const canDelete = can('services.delete');

    const loadGroupedServices = async () => {
        if (!canView) return;
        setLoading(true);
        setError(null);
        try {
            const response = await serviceService.getGroupedServices();
            if (response?.data?.status === 'success') {
                const data = response.data.data || [];
                setGroupedData(data);
                setFilteredData(data);
            } else {
                setGroupedData([]);
                setFilteredData([]);
            }
        } catch (err) {
            console.error('Grouped services error:', err);
            setError(err.message || 'Failed to load services');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canView) loadGroupedServices();
    }, [canView]);

    useEffect(() => {
        if (!search.trim()) {
            setFilteredData(groupedData);
            return;
        }
        const lowerSearch = search.toLowerCase();
        const filtered = groupedData
            .map(category => ({
                ...category,
                services: category.services.filter(service =>
                    service.name.toLowerCase().includes(lowerSearch) ||
                    service.name_en?.toLowerCase().includes(lowerSearch) ||
                    service.name_sw?.toLowerCase().includes(lowerSearch)
                ),
            }))
            .filter(category => category.services.length > 0);
        setFilteredData(filtered);
    }, [search, groupedData]);

    const handleMenuOpen = (event, service) => {
        setSelectedService(service);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => setActionMenu(null);

    const openConfirmDialog = (title, message, actionFn) => {
        setConfirmDialog({ open: true, title, message, action: actionFn });
    };

    const handleDelete = async (id) => {
        try {
            await serviceService.deleteService(id);
            showSnackbar({ type: 'success', message: 'Service deleted successfully' });
            await loadGroupedServices();
            return true;
        } catch (err) {
            console.error('Delete error:', err);
            const errorMessage = err.response?.data?.message || 'Failed to delete service';
            showSnackbar({ type: 'error', message: errorMessage });
            throw err;
        }
    };

    const handleConfirm = async () => {
        if (!confirmDialog.action) return;
        const action = confirmDialog.action;
        setConfirmDialog(prev => ({ ...prev, open: false }));
        try {
            await action();
        } catch (err) {
            console.error('Confirm action failed:', err);
        }
    };

    const handleViewTechnicians = (serviceId, serviceName) => {
        setTechniciansModal({ open: true, serviceId, serviceName });
    };

    // ✅ Fetch full service details before editing
    const handleEdit = async (service) => {
        try {
            const response = await serviceService.getService(service.id);
            if (response?.data?.status === 'success') {
                const fullService = response.data.data;
                setEditingService(fullService);
                setOpenModal(true);
            } else {
                showSnackbar({ type: 'error', message: 'Failed to load service details' });
            }
        } catch (err) {
            console.error('Error fetching service details:', err);
            showSnackbar({ type: 'error', message: 'Failed to load service details' });
        }
        handleMenuClose();
    };

    if (!canView) {
        return (
            <Box p={3}>
                <Paper sx={{ p: 3, textAlign: 'center' }}>
                    <Typography color="error">You do not have permission to view services.</Typography>
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
                        <Button color="inherit" size="small" onClick={() => { setError(null); loadGroupedServices(); }}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    return (
        <Box sx={{ width: '100%', p: { xs: 1, sm: 2 }, m: 0 }}>
            <Paper sx={{
                width: '100%',
                borderRadius: { xs: 1, sm: 2 },
                overflow: 'hidden',
                boxShadow: { xs: 0, sm: 1 },
                backgroundColor: colors.light,
                border: `1px solid ${colors.middle}`,
            }}>
                <Box sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                    <Box display="flex" justifyContent="space-between" alignItems="center" mb={2} flexWrap="wrap" gap={1}>
                        <Typography variant="h5" fontWeight="600" sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem' }, color: colors.dark }}>
                            Service Management
                        </Typography>
                        <Box display="flex" alignItems="center" gap={2}>
                            {canCreate && (
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => { setEditingService(null); setOpenModal(true); }}
                                    size={isMobile ? "small" : "medium"}
                                    sx={{
                                        borderRadius: 2,
                                        backgroundColor: colors.salat,
                                        '&:hover': { backgroundColor: colors.dark }
                                    }}
                                >
                                    Add Service
                                </Button>
                            )}
                        </Box>
                    </Box>

                    <Box display="flex" gap={2} flexWrap="wrap" alignItems="center">
                        <TextField
                            label="Search Services"
                            size="small"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            InputProps={{
                                startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>
                            }}
                            sx={{
                                minWidth: { xs: '100%', sm: 250 },
                                flexGrow: { xs: 1, sm: 0 },
                                '& .MuiInputBase-root': {
                                    backgroundColor: colors.sky,
                                    borderRadius: 2,
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle,
                                },
                            }}
                        />
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={loadGroupedServices}
                            size={isMobile ? "small" : "medium"}
                            sx={{
                                borderColor: colors.middle,
                                color: colors.sea,
                                '&:hover': {
                                    borderColor: colors.sea,
                                    backgroundColor: colors.wave,
                                }
                            }}
                        >
                            Refresh
                        </Button>
                    </Box>
                </Box>

                <Box sx={{ p: { xs: 2, sm: 3 } }}>
                    {loading ? (
                        <Box display="flex" justifyContent="center" py={4}>
                            <CircularProgress sx={{ color: colors.sea }} />
                        </Box>
                    ) : filteredData.length === 0 ? (
                        <Paper variant="outlined" sx={{ p: 4, textAlign: 'center', borderColor: colors.middle }}>
                            <Typography sx={{ color: colors.rain }}>
                                {search ? 'No services match your search' : 'No categories or services found'}
                            </Typography>
                        </Paper>
                    ) : (
                        filteredData.map((category) => (
                            <Paper
                                key={category.category_id}
                                sx={{
                                    mb: 3,
                                    p: { xs: 2, sm: 3 },
                                    borderRadius: 2,
                                    border: `1px solid ${colors.middle}`,
                                    backgroundColor: colors.sky,
                                }}
                            >
                                <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
                                    <Typography variant="h6" sx={{ color: colors.dark }}>
                                        {category.category_name}
                                        <Chip
                                            label={`${category.service_count} services`}
                                            size="small"
                                            sx={{ ml: 2, bgcolor: colors.light, color: colors.rain }}
                                        />
                                    </Typography>
                                </Box>
                                <Grid container spacing={2}>
                                    {category.services.map((service) => (
                                        <Grid item xs={12} sm={6} md={4} key={service.id}>
                                            <Card sx={{
                                                height: '100%',
                                                borderRadius: 2,
                                                border: `1px solid ${colors.middle}`,
                                                transition: 'all 0.2s',
                                                '&:hover': {
                                                    boxShadow: 4,
                                                    borderColor: colors.sea,
                                                }
                                            }}>
                                                <CardContent>
                                                    <Box display="flex" justifyContent="space-between" alignItems="flex-start">
                                                        <Typography variant="subtitle1" fontWeight="bold" sx={{ color: colors.dark }}>
                                                            {service.name}
                                                        </Typography>
                                                        <IconButton
                                                            size="small"
                                                            onClick={(e) => handleMenuOpen(e, service)}
                                                            sx={{ color: colors.rain }}
                                                        >
                                                            <MoreVertIcon fontSize="small" />
                                                        </IconButton>
                                                    </Box>

                                                    <Box display="flex" alignItems="center" mt={1} mb={1}>
                                                        <PeopleIcon fontSize="small" sx={{ color: colors.rain, mr: 0.5 }} />
                                                        <Typography variant="body2" sx={{ color: colors.black }}>
                                                            {service.technicians_count || 0} technician{service.technicians_count !== 1 ? 's' : ''}
                                                        </Typography>
                                                    </Box>

                                                    <Button
                                                        variant="outlined"
                                                        size="small"
                                                        fullWidth
                                                        onClick={() => handleViewTechnicians(service.id, service.name)}
                                                        sx={{
                                                            mt: 1,
                                                            borderColor: colors.middle,
                                                            color: colors.sea,
                                                            '&:hover': {
                                                                borderColor: colors.sea,
                                                                backgroundColor: colors.wave,
                                                            }
                                                        }}
                                                    >
                                                        View Technicians
                                                    </Button>
                                                </CardContent>
                                            </Card>
                                        </Grid>
                                    ))}
                                </Grid>
                            </Paper>
                        ))
                    )}
                </Box>
            </Paper>

            {/* Action Menu */}
            <Menu
                anchorEl={actionMenu}
                open={Boolean(actionMenu)}
                onClose={handleMenuClose}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                transformOrigin={{ vertical: 'top', horizontal: 'right' }}
            >
                {canEdit && (
                    <MenuItem onClick={() => handleEdit(selectedService)}>
                        <EditIcon sx={{ mr: 1, fontSize: 20, color: colors.sea }} /> Edit
                    </MenuItem>
                )}
                {canDelete && (
                    <MenuItem onClick={() => {
                        openConfirmDialog(
                            'Delete Service',
                            `Are you sure you want to delete "${selectedService?.name}"? This action cannot be undone.`,
                            () => handleDelete(selectedService?.id)
                        );
                        handleMenuClose();
                    }} sx={{ color: 'error.main' }}>
                        <DeleteIcon sx={{ mr: 1, fontSize: 20 }} /> Delete
                    </MenuItem>
                )}
            </Menu>

            {/* Service Form Modal */}
            <ServiceFormModal
                open={openModal}
                onClose={() => {
                    setOpenModal(false);
                    setEditingService(null);
                    loadGroupedServices();
                }}
                service={editingService}
            />

            {/* Technicians Modal */}
            <TechniciansModal
                open={techniciansModal.open}
                onClose={() => setTechniciansModal({ open: false, serviceId: null, serviceName: '' })}
                serviceId={techniciansModal.serviceId}
                serviceName={techniciansModal.serviceName}
            />

            {/* Confirmation Dialog */}
            <Dialog
                open={confirmDialog.open}
                onClose={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                fullWidth
                maxWidth="xs"
                PaperProps={{
                    sx: {
                        borderRadius: 2,
                        backgroundColor: colors.light,
                    }
                }}
            >
                <DialogTitle sx={{ pb: 1, color: colors.dark }}>{confirmDialog.title}</DialogTitle>
                <DialogContent>
                    <Typography sx={{ color: colors.black }}>{confirmDialog.message}</Typography>
                </DialogContent>
                <DialogActions sx={{ p: 2, pt: 0 }}>
                    <Button
                        onClick={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                        sx={{ color: colors.rain }}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleConfirm}
                        variant="contained"
                        sx={{
                            backgroundColor: 'error.main',
                            '&:hover': { backgroundColor: 'error.dark' },
                        }}
                    >
                        Confirm
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default ServicesList;