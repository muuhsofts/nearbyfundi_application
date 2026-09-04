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
    Avatar,
    Tooltip,
    Stack,
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
    People as PeopleIcon,
    Handyman as HandymanIcon,
    SupportAgent as SupportIcon,
    AdminPanelSettings as AdminIcon,
    CheckCircle as CheckCircleIcon,
    Cancel as CancelIcon,
    Pending as PendingIcon,
    Phone as PhoneIcon,
    Work as WorkIcon,
    Clear as ClearIcon,
} from '@mui/icons-material';
import { useUserManagement } from 'hooks/useUser';
import { usePermissions } from 'hooks/usePermissions';
import { userService } from 'services/user.service';
import { showSnackbar } from 'utils/snackbar';
import UserFormModal from './UserFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

// High-contrast status styles
const statusStyles = {
    active: {
        color: '#047857',
        bg: '#d1fae5',
        border: '#10b981',
        label: 'Active',
        icon: <CheckCircleIcon sx={{ fontSize: 16 }} />,
    },
    inactive: {
        color: '#4b5563',
        bg: '#f3f4f6',
        border: '#9ca3af',
        label: 'Inactive',
        icon: <CancelIcon sx={{ fontSize: 16 }} />,
    },
    pending: {
        color: '#b45309',
        bg: '#fef3c7',
        border: '#f59e0b',
        label: 'Pending',
        icon: <PendingIcon sx={{ fontSize: 16 }} />,
    },
    suspended: {
        color: '#b91c1c',
        bg: '#fee2e2',
        border: '#ef4444',
        label: 'Suspended',
        icon: <BlockIcon sx={{ fontSize: 16 }} />,
    },
};

