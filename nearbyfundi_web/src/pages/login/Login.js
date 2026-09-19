// src/pages/login/Login.js
import { useState, useEffect, useRef } from 'react';
import {
    Box, Paper, TextField, Button, Typography, InputAdornment,
    CircularProgress, Checkbox, FormControlLabel, Link, alpha, Stack,
    ToggleButton, ToggleButtonGroup, MenuItem,
    Autocomplete, Tooltip, IconButton, Popover,
} from '@mui/material';
import {
    LockOutlined, SmsOutlined, EmailOutlined,
    PhoneOutlined, AlternateEmail,
    Palette as PaletteIcon,
    Check as CheckIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useAuth } from 'context/AuthContext';
import { useLanguage } from 'context/LanguageContext';
import { showSnackbar } from 'utils/snackbar';
import { tLogin } from './loginlang';
import { COUNTRY_CODES } from './countryCodes';
import LanguageSwitcher from 'components/LanguageSwitcher/LanguageSwitcher';
import { useThemeKey } from 'context/ThemeContext';

/* -----------------------------------------------------------
 *  Brand palette — DO NOT change outside this file
 * ----------------------------------------------------------- */
const BRAND = {
    primary:   '#0d7377', // Deep Teal / Forest Green
    secondary: '#1E4D4F', // Mint / Vibrant Green
    success:   '#10B981', // Emerald
    info:      '#8B5CF6', // Violet
    warning:   '#F59E0B', // Amber
};

const logo = '/assets/logo.png';

/* -----------------------------------------------------------
 *  Theme options — reuse brand colors
 * ----------------------------------------------------------- */
const THEME_OPTIONS = [
    { key: 'default',   color: BRAND.primary,   label: 'Teal' },
    { key: 'secondary', color: BRAND.info,      label: 'Violet' },
    { key: 'success',   color: BRAND.success,   label: 'Green' },
    { key: 'dark',      color: '#0F172A',       label: 'Dark' },
];

/* -----------------------------------------------------------
 *  Theme Switcher
 * ----------------------------------------------------------- */
function ThemeSwitcher() {
    const [anchorEl, setAnchorEl] = useState(null);
    const open = Boolean(anchorEl);

    const { themeKey, setThemeKey } = useThemeKey();

    const handleOpen = (e) => setAnchorEl(e.currentTarget);
    const handleClose = () => setAnchorEl(null);

    const handleSelect = (key) => {
        setThemeKey(key);
        handleClose();
    };

    return (
        <>
            <Tooltip title="Change theme">
                <IconButton
                    onClick={handleOpen}
                    size="small"
                    sx={{
                        color: '#ffffff',
                        p: 0.75,
                        '&:hover': { bgcolor: 'rgba(255,255,255,0.15)' },
                    }}
                >
                    <PaletteIcon fontSize="small" />
                </IconButton>
            </Tooltip>

            <Popover
                open={open}
                anchorEl={anchorEl}
                onClose={handleClose}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                PaperProps={{
                    sx: {
                        mt: 1,
                        p: 1.25,
                        borderRadius: 2,
                        bgcolor: 'background.paper',
                        border: '1px solid',
                        borderColor: 'divider',
                        boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
                    },
                }}
            >
                <Typography
                    variant="caption"
                    fontWeight={700}
                    sx={{
                        display: 'block',
                        mb: 1,
                        color: 'text.secondary',
                        textTransform: 'uppercase',
                        letterSpacing: 0.5,
                    }}
                >
                    Theme
                </Typography>
                <Box sx={{ display: 'flex', gap: 1 }}>
                    {THEME_OPTIONS.map((opt) => {
                        const isActive = themeKey === opt.key;
                        return (
                            <Tooltip key={opt.key} title={opt.label}>
                                <Box
                                    onClick={() => handleSelect(opt.key)}
                                    sx={{
                                        width: 32,
                                        height: 32,
                                        borderRadius: '50%',
                                        bgcolor: opt.color,
                                        cursor: 'pointer',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        border: '2px solid',
                                        borderColor: isActive ? BRAND.primary : 'transparent',
                                        boxShadow: isActive
                                            ? `0 0 0 2px ${alpha(BRAND.primary, 0.35)}`
                                            : '0 1px 3px rgba(0,0,0,0.15)',
                                        transition: 'all 0.15s',
                                        '&:hover': {
                                            transform: 'scale(1.1)',
                                            boxShadow: '0 4px 12px rgba(0,0,0,0.25)',
                                        },
                                    }}
                                >
                                    {isActive && (
                                        <CheckIcon sx={{ fontSize: 18, color: '#fff' }} />
                                    )}
                                </Box>
                            </Tooltip>
                        );
                    })}
                </Box>
            </Popover>
        </>
    );
}

