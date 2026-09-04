// src/pages/permissions/PermissionFormModal.js
import React, { useState, useEffect } from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Button,
    CircularProgress,
    useMediaQuery,
    useTheme,
    Typography,
    IconButton,
    Stack,
    Divider,
    Box,
} from '@mui/material';
import { Close as CloseIcon } from '@mui/icons-material';
import { permissionService } from 'services/permission.service';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';

const colors = appConfig.app.colors;

export default function PermissionFormModal({ open, onClose, permission }) {
    const theme = useTheme();
    const fullScreen = useMediaQuery(theme.breakpoints.down('sm'));

    const [loading, setLoading] = useState(false);
    const [form, setForm] = useState({
        name: '',
        display_name: '',
        description: '',
        guard_name: 'web',
    });

    useEffect(() => {
        if (permission) {
            setForm({
                name: permission.name || '',
                display_name: permission.display_name || '',
                description: permission.description || '',
                guard_name: permission.guard_name || 'web',
            });
        } else {
            setForm({
                name: '',
                display_name: '',
                description: '',
                guard_name: 'web',
            });
        }
    }, [permission, open]);

    const handleChange = (e) => {
        setForm({ ...form, [e.target.name]: e.target.value });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setLoading(true);
        try {
            if (permission) {
                await permissionService.updatePermission(permission.id, form);
                showSnackbar({ type: 'success', message: 'Permission updated successfully' });
            } else {
                await permissionService.createPermission(form);
                showSnackbar({ type: 'success', message: 'Permission created successfully' });
            }
            onClose(true);
        } catch (err) {
            showSnackbar({
                type: 'error',
                message: err.response?.data?.message || 'Operation failed',
            });
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
            PaperProps={{
                sx: {
                    borderRadius: { xs: 0, sm: 3 },
                    bgcolor: 'background.paper',
                },
            }}
        >
            <form onSubmit={handleSubmit}>
                <DialogTitle
                    sx={{
                        px: { xs: 2.5, sm: 3 },
                        pt: 2.5,
                        pb: 1.5,
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'flex-start',
                    }}
                >
                    <Box>
                        <Typography variant="h6" fontWeight={800} color="text.primary">
                            {permission ? 'Edit Permission' : 'Add New Permission'}
                        </Typography>
                        <Typography variant="body2" color="text.secondary" fontWeight={500} sx={{ mt: 0.25 }}>
                            {permission
                                ? 'Update permission details below'
                                : 'Create a new permission with a unique key'}
                        </Typography>
                    </Box>
                    <IconButton
                        onClick={() => onClose(false)}
                        size="small"
                        disabled={loading}
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

                <DialogContent sx={{ px: { xs: 2.5, sm: 3 }, py: 2.5 }}>
                    <Stack spacing={2.25}>
                        <TextField
                            label="Permission Name (key)"
                            name="name"
                            value={form.name}
                            onChange={handleChange}
                            required
                            fullWidth
                            size="small"
                            helperText="Unique identifier, e.g. users.view"
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
                            label="Display Name"
                            name="display_name"
                            value={form.display_name}
                            onChange={handleChange}
                            required
                            fullWidth
                            size="small"
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
                            name="description"
                            value={form.description}
                            onChange={handleChange}
                            multiline
                            rows={2}
                            fullWidth
                            size="small"
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
                            label="Guard Name"
                            name="guard_name"
                            value={form.guard_name}
                            onChange={handleChange}
                            required
                            fullWidth
                            size="small"
                            helperText="Usually 'web' or 'api'"
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
                </DialogContent>

                <Divider />

                <DialogActions sx={{ px: { xs: 2.5, sm: 3 }, py: 2, gap: 1.5 }}>
                    <Button
                        onClick={() => onClose(false)}
                        disabled={loading}
                        sx={{
                            fontWeight: 600,
                            textTransform: 'none',
                            color: 'text.secondary',
                            '&:hover': { bgcolor: 'action.hover' },
                        }}
                    >
                        Cancel
                    </Button>
                    <Button
                        type="submit"
                        variant="contained"
                        disabled={loading}
                        sx={{
                            minWidth: 120,
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
                        {loading ? (
                            <CircularProgress size={22} thickness={4} sx={{ color: '#fff' }} />
                        ) : permission ? (
                            'Update Permission'
                        ) : (
                            'Create Permission'
                        )}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}