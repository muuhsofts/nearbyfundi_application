// src/pages/auth/Login.jsx
import { useState, useEffect } from 'react';
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
} from '@mui/material';
import {
    Visibility,
    VisibilityOff,
    Email as EmailIcon,
    Lock as LockIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from 'context/AuthContext';
import { showSnackbar } from 'utils/snackbar';

const logo = '/assets/logo.png';

export default function Login() {
    const theme = useTheme();
    const navigate = useNavigate();
    const { login, isAuthenticated } = useAuth();

    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    // Redirect if already authenticated
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

            // Always redirect to dashboard
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
                bgcolor: '#f5f7fa',
                p: { xs: 2, sm: 3 },
            }}
        >
            <Container maxWidth="lg">
                <Paper
                    elevation={0}
                    sx={{
                        borderRadius: 4,
                        overflow: 'hidden',
                        boxShadow: '0 20px 60px rgba(0,0,0,0.06)',
                        border: `1px solid ${alpha('#006B5E', 0.06)}`,
                        bgcolor: '#ffffff',
                    }}
                >
                    <Grid container>
                        {/* Left Side - Phone Mockup & Branding with #006B5E background */}
                        <Grid
                            item
                            xs={12}
                            md={7}
                            sx={{
                                display: { xs: 'none', md: 'flex' },
                                flexDirection: 'column',
                                justifyContent: 'center',
                                alignItems: 'center',
                                p: 6,
                                background: 'linear-gradient(135deg, #006B5E 0%, #00897B 50%, #00A896 100%)',
                                color: 'white',
                                position: 'relative',
                                overflow: 'hidden',
                                minHeight: '700px',
                            }}
                        >
                            {/* Decorative elements */}
                            <Box
                                sx={{
                                    position: 'absolute',
                                    top: -150,
                                    right: -150,
                                    width: 400,
                                    height: 400,
                                    borderRadius: '50%',
                                    background: alpha('#ffffff', 0.06),
                                }}
                            />
                            <Box
                                sx={{
                                    position: 'absolute',
                                    bottom: -80,
                                    left: -80,
                                    width: 250,
                                    height: 250,
                                    borderRadius: '50%',
                                    background: alpha('#ffffff', 0.05),
                                }}
                            />
                            <Box
                                sx={{
                                    position: 'absolute',
                                    top: '50%',
                                    left: '50%',
                                    transform: 'translate(-50%, -50%)',
                                    width: 600,
                                    height: 600,
                                    borderRadius: '50%',
                                    border: `1px solid ${alpha('#ffffff', 0.05)}`,
                                }}
                            />

                            <Box sx={{ position: 'relative', zIndex: 1, textAlign: 'center', width: '100%' }}>
                                {/* Logo */}
                                <Box
                                    component="img"
                                    src={logo}
                                    alt="NearbyFundi"
                                    onError={(e) => {
                                        e.target.onerror = null;
                                        e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 24 24"%3E%3Ctext x="0" y="20" font-size="20" fill="white"%3ENF%3C/text%3E%3C/svg%3E';
                                    }}
                                    sx={{
                                        width: 80,
                                        height: 80,
                                        mb: 3,
                                        display: 'block',
                                        mx: 'auto',
                                        filter: 'brightness(0) invert(1)',
                                    }}
                                />
                                <Typography variant="h2" fontWeight="800" gutterBottom>
                                    NearbyFundi
                                </Typography>
                                <Typography variant="h6" sx={{ opacity: 0.9, mb: 5, maxWidth: 420, mx: 'auto' }}>
                                    Find trusted technicians near you.
                                </Typography>

                                {/* Phone Mockup - Main Feature */}
                                <Box
                                    sx={{
                                        display: 'flex',
                                        justifyContent: 'center',
                                        alignItems: 'center',
                                        gap: 4,
                                        perspective: '1000px',
                                    }}
                                >
                                    <Box
                                        sx={{
                                            width: 220,
                                            height: 'auto',
                                            borderRadius: 4,
                                            boxShadow: '0 30px 80px rgba(0,0,0,0.35)',
                                            transition: 'all 0.4s ease',
                                            transform: 'rotate(-3deg) scale(1)',
                                            '&:hover': {
                                                transform: 'rotate(0deg) scale(1.03)',
                                                boxShadow: '0 40px 100px rgba(0,0,0,0.45)',
                                            },
                                        }}
                                    >
                                        <Box
                                            component="img"
                                            src="/assets/mockups/phone-mockup-.jpeg"
                                            alt="NearbyFundi App"
                                            onError={(e) => {
                                                e.target.onerror = null;
                                                e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="220" height="400" viewBox="0 0 220 400"%3E%3Crect width="220" height="400" fill="%23333" rx="20"/%3E%3Ctext x="60" y="200" fill="white" font-size="16"%3EPhone%3C/text%3E%3C/svg%3E';
                                            }}
                                            sx={{
                                                width: '100%',
                                                height: 'auto',
                                                borderRadius: 4,
                                                display: 'block',
                                            }}
                                        />
                                    </Box>

                                    <Box
                                        sx={{
                                            width: 220,
                                            height: 'auto',
                                            borderRadius: 4,
                                            boxShadow: '0 30px 80px rgba(0,0,0,0.35)',
                                            transition: 'all 0.4s ease',
                                            transform: 'rotate(3deg) scale(1)',
                                            '&:hover': {
                                                transform: 'rotate(0deg) scale(1.03)',
                                                boxShadow: '0 40px 100px rgba(0,0,0,0.45)',
                                            },
                                        }}
                                    >
                                        <Box
                                            component="img"
                                            src="/assets/mockups/phone-mockup-2.jpeg"
                                            alt="NearbyFundi App"
                                            onError={(e) => {
                                                e.target.onerror = null;
                                                e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="220" height="400" viewBox="0 0 220 400"%3E%3Crect width="220" height="400" fill="%23444" rx="20"/%3E%3Ctext x="60" y="200" fill="white" font-size="16"%3EPhone 2%3C/text%3E%3C/svg%3E';
                                            }}
                                            sx={{
                                                width: '100%',
                                                height: 'auto',
                                                borderRadius: 4,
                                                display: 'block',
                                            }}
                                        />
                                    </Box>
                                </Box>
                            </Box>
                        </Grid>

                        {/* Right Side - Login Form */}
                        <Grid item xs={12} md={5}>
                            <Box sx={{ p: { xs: 4, sm: 5, md: 6 }, bgcolor: '#ffffff' }}>
                                {/* Logo at top */}
                                <Box
                                    component="img"
                                    src={logo}
                                    alt="NearbyFundi"
                                    onError={(e) => {
                                        e.target.onerror = null;
                                        e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="60" height="60" viewBox="0 0 24 24"%3E%3Ctext x="0" y="20" font-size="20" fill="%23006B5E"%3ENF%3C/text%3E%3C/svg%3E';
                                    }}
                                    sx={{
                                        width: 60,
                                        height: 60,
                                        display: 'block',
                                        mx: 'auto',
                                        mb: 2,
                                    }}
                                />

                                {/* Welcome Back Text */}
                                <Box textAlign="center" mb={5}>
                                    <Typography variant="h4" fontWeight="700" gutterBottom sx={{ color: '#1a1a2e' }}>
                                        Welcome Back
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Sign in to find trusted technicians
                                    </Typography>
                                </Box>

                                <form onSubmit={handleSubmit}>
                                    {/* Email Field */}
                                    <TextField
                                        fullWidth
                                        label="Email Address"
                                        type="email"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        autoFocus
                                        sx={{
                                            mb: 3,
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

                                    {/* Password Field */}
                                    <TextField
                                        fullWidth
                                        label="Password"
                                        type={showPassword ? 'text' : 'password'}
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        required
                                        sx={{
                                            mb: 1,
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
                                                    <LockIcon color="action" fontSize="small" />
                                                </InputAdornment>
                                            ),
                                            endAdornment: (
                                                <InputAdornment position="end">
                                                    <IconButton
                                                        onClick={() => setShowPassword(!showPassword)}
                                                        edge="end"
                                                        size="small"
                                                    >
                                                        {showPassword ? <VisibilityOff /> : <Visibility />}
                                                    </IconButton>
                                                </InputAdornment>
                                            ),
                                        }}
                                    />

                                    {error && (
                                        <Typography color="error" variant="body2" sx={{ mt: 1 }}>
                                            {error}
                                        </Typography>
                                    )}

                                    {/* Forgot Password */}
                                    <Box
                                        display="flex"
                                        justifyContent="flex-end"
                                        sx={{ mb: 4 }}
                                    >
                                        <Button
                                            variant="text"
                                            size="small"
                                            onClick={() => navigate('/forgot-password')}
                                            sx={{
                                                textTransform: 'none',
                                                color: 'text.secondary',
                                                '&:hover': { color: '#006B5E' },
                                            }}
                                        >
                                            Forgot Password?
                                        </Button>
                                    </Box>

                                    {/* Sign In Button */}
                                    <Button
                                        type="submit"
                                        variant="contained"
                                        fullWidth
                                        disabled={loading}
                                        sx={{
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
                                        {loading ? <CircularProgress size={24} color="inherit" /> : 'Sign In'}
                                    </Button>
                                </form>

                                {/* Footer */}
                                <Typography
                                    variant="caption"
                                    color="text.secondary"
                                    align="center"
                                    display="block"
                                    sx={{ mt: 5 }}
                                >
                                    © {new Date().getFullYear()} NearbyFundi • All Rights Reserved
                                </Typography>
                            </Box>
                        </Grid>
                    </Grid>
                </Paper>
            </Container>
        </Box>
    );
}