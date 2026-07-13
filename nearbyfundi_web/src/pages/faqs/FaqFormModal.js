import React, { useState, useEffect } from 'react';
import {
    Dialog, DialogTitle, DialogContent, DialogActions,
    TextField, Button, Box, CircularProgress, useMediaQuery,
    useTheme, Typography, IconButton
} from '@mui/material';
import { Close as CloseIcon } from '@mui/icons-material';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';

const colors = appConfig.app.colors;

export default function FaqFormModal({ open, onClose, faq, createFaq, updateFaq }) {
    const theme = useTheme();
    const fullScreen = useMediaQuery(theme.breakpoints.down('sm'));

    const [loading, setLoading] = useState(false);
    const [form, setForm] = useState({ question: '', answer: '', order: 0 });
    const [errors, setErrors] = useState({});

    useEffect(() => {
        if (faq) {
            setForm({
                question: faq.question || '',
                answer: faq.answer || '',
                order: faq.order || 0,
            });
        } else {
            setForm({ question: '', answer: '', order: 0 });
        }
        setErrors({});
    }, [faq, open]);

    const handleChange = (e) => {
        const value = e.target.name === 'order' ? parseInt(e.target.value) || 0 : e.target.value;
        setForm({ ...form, [e.target.name]: value });
        if (errors[e.target.name]) setErrors({ ...errors, [e.target.name]: '' });
    };

    const validate = () => {
        const newErrors = {};
        if (!form.question.trim()) newErrors.question = 'Question is required';
        if (!form.answer.trim()) newErrors.answer = 'Answer is required';
        if (form.order < 0) newErrors.order = 'Order must be a positive number';
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!validate()) return;

        setLoading(true);
        try {
            if (faq) {
                await updateFaq(faq.id, form);
                showSnackbar({ type: 'success', message: 'FAQ updated successfully' });
            } else {
                await createFaq(form);
                showSnackbar({ type: 'success', message: 'FAQ created successfully' });
            }
            onClose(true);
        } catch (err) {
            showSnackbar({ type: 'error', message: err.response?.data?.message || 'Operation failed' });
        } finally {
            setLoading(false);
        }
    };

    return (
        <Dialog open={open} onClose={() => onClose(false)} maxWidth="md" fullWidth fullScreen={fullScreen}
                PaperProps={{ sx: { borderRadius: { xs: 0, sm: 2 }, backgroundColor: colors.light, margin: fullScreen ? 0 : 2 } }}>
            <form onSubmit={handleSubmit}>
                <DialogTitle sx={{ pb: 1, fontSize: { xs: '1.25rem', sm: '1.5rem' }, display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: colors.dark }}>
                    {faq ? 'Edit FAQ' : 'Create New FAQ'}
                    <IconButton onClick={() => onClose(false)} size="small" sx={{ p: 0.5, color: colors.rain, '&:hover': { color: colors.black } }}>
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>
                <DialogContent>
                    <Box display="flex" flexDirection="column" gap={2} mt={1}>
                        <Typography variant="body2" sx={{ color: colors.rain }}>
                            {faq ? 'Update the frequently asked question and answer below.' : 'Create a new frequently asked question.'}
                        </Typography>
                        <TextField
                            label="Question"
                            name="question"
                            value={form.question}
                            onChange={handleChange}
                            required
                            fullWidth
                            multiline
                            rows={2}
                            error={!!errors.question}
                            helperText={errors.question}
                            placeholder="Enter the frequently asked question..."
                            disabled={loading}
                            sx={{
                                '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                                '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                                '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: colors.sea },
                                '& .Mui-focused .MuiOutlinedInput-notchedOutline': { borderColor: colors.sea },
                                '& .MuiInputLabel-root': { color: colors.rain },
                                '& .MuiInputLabel-root.Mui-focused': { color: colors.sea },
                            }}
                        />
                        <TextField
                            label="Answer"
                            name="answer"
                            value={form.answer}
                            onChange={handleChange}
                            required
                            fullWidth
                            multiline
                            rows={4}
                            error={!!errors.answer}
                            helperText={errors.answer}
                            placeholder="Enter the answer to the question..."
                            disabled={loading}
                            sx={{
                                '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                                '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                                '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: colors.sea },
                                '& .Mui-focused .MuiOutlinedInput-notchedOutline': { borderColor: colors.sea },
                                '& .MuiInputLabel-root': { color: colors.rain },
                                '& .MuiInputLabel-root.Mui-focused': { color: colors.sea },
                            }}
                        />
                        <TextField
                            label="Display Order"
                            name="order"
                            type="number"
                            value={form.order}
                            onChange={handleChange}
                            fullWidth
                            error={!!errors.order}
                            helperText={errors.order || "Lower numbers appear first in the list"}
                            InputProps={{ inputProps: { min: 0 } }}
                            disabled={loading}
                            sx={{
                                '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                                '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                                '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: colors.sea },
                                '& .Mui-focused .MuiOutlinedInput-notchedOutline': { borderColor: colors.sea },
                                '& .MuiInputLabel-root': { color: colors.rain },
                                '& .MuiInputLabel-root.Mui-focused': { color: colors.sea },
                            }}
                        />
                    </Box>
                </DialogContent>
                <DialogActions sx={{ p: { xs: 2, sm: 3 }, pt: 0 }}>
                    <Button onClick={() => onClose(false)} sx={{ color: colors.rain, '&:hover': { color: colors.black } }}>Cancel</Button>
                    <Button type="submit" variant="contained" disabled={loading}
                            sx={{ backgroundColor: colors.sea, '&:hover': { backgroundColor: colors.dark } }}>
                        {loading ? <CircularProgress size={24} sx={{ color: colors.light }} /> : (faq ? 'Update' : 'Create')}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}