/* -----------------------------------------------------------
 *  Login Page
 * ----------------------------------------------------------- */
export default function Login() {
    const navigate = useNavigate();
    const { login, requestWebOtp, verifyWebOtp, resendWebOtp, isAuthenticated } = useAuth();

    const { language } = useLanguage();
    const t = (key, replacements) => tLogin(language, key, replacements);

    const [loginMethod, setLoginMethod] = useState('email');
    const [email, setEmail] = useState('');

    const [selectedCountry, setSelectedCountry] = useState(
        COUNTRY_CODES.find(c => c.code === '+255' && c.name === 'Tanzania') || COUNTRY_CODES[0]
    );
    const [phoneNumber, setPhoneNumber] = useState('');

    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [rememberMe, setRememberMe] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const [step, setStep] = useState('credentials');
    const [otp, setOtp] = useState('');
    const [otpMeta, setOtpMeta] = useState(null);
    const [resendCooldown, setResendCooldown] = useState(0);

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
        const interval = setInterval(() => setResendCooldown((c) => c - 1), 1000);
        return () => clearInterval(interval);
    }, [resendCooldown]);

    useEffect(() => {
        if (loginMethod === 'email' && emailRef.current) {
            setTimeout(() => emailRef.current?.focus(), 100);
        } else if (loginMethod === 'phone' && phoneRef.current) {
            setTimeout(() => phoneRef.current?.focus(), 100);
        }
    }, [loginMethod]);

    const getIdentifier = () => {
        if (loginMethod === 'email') return email;
        return `${selectedCountry?.code || ''}${phoneNumber}`;
    };

    const isValidIdentifier = () => {
        if (loginMethod === 'email') {
            return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
        }
        return phoneNumber.replace(/\D/g, '').length >= 7;
    };

    const handleCredentialsSubmit = async (e) => {
        e.preventDefault();
        const identifier = getIdentifier();

        if (!identifier || !password) {
            setError(t('login.msg.fillAll'));
            return;
        }

        if (!isValidIdentifier()) {
            setError(loginMethod === 'email' ? t('login.msg.invalidEmail') : t('login.msg.invalidPhone'));
            return;
        }

        setLoading(true);
        setError('');

        try {
            const data = await requestWebOtp(identifier, password);
            setOtpMeta(data);
            setStep('otp');
            setResendCooldown(60);
            showSnackbar({
                type: 'success',
                message: t('login.msg.otpSent', {
                    target: data.sent_to || t('login.msg.otpSentFallback'),
                }),
            });
        } catch (err) {
            const msg = err?.response?.data?.message || err.message || '';

            if (
                msg.toLowerCase().includes('only available for authorized') ||
                msg.toLowerCase().includes('unauthorized role') ||
                err?.response?.status === 403
            ) {
                try {
                    await login(identifier, password);
                    showSnackbar({ type: 'success', message: t('login.msg.welcome') });
                    navigate('/app/dashboard', { replace: true });
                } catch (classicErr) {
                    setError(classicErr.message || t('login.msg.invalidCredentials'));
                    showSnackbar({ type: 'error', message: classicErr.message || t('login.msg.loginFailed') });
                }
            } else {
                setError(msg || t('login.msg.invalidCredentials'));
                showSnackbar({ type: 'error', message: msg || t('login.msg.loginFailed') });
            }
        } finally {
            setLoading(false);
        }
    };

    const handleOtpSubmit = async (e) => {
        e.preventDefault();
        if (!otp || otp.length !== 6) {
            setError(t('login.msg.enterOtp'));
            return;
        }

        setLoading(true);
        setError('');

        try {
            await verifyWebOtp(otpMeta.email || getIdentifier(), otp);
            showSnackbar({ type: 'success', message: t('login.msg.loginSuccess') });
            navigate('/app/dashboard', { replace: true });
        } catch (err) {
            setError(err.message || t('login.msg.otpInvalid'));
            showSnackbar({ type: 'error', message: err.message || t('login.msg.otpFailed') });
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
            showSnackbar({ type: 'success', message: t('login.msg.otpResent') });
        } catch (err) {
            showSnackbar({ type: 'error', message: err.message || t('login.msg.otpResendFailed') });
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

    const handleLoginMethodChange = (event, newMethod) => {
        if (newMethod !== null) {
            setLoginMethod(newMethod);
            setError('');
        }
    };

    return (
        <Box
            sx={{
                minHeight: '100vh',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                background: (theme) => theme.palette.mode === 'dark'
                    ? 'linear-gradient(135deg, #0F172A 0%, #1A1A2E 50%, #23232D 100%)'
                    : `linear-gradient(135deg, ${BRAND.secondary} 0%, ${BRAND.primary} 40%, #14919b 100%)`,
                p: { xs: 2, sm: 3 },
                position: 'relative',
                overflow: 'hidden',
            }}
        >
            {/* Language + Theme Switcher */}
            <Box
                sx={{
                    position: 'fixed',
                    top: { xs: 12, sm: 20 },
                    right: { xs: 12, sm: 20 },
                    zIndex: 1000,
                    bgcolor: 'rgba(255,255,255,0.15)',
                    backdropFilter: 'blur(10px)',
                    WebkitBackdropFilter: 'blur(10px)',
                    borderRadius: 2,
                    p: 0.5,
                    display: 'flex',
                    alignItems: 'center',
                    gap: 0.5,
                    border: '1px solid rgba(255,255,255,0.25)',
                    boxShadow: '0 4px 16px rgba(0,0,0,0.15)',
                }}
            >
                <LanguageSwitcher iconColor="#ffffff" showLabel size="medium" />
                <Box sx={{ width: '1px', height: 24, bgcolor: 'rgba(255,255,255,0.25)', mx: 0.5 }} />
                <ThemeSwitcher />
            </Box>

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

                <Paper elevation={0} sx={{
                    width: '100%',
                    maxWidth: 900,
                    borderRadius: 4,
                    overflow: 'hidden',
                    display: 'flex',
                    flexDirection: { xs: 'column', md: 'row' },
                    boxShadow: '0 25px 50px -12px rgba(0,0,0,0.35)',
                    bgcolor: 'background.paper',
                }}>
                    {/* Left branding panel */}
                    <Box sx={{
                        flex: { xs: 'none', md: '0 0 42%' },
                        background: (theme) => theme.palette.mode === 'dark'
                            ? `linear-gradient(160deg, ${BRAND.secondary} 0%, ${BRAND.primary} 100%)`
                            : `linear-gradient(160deg, ${BRAND.secondary} 0%, ${BRAND.primary} 60%, #14919b 100%)`,
                        color: '#fff',
                        p: { xs: 4, md: 5 },
                        display: 'flex',
                        flexDirection: 'column',
                        justifyContent: 'center',
                        minHeight: { xs: 220, md: 540 },
                        position: 'relative',
                        overflow: 'hidden',
                    }}>
                        <Box sx={{ position: 'absolute', top: -80, right: -60, width: 280, height: 280, borderRadius: '50%', bgcolor: alpha('#fff', 0.08) }} />
                        <Box sx={{ position: 'relative', zIndex: 1 }}>
                            <Box component="img" src={logo} alt="NearbyFundi" sx={{ width: 56, height: 56, mb: 3, filter: 'brightness(0) invert(1)' }} />
                            <Typography variant="h3" fontWeight={800} sx={{ mb: 1, fontSize: { xs: '1.9rem', md: '2.5rem' } }}>
                                {t('login.brand.welcome')}
                            </Typography>
                            <Typography variant="h6" fontWeight={700} sx={{ mb: 1.5 }}>
                                {t('login.brand.name')}
                            </Typography>
                            <Typography variant="body2" sx={{ color: '#f8fafc', maxWidth: 270, lineHeight: 1.7, display: { xs: 'none', sm: 'block' } }}>
                                {t('login.brand.tagline')}
                            </Typography>
                        </Box>
                    </Box>

                    {/* Right form panel */}
                    <Box sx={{
                        flex: 1,
                        bgcolor: 'background.paper',
                        p: { xs: 3.5, sm: 5 },
                        display: 'flex',
                        flexDirection: 'column',
                        justifyContent: 'center',
                    }}>
                        {step === 'credentials' ? (
                            <>
                                <Typography variant="h4" fontWeight={800} sx={{ color: 'text.primary', mb: 0.5 }}>
                                    {t('login.title')}
                                </Typography>
                                <Typography variant="body2" sx={{ color: 'text.secondary', fontWeight: 500, mb: 3 }}>
                                    {t('login.subtitle')}
                                </Typography>

                                {/* Email / Phone toggle — spaced apart, brand colors */}
                                <ToggleButtonGroup
                                    value={loginMethod}
                                    exclusive
                                    onChange={handleLoginMethodChange}
                                    aria-label="login method"
                                    sx={{
                                        mb: 3,
                                        width: '100%',
                                        display: 'flex',
                                        gap: 1.5, // ✅ Space between buttons
                                        '& .MuiToggleButtonGroup-grouped': {
                                            border: '2px solid !important',
                                            borderColor: `${alpha(BRAND.primary, 0.25)} !important`,
                                            borderRadius: '10px !important',
                                            mx: 0,
                                            '&:not(:first-of-type)': { ml: 0 },
                                        },
                                        '& .MuiToggleButton-root': {
                                            flex: 1,
                                            py: 1.2,
                                            borderRadius: 2.5,
                                            border: '2px solid',
                                            borderColor: alpha(BRAND.primary, 0.25),
                                            color: 'text.primary',
                                            bgcolor: 'transparent',
                                            textTransform: 'none',
                                            fontWeight: 600,
                                            transition: 'all 0.15s',
                                            '&.Mui-selected': {
                                                backgroundColor: BRAND.primary,       // ✅ Brand teal
                                                color: '#fff',
                                                borderColor: BRAND.primary,
                                                '&:hover': {
                                                    backgroundColor: BRAND.secondary, // ✅ Darker teal on hover
                                                },
                                            },
                                            '&:hover': {
                                                backgroundColor: alpha(BRAND.primary, 0.06),
                                                borderColor: BRAND.primary,
                                            },
                                        },
                                    }}
                                >
                                    <ToggleButton value="email" aria-label="email login">
                                        <EmailOutlined sx={{ mr: 1, fontSize: 20 }} />
                                        {t('login.toggle.email')}
                                    </ToggleButton>
                                    <ToggleButton value="phone" aria-label="phone login">
                                        <PhoneOutlined sx={{ mr: 1, fontSize: 20 }} />
                                        {t('login.toggle.phone')}
                                    </ToggleButton>
                                </ToggleButtonGroup>

                                <form onSubmit={handleCredentialsSubmit}>
                                    <Stack spacing={2.5}>
                                        {loginMethod === 'email' ? (
                                            <TextField
                                                fullWidth
                                                ref={emailRef}
                                                placeholder={t('login.field.emailPlaceholder')}
                                                label={t('login.field.emailLabel')}
                                                type="email"
                                                value={email}
                                                onChange={(e) => setEmail(e.target.value)}
                                                required
                                                autoFocus
                                                sx={{
                                                    '& .MuiOutlinedInput-root': {
                                                        borderRadius: 2,
                                                        bgcolor: 'action.hover',
                                                        '&:hover': { bgcolor: 'action.selected' },
                                                        '&.Mui-focused fieldset': {
                                                            borderColor: BRAND.primary,
                                                            borderWidth: 2,
                                                        },
                                                    },
                                                    '& .MuiInputLabel-root.Mui-focused': {
                                                        color: BRAND.primary,
                                                    },
                                                }}
                                                InputProps={{
                                                    startAdornment: (
                                                        <InputAdornment position="start">
                                                            <AlternateEmail sx={{ color: 'text.secondary' }} />
                                                        </InputAdornment>
                                                    ),
                                                }}
                                            />
                                        ) : (
                                            <Box sx={{ display: 'flex', gap: 1.5, alignItems: 'flex-start' }}>
                                                <Autocomplete
                                                    value={selectedCountry}
                                                    onChange={(e, newValue) => {
                                                        if (newValue) setSelectedCountry(newValue);
                                                    }}
                                                    options={COUNTRY_CODES}
                                                    getOptionLabel={(option) => `${option.flag} ${option.code}`}
                                                    isOptionEqualToValue={(option, value) =>
                                                        option.code === value.code && option.name === value.name
                                                    }
                                                    disableClearable
                                                    autoHighlight
                                                    sx={{
                                                        width: 150,
                                                        minWidth: 150,
                                                        flexShrink: 0,
                                                        '& .MuiOutlinedInput-root': {
                                                            borderRadius: 2,
                                                            bgcolor: 'action.hover',
                                                            paddingRight: '24px !important',
                                                            '&:hover': { bgcolor: 'action.selected' },
                                                            '&.Mui-focused fieldset': {
                                                                borderColor: BRAND.primary,
                                                                borderWidth: 2,
                                                            },
                                                        },
                                                        '& .MuiAutocomplete-input': {
                                                            fontWeight: 600,
                                                            fontSize: '0.95rem',
                                                            minWidth: '0 !important',
                                                        },
                                                    }}
                                                    renderInput={(params) => (
                                                        <TextField
                                                            {...params}
                                                            placeholder="+255"
                                                            inputProps={{
                                                                ...params.inputProps,
                                                                style: {
                                                                    fontSize: '0.95rem',
                                                                    fontWeight: 600,
                                                                    letterSpacing: 0.3,
                                                                },
                                                            }}
                                                        />
                                                    )}
                                                    renderOption={(props, option) => (
                                                        <MenuItem
                                                            {...props}
                                                            key={`${option.name}-${option.code}`}
                                                            sx={{
                                                                gap: 1.5,
                                                                py: 1,
                                                                fontSize: '0.9rem',
                                                                '&.Mui-focused, &:hover': {
                                                                    bgcolor: alpha(BRAND.primary, 0.08),
                                                                },
                                                            }}
                                                        >
                                                            <span style={{ fontSize: '1.3rem', lineHeight: 1 }}>{option.flag}</span>
                                                            <Box sx={{ flex: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 2 }}>
                                                                <Typography variant="body2" sx={{ fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                                                    {option.name}
                                                                </Typography>
                                                                <Typography variant="body2" sx={{ fontWeight: 700, fontFamily: 'monospace', flexShrink: 0, color: BRAND.primary }}>
                                                                    {option.code}
                                                                </Typography>
                                                            </Box>
                                                        </MenuItem>
                                                    )}
                                                    noOptionsText={t('login.field.noCountry') || 'No country found'}
                                                    ListboxProps={{
                                                        sx: { maxHeight: 320, '& .MuiMenuItem-root': { minHeight: 44 } },
                                                    }}
                                                />
                                                <TextField
                                                    fullWidth
                                                    ref={phoneRef}
                                                    placeholder={t('login.field.phonePlaceholder')}
                                                    label={t('login.field.phoneLabel')}
                                                    type="tel"
                                                    value={phoneNumber}
                                                    onChange={(e) => setPhoneNumber(e.target.value.replace(/\D/g, ''))}
                                                    required
                                                    autoFocus={loginMethod === 'phone'}
                                                    sx={{
                                                        '& .MuiOutlinedInput-root': {
                                                            borderRadius: 2,
                                                            bgcolor: 'action.hover',
                                                            '&:hover': { bgcolor: 'action.selected' },
                                                            '&.Mui-focused fieldset': {
                                                                borderColor: BRAND.primary,
                                                                borderWidth: 2,
                                                            },
                                                        },
                                                        '& .MuiInputLabel-root.Mui-focused': {
                                                            color: BRAND.primary,
                                                        },
                                                    }}
                                                    InputProps={{
                                                        startAdornment: (
                                                            <InputAdornment position="start">
                                                                <PhoneOutlined sx={{ color: 'text.secondary' }} />
                                                            </InputAdornment>
                                                        ),
                                                    }}
                                                />
                                            </Box>
                                        )}

                                        <TextField
                                            fullWidth
                                            ref={passwordRef}
                                            placeholder={t('login.field.passwordPlaceholder')}
                                            label={t('login.field.passwordLabel')}
                                            type={showPassword ? 'text' : 'password'}
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                            required
                                            sx={{
                                                '& .MuiOutlinedInput-root': {
                                                    borderRadius: 2,
                                                    bgcolor: 'action.hover',
                                                    '&:hover': { bgcolor: 'action.selected' },
                                                    '&.Mui-focused fieldset': {
                                                        borderColor: BRAND.primary,
                                                        borderWidth: 2,
                                                    },
                                                },
                                                '& .MuiInputLabel-root.Mui-focused': {
                                                    color: BRAND.primary,
                                                },
                                            }}
                                            InputProps={{
                                                startAdornment: (
                                                    <InputAdornment position="start">
                                                        <LockOutlined sx={{ color: 'text.secondary' }} />
                                                    </InputAdornment>
                                                ),
                                                endAdornment: (
                                                    <InputAdornment position="end">
                                                        <Button
                                                            size="small"
                                                            onClick={() => setShowPassword(!showPassword)}
                                                            sx={{
                                                                textTransform: 'none',
                                                                color: BRAND.primary, // ✅ Brand teal
                                                                fontWeight: 700,
                                                                minWidth: 'auto',
                                                                '&:hover': {
                                                                    bgcolor: alpha(BRAND.primary, 0.08),
                                                                },
                                                            }}
                                                        >
                                                            {showPassword ? t('login.password.hide') : t('login.password.show')}
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
                                                            '&.Mui-checked': { color: BRAND.primary }, // ✅ Brand teal
                                                        }}
                                                    />
                                                }
                                                label={
                                                    <Typography variant="body2" sx={{ color: 'text.secondary', fontWeight: 500 }}>
                                                        {t('login.remember')}
                                                    </Typography>
                                                }
                                            />
                                            <Link
                                                component="button"
                                                type="button"
                                                underline="hover"
                                                onClick={() => navigate('/forgot-password')}
                                                sx={{
                                                    color: BRAND.primary, // ✅ Brand teal
                                                    fontWeight: 600,
                                                    fontSize: '0.875rem',
                                                }}
                                            >
                                                {t('login.forgot')}
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
                                                bgcolor: BRAND.primary,         // ✅ Brand teal
                                                color: '#fff',
                                                '&:hover': { bgcolor: BRAND.secondary }, // ✅ Darker teal on hover
                                                '&.Mui-disabled': {
                                                    bgcolor: alpha(BRAND.primary, 0.5),
                                                    color: '#fff',
                                                },
                                            }}
                                        >
                                            {loading ? <CircularProgress size={24} color="inherit" /> : t('login.submit')}
                                        </Button>
                                    </Stack>
                                </form>
                            </>
                        ) : (
                            <>
                                <Typography variant="h4" fontWeight={800} sx={{ color: 'text.primary', mb: 0.5 }}>
                                    {t('login.otp.title')}
                                </Typography>
                                <Typography variant="body2" sx={{ color: 'text.secondary', fontWeight: 500, mb: 1 }}>
                                    {t('login.otp.subtitlePrefix')}{' '}
                                    <strong>{otpMeta?.sent_to || t('login.otp.fallbackSentTo')}</strong>
                                </Typography>
                                <Typography variant="caption" sx={{ color: 'text.secondary', mb: 3, display: 'block' }}>
                                    {t('login.otp.expiresIn', { min: otpMeta?.expires_in || 5 })}
                                </Typography>

                                <form onSubmit={handleOtpSubmit}>
                                    <Stack spacing={2.5}>
                                        <TextField
                                            fullWidth
                                            placeholder={t('login.otp.fieldPlaceholder')}
                                            label={t('login.otp.fieldLabel')}
                                            value={otp}
                                            onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                                            required
                                            autoFocus
                                            inputProps={{
                                                maxLength: 6,
                                                inputMode: 'numeric',
                                                pattern: '[0-9]*',
                                                style: { letterSpacing: 8, fontSize: '1.4rem', fontWeight: 700 },
                                            }}
                                            sx={{
                                                '& .MuiOutlinedInput-root': {
                                                    borderRadius: 2,
                                                    bgcolor: 'action.hover',
                                                    '&:hover': { bgcolor: 'action.selected' },
                                                    '&.Mui-focused fieldset': {
                                                        borderColor: BRAND.primary,
                                                        borderWidth: 2,
                                                    },
                                                },
                                                '& .MuiInputLabel-root.Mui-focused': {
                                                    color: BRAND.primary,
                                                },
                                            }}
                                            InputProps={{
                                                startAdornment: (
                                                    <InputAdornment position="start">
                                                        <SmsOutlined sx={{ color: 'text.secondary' }} />
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
                                                bgcolor: BRAND.primary,
                                                color: '#fff',
                                                '&:hover': { bgcolor: BRAND.secondary },
                                                '&.Mui-disabled': {
                                                    bgcolor: alpha(BRAND.primary, 0.5),
                                                    color: '#fff',
                                                },
                                            }}
                                        >
                                            {loading ? <CircularProgress size={24} color="inherit" /> : t('login.otp.submit')}
                                        </Button>

                                        <Box display="flex" justifyContent="space-between" alignItems="center">
                                            <Button
                                                onClick={goBackToCredentials}
                                                sx={{ textTransform: 'none', color: 'text.secondary' }}
                                            >
                                                {t('login.otp.back')}
                                            </Button>
                                            <Button
                                                onClick={handleResendOtp}
                                                disabled={resendCooldown > 0 || loading}
                                                sx={{
                                                    textTransform: 'none',
                                                    color: BRAND.primary, // ✅ Brand teal
                                                    fontWeight: 600,
                                                    '&:hover': {
                                                        bgcolor: alpha(BRAND.primary, 0.08),
                                                    },
                                                    '&:disabled': { color: 'text.disabled' },
                                                }}
                                            >
                                                {resendCooldown > 0
                                                    ? t('login.otp.resendIn', { s: resendCooldown })
                                                    : t('login.otp.resend')}
                                            </Button>
                                        </Box>
                                    </Stack>
                                </form>
                            </>
                        )}

                        <Typography variant="body2" align="center" sx={{ mt: 4, color: 'text.secondary' }}>
                            {t('login.footer.noAccount')}{' '}
                            <Link
                                component="button"
                                underline="hover"
                                onClick={() => navigate('')}
                                sx={{
                                    color: BRAND.primary, // ✅ Brand teal
                                    fontWeight: 700,
                                }}
                            >
                                {t('login.footer.signUp')}
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