const headCells = [
    { id: 'name', label: 'User' },
    { id: 'email', label: 'Email' },
    { id: 'phone', label: 'Phone' },
    { id: 'role', label: 'Role' },
    { id: 'status', label: 'Status' },
    { id: 'subscription', label: 'Subscription' },
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
        verifyUserOtp,
        markUserVerified,
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

    const [verifyOtpDialog, setVerifyOtpDialog] = useState({
        open: false,
        userId: null,
        userName: '',
        otp: '',
        error: '',
    });

    const [search, setSearch] = useState('');
    const [statusFilter, setStatusFilter] = useState('');
    const [roleFilter, setRoleFilter] = useState('');
    const [order, setOrder] = useState('desc');
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
    const canVerify = can('users.verify');

    // Fetch users when filters change
    useEffect(() => {
        if (!showDeleted && canView) {
            getUsers({
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
                status: statusFilter || undefined,
            });
        }
    }, [page, rowsPerPage, showDeleted, search, statusFilter, getUsers, canView]);

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
            filtered = filtered.filter(
                (user) =>
                    user.name?.toLowerCase().includes(searchLower) ||
                    user.email?.toLowerCase().includes(searchLower) ||
                    user.phone?.toLowerCase().includes(searchLower)
            );
        }

        if (statusFilter) {
            filtered = filtered.filter((user) => user.status === statusFilter);
        }

        if (roleFilter) {
            filtered = filtered.filter((user) => {
                if (!user.roles || user.roles.length === 0) return false;
                return user.roles.some((role) => role.name === roleFilter);
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
                case 'subscription':
                    aValue = a.subscription_status || 'inactive';
                    bValue = b.subscription_status || 'inactive';
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

    const handleMenuClose = () => setActionMenu(null);

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
            case 'verify_otp':
                setVerifyOtpDialog({
                    open: true,
                    userId: selectedUser.id,
                    userName: selectedUser.name,
                    otp: '',
                    error: '',
                });
                break;
            case 'mark_verified':
                openConfirmDialog(
                    'Mark as Verified',
                    `Are you sure you want to mark ${selectedUser.name} as verified without OTP? This will activate the account immediately.`,
                    () => handleMarkVerified(selectedUser.id)
                );
                break;
            default:
                break;
        }
    };

    const handleMarkVerified = async (userId) => {
        try {
            await markUserVerified(userId);
            showSnackbar({ type: 'success', message: 'User marked as verified successfully' });
            await getUsers();
        } catch (err) {
            showSnackbar({
                type: 'error',
                message: err.response?.data?.message || 'Failed to mark user as verified',
            });
        }
    };

    const handleVerifyOtp = async () => {
        const { userId, otp } = verifyOtpDialog;

        if (!otp || otp.length !== 6) {
            setVerifyOtpDialog((prev) => ({ ...prev, error: 'Please enter a valid 6-digit OTP' }));
            return;
        }

        try {
            await verifyUserOtp(userId, otp);
            showSnackbar({ type: 'success', message: 'User verified and activated successfully' });
            setVerifyOtpDialog({ open: false, userId: null, userName: '', otp: '', error: '' });
            await getUsers();
        } catch (err) {
            const errorMessage = err.response?.data?.message || 'Failed to verify OTP';
            showSnackbar({ type: 'error', message: errorMessage });
            setVerifyOtpDialog((prev) => ({ ...prev, error: errorMessage }));
        }
    };

    const handleConfirm = async () => {
        if (!confirmDialog.action) return;
        const action = confirmDialog.action;
        setConfirmDialog((prev) => ({ ...prev, open: false }));

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
            setPasswordDialog((prev) => ({ ...prev, error: 'Password must be at least 8 characters' }));
            return;
        }
        if (password !== confirmPassword) {
            setPasswordDialog((prev) => ({ ...prev, error: 'Passwords do not match' }));
            return;
        }

        try {
            await userService.resetUserPassword(userId, password);
            showSnackbar({ type: 'success', message: 'Password reset successfully' });
            setPasswordDialog({
                open: false,
                userId: null,
                userName: '',
                password: '',
                confirmPassword: '',
                error: '',
            });
            await getUsers();
        } catch (err) {
            showSnackbar({ type: 'error', message: 'Failed to reset password' });
            setPasswordDialog((prev) => ({
                ...prev,
                error: err.message || 'Failed to reset password',
            }));
        }
    };

    const formatDate = (dateStr) => {
        if (!dateStr) return '—';
        try {
            return new Date(dateStr).toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
            });
        } catch {
            return '—';
        }
    };

    const getUserRoleName = (user) => {
        if (!user?.roles || !Array.isArray(user.roles) || user.roles.length === 0) {
            return 'User';
        }
        const role = user.roles[0];
        return role.display_name || role.name || 'User';
    };

    const getRoleIcon = (user) => {
        if (!user?.roles || !Array.isArray(user.roles) || user.roles.length === 0) {
            return <PeopleIcon fontSize="small" />;
        }
        const roleName = user.roles[0]?.name || '';
        switch (roleName) {
            case 'ADMINISTRATOR':
                return <AdminIcon fontSize="small" />;
            case 'MONITORING_OFFICER':
                return <SupportIcon fontSize="small" />;
            case 'FUNDI':
                return <HandymanIcon fontSize="small" />;
            default:
                return <PeopleIcon fontSize="small" />;
        }
    };

    const getStatusChip = (status) => {
        const s = statusStyles[status] || statusStyles.inactive;
        return (
            <Chip
                icon={s.icon}
                label={s.label}
                size="small"
                sx={{
                    backgroundColor: s.bg,
                    color: s.color,
                    fontWeight: 700,
                    border: `1.5px solid ${s.border}`,
                    height: 28,
                    '& .MuiChip-icon': { color: s.color },
                    '& .MuiChip-label': { px: 1 },
                }}
            />
        );
    };

    const getSubscriptionStatus = (user) => {
        const status = user.subscription_status || 'inactive';
        const expiresAt = user.subscription_expires_at;

        if (status === 'active' && expiresAt) {
            const expiry = new Date(expiresAt);
            const now = new Date();
            if (expiry < now) {
                return { label: 'Expired', color: '#b91c1c', bg: '#fee2e2', border: '#ef4444' };
            }
            const days = Math.ceil((expiry - now) / (1000 * 60 * 60 * 24));
            return { label: `${days}d left`, color: '#047857', bg: '#d1fae5', border: '#10b981' };
        }

        const map = {
            active: { label: 'Active', color: '#047857', bg: '#d1fae5', border: '#10b981' },
            inactive: { label: 'Inactive', color: '#4b5563', bg: '#f3f4f6', border: '#9ca3af' },
            expired: { label: 'Expired', color: '#b91c1c', bg: '#fee2e2', border: '#ef4444' },
            pending: { label: 'Pending', color: '#b45309', bg: '#fef3c7', border: '#f59e0b' },
        };
        return map[status] || map.inactive;
    };

    // ── Permission / Error states ───────────────────────────────────────────
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
                        You do not have permission to view users.
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
                    variant="filled"
                    action={
                        <Button color="inherit" size="small" onClick={() => { clearError(); getUsers(); }}>
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

    const currentData = showDeleted ? deletedUsers : sortedData;
    const isLoading = showDeleted ? loadingDeleted : loading;
    const totalCount = showDeleted ? trashedTotal : sortedData.length;

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
                {/* ── Header ──────────────────────────────────────────────── */}
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
                                User Management
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                Manage accounts, roles and verification status
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} alignItems="center" justifyContent={{ xs: 'space-between', sm: 'flex-end' }}>
                            <FormControlLabel
                                control={
                                    <Switch
                                        checked={showDeleted}
                                        onChange={(e) => {
                                            setShowDeleted(e.target.checked);
                                            setPage(0);
                                        }}
                                        color="primary"
                                    />
                                }
                                label={
                                    <Typography variant="body2" fontWeight={600}>
                                        Show Deleted
                                    </Typography>
                                }
                            />

                            {canCreate && !showDeleted && (
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => {
                                        setEditingUser(null);
                                        setOpenModal(true);
                                    }}
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
                                    Add User
                                </Button>
                            )}
                        </Stack>
                    </Stack>

                    {/* Filters */}
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        spacing={1.5}
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        flexWrap="wrap"
                    >
                        <TextField
                            placeholder="Search name, email, phone…"
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
                                        '& .MuiOutlinedInput-root': {
                                            borderRadius: 2,
                                            bgcolor: 'action.hover',
                                            '& fieldset': { borderColor: 'transparent' },
                                            '&:hover fieldset': { borderColor: 'divider' },
                                        },
                                    }}
                                >
                                    <MenuItem value="">All statuses</MenuItem>
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
                                        minWidth: { xs: '100%', sm: 170 },
                                        '& .MuiOutlinedInput-root': {
                                            borderRadius: 2,
                                            bgcolor: 'action.hover',
                                            '& fieldset': { borderColor: 'transparent' },
                                            '&:hover fieldset': { borderColor: 'divider' },
                                        },
                                    }}
                                >
                                    <MenuItem value="">All roles</MenuItem>
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
                            onClick={() => (showDeleted ? fetchDeletedUsers() : getUsers())}
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

                {/* ── Table (desktop) ─────────────────────────────────────── */}
                {showTableView ? (
                    <TableContainer>
                        <Table sx={{ minWidth: 960 }}>
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
                                            {!cell.disableSort && !showDeleted ? (
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
                                {isLoading ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                            <CircularProgress size={36} thickness={4} />
                                        </TableCell>
                                    </TableRow>
                                ) : currentData.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center" sx={{ py: 8 }}>
                                            <Typography color="text.secondary" fontWeight={500}>
                                                {showDeleted ? 'No deleted users found' : 'No users found'}
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    currentData.map((user) => {
                                        const subscriptionStatus = getSubscriptionStatus(user);
                                        const isVerified = !!user.email_verified_at;

                                        return (
                                            <TableRow
                                                key={user.id}
                                                hover
                                                sx={{
                                                    '&:last-child td': { borderBottom: 0 },
                                                    transition: 'background-color 0.15s',
                                                }}
                                            >
                                                {/* User */}
                                                <TableCell sx={{ py: 2 }}>
                                                    <Stack direction="row" spacing={1.5} alignItems="center">
                                                        <Avatar
                                                            sx={{
                                                                width: 40,
                                                                height: 40,
                                                                bgcolor: isVerified
                                                                    ? colors.salat || '#10b981'
                                                                    : '#64748b',
                                                                fontSize: 15,
                                                                fontWeight: 700,
                                                            }}
                                                        >
                                                            {user.name?.[0]?.toUpperCase() || 'U'}
                                                        </Avatar>
                                                        <Box>
                                                            <Typography variant="body2" fontWeight={600} color="text.primary">
                                                                {user.name}
                                                            </Typography>
                                                            <Typography variant="caption" color="text.secondary">
                                                                ID: {user.id}
                                                            </Typography>
                                                        </Box>
                                                    </Stack>
                                                </TableCell>

                                                {/* Email */}
                                                <TableCell>
                                                    <Typography variant="body2" fontWeight={500}>
                                                        {user.email}
                                                    </Typography>
                                                    {isVerified ? (
                                                        <Chip
                                                            label="Verified"
                                                            size="small"
                                                            icon={<VerifiedIcon sx={{ fontSize: 12 }} />}
                                                            sx={{
                                                                mt: 0.5,
                                                                height: 22,
                                                                fontWeight: 700,
                                                                bgcolor: '#d1fae5',
                                                                color: '#047857',
                                                                border: '1px solid #10b981',
                                                                '& .MuiChip-label': { fontSize: 11, px: 0.75 },
                                                                '& .MuiChip-icon': { color: '#047857' },
                                                            }}
                                                        />
                                                    ) : (
                                                        user.status !== 'deleted' && (
                                                            <Chip
                                                                label="Unverified"
                                                                size="small"
                                                                sx={{
                                                                    mt: 0.5,
                                                                    height: 22,
                                                                    fontWeight: 700,
                                                                    bgcolor: '#f3f4f6',
                                                                    color: '#4b5563',
                                                                    border: '1px solid #9ca3af',
                                                                    '& .MuiChip-label': { fontSize: 11, px: 0.75 },
                                                                }}
                                                            />
                                                        )
                                                    )}
                                                </TableCell>

                                                {/* Phone */}
                                                <TableCell>
                                                    <Typography variant="body2" fontWeight={500}>
                                                        {user.phone || '—'}
                                                    </Typography>
                                                </TableCell>

                                                {/* Role */}
                                                <TableCell>
                                                    <Chip
                                                        icon={getRoleIcon(user)}
                                                        label={getUserRoleName(user)}
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 600,
                                                            bgcolor: 'action.hover',
                                                            color: 'text.primary',
                                                            border: '1px solid',
                                                            borderColor: 'divider',
                                                            height: 28,
                                                            '& .MuiChip-icon': { color: 'text.secondary' },
                                                        }}
                                                    />
                                                </TableCell>

                                                {/* Status */}
                                                <TableCell>
                                                    {showDeleted ? (
                                                        <Chip
                                                            label="Deleted"
                                                            size="small"
                                                            sx={{
                                                                fontWeight: 700,
                                                                bgcolor: '#fee2e2',
                                                                color: '#b91c1c',
                                                                border: '1.5px solid #ef4444',
                                                                height: 28,
                                                            }}
                                                        />
                                                    ) : (
                                                        getStatusChip(user.status)
                                                    )}
                                                </TableCell>

                                                {/* Subscription */}
                                                <TableCell>
                                                    <Chip
                                                        label={subscriptionStatus.label}
                                                        size="small"
                                                        sx={{
                                                            fontWeight: 700,
                                                            bgcolor: subscriptionStatus.bg,
                                                            color: subscriptionStatus.color,
                                                            border: `1.5px solid ${subscriptionStatus.border}`,
                                                            height: 28,
                                                        }}
                                                    />
                                                </TableCell>

                                                {/* Created */}
                                                <TableCell>
                                                    <Typography variant="body2" fontWeight={500} color="text.secondary">
                                                        {formatDate(user.created_at)}
                                                    </Typography>
                                                </TableCell>

                                                {/* Actions */}
                                                <TableCell align="center">
                                                    <IconButton
                                                        size="small"
                                                        onClick={(e) => handleMenuOpen(e, user)}
                                                        sx={{
                                                            color: 'text.secondary',
                                                            '&:hover': {
                                                                bgcolor: 'action.hover',
                                                                color: 'text.primary',
                                                            },
                                                        }}
                                                    >
                                                        <MoreVertIcon />
                                                    </IconButton>
                                                </TableCell>
                                            </TableRow>
                                        );
                                    })
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                ) : (
                    /* ── Mobile cards ────────────────────────────────────── */
                    <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
                        {isLoading ? (
                            <Box display="flex" justifyContent="center" py={6}>
                                <CircularProgress size={36} thickness={4} />
                            </Box>
                        ) : currentData.length === 0 ? (
                            <Paper
                                variant="outlined"
                                sx={{
                                    p: 5,
                                    textAlign: 'center',
                                    borderRadius: 3,
                                    borderStyle: 'dashed',
                                }}
                            >
                                <Typography color="text.secondary" fontWeight={500}>
                                    {showDeleted ? 'No deleted users found' : 'No users found'}
                                </Typography>
                            </Paper>
                        ) : (
                            <Stack spacing={2}>
                                {currentData.map((user) => {
                                    const subscriptionStatus = getSubscriptionStatus(user);
                                    const isVerified = !!user.email_verified_at;

                                    return (
                                        <Card
                                            key={user.id}
                                            elevation={0}
                                            sx={{
                                                borderRadius: 3,
                                                border: '1px solid',
                                                borderColor: 'divider',
                                                overflow: 'hidden',
                                            }}
                                        >
                                            <CardContent sx={{ p: 2.25 }}>
                                                <Stack
                                                    direction="row"
                                                    justifyContent="space-between"
                                                    alignItems="flex-start"
                                                    mb={1.5}
                                                >
                                                    <Stack direction="row" spacing={1.5} alignItems="center">
                                                        <Avatar
                                                            sx={{
                                                                width: 44,
                                                                height: 44,
                                                                bgcolor: isVerified
                                                                    ? colors.salat || '#10b981'
                                                                    : '#64748b',
                                                                fontSize: 16,
                                                                fontWeight: 700,
                                                            }}
                                                        >
                                                            {user.name?.[0]?.toUpperCase() || 'U'}
                                                        </Avatar>
                                                        <Box>
                                                            <Typography variant="body1" fontWeight={700}>
                                                                {user.name}
                                                            </Typography>
                                                            <Typography variant="caption" color="text.secondary">
                                                                ID: {user.id}
                                                            </Typography>
                                                        </Box>
                                                    </Stack>
                                                    <IconButton
                                                        size="small"
                                                        onClick={(e) => handleMenuOpen(e, user)}
                                                        sx={{ color: 'text.secondary' }}
                                                    >
                                                        <MoreVertIcon fontSize="small" />
                                                    </IconButton>
                                                </Stack>

                                                <Stack spacing={1} mb={1.5}>
                                                    <Stack direction="row" spacing={1} alignItems="center">
                                                        <EmailIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                                        <Typography variant="body2" fontWeight={500}>
                                                            {user.email}
                                                        </Typography>
                                                        {isVerified && (
                                                            <VerifiedIcon sx={{ fontSize: 16, color: '#10b981' }} />
                                                        )}
                                                    </Stack>

                                                    {user.phone && (
                                                        <Stack direction="row" spacing={1} alignItems="center">
                                                            <PhoneIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                                            <Typography variant="body2" fontWeight={500}>
                                                                {user.phone}
                                                            </Typography>
                                                        </Stack>
                                                    )}

                                                    <Stack direction="row" spacing={1} alignItems="center">
                                                        <WorkIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                                        <Chip
                                                            icon={getRoleIcon(user)}
                                                            label={getUserRoleName(user)}
                                                            size="small"
                                                            sx={{
                                                                fontWeight: 600,
                                                                bgcolor: 'action.hover',
                                                                border: '1px solid',
                                                                borderColor: 'divider',
                                                                height: 26,
                                                            }}
                                                        />
                                                    </Stack>
                                                </Stack>

                                                <Divider sx={{ my: 1.5 }} />

                                                <Stack
                                                    direction="row"
                                                    justifyContent="space-between"
                                                    alignItems="center"
                                                    flexWrap="wrap"
                                                    gap={1}
                                                >
                                                    <Stack direction="row" spacing={1} flexWrap="wrap">
                                                        {showDeleted ? (
                                                            <Chip
                                                                label="Deleted"
                                                                size="small"
                                                                sx={{
                                                                    fontWeight: 700,
                                                                    bgcolor: '#fee2e2',
                                                                    color: '#b91c1c',
                                                                    border: '1.5px solid #ef4444',
                                                                    height: 26,
                                                                }}
                                                            />
                                                        ) : (
                                                            getStatusChip(user.status)
                                                        )}
                                                        <Chip
                                                            label={subscriptionStatus.label}
                                                            size="small"
                                                            sx={{
                                                                fontWeight: 700,
                                                                bgcolor: subscriptionStatus.bg,
                                                                color: subscriptionStatus.color,
                                                                border: `1.5px solid ${subscriptionStatus.border}`,
                                                                height: 26,
                                                            }}
                                                        />
                                                    </Stack>
                                                    <Typography variant="caption" color="text.secondary" fontWeight={500}>
                                                        Joined {formatDate(user.created_at)}
                                                    </Typography>
                                                </Stack>
                                            </CardContent>
                                        </Card>
                                    );
                                })}
                            </Stack>
                        )}
                    </Box>
                )}

                {/* Pagination */}
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
                                fontWeight: 500,
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
                PaperProps={{
                    elevation: 8,
                    sx: { borderRadius: 2, minWidth: 200, mt: 0.5 },
                }}
            >
                {(() => {
                    const menuItems = [];
                    if (showDeleted) {
                        if (canRestore) {
                            menuItems.push(
                                <MenuItem key="restore" onClick={() => handleAction('restore')} sx={{ fontWeight: 500 }}>
                                    <RestoreIcon sx={{ mr: 1.5, color: '#10b981', fontSize: 20 }} /> Restore
                                </MenuItem>
                            );
                        }
                        if (canDelete) {
                            menuItems.push(
                                <MenuItem
                                    key="force_delete"
                                    onClick={() => handleAction('force_delete')}
                                    sx={{ color: 'error.main', fontWeight: 500 }}
                                >
                                    <DeleteSweepIcon sx={{ mr: 1.5, fontSize: 20 }} /> Permanently Delete
                                </MenuItem>
                            );
                        }
                    } else {
                        if (canEdit) {
                            menuItems.push(
                                <MenuItem key="edit" onClick={() => handleAction('edit')} sx={{ fontWeight: 500 }}>
                                    <EditIcon sx={{ mr: 1.5, fontSize: 20, color: colors.sea || '#0f766e' }} /> Edit
                                </MenuItem>
                            );
                        }
                        if (canActivate && selectedUser?.status !== 'active') {
                            menuItems.push(
                                <MenuItem key="activate" onClick={() => handleAction('activate')} sx={{ fontWeight: 500 }}>
                                    <VerifiedIcon sx={{ mr: 1.5, color: '#10b981', fontSize: 20 }} /> Activate
                                </MenuItem>
                            );
                        }
                        if (canDeactivate && selectedUser?.status === 'active') {
                            menuItems.push(
                                <MenuItem key="deactivate" onClick={() => handleAction('deactivate')} sx={{ fontWeight: 500 }}>
                                    <BlockIcon sx={{ mr: 1.5, color: '#f59e0b', fontSize: 20 }} /> Deactivate
                                </MenuItem>
                            );
                        }
                        if (canSuspend && selectedUser?.status !== 'suspended') {
                            menuItems.push(
                                <MenuItem key="suspend" onClick={() => handleAction('suspend')} sx={{ fontWeight: 500 }}>
                                    <LockOpenIcon sx={{ mr: 1.5, color: '#ef4444', fontSize: 20 }} /> Suspend
                                </MenuItem>
                            );
                        }
                        if (canResetPassword) {
                            menuItems.push(
                                <MenuItem key="reset_password" onClick={() => handleAction('reset_password')} sx={{ fontWeight: 500 }}>
                                    <VpnKeyIcon sx={{ mr: 1.5, fontSize: 20 }} /> Reset Password
                                </MenuItem>
                            );
                        }
                        if (canVerify && !selectedUser?.email_verified_at && selectedUser?.status !== 'deleted') {
                            menuItems.push(
                                <MenuItem key="verify_otp" onClick={() => handleAction('verify_otp')} sx={{ fontWeight: 500 }}>
                                    <VerifiedIcon sx={{ mr: 1.5, color: '#10b981', fontSize: 20 }} /> Verify OTP
                                </MenuItem>
                            );
                            menuItems.push(
                                <MenuItem key="mark_verified" onClick={() => handleAction('mark_verified')} sx={{ fontWeight: 500 }}>
                                    <VerifiedIcon sx={{ mr: 1.5, color: '#3b82f6', fontSize: 20 }} /> Mark as Verified
                                </MenuItem>
                            );
                        }
                        if (!selectedUser?.email_verified_at && selectedUser?.status !== 'deleted') {
                            menuItems.push(
                                <MenuItem key="resend_otp" onClick={() => handleAction('resend_otp')} sx={{ fontWeight: 500 }}>
                                    <EmailIcon sx={{ mr: 1.5, fontSize: 20 }} /> Resend OTP
                                </MenuItem>
                            );
                        }
                        if (canDelete) {
                            menuItems.push(
                                <MenuItem
                                    key="delete"
                                    onClick={() => handleAction('delete')}
                                    sx={{ color: 'error.main', fontWeight: 500 }}
                                >
                                    <DeleteIcon sx={{ mr: 1.5, fontSize: 20 }} /> Delete
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
                onClose={() =>
                    setPasswordDialog({
                        open: false,
                        userId: null,
                        userName: '',
                        password: '',
                        confirmPassword: '',
                        error: '',
                    })
                }
                maxWidth="xs"
                fullWidth
                PaperProps={{ sx: { borderRadius: 3 } }}
            >
                <DialogTitle sx={{ fontWeight: 700, pb: 1 }}>
                    Reset Password for {passwordDialog.userName}
                </DialogTitle>
                <DialogContent>
                    <TextField
                        fullWidth
                        type="password"
                        label="New Password"
                        value={passwordDialog.password}
                        onChange={(e) =>
                            setPasswordDialog((prev) => ({ ...prev, password: e.target.value, error: '' }))
                        }
                        margin="dense"
                        size="small"
                        error={!!passwordDialog.error}
                        helperText={passwordDialog.error}
                        sx={{
                            '& .MuiOutlinedInput-root': { borderRadius: 2 },
                        }}
                    />
                    <TextField
                        fullWidth
                        type="password"
                        label="Confirm Password"
                        value={passwordDialog.confirmPassword}
                        onChange={(e) =>
                            setPasswordDialog((prev) => ({
                                ...prev,
                                confirmPassword: e.target.value,
                                error: '',
                            }))
                        }
                        margin="dense"
                        size="small"
                        error={!!passwordDialog.error}
                        sx={{
                            '& .MuiOutlinedInput-root': { borderRadius: 2 },
                        }}
                    />
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2.5, pt: 1 }}>
                    <Button
                        onClick={() =>
                            setPasswordDialog({
                                open: false,
                                userId: null,
                                userName: '',
                                password: '',
                                confirmPassword: '',
                                error: '',
                            })
                        }
                        sx={{ fontWeight: 600, textTransform: 'none' }}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handlePasswordReset}
                        variant="contained"
                        sx={{
                            fontWeight: 700,
                            textTransform: 'none',
                            borderRadius: 2,
                            bgcolor: colors.sea || '#0f766e',
                            '&:hover': { bgcolor: colors.dark || '#0d5c56' },
                        }}
                    >
                        Reset Password
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Verify OTP Dialog */}
            <Dialog
                open={verifyOtpDialog.open}
                onClose={() =>
                    setVerifyOtpDialog({ open: false, userId: null, userName: '', otp: '', error: '' })
                }
                maxWidth="xs"
                fullWidth
                PaperProps={{ sx: { borderRadius: 3 } }}
            >
                <DialogTitle sx={{ fontWeight: 700, pb: 1 }}>
                    Verify OTP for {verifyOtpDialog.userName}
                </DialogTitle>
                <DialogContent>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        Enter the 6-digit OTP sent to the user's email/phone.
                    </Typography>
                    <TextField
                        fullWidth
                        type="text"
                        label="OTP Code"
                        value={verifyOtpDialog.otp}
                        onChange={(e) =>
                            setVerifyOtpDialog((prev) => ({
                                ...prev,
                                otp: e.target.value.replace(/\D/g, '').slice(0, 6),
                                error: '',
                            }))
                        }
                        margin="dense"
                        size="small"
                        placeholder="Enter 6-digit OTP"
                        error={!!verifyOtpDialog.error}
                        helperText={verifyOtpDialog.error}
                        inputProps={{ maxLength: 6 }}
                        sx={{
                            '& .MuiOutlinedInput-root': { borderRadius: 2 },
                        }}
                    />
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2.5, pt: 1 }}>
                    <Button
                        onClick={() =>
                            setVerifyOtpDialog({ open: false, userId: null, userName: '', otp: '', error: '' })
                        }
                        sx={{ fontWeight: 600, textTransform: 'none' }}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleVerifyOtp}
                        variant="contained"
                        sx={{
                            fontWeight: 700,
                            textTransform: 'none',
                            borderRadius: 2,
                            bgcolor: colors.salat || '#10b981',
                            '&:hover': { bgcolor: colors.dark || '#047857' },
                        }}
                    >
                        Verify OTP
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Confirmation Dialog */}
            <Dialog
                open={confirmDialog.open}
                onClose={() => setConfirmDialog((prev) => ({ ...prev, open: false }))}
                fullWidth
                maxWidth="xs"
                PaperProps={{ sx: { borderRadius: 3 } }}
            >
                <DialogTitle sx={{ fontWeight: 700, pb: 1 }}>{confirmDialog.title}</DialogTitle>
                <DialogContent>
                    <Typography color="text.secondary">{confirmDialog.message}</Typography>
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2.5, pt: 1 }}>
                    <Button
                        onClick={() => setConfirmDialog((prev) => ({ ...prev, open: false }))}
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
                        Confirm
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default UsersList;