// src/pages/users/UsersList.jsx
import React, { useState, useEffect, useMemo } from 'react';
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
    Chip,
    Menu,
    MenuItem,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    CircularProgress,
    Switch,
    FormControlLabel,
    useMediaQuery,
    useTheme,
    Card,
    CardContent,
    Divider,
    Alert,
} from '@mui/material';
import {
    Add as AddIcon,
    Search as SearchIcon,
    Refresh as RefreshIcon,
    MoreVert as MoreVertIcon,
    Edit as EditIcon,
    Delete as DeleteIcon,
    Verified as VerifiedIcon,
    Block as BlockIcon,
    LockOpen as LockOpenIcon,
    VpnKey as VpnKeyIcon,
    Email as EmailIcon,
    Restore as RestoreIcon,
    DeleteSweep as DeleteSweepIcon,
    Person as PersonIcon,
    Email as EmailOutlinedIcon,
    Phone as PhoneIcon,
    Work as WorkIcon,
} from '@mui/icons-material';
import { useUserManagement } from 'hooks/useUser';
import { usePermissions } from 'hooks/usePermissions';
import { userService } from 'services/user.service';
import { showSnackbar } from 'utils/snackbar';
import UserFormModal from './UserFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'name', label: 'Name' },
    { id: 'email', label: 'Email' },
    { id: 'phone', label: 'Phone' },
    { id: 'role', label: 'Role' },
    { id: 'status', label: 'Status' },
    { id: 'email_verified', label: 'Verified' },
    { id: 'created_at', label: 'Created' },
    { id: 'actions', label: 'Actions', disableSort: true },
];

