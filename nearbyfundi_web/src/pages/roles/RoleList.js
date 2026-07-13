// src/pages/roles/RoleList.js
import React, { useState, useEffect } from 'react';
import {
    Box, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle,
    IconButton, InputAdornment, Menu, MenuItem, Paper, Table, TableBody,
    TableCell, TableContainer, TableHead, TablePagination, TableRow,
    TextField, Typography, useTheme, useMediaQuery, Card, CardContent,
    Divider, CircularProgress, Alert
} from '@mui/material';
import {
    Add as AddIcon,
    Edit as EditIcon,
    Refresh as RefreshIcon,
    Search as SearchIcon,
    MoreVert as MoreVertIcon,
    VpnKey as PermissionsIcon,
    Shield as ShieldIcon,
    Description as DescriptionIcon,
    Delete as DeleteIcon
} from '@mui/icons-material';
import { roleService } from 'services/role.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import RoleFormModal from './RoleFormModal';
import RolePermissionsModal from './RolePermissionsModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'name', label: 'Role Name' },
    { id: 'display_name', label: 'Display Name' },
    { id: 'description', label: 'Description' },
    { id: 'guard_name', label: 'Guard' },
    { id: 'actions', label: 'Actions', disableSort: true },
];

export default function RoleList() {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const { can } = usePermissions();
    const canView = can('roles.view');
    const canCreate = can('roles.create');
    const canEdit = can('roles.edit');
    const canAssignPermissions = can('roles.assign_permissions');

    const [roles, setRoles] = useState([]);
    const [total, setTotal] = useState(0);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [openFormModal, setOpenFormModal] = useState(false);
    const [editingRole, setEditingRole] = useState(null);
    const [openPermissionsModal, setOpenPermissionsModal] = useState(false);
    const [selectedRoleForPermissions, setSelectedRoleForPermissions] = useState(null);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedRole, setSelectedRole] = useState(null);
    const [search, setSearch] = useState('');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [confirmDialog, setConfirmDialog] = useState({ open: false, title: '', message: '', action: null });

    const fetchRoles = async () => {
        if (!canView) return;
        setLoading(true);
        setError(null);
        try {
            const response = await roleService.getRoles({
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined
            });
            console.log('Roles response:', response);

            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    setRoles(data.data);
                    setTotal(data.total || 0);
                } else if (Array.isArray(data)) {
                    setRoles(data);
                    setTotal(data.length || 0);
                } else {
                    setRoles([]);
                    setTotal(0);
                }
            } else {
                setRoles([]);
                setTotal(0);
                setError(response?.data?.message || 'Failed to load roles');
            }
        } catch (err) {
            console.error('Roles error:', err);
            setError(err.message || 'Failed to load roles');
            showSnackbar({ type: 'error', message: 'Failed to load roles' });
            setRoles([]);
            setTotal(0);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canView) {
            fetchRoles();
        }
    }, [page, rowsPerPage, search, canView]);

    const handleMenuOpen = (event, role) => {
        setSelectedRole(role);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => setActionMenu(null);

    const openConfirmDialog = (title, message, actionFn) => {
        setConfirmDialog({ open: true, title, message, action: actionFn });
    };

    const handleEdit = () => {
        setEditingRole(selectedRole);
        setOpenFormModal(true);
        handleMenuClose();
    };

    const handlePermissions = () => {
        setSelectedRoleForPermissions(selectedRole);
        setOpenPermissionsModal(true);
        handleMenuClose();
    };

    const handleCreate = () => {
        setEditingRole(null);
        setOpenFormModal(true);
    };

    const handleFormModalClose = () => {
        setOpenFormModal(false);
        setEditingRole(null);
        fetchRoles();
    };

    const handlePermissionsModalClose = () => {
        setOpenPermissionsModal(false);
        setSelectedRoleForPermissions(null);
    };

    const handleDelete = async () => {
        if (!selectedRole) return;
        if (!window.confirm(`Are you sure you want to delete role "${selectedRole.name}"?`)) return;

        try {
            await roleService.deleteRole(selectedRole.id);
            showSnackbar({ type: 'success', message: 'Role deleted successfully' });
            fetchRoles();
        } catch (err) {
            showSnackbar({ type: 'error', message: err.response?.data?.message || 'Failed to delete role' });
        }
        handleMenuClose();
    };

    const handleConfirm = async () => {
        if (!confirmDialog.action) return;
        setConfirmDialog(prev => ({ ...prev, open: false }));
        try {
            await confirmDialog.action();
            fetchRoles();
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Action failed' });
        }
    };

    if (!canView) {
        return (
            <Box sx={{ p: 2 }}>
                <Paper sx={{
                    p: 4,
                    textAlign: 'center',
                    backgroundColor: colors.light,
                    border: `1px solid ${colors.middle}`,
                    borderRadius: 2
                }}>
                    <Typography variant="h5" color="error" gutterBottom>
                        Access Denied
                    </Typography>
                    <Typography color="text.secondary">
                        You do not have permission to view roles.
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
                        <Button color="inherit" size="small" onClick={() => { setError(null); fetchRoles(); }}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    const roleList = Array.isArray(roles) ? roles : [];

    const RoleCard = ({ role }) => (
        <Card sx={{
            mb: 2,
            borderRadius: 2,
            overflow: 'hidden',
            border: `1px solid ${colors.middle}`,
        }}>
            <CardContent sx={{ p: 2, '&:last-child': { pb: 2 }, backgroundColor: colors.light }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 1.5 }}>
                    <Chip
                        label={role.name}
                        size="small"
                        icon={<ShieldIcon sx={{ color: colors.sea }} />}
                        sx={{
                            maxWidth: 'calc(100% - 40px)',
                            backgroundColor: colors.wave,
                            color: colors.sea,
                            '& .MuiChip-label': { overflow: 'hidden', textOverflow: 'ellipsis' }
                        }}
                    />
                    <IconButton
                        size="small"
                        onClick={(e) => handleMenuOpen(e, role)}
                        sx={{ color: colors.rain }}
                    >
                        <MoreVertIcon fontSize="small" />
                    </IconButton>
                </Box>
                <Typography variant="body1" fontWeight="medium" sx={{ mb: 0.5, color: colors.dark }}>
                    {role.display_name || role.name}
                </Typography>
                {role.description && (
                    <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1, mb: 1 }}>
                        <DescriptionIcon fontSize="small" sx={{ color: colors.rain, mt: 0.2 }} />
                        <Typography variant="body2" sx={{ color: colors.black }}>
                            {role.description}
                        </Typography>
                    </Box>
                )}
                <Divider sx={{ my: 1, borderColor: colors.middle }} />
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                    <ShieldIcon fontSize="small" sx={{ color: colors.rain }} />
                    <Typography variant="caption" sx={{ color: colors.rain }}>
                        Guard: {role.guard_name}
                    </Typography>
                </Box>
            </CardContent>
        </Card>
    );

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
                {/* Header */}
                <Box sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                    <Box display="flex" justifyContent="space-between" alignItems="center" mb={2} flexWrap="wrap" gap={1}>
                        <Typography variant="h5" fontWeight="600" sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem' }, color: colors.dark }}>
                            Roles
                        </Typography>
                        {canCreate && (
                            <Button
                                variant="contained"
                                startIcon={<AddIcon />}
                                onClick={handleCreate}
                                size={isMobile ? "small" : "medium"}
                                sx={{
                                    borderRadius: 2,
                                    backgroundColor: colors.salat,
                                    '&:hover': { backgroundColor: colors.dark }
                                }}
                            >
                                Add Role
                            </Button>
                        )}
                    </Box>
                    <Box display="flex" gap={2} flexWrap="wrap" alignItems="center">
                        <TextField
                            label="Search"
                            size="small"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            InputProps={{
                                startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" sx={{ color: colors.rain }} /></InputAdornment>
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
                            onClick={fetchRoles}
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

                {/* Records */}
                {showTableView ? (
                    <TableContainer sx={{ width: '100%', overflowX: 'auto' }}>
                        <Table sx={{ width: '100%', minWidth: 800 }}>
                            <TableHead>
                                <TableRow sx={{ backgroundColor: colors.sky }}>
                                    {headCells.map((cell) => (
                                        <TableCell key={cell.id} sx={{ fontWeight: 'bold', color: colors.dark }}>
                                            {cell.label}
                                        </TableCell>
                                    ))}
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {loading ? (
                                    <TableRow>
                                        <TableCell colSpan={5} align="center">
                                            <CircularProgress size={32} sx={{ color: colors.sea, my: 3 }} />
                                        </TableCell>
                                    </TableRow>
                                ) : roleList.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={5} align="center">
                                            <Typography sx={{ py: 3, color: colors.rain }}>No roles found</Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    roleList.map((role) => (
                                        <TableRow key={role.id} hover>
                                            <TableCell>
                                                <Chip
                                                    label={role.name}
                                                    size="small"
                                                    sx={{
                                                        backgroundColor: colors.wave,
                                                        color: colors.sea,
                                                    }}
                                                />
                                            </TableCell>
                                            <TableCell sx={{ color: colors.black }}>{role.display_name || role.name}</TableCell>
                                            <TableCell sx={{ maxWidth: 300, wordBreak: 'break-word', color: colors.black }}>
                                                {role.description || '-'}
                                            </TableCell>
                                            <TableCell sx={{ color: colors.black }}>{role.guard_name}</TableCell>
                                            <TableCell align="center">
                                                <IconButton
                                                    size="small"
                                                    onClick={(e) => handleMenuOpen(e, role)}
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
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        {loading ? (
                            <Box display="flex" justifyContent="center" py={4}>
                                <CircularProgress sx={{ color: colors.sea }} />
                            </Box>
                        ) : roleList.length === 0 ? (
                            <Paper variant="outlined" sx={{ p: 4, textAlign: 'center', borderColor: colors.middle }}>
                                <Typography sx={{ color: colors.rain }}>No roles found</Typography>
                            </Paper>
                        ) : (
                            roleList.map((role) => <RoleCard key={role.id} role={role} />)
                        )}
                    </Box>
                )}

                {/* Pagination */}
                <Box sx={{ borderTop: `1px solid ${colors.middle}`, py: { xs: 1, sm: 0 } }}>
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
                                fontSize: { xs: '0.75rem', sm: '0.875rem' },
                                color: colors.black,
                            },
                            '.MuiTablePagination-actions': {
                                color: colors.sea,
                            }
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
                    <MenuItem onClick={handleEdit} sx={{ color: colors.sea }}>
                        <EditIcon sx={{ mr: 1, fontSize: 20 }} /> Edit
                    </MenuItem>
                )}
                {canAssignPermissions && (
                    <MenuItem onClick={handlePermissions} sx={{ color: colors.sea }}>
                        <PermissionsIcon sx={{ mr: 1, fontSize: 20 }} /> Assign Permissions
                    </MenuItem>
                )}
                <MenuItem onClick={handleDelete} sx={{ color: 'error.main' }}>
                    <DeleteIcon sx={{ mr: 1, fontSize: 20 }} /> Delete
                </MenuItem>
            </Menu>

            {/* Modals */}
            <RoleFormModal open={openFormModal} onClose={handleFormModalClose} role={editingRole} />
            {selectedRoleForPermissions && (
                <RolePermissionsModal open={openPermissionsModal} onClose={handlePermissionsModalClose} role={selectedRoleForPermissions} />
            )}

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
                <DialogTitle sx={{ color: colors.dark }}>{confirmDialog.title}</DialogTitle>
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
}