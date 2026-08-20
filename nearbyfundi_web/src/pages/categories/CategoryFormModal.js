// src/pages/categories/CategoryFormModal.js
import React, { useState, useEffect } from 'react';
import {
    Dialog, DialogTitle, DialogContent, DialogActions,
    TextField, Button, CircularProgress, Box,
} from '@mui/material';
import { serviceService } from 'services/service.service';
import { showSnackbar } from 'utils/snackbar';

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
                showSnackbar({ type: 'success', message: 'Category updated' });
            } else {
                await serviceService.createCategory(payload);
                showSnackbar({ type: 'success', message: 'Category created' });
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
        <Dialog open={open} onClose={() => onClose(false)} maxWidth="sm" fullWidth>
            <form onSubmit={handleSubmit}>
                <DialogTitle>{category ? 'Edit Category' : 'New Category'}</DialogTitle>
                <DialogContent>
                    <Box display="flex" flexDirection="column" gap={2} mt={1}>
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
                        />
                        <TextField
                            label="Category Name (Swahili)"
                            name="swahili_name"
                            value={form.swahili_name}
                            onChange={handleChange}
                            fullWidth
                        />
                        <TextField
                            label="Slug (URL friendly)"
                            name="slug"
                            value={form.slug}
                            onChange={handleChange}
                            helperText="Leave blank to auto-generate from name"
                            fullWidth
                        />
                        <TextField
                            label="Description"
                            name="description"
                            value={form.description}
                            onChange={handleChange}
                            multiline
                            rows={2}
                            fullWidth
                        />
                    </Box>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => onClose(false)} disabled={loading}>Cancel</Button>
                    <Button type="submit" variant="contained" disabled={loading}>
                        {loading ? <CircularProgress size={24} /> : (category ? 'Update' : 'Create')}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
};

export default CategoryFormModal;