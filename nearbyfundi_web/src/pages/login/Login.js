// src/pages/auth/Login.jsx
import { useState, useEffect, useRef } from 'react';
import {
    Box, Paper, TextField, Button, Typography, InputAdornment,
    CircularProgress, Checkbox, FormControlLabel, Link, alpha, Stack,
    ToggleButton, ToggleButtonGroup, MenuItem, Select, FormControl,
} from '@mui/material';
import {
    PersonOutline, LockOutlined, SmsOutlined,
    EmailOutlined, PhoneOutlined, AlternateEmail
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from 'context/AuthContext';
import { showSnackbar } from 'utils/snackbar';

const logo = '/assets/logo.png';

// Country codes for phone input
const COUNTRY_CODES = [
    { code: '+255', country: 'TZ', label: '🇹🇿 +255' },
    { code: '+254', country: 'KE', label: '🇰🇪 +254' },
    { code: '+256', country: 'UG', label: '🇺🇬 +256' },
    { code: '+250', country: 'RW', label: '🇷🇼 +250' },
    { code: '+257', country: 'BI', label: '🇧🇮 +257' },
    { code: '+1', country: 'US', label: '🇺🇸 +1' },
    { code: '+44', country: 'GB', label: '🇬🇧 +44' },
];

export default function Login() {
    const navigate = useNavigate();
    const { login, requestWebOtp, verifyWebOtp, resendWebOtp, isAuthenticated } = useAuth();

    // Login method toggle: 'email' or 'phone'
    const [loginMethod, setLoginMethod] = useState('email');

    // Email login fields
    const [email, setEmail] = useState('');

    // Phone login fields
    const [countryCode, setCountryCode] = useState('+255');
    const [phoneNumber, setPhoneNumber] = useState('');

    // Shared fields
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [rememberMe, setRememberMe] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    // OTP step
    const [step, setStep] = useState('credentials');
    const [otp, setOtp] = useState('');
    const [otpMeta, setOtpMeta] = useState(null);
    const [resendCooldown, setResendCooldown] = useState(0);

    // Refs for auto-focus
    const emailRef = useRef(null);
    const phoneRef = useRef(null);
    const passwordRef = useRef(null);

    useEffect(() => {
        if (isAuthenticated) {
            navigate('/app/dashboard', { replace: true });
        }
    }, [isAuthenticated, navigate]);

    useEffect(() => {
        if (resendCooldown <= 0) return;
        const t = setInterval(() => setResendCooldown((c) => c - 1), 1000);
        return () => clearInterval(t);
    }, [resendCooldown]);

    // Focus on appropriate field when login method changes
    useEffect(() => {
        if (loginMethod === 'email' && emailRef.current) {
            setTimeout(() => emailRef.current?.focus(), 100);
        } else if (loginMethod === 'phone' && phoneRef.current) {
            setTimeout(() => phoneRef.current?.focus(), 100);
        }
    }, [loginMethod]);

    // Get full identifier (email or phone with country code)
    const getIdentifier = () => {
        if (loginMethod === 'email') {
            return email;
        } else {
            return `${countryCode}${phoneNumber}`;
        }
    };

    // Validate input based on method
    const isValidIdentifier = () => {
        if (loginMethod === 'email') {
            return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
        } else {
            return phoneNumber.replace(/\D/g, '').length >= 7;
        }
    };

    // ─── Step 1: Credentials ──────────────────────────────────
    const handleCredentialsSubmit = async (e) => {
        e.preventDefault();

        const identifier = getIdentifier();

        if (!identifier || !password) {
            setError('Please fill in all fields');
            return;
        }

        if (!isValidIdentifier()) {
            setError(loginMethod === 'email' ? 'Please enter a valid email address' : 'Please enter a valid phone number');
            return;
        }

        setLoading(true);
        setError('');

        try {
            const data = await requestWebOtp(identifier, password);
            setOtpMeta(data);
            setStep('otp');
            setResendCooldown(60);
            showSnackbar({ type: 'success', message: `OTP sent to ${data.sent_to || 'your phone'}` });
        } catch (err) {
            const msg = err?.response?.data?.message || err.message || '';

            if (
                msg.toLowerCase().includes('only available for authorized') ||
                msg.toLowerCase().includes('unauthorized role') ||
                err?.response?.status === 403
            ) {
                try {
                    await login(identifier, password);
                    showSnackbar({ type: 'success', message: 'Welcome back! 👋' });
                    navigate('/app/dashboard', { replace: true });
                } catch (classicErr) {
                    setError(classicErr.message || 'Invalid credentials');
                    showSnackbar({ type: 'error', message: classicErr.message || 'Login failed' });
                }
            } else {
                setError(msg || 'Invalid credentials');
                showSnackbar({ type: 'error', message: msg || 'Login failed' });
            }
        } finally {
            setLoading(false);
        }
    };

    // ─── Step 2: Verify OTP ───────────────────────────────────
    const handleOtpSubmit = async (e) => {
        e.preventDefault();
        if (!otp || otp.length !== 6) {
            setError('Please enter the 6-digit OTP');
            return;
        }

        setLoading(true);
        setError('');

        try {
            await verifyWebOtp(otpMeta.email || getIdentifier(), otp);
            showSnackbar({ type: 'success', message: 'Login successful!' });
            navigate('/app/dashboard', { replace: true });
        } catch (err) {
            setError(err.message || 'Invalid or expired OTP');
            showSnackbar({ type: 'error', message: err.message || 'OTP verification failed' });
        } finally {
            setLoading(false);
        }
    };

    const handleResendOtp = async () => {
        if (resendCooldown > 0) return;
        setLoading(true);
        try {
            const data = await resendWebOtp(otpMeta.email || getIdentifier());
            setOtpMeta(data);
            setResendCooldown(60);
            showSnackbar({ type: 'success', message: 'OTP resent successfully' });
        } catch (err) {
            showSnackbar({ type: 'error', message: err.message || 'Failed to resend OTP' });
        } finally {
            setLoading(false);
        }
    };

    const goBackToCredentials = () => {
        setStep('credentials');
        setOtp('');
        setError('');
        setOtpMeta(null);
    };

    // Handle login method change
    const handleLoginMethodChange = (event, newMethod) => {
        if (newMethod !== null) {
            setLoginMethod(newMethod);
            setError('');
        }
    };

    // ─── UI ───────────────────────────────────────────────────
    return (
        <Box
            sx={{
                minHeight: '100vh',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                background: 'linear-gradient(135deg, #0d5c5f 0%, #0d7377 40%, #14919b 100%)',
                p: { xs: 2, sm: 3 },
                position: 'relative',
                overflow: 'hidden',
            }}
        >
            <Box
                sx={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: { xs: 0, md: 3, lg: 5 },
                    width: '100%',
                    maxWidth: 1400,
                }}
            >
                {/* Left mockup */}
                <Box sx={{ display: { xs: 'none', md: 'block' }, width: { md: 210, lg: 240 }, flexShrink: 0, transform: 'rotate(-7deg)' }}>
                    <Box component="img" src="/assets/mockups/phone-mockup.png" alt="NearbyFundi" sx={{ width: '100%', borderRadius: 5, boxShadow: '0 30px 60px rgba(0,0,0,0.45)' }} />
                </Box>

                <Paper elevation={0} sx={{ width: '100%', maxWidth: 900, borderRadius: 4, overflow: 'hidden', display: 'flex', flexDirection: { xs: 'column', md: 'row' }, boxShadow: '0 25px 50px -12px rgba(0,0,0,0.35)' }}>
                    {/* Left branding panel */}
                    <Box sx={{ flex: { xs: 'none', md: '0 0 42%' }, background: 'linear-gradient(160deg, #0a5c5f 0%, #0d7377 50%, #14919b 100%)', color: '#fff', p: { xs: 4, md: 5 }, display: 'flex', flexDirection: 'column', justifyContent: 'center', minHeight: { xs: 220, md: 540 }, position: 'relative', overflow: 'hidden' }}>
                        <Box sx={{ position: 'absolute', top: -80, right: -60, width: 280, height: 280, borderRadius: '50%', bgcolor: alpha('#fff', 0.08) }} />
                        <Box sx={{ position: 'relative', zIndex: 1 }}>
                            <Box component="img" src={logo} alt="NearbyFundi" sx={{ width: 56, height: 56, mb: 3, filter: 'brightness(0) invert(1)' }} />
                            <Typography variant="h3" fontWeight={800} sx={{ mb: 1, fontSize: { xs: '1.9rem', md: '2.5rem' } }}>WELCOME</Typography>
                            <Typography variant="h6" fontWeight={700} sx={{ mb: 1.5 }}>NearbyFundi</Typography>
                            <Typography variant="body2" sx={{ color: '#f8fafc', maxWidth: 270, lineHeight: 1.7, display: { xs: 'none', sm: 'block' } }}>
                                Find trusted technicians near you. Fast, reliable and verified local fundis at your fingertips.
                            </Typography>
                        </Box>
                    </Box>

                    {/* Right form panel */}
                    <Box sx={{ flex: 1, bgcolor: '#fff', p: { xs: 3.5, sm: 5 }, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                        {step === 'credentials' ? (
                            <>
                                <Typography variant="h4" fontWeight={800} sx={{ color: '#0f172a', mb: 0.5 }}>Sign in</Typography>
                                <Typography variant="body2" sx={{ color: '#334155', fontWeight: 500, mb: 3 }}>
                                    Sign in to find trusted technicians near you
                                </Typography>

                                {/* Login Method Toggle - Horizontal */}
                                <ToggleButtonGroup
                                    value={loginMethod}
                                    exclusive
                                    onChange={handleLoginMethodChange}
                                    aria-label="login method"
                                    sx={{
                                        mb: 3,
                                        width: '100%',
                                        '& .MuiToggleButton-root': {
                                            flex: 1,
                                            py: 1.2,
                                            borderRadius: 2,
                                            border: '2px solid #e2e8f0',
                                            textTransform: 'none',
                                            fontWeight: 600,
                                            '&.Mui-selected': {
                                                backgroundColor: '#0d5c5f',
                                                color: '#fff',
                                                borderColor: '#0d5c5f',
                                                '&:hover': {
                                                    backgroundColor: '#0a4a4d',
                                                }
                                            },
                                            '&:hover': {
                                                backgroundColor: alpha('#0d5c5f', 0.05),
                                            }
                                        }
                                    }}
                                >
                                    <ToggleButton value="email" aria-label="email login">
                                        <EmailOutlined sx={{ mr: 1, fontSize: 20 }} />
                                        Email
                                    </ToggleButton>
                                    <ToggleButton value="phone" aria-label="phone login">
                                        <PhoneOutlined sx={{ mr: 1, fontSize: 20 }} />
                                        Phone
                                    </ToggleButton>
                                </ToggleButtonGroup>

                                <form onSubmit={handleCredentialsSubmit}>
                                    <Stack spacing={2.5}>
                                        {/* Dynamic Input Field */}
                                        {loginMethod === 'email' ? (
                                            <TextField
                                                fullWidth
                                                ref={emailRef}
                                                placeholder="Enter your email address"
                                                label="Email Address"
                                                type="email"
                                                value={email}
                                                onChange={(e) => setEmail(e.target.value)}
                                                required
                                                autoFocus
                                                sx={{
                                                    '& .MuiOutlinedInput-root': {
                                                        borderRadius: 2,
                                                        bgcolor: '#f8fafc',
                                                        '&:hover': {
                                                            bgcolor: '#f1f5f9',
                                                        }
                                                    }
                                                }}
                                                InputProps={{
                                                    startAdornment: (
                                                        <InputAdornment position="start">
                                                            <AlternateEmail sx={{ color: '#475569' }} />
                                                        </InputAdornment>
                                                    ),
                                                }}
                                            />
                                        ) : (
                                            <Box sx={{ display: 'flex', gap: 1 }}>
                                                <FormControl sx={{ minWidth: 120 }}>
                                                    <Select
                                                        value={countryCode}
                                                        onChange={(e) => setCountryCode(e.target.value)}
                                                        sx={{
                                                            borderRadius: 2,
                                                            bgcolor: '#f8fafc',
                                                            '& .MuiSelect-select': {
                                                                py: 1.7,
                                                            }
                                                        }}
                                                    >
                                                        {COUNTRY_CODES.map((country) => (
                                                            <MenuItem key={country.code} value={country.code}>
                                                                {country.label}
                                                            </MenuItem>
                                                        ))}
                                                    </Select>
                                                </FormControl>
                                                <TextField
                                                    fullWidth
                                                    ref={phoneRef}
                                                    placeholder="Enter phone number"
                                                    label="Phone Number"
                                                    type="tel"
                                                    value={phoneNumber}
                                                    onChange={(e) => setPhoneNumber(e.target.value.replace(/\D/g, ''))}
                                                    required
                                                    autoFocus={loginMethod === 'phone'}
                                                    sx={{
                                                        '& .MuiOutlinedInput-root': {
                                                            borderRadius: 2,
                                                            bgcolor: '#f8fafc',
                                                            '&:hover': {
                                                                bgcolor: '#f1f5f9',
                                                            }
                                                        }
                                                    }}
                                                    InputProps={{
                                                        startAdornment: (
                                                            <InputAdornment position="start">
                                                                <PhoneOutlined sx={{ color: '#475569' }} />
                                                            </InputAdornment>
                                                        ),
                                                    }}
                                                />
                                            </Box>
                                        )}

                                        <TextField
                                            fullWidth
                                            ref={passwordRef}
                                            placeholder="Enter your password"
                                            label="Password"
                                            type={showPassword ? 'text' : 'password'}
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                            required
                                            sx={{
                                                '& .MuiOutlinedInput-root': {
                                                    borderRadius: 2,
                                                    bgcolor: '#f8fafc',
                                                    '&:hover': {
                                                        bgcolor: '#f1f5f9',
                                                    }
                                                }
                                            }}
                                            InputProps={{
                                                startAdornment: (
                                                    <InputAdornment position="start">
                                                        <LockOutlined sx={{ color: '#475569' }} />
                                                    </InputAdornment>
                                                ),
                                                endAdornment: (
                                                    <InputAdornment position="end">
                                                        <Button
                                                            size="small"
                                                            onClick={() => setShowPassword(!showPassword)}
                                                            sx={{
                                                                textTransform: 'none',
                                                                color: '#0d7377',
                                                                fontWeight: 700,
                                                                minWidth: 'auto',
                                                            }}
                                                        >
                                                            {showPassword ? 'Hide' : 'Show'}
                                                        </Button>
                                                    </InputAdornment>
                                                ),
                                            }}
                                        />

                                        {error && (
                                            <Typography color="error" variant="body2" fontWeight={600}>
                                                {error}
                                            </Typography>
                                        )}

                                        <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap">
                                            <FormControlLabel
                                                control={
                                                    <Checkbox
                                                        checked={rememberMe}
                                                        onChange={(e) => setRememberMe(e.target.checked)}
                                                        size="small"
                                                        sx={{
                                                            '&.Mui-checked': {
                                                                color: '#0d7377'
                                                            }
                                                        }}
                                                    />
                                                }
                                                label={
                                                    <Typography variant="body2" sx={{ color: '#334155', fontWeight: 500 }}>
                                                        Remember me
                                                    </Typography>
                                                }
                                            />
                                            <Link
                                                component="button"
                                                type="button"
                                                underline="hover"
                                                onClick={() => navigate('/forgot-password')}
                                                sx={{
                                                    color: '#0d7377',
                                                    fontWeight: 600,
                                                    fontSize: '0.875rem',
                                                }}
                                            >
                                                Forgot Password?
                                            </Link>
                                        </Box>

                                        <Button
                                            type="submit"
                                            fullWidth
                                            disabled={loading}
                                            sx={{
                                                py: 1.7,
                                                borderRadius: 2,
                                                textTransform: 'none',
                                                fontWeight: 700,
                                                bgcolor: '#0d5c5f',
                                                color: '#fff',
                                                '&:hover': {
                                                    bgcolor: '#0a4a4d'
                                                },
                                                '&:disabled': {
                                                    bgcolor: alpha('#0d5c5f', 0.6),
                                                }
                                            }}
                                        >
                                            {loading ? <CircularProgress size={24} color="inherit" /> : 'Sign in'}
                                        </Button>
                                    </Stack>
                                </form>
                            </>
                        ) : (
                            // ─── OTP Step ──────────────────────────────────────
                            <>
                                <Typography variant="h4" fontWeight={800} sx={{ color: '#0f172a', mb: 0.5 }}>Enter OTP</Typography>
                                <Typography variant="body2" sx={{ color: '#334155', fontWeight: 500, mb: 1 }}>
                                    We sent a 6-digit code to <strong>{otpMeta?.sent_to || 'your phone'}</strong>
                                </Typography>
                                <Typography variant="caption" sx={{ color: '#64748b', mb: 3, display: 'block' }}>
                                    Code expires in {otpMeta?.expires_in || 5} minutes
                                </Typography>

                                <form onSubmit={handleOtpSubmit}>
                                    <Stack spacing={2.5}>
                                        <TextField
                                            fullWidth
                                            placeholder="Enter 6-digit OTP"
                                            label="Verification Code"
                                            value={otp}
                                            onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                                            required
                                            autoFocus
                                            inputProps={{
                                                maxLength: 6,
                                                inputMode: 'numeric',
                                                pattern: '[0-9]*',
                                                style: { letterSpacing: 8, fontSize: '1.4rem', fontWeight: 700 }
                                            }}
                                            sx={{
                                                '& .MuiOutlinedInput-root': {
                                                    borderRadius: 2,
                                                    bgcolor: '#f8fafc',
                                                    '&:hover': {
                                                        bgcolor: '#f1f5f9',
                                                    }
                                                }
                                            }}
                                            InputProps={{
                                                startAdornment: (
                                                    <InputAdornment position="start">
                                                        <SmsOutlined sx={{ color: '#475569' }} />
                                                    </InputAdornment>
                                                ),
                                            }}
                                        />

                                        {error && (
                                            <Typography color="error" variant="body2" fontWeight={600}>
                                                {error}
                                            </Typography>
                                        )}

                                        <Button
                                            type="submit"
                                            fullWidth
                                            disabled={loading || otp.length !== 6}
                                            sx={{
                                                py: 1.7,
                                                borderRadius: 2,
                                                textTransform: 'none',
                                                fontWeight: 700,
                                                bgcolor: '#0d5c5f',
                                                color: '#fff',
                                                '&:hover': {
                                                    bgcolor: '#0a4a4d'
                                                },
                                                '&:disabled': {
                                                    bgcolor: alpha('#0d5c5f', 0.6),
                                                }
                                            }}
                                        >
                                            {loading ? <CircularProgress size={24} color="inherit" /> : 'Verify & Login'}
                                        </Button>

                                        <Box display="flex" justifyContent="space-between" alignItems="center">
                                            <Button
                                                onClick={goBackToCredentials}
                                                sx={{
                                                    textTransform: 'none',
                                                    color: '#64748b',
                                                    '&:hover': {
                                                        bgcolor: alpha('#64748b', 0.05),
                                                    }
                                                }}
                                            >
                                                ← Back to login
                                            </Button>
                                            <Button
                                                onClick={handleResendOtp}
                                                disabled={resendCooldown > 0 || loading}
                                                sx={{
                                                    textTransform: 'none',
                                                    color: '#0d7377',
                                                    fontWeight: 600,
                                                    '&:hover': {
                                                        bgcolor: alpha('#0d7377', 0.05),
                                                    },
                                                    '&:disabled': {
                                                        color: '#94a3b8',
                                                    }
                                                }}
                                            >
                                                {resendCooldown > 0 ? `Resend in ${resendCooldown}s` : 'Resend OTP'}
                                            </Button>
                                        </Box>
                                    </Stack>
                                </form>
                            </>
                        )}

                        <Typography variant="body2" align="center" sx={{ mt: 4, color: '#334155' }}>
                            Don't have an account?{' '}
                            <Link
                                component="button"
                                underline="hover"
                                onClick={() => navigate('')}
                                sx={{
                                    color: '#0d7377',
                                    fontWeight: 700,
                                    '&:hover': {
                                        color: '#0a4a4d',
                                    }
                                }}
                            >
                                Sign Up
                            </Link>
                        </Typography>
                    </Box>
                </Paper>

                {/* Right mockup */}
                <Box sx={{ display: { xs: 'none', md: 'block' }, width: { md: 210, lg: 240 }, flexShrink: 0, transform: 'rotate(7deg)' }}>
                    <Box component="img" src="/assets/mockups/phone-mockup1.png" alt="NearbyFundi" sx={{ width: '100%', borderRadius: 5, boxShadow: '0 30px 60px rgba(0,0,0,0.45)' }} />
                </Box>
            </Box>
        </Box>
    );
}