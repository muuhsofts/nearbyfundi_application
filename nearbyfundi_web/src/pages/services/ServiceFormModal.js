// src/pages/services/ServiceFormModal.js
import React, { useState, useEffect } from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Button,
    Box,
    CircularProgress,
    useMediaQuery,
    useTheme,
    IconButton,
} from '@mui/material';
import { Close as CloseIcon } from '@mui/icons-material';
import { useServiceManagement } from 'hooks/useService';
import { showSnackbar } from 'utils/snackbar';

export default function ServiceFormModal({ open, onClose, service }) {
    const theme = useTheme();
    const fullScreen = useMediaQuery(theme.breakpoints.down('sm'));

    const { createService, updateService } = useServiceManagement();
    const [loading, setLoading] = useState(false);

    const [form, setForm] = useState({
        name: '',
    });
    const [errors, setErrors] = useState({});

    // Set form data when editing
    useEffect(() => {
        if (service) {
            setForm({
                name: service.name || '',
            });
        } else {
            setForm({
                name: '',
            });
        }
        setErrors({});
    }, [service]);

    const handleChange = (e) => {
        setForm({ ...form, [e.target.name]: e.target.value });
        if (errors[e.target.name]) {
            setErrors({ ...errors, [e.target.name]: '' });
        }
    };

    const validate = () => {
        const newErrors = {};
        if (!form.name.trim()) {
            newErrors.name = 'Service name is required';
        } else if (form.name.trim().length < 3) {
            newErrors.name = 'Service name must be at least 3 characters';
        }
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!validate()) return;

        setLoading(true);
        try {
            const payload = {
                name: form.name.trim(),
            };

            if (service) {
                await updateService(service.id, payload);
                showSnackbar({ type: 'success', message: 'Service updated successfully' });
            } else {
                await createService(payload);
                showSnackbar({ type: 'success', message: 'Service created successfully' });
            }
            onClose(true);
        } catch (err) {
            const errorMessage = err.response?.data?.message || 'Operation failed';
            const errorData = err.response?.data?.errors;

            if (errorData) {
                // Set field-specific errors from validation
                const fieldErrors = {};
                Object.keys(errorData).forEach(key => {
                    fieldErrors[key] = errorData[key][0];
                });
                setErrors(fieldErrors);
            } else if (errorMessage.toLowerCase().includes('already been taken') ||
                errorMessage.toLowerCase().includes('duplicate') ||
                errorMessage.toLowerCase().includes('unique')) {
                setErrors({ name: 'This service name already exists' });
            }

            showSnackbar({
                type: 'error',
                message: errorMessage,
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
                sx: { borderRadius: { xs: 0, sm: 2 } }
            }}
        >
            <form onSubmit={handleSubmit}>
                <DialogTitle sx={{
                    pb: 1,
                    fontSize: { xs: '1.25rem', sm: '1.5rem' },
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center'
                }}>
                    {service ? 'Edit Service' : 'Add New Service'}
                    <IconButton
                        onClick={() => onClose(false)}
                        size="small"
                        sx={{ minWidth: 'auto', p: 0.5 }}
                    >
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>
                <DialogContent>
                    <Box display="flex" flexDirection="column" gap={2} mt={1}>
                        <TextField
                            label="Service Name"
                            name="name"
                            value={form.name}
                            onChange={handleChange}
                            required
                            fullWidth
                            size="medium"
                            error={!!errors.name}
                            helperText={errors.name || 'Enter the service name (e.g., TV Repair, Plumbing)'}
                            disabled={loading}
                            placeholder="e.g., TV Repair, Plumbing, AC Service"
                            autoFocus
                            InputProps={{
                                sx: { borderRadius: 1 }
                            }}
                        />
                    </Box>
                </DialogContent>
                <DialogActions sx={{ p: { xs: 2, sm: 3 }, pt: 0 }}>
                    <Button
                        onClick={() => onClose(false)}
                        disabled={loading}
                        sx={{ borderRadius: 1 }}
                    >
                        Cancel
                    </Button>
                    <Button
                        type="submit"
                        variant="contained"
                        disabled={loading}
                        sx={{
                            borderRadius: 1,
                            minWidth: 100,
                        }}
                    >
                        {loading ? (
                            <CircularProgress size={24} color="inherit" />
                        ) : (
                            service ? 'Update' : 'Create'
                        )}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}