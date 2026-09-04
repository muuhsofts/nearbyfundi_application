// src/pages/privacy/PrivacyPolicyFormModal.js
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
    IconButton,
    useMediaQuery,
    useTheme,
    Typography,
    Stack,
} from '@mui/material';
import { Close as CloseIcon } from '@mui/icons-material';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

export default function PrivacyPolicyFormModal({
                                                   open,
                                                   onClose,
                                                   policyData,
                                                   createPrivacyPolicy,
                                                   updatePrivacyPolicy,
                                               }) {
    const theme = useTheme();
    const fullScreen = useMediaQuery(theme.breakpoints.down('sm'));

    const [loading, setLoading] = useState(false);
    const [form, setForm] = useState({ content: '' });
    const [errors, setErrors] = useState({});

    useEffect(() => {
        setForm({ content: policyData?.content || '' });
        setErrors({});
    }, [policyData, open]);

    const handleChange = (e) => {
        setForm({ ...form, [e.target.name]: e.target.value });
        if (errors[e.target.name]) setErrors({ ...errors, [e.target.name]: '' });
    };

    const validate = () => {
        const newErrors = {};
        if (!form.content.trim()) newErrors.content = 'Content is required';
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!validate()) return;

        setLoading(true);
        try {
            if (policyData) {
                await updatePrivacyPolicy(policyData.id, { content: form.content });
                showSnackbar({ type: 'success', message: 'Privacy policy updated successfully' });
            } else {
                await createPrivacyPolicy({ content: form.content });
                showSnackbar({ type: 'success', message: 'Privacy policy created successfully' });
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
                },
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
                    {policyData ? 'Edit Privacy Policy' : 'Create Privacy Policy'}
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
                            {policyData
                                ? 'Update the privacy policy content below.'
                                : 'Create new privacy policy content.'}
                        </Typography>

                        <TextField
                            label="Content"
                            name="content"
                            value={form.content}
                            onChange={handleChange}
                            required
                            fullWidth
                            multiline
                            rows={14}
                            error={!!errors.content}
                            helperText={errors.content}
                            placeholder="Enter privacy policy content..."
                            disabled={loading}
                            sx={{
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    fontFamily: 'inherit',
                                    fontSize: '1rem',
                                    lineHeight: 1.8,
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
                        {loading ? (
                            <CircularProgress size={24} color="inherit" />
                        ) : policyData ? (
                            'Update'
                        ) : (
                            'Create'
                        )}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}