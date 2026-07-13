// src/pages/users/UserFormModal.jsx
import React, { useState, useEffect } from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Button,
    MenuItem,
    Box,
    CircularProgress,
    useMediaQuery,
    useTheme,
    IconButton,
    Typography,
    Alert,
} from '@mui/material';
import { Close as CloseIcon } from '@mui/icons-material';
import { useUserManagement } from 'hooks/useUser';
import { roleService } from "services/role.service";
import { showSnackbar } from "utils/snackbar";
import appConfig from '../../config';

const colors = appConfig.app.colors;

export default function UserFormModal({ open, onClose, user }) {
    const theme = useTheme();
    const fullScreen = useMediaQuery(theme.breakpoints.down('sm'));

    const { createUser, updateUser } = useUserManagement();
    const [loading, setLoading] = useState(false);
    const [roles, setRoles] = useState([]);
    const [loadingOptions, setLoadingOptions] = useState(false);
    const [validationErrors, setValidationErrors] = useState({});

    const [form, setForm] = useState({
        name: '',
        email: '',
        phone: '',
        role: '',
        password: '',
        password_confirmation: '',
        status: 'active',
    });
    const [errors, setErrors] = useState({});

    useEffect(() => {
        if (!open) return;
        const fetchOptions = async () => {
            setLoadingOptions(true);
            try {
                const rolesData = await roleService.getRolesDropdown();
                setRoles(Array.isArray(rolesData) ? rolesData : []);
            } catch (err) {
                console.error('Failed to load options', err);
                setRoles([]);
                showSnackbar({ type: 'error', message: 'Failed to load roles' });
            } finally {
                setLoadingOptions(false);
            }
        };
        fetchOptions();
    }, [open]);

    useEffect(() => {
        if (user) {
            const userRole = user.roles?.[0]?.name || '';
            setForm({
                name: user.name || '',
                email: user.email || '',
                phone: user.phone || '',
                role: userRole,
                status: user.status || 'active',
                password: '',
                password_confirmation: '',
            });
        } else {
            setForm({
                name: '',
                email: '',
                phone: '',
                role: '',
                password: '',
                password_confirmation: '',
                status: 'active',
            });
        }
        setErrors({});
        setValidationErrors({});
    }, [user]);

    const handleChange = (e) => {
        setForm({ ...form, [e.target.name]: e.target.value });
        if (errors[e.target.name]) {
            setErrors({ ...errors, [e.target.name]: '' });
        }
        if (validationErrors[e.target.name]) {
            setValidationErrors({ ...validationErrors, [e.target.name]: '' });
        }
    };

    const validate = () => {
        const newErrors = {};
        if (!form.name.trim()) newErrors.name = 'Name is required';
        if (!form.email.trim()) newErrors.email = 'Email is required';
        if (!form.role) newErrors.role = 'Role is required';
        if (!user) {
            if (!form.password) newErrors.password = 'Password is required';
            if (form.password.length < 8) newErrors.password = 'Password must be at least 8 characters';
            if (form.password !== form.password_confirmation) {
                newErrors.password_confirmation = 'Passwords do not match';
            }
        }
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!validate()) return;

        setLoading(true);
        setValidationErrors({});

        try {
            if (user) {
                await updateUser(user.id, {
                    name: form.name,
                    email: form.email,
                    phone: form.phone || null,
                    status: form.status,
                    role: form.role,
                });
                showSnackbar({ type: 'success', message: 'User updated successfully' });
                onClose(true);
            } else {
                await createUser({
                    name: form.name,
                    email: form.email,
                    phone: form.phone || null,
                    role: form.role,
                    password: form.password,
                    password_confirmation: form.password_confirmation,
                });
                showSnackbar({ type: 'success', message: 'User created successfully' });
                onClose(true);
            }
        } catch (err) {
            if (err.response?.data?.errors) {
                setValidationErrors(err.response.data.errors);
                showSnackbar({ type: 'error', message: 'Please check the form for errors.' });
            } else {
                showSnackbar({ type: 'error', message: err.message || 'Operation failed' });
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <Dialog
            open={open}
            onClose={() => onClose(false)}
            maxWidth="sm"
            fullWidth
            fullScreen={fullScreen}
            PaperProps={{ sx: { borderRadius: { xs: 0, sm: 2 }, backgroundColor: colors.light } }}
        >
            <form onSubmit={handleSubmit}>
                <DialogTitle sx={{ pb: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: colors.dark }}>
                    {user ? 'Edit User' : 'Add New User'}
                    <IconButton onClick={() => onClose(false)} size="small" sx={{ color: colors.rain }}>
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>
                <DialogContent>
                    <Box display="flex" flexDirection="column" gap={2} mt={1}>
                        {Object.keys(validationErrors).length > 0 && (
                            <Alert severity="error">
                                {Object.values(validationErrors).flat().map((msg, idx) => (
                                    <div key={idx}>{msg}</div>
                                ))}
                            </Alert>
                        )}

                        <TextField
                            label="Full Name"
                            name="name"
                            value={form.name}
                            onChange={handleChange}
                            required
                            fullWidth
                            size="small"
                            error={!!errors.name || !!validationErrors.name}
                            helperText={errors.name || (validationErrors.name?.[0] || '')}
                            disabled={loading}
                        />

                        <TextField
                            label="Email"
                            name="email"
                            type="email"
                            value={form.email}
                            onChange={handleChange}
                            required
                            fullWidth
                            disabled={!!user || loading}
                            size="small"
                            error={!!errors.email || !!validationErrors.email}
                            helperText={errors.email || (validationErrors.email?.[0] || '')}
                        />

                        <TextField
                            label="Phone"
                            name="phone"
                            value={form.phone}
                            onChange={handleChange}
                            fullWidth
                            size="small"
                            disabled={loading}
                            error={!!validationErrors.phone}
                            helperText={validationErrors.phone?.[0] || ''}
                        />

                        <TextField
                            select
                            label="Role"
                            name="role"
                            value={form.role}
                            onChange={handleChange}
                            required
                            fullWidth
                            disabled={loadingOptions || loading}
                            size="small"
                            error={!!errors.role || !!validationErrors.role}
                            helperText={errors.role || (validationErrors.role?.[0] || '')}
                        >
                            <MenuItem value="">Select Role</MenuItem>
                            {roles.map((role) => (
                                <MenuItem key={role.id} value={role.name}>
                                    {role.display_name || role.name}
                                </MenuItem>
                            ))}
                        </TextField>

                        {!user && (
                            <>
                                <TextField
                                    label="Password"
                                    name="password"
                                    type="password"
                                    value={form.password}
                                    onChange={handleChange}
                                    required
                                    fullWidth
                                    size="small"
                                    error={!!errors.password || !!validationErrors.password}
                                    helperText={errors.password || (validationErrors.password?.[0] || 'Minimum 8 characters')}
                                    disabled={loading}
                                />
                                <TextField
                                    label="Confirm Password"
                                    name="password_confirmation"
                                    type="password"
                                    value={form.password_confirmation}
                                    onChange={handleChange}
                                    required
                                    fullWidth
                                    size="small"
                                    error={!!errors.password_confirmation || !!validationErrors.password_confirmation}
                                    helperText={errors.password_confirmation || (validationErrors.password_confirmation?.[0] || '')}
                                    disabled={loading}
                                />
                            </>
                        )}

                        {user && (
                            <TextField
                                select
                                label="Status"
                                name="status"
                                value={form.status}
                                onChange={handleChange}
                                fullWidth
                                size="small"
                                disabled={loading}
                            >
                                <MenuItem value="active">Active</MenuItem>
                                <MenuItem value="inactive">Inactive</MenuItem>
                                <MenuItem value="pending">Pending</MenuItem>
                                <MenuItem value="suspended">Suspended</MenuItem>
                            </TextField>
                        )}
                    </Box>
                </DialogContent>
                <DialogActions sx={{ p: { xs: 2, sm: 3 }, pt: 0 }}>
                    <Button onClick={() => onClose(false)} sx={{ color: colors.rain }}>Cancel</Button>
                    <Button
                        type="submit"
                        variant="contained"
                        disabled={loading || loadingOptions}
                        sx={{ backgroundColor: colors.sea, '&:hover': { backgroundColor: colors.dark } }}
                    >
                        {loading ? <CircularProgress size={24} sx={{ color: colors.light }} /> : (user ? 'Update' : 'Create')}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}