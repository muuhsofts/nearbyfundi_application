// src/pages/services/ServicesList.js
import React, { useState, useEffect } from 'react';
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
    TablePagination,
    TableSortLabel,
    TextField,
    InputAdornment,
    IconButton,
    Menu,
    MenuItem,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    CircularProgress,
    useMediaQuery,
    useTheme,
    Card,
    CardContent,
    Divider,
    Avatar,
    Tooltip,
    Alert,
} from '@mui/material';
import {
    Add as AddIcon,
    Search as SearchIcon,
    Refresh as RefreshIcon,
    MoreVert as MoreVertIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Build as BuildIcon,
    People as PeopleIcon,
} from '@mui/icons-material';
import { serviceService } from 'services/service.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import ServiceFormModal from './ServiceFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'name', label: 'Service Name' },
    { id: 'technicians', label: 'Technicians' },
    { id: 'created_at', label: 'Created' },
    { id: 'actions', label: 'Actions', disableSort: true },
];

const ServicesList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const [services, setServices] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const { can } = usePermissions();

    const [openModal, setOpenModal] = useState(false);
    const [editingService, setEditingService] = useState(null);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedService, setSelectedService] = useState(null);

    const [confirmDialog, setConfirmDialog] = useState({
        open: false,
        title: '',
        message: '',
        action: null,
    });

    const [search, setSearch] = useState('');
    const [order, setOrder] = useState('asc');
    const [orderBy, setOrderBy] = useState('created_at');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    // Permissions
    const canView = can('services.view');
    const canCreate = can('services.create');
    const canEdit = can('services.edit');
    const canDelete = can('services.delete');

    // Fetch services
    const loadServices = async () => {
        if (!canView) return;

        setLoading(true);
        setError(null);
        try {
            const response = await serviceService.getServices({
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
            });

            if (response?.data?.status === 'success') {
                const data = response.data.data;
                setServices(Array.isArray(data) ? data : [data]);
            } else {
                setServices([]);
            }
        } catch (err) {
            console.error('Services error:', err);
            setError(err.message || 'Failed to load services');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canView) {
            loadServices();
        }
    }, [page, rowsPerPage, search, canView]);

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    const handleMenuOpen = (event, service) => {
        setSelectedService(service);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => {
        setActionMenu(null);
    };

    const openConfirmDialog = (title, message, actionFn) => {
        setConfirmDialog({ open: true, title, message, action: actionFn });
    };

    const handleDelete = async (id) => {
        try {
            await serviceService.deleteService(id);
            showSnackbar({ type: 'success', message: 'Service deleted successfully' });
            await loadServices();
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
            // Error already handled in the action
            console.error('Confirm action failed:', err);
        }
    };

    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        try {
            return new Date(dateStr).toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
            });
        } catch {
            return '-';
        }
    };

    const getTechnicianCount = (service) => {
        if (!service.technicians) return 0;
        return Array.isArray(service.technicians) ? service.technicians.length : 0;
    };

    const getTechnicianNames = (service) => {
        if (!service.technicians || !Array.isArray(service.technicians) || service.technicians.length === 0) {
            return 'No technicians assigned';
        }
        return service.technicians
            .map(t => t.user?.name || 'Unknown')
            .join(', ');
    };

    const getTechnicianAvatars = (service) => {
        if (!service.technicians || !Array.isArray(service.technicians)) return [];
        return service.technicians.slice(0, 3).map(t => ({
            name: t.user?.name || 'Unknown',
            photo: t.profile_photo || null,
        }));
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
                        <Button color="inherit" size="small" onClick={() => { setError(null); loadServices(); }}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    const sortedServices = [...services].sort((a, b) => {
        let aValue = a[orderBy] || '';
        let bValue = b[orderBy] || '';
        if (orderBy === 'technicians') {
            aValue = getTechnicianCount(a);
            bValue = getTechnicianCount(b);
        }
        if (typeof aValue === 'string') {
            aValue = aValue.toLowerCase();
            bValue = bValue.toLowerCase();
        }
        if (aValue < bValue) return order === 'asc' ? -1 : 1;
        if (aValue > bValue) return order === 'asc' ? 1 : -1;
        return 0;
    });

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
                {/* Header Section */}
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

                    {/* Filters */}
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
                            onClick={loadServices}
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

                {/* Table View (Desktop) */}
                {showTableView ? (
                    <TableContainer sx={{ width: '100%', overflowX: 'auto' }}>
                        <Table sx={{ width: '100%', minWidth: 700 }}>
                            <TableHead>
                                <TableRow sx={{ backgroundColor: colors.sky }}>
                                    {headCells.map((cell) => (
                                        <TableCell key={cell.id} sx={{ fontWeight: 'bold', color: colors.dark, whiteSpace: 'nowrap' }}>
                                            {!cell.disableSort ? (
                                                <TableSortLabel
                                                    active={orderBy === cell.id}
                                                    direction={orderBy === cell.id ? order : 'asc'}
                                                    onClick={() => handleRequestSort(cell.id)}
                                                    sx={{ color: colors.dark }}
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
                                        <TableCell colSpan={headCells.length} align="center">
                                            <CircularProgress sx={{ color: colors.sea, my: 3 }} />
                                        </TableCell>
                                    </TableRow>
                                ) : sortedServices.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center">
                                            <Typography sx={{ py: 3, color: colors.rain }}>
                                                No services found
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sortedServices.map((service) => (
                                        <TableRow key={service.id} hover>
                                            <TableCell>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <BuildIcon sx={{ color: colors.sea }} fontSize="small" />
                                                    <Typography variant="body2" fontWeight="medium" sx={{ color: colors.dark }}>
                                                        {service.name}
                                                    </Typography>
                                                </Box>
                                            </TableCell>
                                            <TableCell>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <PeopleIcon fontSize="small" sx={{ color: colors.rain }} />
                                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                                        {getTechnicianCount(service)} technician{getTechnicianCount(service) !== 1 ? 's' : ''}
                                                    </Typography>
                                                    {getTechnicianCount(service) > 0 && (
                                                        <Tooltip title={getTechnicianNames(service)} arrow>
                                                            <Box display="flex" ml={1}>
                                                                {getTechnicianAvatars(service).map((tech, index) => (
                                                                    <Avatar
                                                                        key={index}
                                                                        src={tech.photo ? `${process.env.REACT_APP_API_URL}/storage/${tech.photo}` : undefined}
                                                                        sx={{
                                                                            width: 28,
                                                                            height: 28,
                                                                            ml: index > 0 ? -1 : 0,
                                                                            border: `2px solid ${colors.light}`,
                                                                            fontSize: '0.75rem',
                                                                            bgcolor: colors.sea,
                                                                            color: colors.light,
                                                                        }}
                                                                    >
                                                                        {!tech.photo && tech.name.charAt(0).toUpperCase()}
                                                                    </Avatar>
                                                                ))}
                                                                {getTechnicianCount(service) > 3 && (
                                                                    <Avatar
                                                                        sx={{
                                                                            width: 28,
                                                                            height: 28,
                                                                            ml: -1,
                                                                            border: `2px solid ${colors.light}`,
                                                                            fontSize: '0.75rem',
                                                                            bgcolor: colors.middle,
                                                                            color: colors.rain,
                                                                        }}
                                                                    >
                                                                        +{getTechnicianCount(service) - 3}
                                                                    </Avatar>
                                                                )}
                                                            </Box>
                                                        </Tooltip>
                                                    )}
                                                </Box>
                                            </TableCell>
                                            <TableCell>
                                                <Typography variant="body2" sx={{ color: colors.black }}>
                                                    {formatDate(service.created_at)}
                                                </Typography>
                                            </TableCell>
                                            <TableCell align="center">
                                                <IconButton
                                                    size="small"
                                                    onClick={(e) => handleMenuOpen(e, service)}
                                                    sx={{ color: colors.rain }}
                                                >
                                                    <MoreVertIcon />
                                                </IconButton>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                ) : (
                    // Mobile Card View
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        {loading ? (
                            <Box display="flex" justifyContent="center" py={4}>
                                <CircularProgress sx={{ color: colors.sea }} />
                            </Box>
                        ) : sortedServices.length === 0 ? (
                            <Paper variant="outlined" sx={{ p: 4, textAlign: 'center', borderColor: colors.middle }}>
                                <Typography sx={{ color: colors.rain }}>
                                    No services found
                                </Typography>
                            </Paper>
                        ) : (
                            sortedServices.map((service) => (
                                <Card key={service.id} sx={{
                                    mb: 2,
                                    borderRadius: 2,
                                    border: `1px solid ${colors.middle}`,
                                }}>
                                    <CardContent sx={{ p: 2 }}>
                                        <Box display="flex" justifyContent="space-between" alignItems="flex-start" mb={1.5}>
                                            <Box display="flex" alignItems="center" gap={1}>
                                                <BuildIcon sx={{ color: colors.sea }} />
                                                <Typography variant="h6" fontSize="1rem" fontWeight="medium" sx={{ color: colors.dark }}>
                                                    {service.name}
                                                </Typography>
                                            </Box>
                                            <IconButton
                                                size="small"
                                                onClick={(e) => handleMenuOpen(e, service)}
                                                sx={{ color: colors.rain }}
                                            >
                                                <MoreVertIcon fontSize="small" />
                                            </IconButton>
                                        </Box>

                                        <Box display="flex" alignItems="center" gap={1} mb={1}>
                                            <PeopleIcon fontSize="small" sx={{ color: colors.rain }} />
                                            <Typography variant="body2" sx={{ color: colors.black }}>
                                                {getTechnicianCount(service)} technician{getTechnicianCount(service) !== 1 ? 's' : ''}
                                            </Typography>
                                        </Box>

                                        {getTechnicianCount(service) > 0 && (
                                            <Box display="flex" alignItems="center" gap={1} mb={1} flexWrap="wrap">
                                                {getTechnicianAvatars(service).map((tech, index) => (
                                                    <Tooltip key={index} title={tech.name} arrow>
                                                        <Avatar
                                                            src={tech.photo ? `${process.env.REACT_APP_API_URL}/storage/${tech.photo}` : undefined}
                                                            sx={{
                                                                width: 32,
                                                                height: 32,
                                                                border: `2px solid ${colors.light}`,
                                                                fontSize: '0.75rem',
                                                                bgcolor: colors.sea,
                                                                color: colors.light,
                                                            }}
                                                        >
                                                            {!tech.photo && tech.name.charAt(0).toUpperCase()}
                                                        </Avatar>
                                                    </Tooltip>
                                                ))}
                                                {getTechnicianCount(service) > 3 && (
                                                    <Avatar
                                                        sx={{
                                                            width: 32,
                                                            height: 32,
                                                            border: `2px solid ${colors.light}`,
                                                            fontSize: '0.75rem',
                                                            bgcolor: colors.middle,
                                                            color: colors.rain,
                                                        }}
                                                    >
                                                        +{getTechnicianCount(service) - 3}
                                                    </Avatar>
                                                )}
                                            </Box>
                                        )}

                                        <Divider sx={{ my: 1, borderColor: colors.middle }} />

                                        <Box display="flex" justifyContent="space-between" alignItems="center">
                                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                                Created: {formatDate(service.created_at)}
                                            </Typography>
                                        </Box>
                                    </CardContent>
                                </Card>
                            ))
                        )}
                    </Box>
                )}

                {/* Pagination */}
                <Box sx={{ borderTop: `1px solid ${colors.middle}`, py: { xs: 1, sm: 0 } }}>
                    <TablePagination
                        rowsPerPageOptions={[5, 10, 25, 50]}
                        component="div"
                        count={services.length}
                        rowsPerPage={rowsPerPage}
                        page={page}
                        onPageChange={(e, newPage) => setPage(newPage)}
                        onRowsPerPageChange={(e) => {
                            setRowsPerPage(parseInt(e.target.value, 10));
                            setPage(0);
                        }}
                        sx={{
                            '.MuiTablePagination-selectLabel, .MuiTablePagination-displayedRows': {
                                fontSize: { xs: '0.75rem', sm: '0.875rem' },
                                color: colors.black,
                            },
                            '.MuiTablePagination-actions': {
                                color: colors.sea,
                            },
                        }}
                    />
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
                    <MenuItem onClick={() => {
                        setEditingService(selectedService);
                        setOpenModal(true);
                        handleMenuClose();
                    }}>
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
                    loadServices();
                }}
                service={editingService}
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