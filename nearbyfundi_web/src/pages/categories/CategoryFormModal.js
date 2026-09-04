// src/pages/categories/CategoryFormModal.js
import React, { useState, useEffect } from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Button,
    CircularProgress,
    Box,
    Stack,
    IconButton,
    alpha,
} from '@mui/material';
import { Close as CloseIcon } from '@mui/icons-material';
import { serviceService } from 'services/service.service';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const CategoryFormModal = ({ open, onClose, category }) => {
    const [form, setForm] = useState({ category_name: '', swahili_name: '', slug: '', description: '' });
    const [loading, setLoading] = useState(false);
    const [errors, setErrors] = useState({});

    useEffect(() => {
        if (category) {
            setForm({
                category_name: category.category_name || '',
                swahili_name: category.swahili_name || '',
                slug: category.slug || '',
                description: category.description || '',
            });
        } else {
            setForm({ category_name: '', swahili_name: '', slug: '', description: '' });
        }
        setErrors({});
    }, [category, open]);

    const handleChange = (e) => {
        setForm({ ...form, [e.target.name]: e.target.value });
        if (errors[e.target.name]) setErrors({ ...errors, [e.target.name]: '' });
    };

    const validate = () => {
        const newErrors = {};
        if (!form.category_name.trim()) newErrors.category_name = 'Category name is required';
        if (form.category_name.trim().length < 2) newErrors.category_name = 'Must be at least 2 characters';
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!validate()) return;
        setLoading(true);
        try {
            const payload = {
                category_name: form.category_name.trim(),
                swahili_name: form.swahili_name?.trim() || null,
                slug: form.slug?.trim() || null,
                description: form.description?.trim() || null,
            };
            if (category) {
                await serviceService.updateCategory(category.service_categoryID, payload);
                showSnackbar({ type: 'success', message: 'Category updated successfully' });
            } else {
                await serviceService.createCategory(payload);
                showSnackbar({ type: 'success', message: 'Category created successfully' });
            }
            onClose(true);
        } catch (err) {
            const msg = err.response?.data?.message || 'Operation failed';
            const errData = err.response?.data?.errors;
            if (errData) {
                const fieldErrors = {};
                Object.keys(errData).forEach(key => fieldErrors[key] = errData[key][0]);
                setErrors(fieldErrors);
            } else if (msg.toLowerCase().includes('already been taken') || msg.toLowerCase().includes('duplicate')) {
                setErrors({ category_name: 'Category name already exists' });
            }
            showSnackbar({ type: 'error', message: msg });
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
            PaperProps={{
                sx: {
                    borderRadius: 3,
                    border: '1px solid',
                    borderColor: 'divider',
                }
            }}
        >
            <form onSubmit={handleSubmit}>
                <DialogTitle
                    sx={{
                        pb: 1.5,
                        fontWeight: 700,
                        fontSize: '1.2rem',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        borderBottom: '1px solid',
                        borderColor: 'divider',
                        color: 'text.primary',
                    }}
                >
                    {category ? 'Edit Category' : 'New Category'}
                    <IconButton
                        onClick={() => onClose(false)}
                        size="small"
                        sx={{
                            color: 'text.secondary',
                            '&:hover': { bgcolor: 'action.hover' },
                        }}
                    >
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>

                <DialogContent sx={{ pt: 3, pb: 1 }}>
                    <Stack spacing={2.5}>
                        <TextField
                            label="Category Name (English)"
                            name="category_name"
                            value={form.category_name}
                            onChange={handleChange}
                            required
                            error={!!errors.category_name}
                            helperText={errors.category_name}
                            fullWidth
                            autoFocus
                            disabled={loading}
                            sx={{
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                    },
                                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                        borderWidth: 2,
                                    },
                                },
                            }}
                        />

                        <TextField
                            label="Category Name (Swahili)"
                            name="swahili_name"
                            value={form.swahili_name}
                            onChange={handleChange}
                            fullWidth
                            disabled={loading}
                            placeholder="e.g., Aina ya Huduma"
                            sx={{
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                    },
                                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                        borderWidth: 2,
                                    },
                                },
                            }}
                        />

                        <TextField
                            label="Slug (URL friendly)"
                            name="slug"
                            value={form.slug}
                            onChange={handleChange}
                            helperText="Leave blank to auto-generate from name"
                            fullWidth
                            disabled={loading}
                            placeholder="e.g., tv-repair"
                            sx={{
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                    },
                                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                        borderWidth: 2,
                                    },
                                },
                            }}
                        />

                        <TextField
                            label="Description"
                            name="description"
                            value={form.description}
                            onChange={handleChange}
                            multiline
                            rows={3}
                            fullWidth
                            disabled={loading}
                            placeholder="Brief description of the category..."
                            sx={{
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                    },
                                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                        borderWidth: 2,
                                    },
                                },
                            }}
                        />
                    </Stack>
                </DialogContent>

                <DialogActions sx={{ p: { xs: 2, sm: 3 }, pt: 1, borderTop: '1px solid', borderColor: 'divider' }}>
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
                            borderRadius: 2,
                            fontWeight: 700,
                            textTransform: 'none',
                            px: 3,
                            bgcolor: colors.sea || '#0f766e',
                            '&:hover': { bgcolor: colors.dark || '#0d5c56' },
                            '&:disabled': { opacity: 0.6 },
                        }}
                    >
                        {loading ? <CircularProgress size={24} color="inherit" /> : (category ? 'Update' : 'Create')}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
};

export default CategoryFormModal;