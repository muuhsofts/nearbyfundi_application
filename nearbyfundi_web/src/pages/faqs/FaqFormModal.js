// src/pages/faqs/FaqFormModal.js
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
    Typography,
    IconButton,
    Stack,
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
        <Dialog
            open={open}
            onClose={() => onClose(false)}
            maxWidth="md"
            fullWidth
            fullScreen={fullScreen}
            PaperProps={{
                sx: {
                    borderRadius: { xs: 0, sm: 3 },
                    border: '1px solid',
                    borderColor: 'divider',
                    margin: fullScreen ? 0 : 2,
                }
            }}
        >
            <form onSubmit={handleSubmit}>
                <DialogTitle
                    sx={{
                        pb: 1.5,
                        fontWeight: 700,
                        fontSize: { xs: '1.2rem', sm: '1.4rem' },
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        borderBottom: '1px solid',
                        borderColor: 'divider',
                        color: 'text.primary',
                    }}
                >
                    {faq ? 'Edit FAQ' : 'Create New FAQ'}
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
                        <Typography variant="body2" color="text.secondary">
                            {faq
                                ? 'Update the frequently asked question and answer below.'
                                : 'Create a new frequently asked question.'}
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
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    bgcolor: 'action.hover',
                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                    },
                                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                        borderWidth: 2,
                                    },
                                },
                                '& .MuiInputLabel-root': {
                                    color: 'text.secondary',
                                    '&.Mui-focused': {
                                        color: colors.sea,
                                    },
                                },
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
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    bgcolor: 'action.hover',
                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                    },
                                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                        borderWidth: 2,
                                    },
                                },
                                '& .MuiInputLabel-root': {
                                    color: 'text.secondary',
                                    '&.Mui-focused': {
                                        color: colors.sea,
                                    },
                                },
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
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    bgcolor: 'action.hover',
                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                    },
                                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                        borderWidth: 2,
                                    },
                                },
                                '& .MuiInputLabel-root': {
                                    color: 'text.secondary',
                                    '&.Mui-focused': {
                                        color: colors.sea,
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
                        {loading ? <CircularProgress size={24} color="inherit" /> : (faq ? 'Update' : 'Create')}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}