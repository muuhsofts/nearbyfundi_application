// src/pages/auth/ResetPassword.jsx
import { useState, useEffect, useRef } from 'react';
import {
    Container,
    Paper,
    TextField,
    Button,
    Typography,
    Box,
    IconButton,
    InputAdornment,
    CircularProgress,
    useTheme,
    alpha,
    Grid,
    Alert,
} from '@mui/material';
import {
    Visibility,
    VisibilityOff,
    Lock as LockIcon,
    ArrowBack as ArrowBackIcon,
} from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { showSnackbar } from 'utils/snackbar';
import { authService } from 'services/auth.service';

const logo = '/assets/logo.png';

export default function ResetPassword() {
    const theme = useTheme();
    const navigate = useNavigate();
    const location = useLocation();

    // Get email from URL query parameter or state
    const queryParams = new URLSearchParams(location.search);
    const emailFromUrl = queryParams.get('email');
    const emailFromState = location.state?.email || '';
    const email = emailFromUrl || emailFromState;

    const [otp, setOtp] = useState(['', '', '', '', '', '']);
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirm, setShowConfirm] = useState(false);

    const inputRefs = useRef([]);

    useEffect(() => {
        if (!email) {
            showSnackbar({ type: 'warning', message: 'Please request a password reset first' });
            navigate('/forgot-password', { replace: true });
        }
    }, [email, navigate]);

    useEffect(() => {
        if (inputRefs.current[0]) {
            inputRefs.current[0].focus();
        }
    }, []);

    const handleOtpChange = (index, value) => {
        if (value.length > 1) {
            const pasteData = value.slice(0, 6);
            const newOtp = [...otp];
            for (let i = 0; i < pasteData.length && i < 6; i++) {
                newOtp[i] = pasteData[i] || '';
            }
            setOtp(newOtp);
            const nextIndex = Math.min(pasteData.length, 5);
            if (inputRefs.current[nextIndex]) {
                inputRefs.current[nextIndex].focus();
            }
            return;
        }

        const newOtp = [...otp];
        newOtp[index] = value;
        setOtp(newOtp);

        if (value && index < 5) {
            inputRefs.current[index + 1].focus();
        }
    };

    const handleKeyDown = (index, e) => {
        if (e.key === 'Backspace' && !otp[index] && index > 0) {
            inputRefs.current[index - 1].focus();
        }
    };

    const handlePaste = (e) => {
        e.preventDefault();
        const pasteData = e.clipboardData.getData('text').slice(0, 6);
        if (/^\d+$/.test(pasteData)) {
            const newOtp = [...otp];
            for (let i = 0; i < pasteData.length && i < 6; i++) {
                newOtp[i] = pasteData[i];
            }
            setOtp(newOtp);
            const nextIndex = Math.min(pasteData.length, 5);
            if (inputRefs.current[nextIndex]) {
                inputRefs.current[nextIndex].focus();
            }
        }
    };

    const getOtpString = () => otp.join('');

    const handleSubmit = async (e) => {
        e.preventDefault();
        const otpString = getOtpString();

        if (password !== confirmPassword) {
            setError('Passwords do not match');
            return;
        }
        if (otpString.length !== 6) {
            setError('Please enter all 6 digits of OTP');
            return;
        }
        if (password.length < 8) {
            setError('Password must be at least 8 characters');
            return;
        }

        setLoading(true);
        setError('');

        try {
            const res = await authService.resetPassword(email, otpString, password, confirmPassword);
            if (res.data.success) {
                showSnackbar({ type: 'success', message: 'Password reset successful! 🎉' });
                setTimeout(() => navigate('/login', { replace: true }), 2000);
            } else {
                setError(res.data.message || 'Reset failed');
            }
        } catch (err) {
            setError(err.response?.data?.message || 'Password reset failed');
        } finally {
            setLoading(false);
        }
    };

    if (!email) {
        return null;
    }

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
                                border: `1px solid ${alpha('#006B5E', 0.15)}`,
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
                                <Typography variant="h4" fontWeight="800" gutterBottom sx={{ color: '#0f172a' }}>
                                    Reset Password
                                </Typography>
                                <Typography variant="body2" sx={{ color: '#334155', fontWeight: 500 }}>
                                    Enter the OTP sent to <strong style={{ color: '#006B5E', fontWeight: 700 }}>{email}</strong>
                                </Typography>
                            </Box>

                            <form onSubmit={handleSubmit}>
                                <Box sx={{ mb: 3 }}>
                                    <Typography variant="caption" display="block" sx={{ mb: 2, color: '#334155', fontWeight: 600, fontSize: '0.85rem' }}>
                                        Enter 6-digit OTP
                                    </Typography>
                                    <Box
                                        display="flex"
                                        justifyContent="center"
                                        gap={1.5}
                                        onPaste={handlePaste}
                                    >
                                        {[0, 1, 2, 3, 4, 5].map((index) => (
                                            <TextField
                                                key={index}
                                                inputRef={(el) => (inputRefs.current[index] = el)}
                                                value={otp[index]}
                                                onChange={(e) => {
                                                    const value = e.target.value.replace(/\D/g, '');
                                                    handleOtpChange(index, value);
                                                }}
                                                onKeyDown={(e) => handleKeyDown(index, e)}
                                                inputProps={{
                                                    maxLength: 6,
                                                    style: {
                                                        textAlign: 'center',
                                                        fontSize: '1.5rem',
                                                        fontWeight: 700,
                                                        color: '#0f172a',
                                                        width: '44px',
                                                        height: '56px',
                                                        padding: '0',
                                                    },
                                                }}
                                                sx={{
                                                    '& .MuiInputBase-root': {
                                                        borderRadius: 2,
                                                        bgcolor: '#f8fafc',
                                                        '& .MuiOutlinedInput-notchedOutline': {
                                                            borderColor: '#cbd5e1',
                                                        },
                                                        '&:hover .MuiOutlinedInput-notchedOutline': {
                                                            borderColor: '#006B5E',
                                                        },
                                                        '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                                            borderColor: '#006B5E',
                                                            borderWidth: 2,
                                                        },
                                                    },
                                                    width: '52px',
                                                }}
                                            />
                                        ))}
                                    </Box>
                                    <Typography variant="caption" display="block" sx={{ mt: 1, textAlign: 'center', color: '#475569', fontWeight: 500 }}>
                                        Check your email for the OTP code
                                    </Typography>
                                </Box>

                                <TextField
                                    fullWidth
                                    label="New Password"
                                    type={showPassword ? 'text' : 'password'}
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    required
                                    sx={{
                                        mb: 2,
                                        '& .MuiInputLabel-root': {
                                            color: '#475569',
                                            fontWeight: 500,
                                            '&.Mui-focused': { color: '#006B5E' },
                                        },
                                        '& .MuiInputBase-root': {
                                            borderRadius: 2,
                                            py: 0.5,
                                            bgcolor: '#f8fafc',
                                            color: '#0f172a',
                                            fontWeight: 500,
                                        },
                                        '& .MuiOutlinedInput-notchedOutline': {
                                            borderColor: '#cbd5e1',
                                        },
                                        '&:hover .MuiOutlinedInput-notchedOutline': {
                                            borderColor: '#94a3b8',
                                        },
                                        '& .MuiFormHelperText-root': {
                                            color: '#475569',
                                            fontWeight: 500,
                                        },
                                    }}
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start">
                                                <LockIcon sx={{ color: '#475569' }} fontSize="small" />
                                            </InputAdornment>
                                        ),
                                        endAdornment: (
                                            <InputAdornment position="end">
                                                <IconButton onClick={() => setShowPassword(!showPassword)} edge="end" size="small" sx={{ color: '#006B5E' }}>
                                                    {showPassword ? <VisibilityOff /> : <Visibility />}
                                                </IconButton>
                                            </InputAdornment>
                                        ),
                                    }}
                                    helperText="Minimum 8 characters"
                                />

                                <TextField
                                    fullWidth
                                    label="Confirm Password"
                                    type={showConfirm ? 'text' : 'password'}
                                    value={confirmPassword}
                                    onChange={(e) => setConfirmPassword(e.target.value)}
                                    required
                                    sx={{
                                        mb: 1,
                                        '& .MuiInputLabel-root': {
                                            color: '#475569',
                                            fontWeight: 500,
                                            '&.Mui-focused': { color: '#006B5E' },
                                        },
                                        '& .MuiInputBase-root': {
                                            borderRadius: 2,
                                            py: 0.5,
                                            bgcolor: '#f8fafc',
                                            color: '#0f172a',
                                            fontWeight: 500,
                                        },
                                        '& .MuiOutlinedInput-notchedOutline': {
                                            borderColor: '#cbd5e1',
                                        },
                                        '&:hover .MuiOutlinedInput-notchedOutline': {
                                            borderColor: '#94a3b8',
                                        },
                                    }}
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start">
                                                <LockIcon sx={{ color: '#475569' }} fontSize="small" />
                                            </InputAdornment>
                                        ),
                                        endAdornment: (
                                            <InputAdornment position="end">
                                                <IconButton onClick={() => setShowConfirm(!showConfirm)} edge="end" size="small" sx={{ color: '#006B5E' }}>
                                                    {showConfirm ? <VisibilityOff /> : <Visibility />}
                                                </IconButton>
                                            </InputAdornment>
                                        ),
                                    }}
                                />

                                {error && (
                                    <Alert severity="error" sx={{ mt: 2, fontWeight: 600 }}>
                                        {error}
                                    </Alert>
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
                                        fontWeight: 700,
                                        borderRadius: 2,
                                        textTransform: 'none',
                                        background: 'linear-gradient(135deg, #006B5E 0%, #00897B 100%)',
                                        color: '#ffffff',
                                        '&:hover': {
                                            transform: 'translateY(-2px)',
                                            boxShadow: 4,
                                            background: 'linear-gradient(135deg, #005245 0%, #006B5E 100%)',
                                        },
                                    }}
                                >
                                    {loading ? <CircularProgress size={24} color="inherit" /> : 'Reset Password'}
                                </Button>

                                <Button
                                    fullWidth
                                    variant="text"
                                    startIcon={<ArrowBackIcon />}
                                    onClick={() => navigate('/forgot-password')}
                                    sx={{ mt: 2, textTransform: 'none', color: '#006B5E', fontWeight: 700 }}
                                >
                                    Back
                                </Button>
                            </form>
                        </Paper>
                    </Grid>
                </Grid>
            </Container>
        </Box>
    );
}