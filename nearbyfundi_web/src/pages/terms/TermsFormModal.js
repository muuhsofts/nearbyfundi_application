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

export default function TermsFormModal({ open, onClose, termsData, createTerms, updateTerms }) {
    const theme = useTheme();
    const fullScreen = useMediaQuery(theme.breakpoints.down('sm'));

    const [loading, setLoading] = useState(false);
    const [form, setForm] = useState({ content: '' });
    const [errors, setErrors] = useState({});

    useEffect(() => {
        setForm({ content: termsData?.content || '' });
        setErrors({});
    }, [termsData, open]);

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
            if (termsData) {
                await updateTerms({ content: form.content });
                showSnackbar({ type: 'success', message: 'Terms page updated successfully' });
            } else {
                await createTerms({ content: form.content });
                showSnackbar({ type: 'success', message: 'Terms page created successfully' });
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
                    {termsData ? 'Edit Terms & Conditions' : 'Create Terms & Conditions'}
                    <IconButton onClick={() => onClose(false)} size="small" sx={{ p: 0.5, color: colors.rain, '&:hover': { color: colors.black } }}>
                        <CloseIcon />
                    </IconButton>
                </DialogTitle>
                <DialogContent>
                    <Box display="flex" flexDirection="column" gap={2} mt={1}>
                        <Typography variant="body2" sx={{ color: colors.rain }}>
                            {termsData ? 'Update the terms and conditions content below.' : 'Create new terms and conditions content.'}
                        </Typography>
                        <TextField
                            label="Content"
                            name="content"
                            value={form.content}
                            onChange={handleChange}
                            required
                            fullWidth
                            multiline
                            rows={12}
                            error={!!errors.content}
                            helperText={errors.content}
                            placeholder="Enter terms and conditions content..."
                            disabled={loading}
                            sx={{
                                '& .MuiInputBase-root': { fontFamily: 'inherit', fontSize: '1rem', lineHeight: 1.8, backgroundColor: colors.sky, borderRadius: 2 },
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
                        {loading ? <CircularProgress size={24} sx={{ color: colors.light }} /> : (termsData ? 'Update' : 'Create')}
                    </Button>
                </DialogActions>
            </form>
        </Dialog>
    );
}