const UsersList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const {
        users,
        loading,
        error,
        getUsers,
        deleteUser,
        updateUser,
        clearError,
    } = useUserManagement();

    const { can } = usePermissions();

    const [showDeleted, setShowDeleted] = useState(false);
    const [deletedUsers, setDeletedUsers] = useState([]);
    const [trashedTotal, setTrashedTotal] = useState(0);
    const [loadingDeleted, setLoadingDeleted] = useState(false);

    const [openModal, setOpenModal] = useState(false);
    const [editingUser, setEditingUser] = useState(null);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedUser, setSelectedUser] = useState(null);

    const [confirmDialog, setConfirmDialog] = useState({
        open: false,
        title: '',
        message: '',
        action: null,
    });

    const [passwordDialog, setPasswordDialog] = useState({
        open: false,
        userId: null,
        userName: '',
        password: '',
        confirmPassword: '',
        error: '',
    });

    const [search, setSearch] = useState('');
    const [statusFilter, setStatusFilter] = useState('');
    const [roleFilter, setRoleFilter] = useState('');
    const [order, setOrder] = useState('asc');
    const [orderBy, setOrderBy] = useState('created_at');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    // Permissions
    const canView = can('users.view');
    const canCreate = can('users.create');
    const canEdit = can('users.edit');
    const canDelete = can('users.delete');
    const canActivate = can('users.activate');
    const canDeactivate = can('users.deactivate');
    const canSuspend = can('users.suspend');
    const canResetPassword = can('users.reset_password');
    const canRestore = can('users.restore');

    // Fetch users when filters change
    useEffect(() => {
        if (!showDeleted && canView) {
            getUsers({
                page: page + 1,
                per_page: rowsPerPage,
            });
        }
    }, [page, rowsPerPage, showDeleted, getUsers, canView]);

    // Fetch deleted users when toggled
    useEffect(() => {
        if (showDeleted && canView) {
            fetchDeletedUsers();
        }
    }, [showDeleted, page, rowsPerPage, search, canView]);

    const fetchDeletedUsers = async () => {
        setLoadingDeleted(true);
        try {
            const response = await userService.getTrashedUsers({
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
            });
            const data = response.data?.data;
            setDeletedUsers(data?.data || []);
            setTrashedTotal(data?.total || 0);
        } catch (error) {
            console.error('Failed to load deleted users', error);
            showSnackbar({ type: 'error', message: 'Failed to load deleted users' });
            setDeletedUsers([]);
            setTrashedTotal(0);
        } finally {
            setLoadingDeleted(false);
        }
    };

    // Client-side filtering
    const filteredUsers = useMemo(() => {
        if (!Array.isArray(users)) return [];

        let filtered = [...users];

        if (search) {
            const searchLower = search.toLowerCase();
            filtered = filtered.filter(user =>
                user.name?.toLowerCase().includes(searchLower) ||
                user.email?.toLowerCase().includes(searchLower) ||
                user.phone?.toLowerCase().includes(searchLower)
            );
        }

        if (statusFilter) {
            filtered = filtered.filter(user => user.status === statusFilter);
        }

        if (roleFilter) {
            filtered = filtered.filter(user => {
                if (!user.roles || user.roles.length === 0) return false;
                return user.roles.some(role => role.name === roleFilter);
            });
        }

        return filtered;
    }, [users, search, statusFilter, roleFilter]);

    // Sort the filtered data
    const sortedData = useMemo(() => {
        const sorted = [...filteredUsers];
        sorted.sort((a, b) => {
            let aValue, bValue;

            switch (orderBy) {
                case 'name':
                    aValue = a.name || '';
                    bValue = b.name || '';
                    break;
                case 'email':
                    aValue = a.email || '';
                    bValue = b.email || '';
                    break;
                case 'phone':
                    aValue = a.phone || '';
                    bValue = b.phone || '';
                    break;
                case 'role':
                    aValue = getUserRoleName(a);
                    bValue = getUserRoleName(b);
                    break;
                case 'status':
                    aValue = a.status || '';
                    bValue = b.status || '';
                    break;
                case 'email_verified':
                    aValue = a.email_verified_at ? 1 : 0;
                    bValue = b.email_verified_at ? 1 : 0;
                    break;
                case 'created_at':
                    aValue = a.created_at || '';
                    bValue = b.created_at || '';
                    break;
                default:
                    aValue = a[orderBy] || '';
                    bValue = b[orderBy] || '';
            }

            if (typeof aValue === 'string') {
                aValue = aValue.toLowerCase();
                bValue = bValue.toLowerCase();
            }

            if (aValue < bValue) return order === 'asc' ? -1 : 1;
            if (aValue > bValue) return order === 'asc' ? 1 : -1;
            return 0;
        });
        return sorted;
    }, [filteredUsers, orderBy, order]);

    const handleRestoreUser = async (userId) => {
        try {
            await userService.restoreUser(userId);
            showSnackbar({ type: 'success', message: 'User restored successfully' });
            await fetchDeletedUsers();
            if (!showDeleted) await getUsers();
        } catch (error) {
            showSnackbar({ type: 'error', message: 'Failed to restore user' });
        }
    };

    const handleForceDelete = async (userId) => {
        try {
            await userService.forceDeleteUser(userId);
            showSnackbar({ type: 'success', message: 'User permanently deleted' });
            await fetchDeletedUsers();
        } catch (error) {
            showSnackbar({ type: 'error', message: 'Failed to permanently delete user' });
        }
    };

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    const handleMenuOpen = (event, user) => {
        setSelectedUser(user);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => {
        setActionMenu(null);
    };

    const openConfirmDialog = (title, message, actionFn) => {
        setConfirmDialog({ open: true, title, message, action: actionFn });
    };

    const handleAction = async (actionType) => {
        if (!selectedUser) return;
        handleMenuClose();

        if (showDeleted) {
            switch (actionType) {
                case 'restore':
                    openConfirmDialog(
                        'Restore User',
                        `Are you sure you want to restore ${selectedUser.name}?`,
                        () => handleRestoreUser(selectedUser.id)
                    );
                    break;
                case 'force_delete':
                    openConfirmDialog(
                        'Permanently Delete User',
                        `Are you sure you want to permanently delete ${selectedUser.name}?`,
                        () => handleForceDelete(selectedUser.id)
                    );
                    break;
                default:
                    break;
            }
            return;
        }

        switch (actionType) {
            case 'edit':
                setEditingUser(selectedUser);
                setOpenModal(true);
                break;
            case 'activate':
                try {
                    await updateUser(selectedUser.id, { status: 'active' });
                    showSnackbar({ type: 'success', message: 'User activated successfully' });
                    await getUsers();
                } catch (err) {
                    showSnackbar({ type: 'error', message: 'Failed to activate user' });
                }
                break;
            case 'deactivate':
                openConfirmDialog(
                    'Deactivate User',
                    `Are you sure you want to deactivate ${selectedUser.name}?`,
                    () => updateUser(selectedUser.id, { status: 'inactive' })
                );
                break;
            case 'suspend':
                openConfirmDialog(
                    'Suspend User',
                    `Are you sure you want to suspend ${selectedUser.name}?`,
                    () => updateUser(selectedUser.id, { status: 'suspended' })
                );
                break;
            case 'delete':
                openConfirmDialog(
                    'Delete User',
                    `Are you sure you want to delete ${selectedUser.name}?`,
                    () => deleteUser(selectedUser.id)
                );
                break;
            case 'reset_password':
                setPasswordDialog({
                    open: true,
                    userId: selectedUser.id,
                    userName: selectedUser.name,
                    password: '',
                    confirmPassword: '',
                    error: '',
                });
                break;
            case 'resend_otp':
                try {
                    await userService.resendOtp(selectedUser.id);
                    showSnackbar({ type: 'success', message: 'OTP sent successfully' });
                } catch (err) {
                    showSnackbar({ type: 'error', message: 'Failed to send OTP' });
                }
                break;
            default:
                break;
        }
    };

    const handleConfirm = async () => {
        if (!confirmDialog.action) return;
        const action = confirmDialog.action;
        setConfirmDialog(prev => ({ ...prev, open: false }));

        try {
            await action();
            showSnackbar({ type: 'success', message: 'Action completed successfully' });
            if (showDeleted) {
                await fetchDeletedUsers();
            } else {
                await getUsers();
            }
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Action failed' });
        }
    };

    const handlePasswordReset = async () => {
        const { userId, password, confirmPassword } = passwordDialog;

        if (!password || password.length < 8) {
            setPasswordDialog(prev => ({ ...prev, error: 'Password must be at least 8 characters' }));
            return;
        }
        if (password !== confirmPassword) {
            setPasswordDialog(prev => ({ ...prev, error: 'Passwords do not match' }));
            return;
        }

        try {
            await userService.resetUserPassword(userId, password);
            showSnackbar({ type: 'success', message: 'Password reset successfully' });
            setPasswordDialog({ open: false, userId: null, userName: '', password: '', confirmPassword: '', error: '' });
            await getUsers();
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Failed to reset password' });
            setPasswordDialog(prev => ({ ...prev, error: err.message || 'Failed to reset password' }));
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

    const getUserRoleName = (user) => {
        if (!user?.roles || !Array.isArray(user.roles) || user.roles.length === 0) {
            return '-';
        }
        const role = user.roles[0];
        return role.display_name || role.name || '-';
    };

    if (!canView) {
        return (
            <Box p={3}>
                <Paper sx={{ p: 3, textAlign: 'center', backgroundColor: colors.light }}>
                    <Typography color="error">You do not have permission to view users.</Typography>
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
                        <Button color="inherit" size="small" onClick={() => { clearError(); getUsers(); }}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    const currentData = showDeleted ? deletedUsers : sortedData;
    const isLoading = showDeleted ? loadingDeleted : loading;
    const totalCount = showDeleted ? trashedTotal : sortedData.length;

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
                            User Management
                        </Typography>
                        <Box display="flex" alignItems="center" gap={2}>
                            <FormControlLabel
                                control={
                                    <Switch
                                        checked={showDeleted}
                                        onChange={(e) => {
                                            setShowDeleted(e.target.checked);
                                            setPage(0);
                                        }}
                                        sx={{
                                            '& .MuiSwitch-switchBase.Mui-checked': {
                                                color: colors.sea,
                                            },
                                            '& .MuiSwitch-switchBase.Mui-checked + .MuiSwitch-track': {
                                                backgroundColor: colors.sea,
                                            },
                                        }}
                                    />
                                }
                                label="Show Deleted"
                            />
                            {canCreate && !showDeleted && (
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => { setEditingUser(null); setOpenModal(true); }}
                                    size={isMobile ? "small" : "medium"}
                                    sx={{
                                        borderRadius: 2,
                                        backgroundColor: colors.salat,
                                        '&:hover': { backgroundColor: colors.dark }
                                    }}
                                >
                                    Add User
                                </Button>
                            )}
                        </Box>
                    </Box>

                    {/* Filters */}
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
                        {!showDeleted && (
                            <>
                                <TextField
                                    select
                                    label="Status"
                                    size="small"
                                    value={statusFilter}
                                    onChange={(e) => setStatusFilter(e.target.value)}
                                    sx={{
                                        minWidth: { xs: '100%', sm: 140 },
                                        '& .MuiInputBase-root': {
                                            backgroundColor: colors.sky,
                                            borderRadius: 2,
                                        },
                                        '& .MuiOutlinedInput-notchedOutline': {
                                            borderColor: colors.middle,
                                        },
                                    }}
                                >
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="active">Active</MenuItem>
                                    <MenuItem value="inactive">Inactive</MenuItem>
                                    <MenuItem value="pending">Pending</MenuItem>
                                    <MenuItem value="suspended">Suspended</MenuItem>
                                </TextField>
                                <TextField
                                    select
                                    label="Role"
                                    size="small"
                                    value={roleFilter}
                                    onChange={(e) => setRoleFilter(e.target.value)}
                                    sx={{
                                        minWidth: { xs: '100%', sm: 160 },
                                        '& .MuiInputBase-root': {
                                            backgroundColor: colors.sky,
                                            borderRadius: 2,
                                        },
                                        '& .MuiOutlinedInput-notchedOutline': {
                                            borderColor: colors.middle,
                                        },
                                    }}
                                >
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="ADMINISTRATOR">Administrator</MenuItem>
                                    <MenuItem value="MANAGER">Manager</MenuItem>
                                    <MenuItem value="MONITORING_OFFICER">Monitoring Officer</MenuItem>
                                    <MenuItem value="FUNDI">Fundi</MenuItem>
                                    <MenuItem value="CUSTOMER">Customer</MenuItem>
                                </TextField>
                            </>
                        )}
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={() => showDeleted ? fetchDeletedUsers() : getUsers()}
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

                {/* Table View */}
                {showTableView ? (
                    <TableContainer sx={{ width: '100%', overflowX: 'auto' }}>
                        <Table sx={{ width: '100%', minWidth: 800 }}>
                            <TableHead>
                                <TableRow sx={{ backgroundColor: colors.sky }}>
                                    {headCells.map((cell) => (
                                        <TableCell key={cell.id} sx={{ fontWeight: 'bold', color: colors.dark, whiteSpace: 'nowrap' }}>
                                            {!cell.disableSort && !showDeleted ? (
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
                                {isLoading ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center">
                                            <CircularProgress size={32} sx={{ color: colors.sea, my: 3 }} />
                                        </TableCell>
                                    </TableRow>
                                ) : currentData.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center">
                                            <Typography sx={{ py: 3, color: colors.rain }}>
                                                {showDeleted ? 'No deleted users found' : 'No users found'}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    currentData.map((user) => (
                                        <TableRow key={user.id} hover>
                                            <TableCell sx={{ color: colors.black }}>{user.name}</TableCell>
                                            <TableCell sx={{ color: colors.black }}>{user.email}</TableCell>
                                            <TableCell sx={{ color: colors.black }}>{user.phone || '-'}</TableCell>
                                            <TableCell>
                                                <Chip
                                                    label={getUserRoleName(user)}
                                                    size="small"
                                                    sx={{
                                                        backgroundColor: colors.wave,
                                                        color: colors.sea,
                                                    }}
                                                />
                                            </TableCell>
                                            <TableCell>
                                                {showDeleted ? (
                                                    <Chip label="Deleted" color="error" size="small" />
                                                ) : (
                                                    <Chip
                                                        label={user.status || 'pending'}
                                                        sx={{
                                                            backgroundColor: user.status === 'active' ? colors.salat :
                                                                user.status === 'suspended' ? '#fee2e2' :
                                                                    user.status === 'inactive' ? '#fef3c7' :
                                                                        user.status === 'pending' ? '#dbeafe' : colors.sky,
                                                            color: user.status === 'active' ? colors.light :
                                                                user.status === 'suspended' ? '#991b1b' :
                                                                    user.status === 'inactive' ? '#92400e' :
                                                                        user.status === 'pending' ? '#1e40af' : colors.rain,
                                                        }}
                                                        size="small"
                                                    />
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                {!showDeleted && (
                                                    user.email_verified_at ? (
                                                        <Chip label="Verified" size="small" icon={<VerifiedIcon sx={{ fontSize: 14 }} />} sx={{ backgroundColor: colors.salat, color: colors.light }} />
                                                    ) : (
                                                        <Chip label="Not Verified" size="small" sx={{ backgroundColor: colors.sky, color: colors.rain }} />
                                                    )
                                                )}
                                            </TableCell>
                                            <TableCell sx={{ color: colors.black }}>
                                                {formatDate(user.created_at)}
                                            </TableCell>
                                            <TableCell align="center">
                                                <IconButton
                                                    size="small"
                                                    onClick={(e) => handleMenuOpen(e, user)}
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
                        {isLoading ? (
                            <Box display="flex" justifyContent="center" py={4}>
                                <CircularProgress sx={{ color: colors.sea }} />
                            </Box>
                        ) : currentData.length === 0 ? (
                            <Paper variant="outlined" sx={{ p: 4, textAlign: 'center', borderColor: colors.middle }}>
                                <Typography sx={{ color: colors.rain }}>
                                    {showDeleted ? 'No deleted users found' : 'No users found'}
                                </Typography>
                            </Paper>
                        ) : (
                            currentData.map((user) => (
                                <Card key={user.id} sx={{ mb: 2, borderRadius: 2, border: `1px solid ${colors.middle}` }}>
                                    <CardContent sx={{ p: 2, backgroundColor: colors.light }}>
                                        <Box display="flex" justifyContent="space-between" alignItems="flex-start" mb={1.5}>
                                            <Box display="flex" alignItems="center" gap={1}>
                                                <PersonIcon fontSize="small" sx={{ color: colors.rain }} />
                                                <Typography variant="body1" fontWeight="medium" sx={{ color: colors.dark }}>
                                                    {user.name}
                                                </Typography>
                                            </Box>
                                            <IconButton
                                                size="small"
                                                onClick={(e) => handleMenuOpen(e, user)}
                                                sx={{ color: colors.rain }}
                                            >
                                                <MoreVertIcon fontSize="small" />
                                            </IconButton>
                                        </Box>

                                        <Box display="flex" alignItems="center" gap={1} mb={1}>
                                            <EmailOutlinedIcon fontSize="small" sx={{ color: colors.rain }} />
                                            <Typography variant="body2" sx={{ color: colors.black }}>{user.email}</Typography>
                                        </Box>

                                        {user.phone && (
                                            <Box display="flex" alignItems="center" gap={1} mb={1}>
                                                <PhoneIcon fontSize="small" sx={{ color: colors.rain }} />
                                                <Typography variant="body2" sx={{ color: colors.black }}>{user.phone}</Typography>
                                            </Box>
                                        )}

                                        <Box display="flex" alignItems="center" gap={1} mb={1}>
                                            <WorkIcon fontSize="small" sx={{ color: colors.rain }} />
                                            <Typography variant="body2" sx={{ color: colors.black }}>
                                                {getUserRoleName(user)}
                                            </Typography>
                                        </Box>

                                        <Divider sx={{ my: 1, borderColor: colors.middle }} />

                                        <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={1}>
                                            <Box display="flex" gap={1} flexWrap="wrap">
                                                {showDeleted ? (
                                                    <Chip label="Deleted" color="error" size="small" />
                                                ) : (
                                                    <Chip
                                                        label={user.status || 'pending'}
                                                        sx={{
                                                            backgroundColor: user.status === 'active' ? colors.salat :
                                                                user.status === 'suspended' ? '#fee2e2' :
                                                                    user.status === 'inactive' ? '#fef3c7' :
                                                                        user.status === 'pending' ? '#dbeafe' : colors.sky,
                                                            color: user.status === 'active' ? colors.light :
                                                                user.status === 'suspended' ? '#991b1b' :
                                                                    user.status === 'inactive' ? '#92400e' :
                                                                        user.status === 'pending' ? '#1e40af' : colors.rain,
                                                        }}
                                                        size="small"
                                                    />
                                                )}
                                                {!showDeleted && (
                                                    user.email_verified_at ? (
                                                        <Chip label="Verified" size="small" icon={<VerifiedIcon sx={{ fontSize: 14 }} />} sx={{ backgroundColor: colors.salat, color: colors.light }} />
                                                    ) : (
                                                        <Chip label="Not Verified" size="small" sx={{ backgroundColor: colors.sky, color: colors.rain }} />
                                                    )
                                                )}
                                            </Box>
                                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                                Created: {formatDate(user.created_at)}
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
                        count={totalCount}
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
                {(() => {
                    const menuItems = [];
                    if (showDeleted) {
                        if (canRestore) {
                            menuItems.push(
                                <MenuItem key="restore" onClick={() => handleAction('restore')}>
                                    <RestoreIcon sx={{ mr: 1, color: 'success.main', fontSize: 20 }} /> Restore
                                </MenuItem>
                            );
                        }
                        if (canDelete) {
                            menuItems.push(
                                <MenuItem key="force_delete" onClick={() => handleAction('force_delete')} sx={{ color: 'error.main' }}>
                                    <DeleteSweepIcon sx={{ mr: 1, fontSize: 20 }} /> Permanently Delete
                                </MenuItem>
                            );
                        }
                    } else {
                        if (canEdit) {
                            menuItems.push(
                                <MenuItem key="edit" onClick={() => handleAction('edit')}>
                                    <EditIcon sx={{ mr: 1, fontSize: 20, color: colors.sea }} /> Edit
                                </MenuItem>
                            );
                        }
                        if (canActivate && selectedUser?.status !== 'active') {
                            menuItems.push(
                                <MenuItem key="activate" onClick={() => handleAction('activate')}>
                                    <VerifiedIcon sx={{ mr: 1, color: 'success.main', fontSize: 20 }} /> Activate
                                </MenuItem>
                            );
                        }
                        if (canDeactivate && selectedUser?.status === 'active') {
                            menuItems.push(
                                <MenuItem key="deactivate" onClick={() => handleAction('deactivate')}>
                                    <BlockIcon sx={{ mr: 1, color: 'warning.main', fontSize: 20 }} /> Deactivate
                                </MenuItem>
                            );
                        }
                        if (canSuspend && selectedUser?.status !== 'suspended') {
                            menuItems.push(
                                <MenuItem key="suspend" onClick={() => handleAction('suspend')}>
                                    <LockOpenIcon sx={{ mr: 1, color: 'error.main', fontSize: 20 }} /> Suspend
                                </MenuItem>
                            );
                        }
                        if (canResetPassword) {
                            menuItems.push(
                                <MenuItem key="reset_password" onClick={() => handleAction('reset_password')}>
                                    <VpnKeyIcon sx={{ mr: 1, fontSize: 20 }} /> Reset Password
                                </MenuItem>
                            );
                        }
                        if (!selectedUser?.email_verified_at) {
                            menuItems.push(
                                <MenuItem key="resend_otp" onClick={() => handleAction('resend_otp')}>
                                    <EmailIcon sx={{ mr: 1, fontSize: 20 }} /> Resend OTP
                                </MenuItem>
                            );
                        }
                        if (canDelete) {
                            menuItems.push(
                                <MenuItem key="delete" onClick={() => handleAction('delete')} sx={{ color: 'error.main' }}>
                                    <DeleteIcon sx={{ mr: 1, fontSize: 20 }} /> Delete
                                </MenuItem>
                            );
                        }
                    }
                    return menuItems;
                })()}
            </Menu>

            {/* User Form Modal */}
            <UserFormModal
                open={openModal}
                onClose={() => {
                    setOpenModal(false);
                    setEditingUser(null);
                    getUsers();
                }}
                user={editingUser}
            />

            {/* Password Reset Dialog */}
            <Dialog
                open={passwordDialog.open}
                onClose={() => setPasswordDialog({ open: false, userId: null, userName: '', password: '', confirmPassword: '', error: '' })}
                maxWidth="xs"
                fullWidth
                PaperProps={{ sx: { borderRadius: 2, backgroundColor: colors.light } }}
            >
                <DialogTitle sx={{ color: colors.dark }}>
                    Reset Password for {passwordDialog.userName}
                </DialogTitle>
                <DialogContent>
                    <TextField
                        fullWidth
                        type="password"
                        label="New Password"
                        value={passwordDialog.password}
                        onChange={(e) => setPasswordDialog(prev => ({ ...prev, password: e.target.value, error: '' }))}
                        margin="dense"
                        size="small"
                        error={!!passwordDialog.error}
                        helperText={passwordDialog.error}
                        sx={{
                            '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                            '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                        }}
                    />
                    <TextField
                        fullWidth
                        type="password"
                        label="Confirm Password"
                        value={passwordDialog.confirmPassword}
                        onChange={(e) => setPasswordDialog(prev => ({ ...prev, confirmPassword: e.target.value, error: '' }))}
                        margin="dense"
                        size="small"
                        error={!!passwordDialog.error}
                        helperText={passwordDialog.error}
                        sx={{
                            '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                            '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                        }}
                    />
                </DialogContent>
                <DialogActions sx={{ p: 2, pt: 0 }}>
                    <Button
                        onClick={() => setPasswordDialog({ open: false, userId: null, userName: '', password: '', confirmPassword: '', error: '' })}
                        sx={{ color: colors.rain }}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handlePasswordReset}
                        variant="contained"
                        sx={{ backgroundColor: colors.sea, '&:hover': { backgroundColor: colors.dark } }}
                    >
                        Reset Password
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Confirmation Dialog */}
            <Dialog
                open={confirmDialog.open}
                onClose={() => setConfirmDialog(prev => ({ ...prev, open: false }))}
                fullWidth
                maxWidth="xs"
                PaperProps={{ sx: { borderRadius: 2, backgroundColor: colors.light } }}
            >
                <DialogTitle sx={{ color: colors.dark }}>{confirmDialog.title}</DialogTitle>
                <DialogContent>
                    <Typography sx={{ color: colors.black }}>{confirmDialog.message}</Typography>
                </DialogContent>
                <DialogActions sx={{ p: 2, pt: 0 }}>
                    <Button onClick={() => setConfirmDialog(prev => ({ ...prev, open: false }))} sx={{ color: colors.rain }}>
                        Cancel
                    </Button>
                    <Button
                        onClick={handleConfirm}
                        variant="contained"
                        sx={{ backgroundColor: 'error.main', '&:hover': { backgroundColor: 'error.dark' } }}
                    >
                        Confirm
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default UsersList;