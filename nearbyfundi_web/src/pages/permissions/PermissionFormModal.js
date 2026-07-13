// src/pages/permissions/PermissionFormModal.js
import React, { useState, useEffect } from 'react';
import {
    Dialog, DialogTitle, DialogContent, DialogActions,
    TextField, Button, Box, CircularProgress, useMediaQuery, useTheme,
    Typography
} from '@mui/material';
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
                    borderRadius: { xs: 0, sm: 2 },
                    backgroundColor: colors.light,
                }
            }}
        >
            <form onSubmit={handleSubmit}>
                <DialogTitle sx={{
                    pb: 1,
                    fontSize: { xs: '1.25rem', sm: '1.5rem' },
                    color: colors.dark,
                }}>
                    {permission ? 'Edit Permission' : 'Add New Permission'}
                </DialogTitle>
                <DialogContent>
                    <Box display="flex" flexDirection="column" gap={2} mt={1}>
                        <Typography variant="body2" sx={{ color: colors.rain }}>
                            {permission
                                ? 'Update the permission details below.'
                                : 'Create a new permission.'}
                        </Typography>

                        <TextField
                            label="Permission Name (key)"
                            name="name"
                            value={form.name}
                            onChange={handleChange}
                            required
                            fullWidth
                            helperText="Unique identifier, e.g. 'users.view'"
                            size="small"
                            sx={{
                                '& .MuiInputBase-root': {
                                    backgroundColor: colors.sky,
                                    borderRadius: 2,
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle,
                                },
                                '&:hover .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.sea,
                                },
                                '& .Mui-focused .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.sea,
                                },
                                '& .MuiInputLabel-root': {
                                    color: colors.rain,
                                },
                                '& .MuiInputLabel-root.Mui-focused': {
                                    color: colors.sea,
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
                                '& .MuiInputBase-root': {
                                    backgroundColor: colors.sky,
                                    borderRadius: 2,
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle,
                                },
                                '&:hover .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.sea,
                                },
                                '& .Mui-focused .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.sea,
                                },
                                '& .MuiInputLabel-root': {
                                    color: colors.rain,
                                },
                                '& .MuiInputLabel-root.Mui-focused': {
                                    color: colors.sea,
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
                                '& .MuiInputBase-root': {
                                    backgroundColor: colors.sky,
                                    borderRadius: 2,
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle,
                                },
                                '&:hover .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.sea,
                                },
                                '& .Mui-focused .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.sea,
                                },
                                '& .MuiInputLabel-root': {
                                    color: colors.rain,
                                },
                                '& .MuiInputLabel-root.Mui-focused': {
                                    color: colors.sea,
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
                            helperText="Usually 'web' or 'api'"
                            size="small"
                            sx={{
                                '& .MuiInputBase-root': {
                                    backgroundColor: colors.sky,
                                    borderRadius: 2,
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle,
                                },
                                '&:hover .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.sea,
                                },
                                '& .Mui-focused .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.sea,
                                },
                                '& .MuiInputLabel-root': {
                                    color: colors.rain,
                                },
                                '& .MuiInputLabel-root.Mui-focused': {
                                    color: colors.sea,
                                },
                            }}
                        />
                    </Box>
                </DialogContent>
                <DialogActions sx={{ p: 2, pt: 0 }}>
                    <Button
                        onClick={() => onClose(false)}
                        sx={{
                            color: colors.rain,
                            '&:hover': { color: colors.black }
                        }}
                    >
                        Cancel
                    </Button>
                    <Button
                        type="submit"
                        variant="contained"
                        disabled={loading}
                        sx={{
                            backgroundColor: colors.sea,
                            '&:hover': { backgroundColor: colors.dark },
                        }}
                    >
                        {loading ? <CircularProgress size={24} sx={{ color: colors.light }} /> : (permission ? 'Update' : 'Create')}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}