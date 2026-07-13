// src/pages/auth/ForgotPassword.jsx
import { useState } from 'react';
import {
    Container,
    Paper,
    TextField,
    Button,
    Typography,
    Box,
    CircularProgress,
    useTheme,
    alpha,
    InputAdornment,
    Grid,
} from '@mui/material';
import { Email as EmailIcon, ArrowBack as ArrowBackIcon } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { showSnackbar } from 'utils/snackbar';
import { authService } from 'services/auth.service';

const logo = '/assets/logo.png';

export default function ForgotPassword() {
    const theme = useTheme();
    const navigate = useNavigate();
    const [email, setEmail] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!email) {
            setError('Email is required');
            return;
        }
        setLoading(true);
        setError('');
        try {
            const res = await authService.forgotPassword(email);
            if (res.data.success) {
                showSnackbar({ type: 'success', message: 'OTP sent to your email! 📧' });
                // ✅ Pass email to reset password page
                navigate('/reset-password', { state: { email: email }, replace: true });
            } else {
                setError(res.data.message || 'Failed to send OTP');
            }
        } catch (err) {
            setError(err.response?.data?.message || 'Failed to send OTP');
        } finally {
            setLoading(false);
        }
    };

    return (
        <Box
            sx={{
                minHeight: '100vh',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                bgcolor: '#f5f7fa',
                p: { xs: 2, sm: 3 },
            }}
        >
            <Container maxWidth="sm">
                <Grid container spacing={0}>
                    <Grid item xs={12}>
                        <Paper
                            elevation={0}
                            sx={{
                                p: { xs: 4, sm: 5, md: 6 },
                                borderRadius: 4,
                                boxShadow: '0 20px 60px rgba(0,0,0,0.06)',
                                border: `1px solid ${alpha('#006B5E', 0.08)}`,
                                bgcolor: '#ffffff',
                            }}
                        >
                            <Box textAlign="center" mb={4}>
                                <Box
                                    component="img"
                                    src={logo}
                                    alt="NearbyFundi"
                                    onError={(e) => {
                                        e.target.onerror = null;
                                        e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="50" height="50" viewBox="0 0 24 24"%3E%3Ctext x="0" y="18" font-size="18" fill="%23006B5E"%3ENF%3C/text%3E%3C/svg%3E';
                                    }}
                                    sx={{ width: 50, height: 50, mx: 'auto', mb: 2 }}
                                />
                                <Typography variant="h4" fontWeight="700" gutterBottom sx={{ color: '#1a1a2e' }}>
                                    Forgot Password?
                                </Typography>
                                <Typography variant="body2" color="text.secondary">
                                    Enter your email to receive a password reset OTP
                                </Typography>
                            </Box>

                            <form onSubmit={handleSubmit}>
                                <TextField
                                    fullWidth
                                    label="Email Address"
                                    type="email"
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                    required
                                    autoFocus
                                    sx={{
                                        '& .MuiInputBase-root': {
                                            borderRadius: 2,
                                            py: 0.5,
                                            bgcolor: '#f8f9fa',
                                        },
                                        '& .MuiOutlinedInput-notchedOutline': {
                                            borderColor: '#e0e0e0',
                                        },
                                    }}
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start">
                                                <EmailIcon color="action" fontSize="small" />
                                            </InputAdornment>
                                        ),
                                    }}
                                />

                                {error && (
                                    <Typography color="error" variant="body2" sx={{ mt: 2 }}>
                                        {error}
                                    </Typography>
                                )}

                                <Button
                                    type="submit"
                                    fullWidth
                                    variant="contained"
                                    disabled={loading}
                                    sx={{
                                        mt: 3,
                                        py: 1.8,
                                        fontSize: '1.1rem',
                                        fontWeight: 600,
                                        borderRadius: 2,
                                        textTransform: 'none',
                                        background: 'linear-gradient(135deg, #006B5E 0%, #00897B 100%)',
                                        '&:hover': {
                                            transform: 'translateY(-2px)',
                                            boxShadow: 4,
                                            background: 'linear-gradient(135deg, #005245 0%, #006B5E 100%)',
                                        },
                                    }}
                                >
                                    {loading ? <CircularProgress size={24} color="inherit" /> : 'Send Reset OTP'}
                                </Button>

                                <Button
                                    fullWidth
                                    variant="text"
                                    startIcon={<ArrowBackIcon />}
                                    onClick={() => navigate('/login')}
                                    sx={{ mt: 2, textTransform: 'none', color: '#006B5E' }}
                                >
                                    Back to Login
                                </Button>
                            </form>
                        </Paper>
                    </Grid>
                </Grid>
            </Container>
        </Box>
    );
}