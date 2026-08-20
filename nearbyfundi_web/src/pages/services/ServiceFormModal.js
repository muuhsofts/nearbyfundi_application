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
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Chip,
    OutlinedInput,
} from '@mui/material';
import { Close as CloseIcon } from '@mui/icons-material';
import { useServiceManagement } from 'hooks/useService';
import { serviceService } from 'services/service.service';
import { showSnackbar } from 'utils/snackbar';

export default function ServiceFormModal({ open, onClose, service }) {
    const theme = useTheme();
    const fullScreen = useMediaQuery(theme.breakpoints.down('sm'));

    const { createService, updateService } = useServiceManagement();
    const [loading, setLoading] = useState(false);
    const [categories, setCategories] = useState([]);
    const [loadingCategories, setLoadingCategories] = useState(false);

    const [form, setForm] = useState({ name: '', swahili_name: '' });
    const [selectedCategoryIds, setSelectedCategoryIds] = useState([]);
    const [errors, setErrors] = useState({});

    useEffect(() => {
        if (open) loadCategories();
    }, [open]);

    const loadCategories = async () => {
        setLoadingCategories(true);
        try {
            const response = await serviceService.getCategories({ per_page: 100 });
            if (response?.data?.status === 'success') {
                const data = response.data.data;
                setCategories(data.data || []);
            }
        } catch (err) {
            console.error('Failed to load categories:', err);
        } finally {
            setLoadingCategories(false);
        }
    };

    useEffect(() => {
        if (service) {
            // ✅ Handle both `swahili_name` and `name_sw` (backend returns `name_sw` in GET response)
            const swahili = service.swahili_name || service.name_sw || '';
            setForm({
                name: service.name || '',
                swahili_name: swahili,
            });
            setSelectedCategoryIds(service.category_ids || []);
        } else {
            setForm({ name: '', swahili_name: '' });
            setSelectedCategoryIds([]);
        }
        setErrors({});
    }, [service]);

    const handleChange = (e) => {
        setForm({ ...form, [e.target.name]: e.target.value });
        if (errors[e.target.name]) setErrors({ ...errors, [e.target.name]: '' });
    };

    const handleCategoryChange = (event) => {
        setSelectedCategoryIds(event.target.value);
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
                swahili_name: form.swahili_name?.trim() || null,
                category_ids: selectedCategoryIds,
            };

            console.log('Submitting payload:', payload); // debug

            if (service) {
                await updateService(service.id, payload);
                showSnackbar({ type: 'success', message: 'Service updated successfully' });
            } else {
                await createService(payload);
                showSnackbar({ type: 'success', message: 'Service created successfully' });
            }
            onClose(true);
        } catch (err) {
            console.error('Submit error:', err);
            const errorMessage = err.response?.data?.message || 'Operation failed';
            const errorData = err.response?.data?.errors;

            if (errorData) {
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

            showSnackbar({ type: 'error', message: errorMessage });
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
            PaperProps={{ sx: { borderRadius: { xs: 0, sm: 2 } } }}
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
                    <IconButton onClick={() => onClose(false)} size="small" sx={{ minWidth: 'auto', p: 0.5 }}>
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>
                <DialogContent>
                    <Box display="flex" flexDirection="column" gap={2} mt={1}>
                        <TextField
                            label="Service Name (English)"
                            name="name"
                            value={form.name}
                            onChange={handleChange}
                            required
                            fullWidth
                            error={!!errors.name}
                            helperText={errors.name || 'Enter the service name (e.g., TV Repair, Plumbing)'}
                            disabled={loading}
                            placeholder="e.g., TV Repair, Plumbing, AC Service"
                            autoFocus
                        />
                        <TextField
                            label="Service Name (Swahili)"
                            name="swahili_name"
                            value={form.swahili_name}
                            onChange={handleChange}
                            fullWidth
                            disabled={loading}
                            placeholder="e.g., Ukarabati wa TV, Mabomba"
                        />

                        <FormControl fullWidth disabled={loadingCategories}>
                            <InputLabel>Categories</InputLabel>
                            <Select
                                multiple
                                value={selectedCategoryIds}
                                onChange={handleCategoryChange}
                                input={<OutlinedInput label="Categories" />}
                                renderValue={(selected) => (
                                    <Box display="flex" flexWrap="wrap" gap={0.5}>
                                        {selected.map((id) => {
                                            const cat = categories.find(c => c.service_categoryID === id);
                                            return <Chip key={id} label={cat?.category_name || id} size="small" />;
                                        })}
                                    </Box>
                                )}
                            >
                                {categories.map((cat) => (
                                    <MenuItem key={cat.service_categoryID} value={cat.service_categoryID}>
                                        {cat.category_name}
                                    </MenuItem>
                                ))}
                            </Select>
                        </FormControl>
                    </Box>
                </DialogContent>
                <DialogActions sx={{ p: { xs: 2, sm: 3 }, pt: 0 }}>
                    <Button onClick={() => onClose(false)} disabled={loading}>Cancel</Button>
                    <Button type="submit" variant="contained" disabled={loading}>
                        {loading ? <CircularProgress size={24} color="inherit" /> : (service ? 'Update' : 'Create')}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}