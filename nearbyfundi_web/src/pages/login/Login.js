// src/pages/auth/Login.jsx
import { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    TextField,
    Button,
    Typography,
    InputAdornment,
    CircularProgress,
    Checkbox,
    FormControlLabel,
    Link,
    alpha,
    Stack,
} from '@mui/material';
import {
    PersonOutline,
    LockOutlined,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from 'context/AuthContext';
import { showSnackbar } from 'utils/snackbar';

const logo = '/assets/logo.png';

export default function Login() {
    const navigate = useNavigate();
    const { login, isAuthenticated } = useAuth();

    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [rememberMe, setRememberMe] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    useEffect(() => {
        if (isAuthenticated) {
            navigate('/app/dashboard', { replace: true });
        }
    }, [isAuthenticated, navigate]);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!email || !password) {
            setError('Please fill in all fields');
            return;
        }

        setLoading(true);
        setError('');

        try {
            await login(email, password);
            showSnackbar({ type: 'success', message: 'Welcome back! 👋' });
            navigate('/app/dashboard', { replace: true });
        } catch (err) {
            setError(err.message || 'Invalid credentials');
            showSnackbar({ type: 'error', message: err.message || 'Login failed' });
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
                background: 'linear-gradient(135deg, #0d5c5f 0%, #0d7377 40%, #14919b 100%)',
                p: { xs: 2, sm: 3 },
                position: 'relative',
                overflow: 'hidden',
            }}
        >
            {/* ========== MAIN CONTAINER (Card + Mockups) ========== */}
            <Box
                sx={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: { xs: 0, md: 3, lg: 5 },
                    width: '100%',
                    maxWidth: 1400,
                    position: 'relative',
                }}
            >
                {/* ===== LEFT PHONE MOCKUP (larger) ===== */}
                <Box
                    sx={{
                        display: { xs: 'none', md: 'block' },
                        width: { md: 210, lg: 240 },
                        flexShrink: 0,
                        transform: 'rotate(-7deg)',
                        transition: 'transform 0.35s ease',
                        '&:hover': {
                            transform: 'rotate(-2deg) scale(1.04)',
                        },
                    }}
                >
                    <Box
                        component="img"
                        src="/assets/mockups/phone-mockup.png"
                        alt="NearbyFundi App"
                        onError={(e) => {
                            e.target.onerror = null;
                            e.target.src =
                                'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="240" height="480" viewBox="0 0 240 480"%3E%3Crect width="240" height="480" fill="%231e293b" rx="28"/%3E%3Ctext x="55" y="245" fill="white" font-size="16"%3EMap View%3C/text%3E%3C/svg%3E';
                        }}
                        sx={{
                            width: '100%',
                            height: 'auto',
                            borderRadius: 5,
                            boxShadow: '0 30px 60px rgba(0,0,0,0.45)',
                            display: 'block',
                        }}
                    />
                </Box>

                {/* ===== MAIN LOGIN CARD ===== */}
                <Paper
                    elevation={0}
                    sx={{
                        width: '100%',
                        maxWidth: 900,
                        borderRadius: 4,
                        overflow: 'hidden',
                        display: 'flex',
                        flexDirection: { xs: 'column', md: 'row' },
                        boxShadow: '0 25px 50px -12px rgba(0,0,0,0.35)',
                        zIndex: 2,
                    }}
                >
                    {/* Left Panel inside card */}
                    <Box
                        sx={{
                            flex: { xs: 'none', md: '0 0 42%' },
                            background: 'linear-gradient(160deg, #0a5c5f 0%, #0d7377 50%, #14919b 100%)',
                            color: 'white',
                            position: 'relative',
                            overflow: 'hidden',
                            p: { xs: 4, md: 5 },
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'center',
                            minHeight: { xs: 220, md: 540 },
                        }}
                    >
                        {/* Abstract circles */}
                        <Box sx={{ position: 'absolute', top: -80, right: -60, width: 280, height: 280, borderRadius: '50%', bgcolor: alpha('#ffffff', 0.08) }} />
                        <Box sx={{ position: 'absolute', bottom: -40, left: -50, width: 180, height: 180, borderRadius: '50%', bgcolor: alpha('#ffffff', 0.1) }} />
                        <Box sx={{ position: 'absolute', bottom: 40, right: 30, width: 110, height: 110, borderRadius: '50%', bgcolor: alpha('#ffffff', 0.12) }} />
                        <Box sx={{ position: 'absolute', top: 60, left: -30, width: 90, height: 90, borderRadius: '50%', bgcolor: alpha('#ffffff', 0.07) }} />

                        <Box sx={{ position: 'relative', zIndex: 1 }}>
                            {/* Logo */}
                            <Box
                                component="img"
                                src={logo}
                                alt="NearbyFundi"
                                onError={(e) => {
                                    e.target.onerror = null;
                                    e.target.src =
                                        'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="52" height="52" viewBox="0 0 24 24"%3E%3Ccircle cx="12" cy="12" r="10" fill="white"/%3E%3Ctext x="5" y="16" font-size="11" fill="%230d7377" font-weight="bold"%3ENF%3C/text%3E%3C/svg%3E';
                                }}
                                sx={{
                                    width: 56,
                                    height: 56,
                                    mb: 3,
                                    filter: 'brightness(0) invert(1)',
                                }}
                            />

                            <Typography
                                variant="h3"
                                fontWeight={800}
                                sx={{
                                    letterSpacing: 1,
                                    mb: 1,
                                    fontSize: { xs: '1.9rem', md: '2.5rem' },
                                }}
                            >
                                WELCOME
                            </Typography>
                            <Typography
                                variant="h6"
                                fontWeight={600}
                                sx={{ opacity: 0.95, mb: 1.5, letterSpacing: 0.5 }}
                            >
                                NearbyFundi
                            </Typography>
                            <Typography
                                variant="body2"
                                sx={{
                                    opacity: 0.85,
                                    maxWidth: 270,
                                    lineHeight: 1.7,
                                    display: { xs: 'none', sm: 'block' },
                                }}
                            >
                                Find trusted technicians near you. Fast, reliable and verified local fundis at your fingertips.
                            </Typography>
                        </Box>
                    </Box>

                    {/* Right Form Panel */}
                    <Box
                        sx={{
                            flex: 1,
                            bgcolor: '#ffffff',
                            p: { xs: 3.5, sm: 5 },
                            display: 'flex',
                            flexDirection: 'column',
                            justifyContent: 'center',
                        }}
                    >
                        <Typography
                            variant="h4"
                            fontWeight={700}
                            sx={{ color: '#1e293b', mb: 0.5, letterSpacing: -0.5 }}
                        >
                            Sign in
                        </Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mb: 4 }}>
                            Sign in to find trusted technicians near you
                        </Typography>

                        <form onSubmit={handleSubmit}>
                            <Stack spacing={2.5}>
                                <TextField
                                    fullWidth
                                    placeholder="Email address"
                                    type="email"
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                    required
                                    autoFocus
                                    sx={{
                                        '& .MuiOutlinedInput-root': {
                                            borderRadius: 2,
                                            bgcolor: '#f1f5f9',
                                            '& fieldset': { border: 'none' },
                                            '&:hover': { bgcolor: '#e2e8f0' },
                                            '&.Mui-focused': {
                                                bgcolor: '#fff',
                                                boxShadow: `0 0 0 2px ${alpha('#0d7377', 0.3)}`,
                                            },
                                        },
                                    }}
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start">
                                                <PersonOutline sx={{ color: '#94a3b8' }} />
                                            </InputAdornment>
                                        ),
                                    }}
                                />

                                <TextField
                                    fullWidth
                                    placeholder="Password"
                                    type={showPassword ? 'text' : 'password'}
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    required
                                    sx={{
                                        '& .MuiOutlinedInput-root': {
                                            borderRadius: 2,
                                            bgcolor: '#f1f5f9',
                                            '& fieldset': { border: 'none' },
                                            '&:hover': { bgcolor: '#e2e8f0' },
                                            '&.Mui-focused': {
                                                bgcolor: '#fff',
                                                boxShadow: `0 0 0 2px ${alpha('#0d7377', 0.3)}`,
                                            },
                                        },
                                    }}
                                    InputProps={{
                                        startAdornment: (
                                            <InputAdornment position="start">
                                                <LockOutlined sx={{ color: '#94a3b8' }} />
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
                                                        fontWeight: 600,
                                                        minWidth: 'auto',
                                                        px: 1,
                                                    }}
                                                >
                                                    {showPassword ? 'HIDE' : 'SHOW'}
                                                </Button>
                                            </InputAdornment>
                                        ),
                                    }}
                                />

                                {error && (
                                    <Typography color="error" variant="body2">
                                        {error}
                                    </Typography>
                                )}

                                <Box display="flex" justifyContent="space-between" alignItems="center">
                                    <FormControlLabel
                                        control={
                                            <Checkbox
                                                checked={rememberMe}
                                                onChange={(e) => setRememberMe(e.target.checked)}
                                                size="small"
                                                sx={{
                                                    color: '#94a3b8',
                                                    '&.Mui-checked': { color: '#0d7377' },
                                                }}
                                            />
                                        }
                                        label={
                                            <Typography variant="body2" color="text.secondary">
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
                                            fontSize: '0.875rem',
                                            fontWeight: 500,
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
                                        mt: 1,
                                        py: 1.7,
                                        borderRadius: 2,
                                        textTransform: 'none',
                                        fontSize: '1rem',
                                        fontWeight: 600,
                                        bgcolor: '#0d5c5f',
                                        color: '#fff',
                                        boxShadow: '0 4px 14px rgba(13, 92, 95, 0.35)',
                                        '&:hover': {
                                            bgcolor: '#0a4a4d',
                                            boxShadow: '0 6px 20px rgba(13, 92, 95, 0.45)',
                                        },
                                        '&.Mui-disabled': {
                                            bgcolor: alpha('#0d5c5f', 0.5),
                                            color: '#fff',
                                        },
                                    }}
                                >
                                    {loading ? (
                                        <CircularProgress size={24} color="inherit" />
                                    ) : (
                                        'Sign in'
                                    )}
                                </Button>
                            </Stack>
                        </form>

                        <Typography
                            variant="body2"
                            align="center"
                            sx={{ mt: 4, color: '#64748b' }}
                        >
                            Don’t have an account?{' '}
                            <Link
                                component="button"
                                underline="hover"
                                onClick={() => navigate('/register')}
                                sx={{ color: '#0d7377', fontWeight: 600 }}
                            >
                                Sign Up
                            </Link>
                        </Typography>
                    </Box>
                </Paper>

                {/* ===== RIGHT PHONE MOCKUP (larger) ===== */}
                <Box
                    sx={{
                        display: { xs: 'none', md: 'block' },
                        width: { md: 210, lg: 240 },
                        flexShrink: 0,
                        transform: 'rotate(7deg)',
                        transition: 'transform 0.35s ease',
                        '&:hover': {
                            transform: 'rotate(2deg) scale(1.04)',
                        },
                    }}
                >
                    <Box
                        component="img"
                        src="/assets/mockups/phone-mockup1.png"
                        alt="NearbyFundi App"
                        onError={(e) => {
                            e.target.onerror = null;
                            e.target.src =
                                'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="240" height="480" viewBox="0 0 240 480"%3E%3Crect width="240" height="480" fill="%23334155" rx="28"/%3E%3Ctext x="50" y="245" fill="white" font-size="16"%3EApp Preview%3C/text%3E%3C/svg%3E';
                        }}
                        sx={{
                            width: '100%',
                            height: 'auto',
                            borderRadius: 5,
                            boxShadow: '0 30px 60px rgba(0,0,0,0.45)',
                            display: 'block',
                        }}
                    />
                </Box>
            </Box>
        </Box>
    );
}