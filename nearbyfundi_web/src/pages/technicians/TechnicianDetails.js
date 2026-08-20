// src/pages/technicians/TechnicianDetails.js

import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    Box, Paper, Typography, Avatar, Chip, CircularProgress, Alert,
    Card, CardContent, Grid, Divider, Button, Stack,
    Dialog, DialogTitle, DialogContent, DialogContentText,
    DialogActions, LinearProgress,
    IconButton, useMediaQuery, useTheme,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import {
    ArrowBack as ArrowBackIcon,
    CheckCircle as VerifiedIcon,
    LocationOn as LocationIcon,
    Email as EmailIcon,
    Phone as PhoneIcon,
    Star as StarIcon,
    Image as ImageIcon,
    Close as CloseIcon,
    ZoomIn as ZoomInIcon,
    Person as PersonIcon,
    Work as WorkIcon,
    DocumentScanner as DocumentIcon,
    CalendarToday as CalendarIcon,
    Subscriptions as SubscriptionsIcon,
    CheckCircle as ApproveIcon,
} from '@mui/icons-material';
import { technicianService } from 'services/technician.service';
import { usePermissions } from 'hooks/usePermissions';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const getImageUrl = (path) => {
    if (!path) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
    }
    const baseUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
    const cleanPath = path.replace(/^\/+/, '');
    return `${baseUrl}/storage/${cleanPath}`;
};

const TechnicianDetails = () => {
    const { id } = useParams();
    const navigate = useNavigate();
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

    const [technician, setTechnician] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const { can } = usePermissions();
    const canView = can('technicians.view');
    const canApprove = can('technicians.approve');

    const [imageErrors, setImageErrors] = useState({});
    const [imageModalOpen, setImageModalOpen] = useState(false);
    const [imageModalSrc, setImageModalSrc] = useState('');
    const [imageModalAlt, setImageModalAlt] = useState('');

    // Approval states
    const [approveDialogOpen, setApproveDialogOpen] = useState(false);
    const [approveProcessing, setApproveProcessing] = useState(false);
    const [approveProgress, setApproveProgress] = useState(0);
    const [approveFeedback, setApproveFeedback] = useState(null);

    useEffect(() => {
        if (!canView) {
            setError('You do not have permission to view technician details.');
            setLoading(false);
            return;
        }
        fetchTechnician();
    }, [id, canView]);

    const fetchTechnician = async () => {
        try {
            const response = await technicianService.getTechnician(id);
            if (response?.data?.status === 'success') {
                setTechnician(response.data.data);
            } else {
                setError('Technician not found.');
            }
        } catch (err) {
            setError(err.message || 'Failed to load technician.');
        } finally {
            setLoading(false);
        }
    };

    const handleImageError = (key) => {
        setImageErrors(prev => ({ ...prev, [key]: true }));
    };

    const openImageModal = (src, alt = '') => {
        setImageModalSrc(src);
        setImageModalAlt(alt);
        setImageModalOpen(true);
    };

    const closeImageModal = () => {
        setImageModalOpen(false);
        setImageModalSrc('');
        setImageModalAlt('');
    };

    const formatDate = (dateString) => {
        if (!dateString) return 'N/A';
        try {
            return new Date(dateString).toLocaleString();
        } catch {
            return 'Invalid date';
        }
    };

    // ─── Approval Handlers ──────────────────────────────────────────

    // Open the confirmation dialog
    const openApproveDialog = () => {
        setApproveDialogOpen(true);
        setApproveProgress(0);
        setApproveFeedback(null);
    };

    // Close dialog without approving
    const closeApproveDialog = () => {
        if (!approveProcessing) {
            setApproveDialogOpen(false);
            setApproveProgress(0);
        }
    };

    // Confirm approval – starts the API call with progress simulation
    const confirmApprove = async () => {
        setApproveProcessing(true);
        setApproveProgress(0);

        // Simulate progress updates while the request is pending
        const interval = setInterval(() => {
            setApproveProgress((prev) => {
                if (prev < 90) {
                    // Random increment up to 90%
                    return Math.min(prev + Math.random() * 10, 90);
                }
                return prev;
            });
        }, 300);

        try {
            const response = await technicianService.approveTechnician(id);
            clearInterval(interval);
            setApproveProgress(100); // complete

            if (response?.data?.status === 'success') {
                setApproveFeedback({
                    type: 'success',
                    message: 'Technician approved successfully! Free trial activated.',
                });
                // Update local state
                setTechnician((prev) => ({
                    ...prev,
                    verified: true,
                    verification_status: 'approved',
                }));
                // Re‑fetch to sync all data
                await fetchTechnician();
            } else {
                setApproveFeedback({
                    type: 'error',
                    message: response?.data?.message || 'Approval failed.',
                });
            }
        } catch (err) {
            clearInterval(interval);
            setApproveProgress(0);
            setApproveFeedback({
                type: 'error',
                message: err.message || 'An error occurred during approval.',
            });
        } finally {
            setApproveProcessing(false);
            // Close dialog after a short delay so the user sees 100%
            setTimeout(() => {
                setApproveDialogOpen(false);
                setApproveProgress(0);
            }, 600);
        }
    };

    // ─── Render ──────────────────────────────────────────────────

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
                <CircularProgress sx={{ color: colors.sea }} />
            </Box>
        );
    }

    if (error) {
        return (
            <Box p={3}>
                <Alert severity="error">{error}</Alert>
                <Button variant="contained" sx={{ mt: 2 }} onClick={() => navigate('/app/technicians')}>
                    Back to List
                </Button>
            </Box>
        );
    }

    if (!technician) return null;

    const user = technician.user || {};
    const profilePhotoUrl = technician.profile_photo ? getImageUrl(technician.profile_photo) : null;
    const idDocumentUrl = technician.id_document_image ? getImageUrl(technician.id_document_image) : null;
    const hasIdDocument = technician.id_document_type || technician.id_document_image;
    const isVerified = technician.verified && technician.verification_status === 'approved';

    return (
        <Box sx={{ p: { xs: 1.5, sm: 2.5, md: 3.5 }, backgroundColor: '#f8fafc', minHeight: '100vh' }}>
            {/* Top Bar with Back and Approve buttons */}
            <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={2} mb={2.5}>
                <Button
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate('/app/technicians')}
                    sx={{ color: colors.sea, fontWeight: 600, textTransform: 'none' }}
                >
                    Back to List
                </Button>

                {canApprove && !isVerified && (
                    <Button
                        variant="contained"
                        startIcon={<ApproveIcon />}
                        onClick={openApproveDialog}
                        sx={{
                            backgroundColor: colors.salat,
                            '&:hover': { backgroundColor: colors.salatDark },
                            textTransform: 'none',
                            fontWeight: 600,
                        }}
                    >
                        Approve Technician
                    </Button>
                )}
            </Box>

            {approveFeedback && (
                <Alert
                    severity={approveFeedback.type}
                    sx={{ mb: 2 }}
                    onClose={() => setApproveFeedback(null)}
                >
                    {approveFeedback.message}
                </Alert>
            )}

            <Paper
                elevation={0}
                sx={{
                    borderRadius: 3,
                    overflow: 'hidden',
                    backgroundColor: '#ffffff',
                    border: `1px solid ${alpha(colors.middle, 0.15)}`,
                    boxShadow: '0 4px 20px rgba(0,0,0,0.04)',
                }}
            >
                {/* ─── Header ──────────────────────────────────────────── */}
                <Box
                    sx={{
                        p: { xs: 2, sm: 3, md: 4 },
                        background: `linear-gradient(135deg, ${alpha(colors.sea, 0.06)}, ${alpha(colors.sea, 0.02)})`,
                        borderBottom: `1px solid ${alpha(colors.middle, 0.12)}`,
                        display: 'flex',
                        flexDirection: { xs: 'column', md: 'row' },
                        gap: 3,
                        alignItems: { xs: 'center', md: 'flex-start' },
                    }}
                >
                    <Box
                        sx={{
                            position: 'relative',
                            cursor: 'pointer',
                            flexShrink: 0,
                        }}
                        onClick={() => profilePhotoUrl && openImageModal(profilePhotoUrl, `${user.name} Profile`)}
                    >
                        <Avatar
                            src={profilePhotoUrl}
                            sx={{
                                width: { xs: 120, sm: 140, md: 160 },
                                height: { xs: 120, sm: 140, md: 160 },
                                bgcolor: colors.sea,
                                fontSize: '4rem',
                                fontWeight: 700,
                                border: `4px solid ${alpha(colors.sea, 0.2)}`,
                                boxShadow: '0 8px 24px rgba(0,0,0,0.08)',
                                transition: 'transform 0.2s',
                                '&:hover': {
                                    transform: 'scale(1.03)',
                                    borderColor: colors.sea,
                                },
                            }}
                            onError={() => handleImageError('profile')}
                        >
                            {!profilePhotoUrl || imageErrors['profile']
                                ? user.name?.charAt(0).toUpperCase() || 'T'
                                : null}
                        </Avatar>
                        {profilePhotoUrl && !imageErrors['profile'] && (
                            <Box
                                sx={{
                                    position: 'absolute',
                                    bottom: 4,
                                    right: 4,
                                    backgroundColor: 'rgba(0,0,0,0.6)',
                                    borderRadius: '50%',
                                    p: 0.5,
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                }}
                            >
                                <ZoomInIcon sx={{ fontSize: 18, color: '#fff' }} />
                            </Box>
                        )}
                    </Box>

                    <Box flex={1} textAlign={{ xs: 'center', md: 'left' }}>
                        <Typography variant="h4" fontWeight="700" sx={{ color: colors.dark, mb: 0.5 }}>
                            {user.name || 'Unknown'}
                        </Typography>

                        {/* Chips */}
                        <Box
                            display="flex"
                            flexWrap="wrap"
                            gap={1}
                            sx={{ mb: 1.5, justifyContent: { xs: 'center', md: 'flex-start' } }}
                        >
                            <Chip
                                label={isVerified ? 'Verified' : 'Unverified'}
                                color={isVerified ? 'success' : 'warning'}
                                size="small"
                                icon={<VerifiedIcon />}
                            />
                            <Chip
                                label={`Status: ${technician.verification_status || 'pending'}`}
                                color={
                                    technician.verification_status === 'approved'
                                        ? 'success'
                                        : technician.verification_status === 'pending'
                                            ? 'warning'
                                            : 'default'
                                }
                                size="small"
                            />
                            <Chip
                                label={technician.registration_completed ? 'Registered' : 'Incomplete'}
                                color={technician.registration_completed ? 'info' : 'default'}
                                size="small"
                            />
                        </Box>

                        {/* Contact info */}
                        <Box display="flex" flexDirection={{ xs: 'column', sm: 'row' }} gap={1.5} flexWrap="wrap">
                            <Box display="flex" alignItems="center" gap={1}>
                                <EmailIcon sx={{ fontSize: 18, color: colors.rain }} />
                                <Typography variant="body2" sx={{ color: colors.black }}>
                                    {user.email || 'N/A'}
                                </Typography>
                            </Box>
                            <Box display="flex" alignItems="center" gap={1}>
                                <PhoneIcon sx={{ fontSize: 18, color: colors.rain }} />
                                <Typography variant="body2" sx={{ color: colors.black }}>
                                    {user.phone || 'N/A'}
                                </Typography>
                            </Box>
                            <Box display="flex" alignItems="center" gap={1}>
                                <LocationIcon sx={{ fontSize: 18, color: colors.rain }} />
                                <Typography variant="body2" sx={{ color: colors.black }}>
                                    {technician.area || 'N/A'}
                                </Typography>
                            </Box>
                        </Box>

                        {/* Rating / Experience / Rate */}
                        <Box display="flex" flexWrap="wrap" gap={2.5} sx={{ mt: 1.5 }}>
                            <Box display="flex" alignItems="center" gap={0.5}>
                                <StarIcon sx={{ fontSize: 20, color: '#f59e0b' }} />
                                <Typography variant="body2" fontWeight="600">
                                    {technician.rating?.toFixed(1) || 'N/A'}
                                </Typography>
                                <Typography variant="caption" sx={{ color: colors.rain }}>
                                    ({technician.completed_jobs_count || 0} jobs)
                                </Typography>
                            </Box>
                            {technician.experience !== undefined && technician.experience !== null && (
                                <Typography variant="body2">
                                    <strong>Experience:</strong> {technician.experience} years
                                </Typography>
                            )}
                            {technician.hourly_rate && (
                                <Typography variant="body2" fontWeight="700" sx={{ color: colors.sea }}>
                                    {technician.hourly_rate} TZS/hr
                                </Typography>
                            )}
                        </Box>
                    </Box>
                </Box>

                {/* ─── Details Grid ──────────────────────────────────────── */}
                <Box sx={{ p: { xs: 2, sm: 3, md: 4 } }}>
                    <Grid container spacing={3}>
                        {/* Left Column */}
                        <Grid item xs={12} md={6}>
                            <Stack spacing={3}>
                                {/* Bio */}
                                <Card variant="outlined" sx={{ borderColor: alpha(colors.middle, 0.15) }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight="700" sx={{ color: colors.dark, mb: 1.5 }}>
                                            <PersonIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Bio
                                        </Typography>
                                        <Typography variant="body2" sx={{ color: colors.black, lineHeight: 1.8 }}>
                                            {technician.bio || 'No bio provided.'}
                                        </Typography>
                                    </CardContent>
                                </Card>

                                {/* Identification */}
                                <Card variant="outlined" sx={{ borderColor: alpha(colors.middle, 0.15) }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight="700" sx={{ color: colors.dark, mb: 1.5 }}>
                                            <DocumentIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Identification & Registration
                                        </Typography>
                                        {hasIdDocument ? (
                                            <Box display="flex" flexDirection="column" gap={1.5}>
                                                {technician.nida && (
                                                    <Typography variant="body2">
                                                        <strong>NIDA:</strong> {technician.nida}
                                                    </Typography>
                                                )}
                                                <Typography variant="body2">
                                                    <strong>Document Type:</strong> {technician.id_document_type || 'N/A'}
                                                </Typography>
                                                <Typography variant="body2">
                                                    <strong>Registration Step:</strong> {technician.registration_step}/4
                                                </Typography>
                                                <Typography variant="body2">
                                                    <strong>Registration Completed:</strong>{' '}
                                                    {technician.registration_completed ? 'Yes' : 'No'}
                                                </Typography>
                                                <Typography variant="body2">
                                                    <strong>Verification Status:</strong> {technician.verification_status}
                                                </Typography>
                                                {idDocumentUrl && !imageErrors['id'] && (
                                                    <Box mt={1}>
                                                        <Typography variant="body2" fontWeight="600" sx={{ mb: 1 }}>
                                                            ID Document Image:
                                                        </Typography>
                                                        <Box
                                                            component="img"
                                                            src={idDocumentUrl}
                                                            alt="ID Document"
                                                            onClick={() => openImageModal(idDocumentUrl, 'ID Document')}
                                                            sx={{
                                                                maxWidth: '100%',
                                                                maxHeight: 250,
                                                                border: `1px solid ${alpha(colors.middle, 0.3)}`,
                                                                borderRadius: 2,
                                                                objectFit: 'contain',
                                                                backgroundColor: '#f8fafc',
                                                                p: 1,
                                                                cursor: 'pointer',
                                                                transition: 'transform 0.2s',
                                                                '&:hover': {
                                                                    transform: 'scale(1.02)',
                                                                    borderColor: colors.sea,
                                                                },
                                                            }}
                                                            onError={() => handleImageError('id')}
                                                        />
                                                    </Box>
                                                )}
                                                {imageErrors['id'] && (
                                                    <Alert severity="warning" icon={<ImageIcon />}>
                                                        Failed to load ID document image.
                                                    </Alert>
                                                )}
                                            </Box>
                                        ) : (
                                            <Typography variant="body2" sx={{ color: colors.rain }}>
                                                No ID documents uploaded yet.
                                            </Typography>
                                        )}
                                    </CardContent>
                                </Card>
                            </Stack>
                        </Grid>

                        {/* Right Column */}
                        <Grid item xs={12} md={6}>
                            <Stack spacing={3}>
                                {/* Services & Pricing */}
                                <Card variant="outlined" sx={{ borderColor: alpha(colors.middle, 0.15) }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight="700" sx={{ color: colors.dark, mb: 1.5 }}>
                                            <WorkIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Services & Pricing
                                        </Typography>
                                        {technician.service_prices && technician.service_prices.length > 0 ? (
                                            <Grid container spacing={2}>
                                                {technician.service_prices.map((service) => (
                                                    <Grid item xs={12} sm={6} key={service.id}>
                                                        <Box
                                                            sx={{
                                                                p: 2,
                                                                backgroundColor: alpha(colors.sea, 0.04),
                                                                borderRadius: 2,
                                                                border: `1px solid ${alpha(colors.middle, 0.15)}`,
                                                                transition: 'all 0.2s',
                                                                '&:hover': {
                                                                    borderColor: colors.sea,
                                                                    backgroundColor: alpha(colors.sea, 0.08),
                                                                },
                                                            }}
                                                        >
                                                            <Typography variant="body2" fontWeight="600" sx={{ color: colors.dark }}>
                                                                {service.name}
                                                            </Typography>
                                                            <Typography variant="body2" sx={{ color: colors.rain }}>
                                                                Price Range: {service.pivot?.min_price || 0} –{' '}
                                                                {service.pivot?.max_price || 0} TZS
                                                            </Typography>
                                                        </Box>
                                                    </Grid>
                                                ))}
                                            </Grid>
                                        ) : (
                                            <Typography variant="body2" sx={{ color: colors.rain }}>
                                                No services assigned.
                                            </Typography>
                                        )}
                                    </CardContent>
                                </Card>

                                {/* Subscription History */}
                                <Card variant="outlined" sx={{ borderColor: alpha(colors.middle, 0.15) }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight="700" sx={{ color: colors.dark, mb: 1.5 }}>
                                            <SubscriptionsIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Subscription History
                                        </Typography>

                                        {user.subscriptions && user.subscriptions.length > 0 ? (
                                            <Box>
                                                {user.subscriptions.map((sub) => (
                                                    <Box
                                                        key={sub.id}
                                                        sx={{
                                                            p: 2,
                                                            mb: 1.5,
                                                            backgroundColor: alpha(colors.sea, 0.04),
                                                            borderRadius: 2,
                                                            border: `1px solid ${alpha(colors.middle, 0.15)}`,
                                                            '&:last-child': { mb: 0 },
                                                        }}
                                                    >
                                                        <Grid container spacing={1}>
                                                            <Grid item xs={12} sm={6}>
                                                                <Typography variant="body2" fontWeight="600">
                                                                    Plan: {sub.rate_card?.name || 'N/A'}
                                                                </Typography>
                                                                <Box display="flex" alignItems="center" gap={0.5} mt={0.5}>
                                                                    <Typography variant="body2" component="span">
                                                                        Status:
                                                                    </Typography>
                                                                    <Chip
                                                                        label={sub.status}
                                                                        size="small"
                                                                        color={
                                                                            sub.status === 'active'
                                                                                ? 'success'
                                                                                : sub.status === 'expired'
                                                                                    ? 'error'
                                                                                    : sub.status === 'pending'
                                                                                        ? 'warning'
                                                                                        : sub.status === 'approved'
                                                                                            ? 'info'
                                                                                            : 'default'
                                                                        }
                                                                    />
                                                                </Box>
                                                                <Typography variant="body2">
                                                                    Amount: {sub.amount_paid} {sub.currency}
                                                                </Typography>
                                                            </Grid>
                                                            <Grid item xs={12} sm={6}>
                                                                <Typography variant="body2">
                                                                    <strong>Start:</strong> {formatDate(sub.start_date)}
                                                                </Typography>
                                                                <Typography variant="body2">
                                                                    <strong>Expiry:</strong> {formatDate(sub.expiry_date)}
                                                                </Typography>
                                                                <Typography variant="body2">
                                                                    <strong>Payment:</strong> {sub.payment_method}{' '}
                                                                    {sub.payment_reference ? `(${sub.payment_reference})` : ''}
                                                                </Typography>
                                                                {sub.admin_notes && (
                                                                    <Typography variant="body2" sx={{ color: colors.rain }}>
                                                                        <strong>Note:</strong> {sub.admin_notes}
                                                                    </Typography>
                                                                )}
                                                            </Grid>
                                                        </Grid>
                                                    </Box>
                                                ))}
                                            </Box>
                                        ) : (
                                            <Typography variant="body2" sx={{ color: colors.rain }}>
                                                No subscription records found.
                                            </Typography>
                                        )}

                                        <Divider sx={{ my: 1.5 }} />
                                        <Box display="flex" flexDirection="column" gap={0.5}>
                                            <Box display="flex" alignItems="center" gap={0.5}>
                                                <Typography variant="body2" component="span">
                                                    <strong>Current Status:</strong>
                                                </Typography>
                                                <Chip
                                                    label={user.subscription_status || 'N/A'}
                                                    size="small"
                                                    color={
                                                        user.subscription_status === 'active'
                                                            ? 'success'
                                                            : user.subscription_status === 'expired'
                                                                ? 'error'
                                                                : user.subscription_status === 'pending'
                                                                    ? 'warning'
                                                                    : 'default'
                                                    }
                                                />
                                            </Box>
                                            {user.subscription_expires_at && (
                                                <Typography variant="body2">
                                                    <strong>Current Expiry:</strong>{' '}
                                                    {formatDate(user.subscription_expires_at)}
                                                </Typography>
                                            )}
                                            {user.current_subscription_id && (
                                                <Typography variant="body2">
                                                    <strong>Current Subscription ID:</strong> {user.current_subscription_id}
                                                </Typography>
                                            )}
                                        </Box>
                                    </CardContent>
                                </Card>

                                {/* Portfolio */}
                                {technician.portfolios && technician.portfolios.length > 0 && (
                                    <Card variant="outlined" sx={{ borderColor: alpha(colors.middle, 0.15) }}>
                                        <CardContent>
                                            <Typography variant="subtitle1" fontWeight="700" sx={{ color: colors.dark, mb: 1.5 }}>
                                                <ImageIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                                Portfolio ({technician.portfolios.length})
                                            </Typography>
                                            <Grid container spacing={2}>
                                                {technician.portfolios.map((item) => {
                                                    const imgUrl = item.image ? getImageUrl(item.image) : null;
                                                    return (
                                                        <Grid item xs={12} sm={6} key={item.id}>
                                                            <Box
                                                                sx={{
                                                                    border: `1px solid ${alpha(colors.middle, 0.2)}`,
                                                                    borderRadius: 2,
                                                                    overflow: 'hidden',
                                                                    backgroundColor: '#f8fafc',
                                                                    transition: 'transform 0.2s',
                                                                    cursor: 'pointer',
                                                                    '&:hover': {
                                                                        transform: 'scale(1.02)',
                                                                        borderColor: colors.sea,
                                                                    },
                                                                }}
                                                                onClick={() =>
                                                                    imgUrl &&
                                                                    openImageModal(
                                                                        imgUrl,
                                                                        item.description || 'Portfolio'
                                                                    )
                                                                }
                                                            >
                                                                {imgUrl && !imageErrors[`portfolio-${item.id}`] ? (
                                                                    <img
                                                                        src={imgUrl}
                                                                        alt={item.description || 'Portfolio'}
                                                                        style={{
                                                                            width: '100%',
                                                                            height: 160,
                                                                            objectFit: 'cover',
                                                                            objectPosition: 'center',
                                                                            display: 'block',
                                                                        }}
                                                                        onError={() =>
                                                                            handleImageError(`portfolio-${item.id}`)
                                                                        }
                                                                    />
                                                                ) : (
                                                                    <Box
                                                                        sx={{
                                                                            height: 160,
                                                                            display: 'flex',
                                                                            alignItems: 'center',
                                                                            justifyContent: 'center',
                                                                            backgroundColor: '#f1f5f9',
                                                                            color: colors.rain,
                                                                        }}
                                                                    >
                                                                        <ImageIcon sx={{ fontSize: 48, opacity: 0.5 }} />
                                                                    </Box>
                                                                )}
                                                                {item.description && (
                                                                    <Box sx={{ p: 1.5, backgroundColor: '#ffffff' }}>
                                                                        <Typography variant="caption" sx={{ color: colors.black }}>
                                                                            {item.description}
                                                                        </Typography>
                                                                    </Box>
                                                                )}
                                                            </Box>
                                                        </Grid>
                                                    );
                                                })}
                                            </Grid>
                                        </CardContent>
                                    </Card>
                                )}

                                {/* Location */}
                                <Card variant="outlined" sx={{ borderColor: alpha(colors.middle, 0.15) }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight="700" sx={{ color: colors.dark, mb: 1.5 }}>
                                            <LocationIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Location
                                        </Typography>
                                        <Box display="flex" flexDirection="column" gap={1.5}>
                                            <Typography variant="body2">
                                                <strong>Area:</strong> {technician.area || 'N/A'}
                                            </Typography>
                                            {technician.latitude && technician.longitude && (
                                                <Typography variant="body2">
                                                    <strong>Coordinates:</strong> {technician.latitude},{' '}
                                                    {technician.longitude}
                                                </Typography>
                                            )}
                                            {technician.location_updated_at && (
                                                <Typography variant="body2" display="flex" alignItems="center" gap={1}>
                                                    <CalendarIcon sx={{ fontSize: 16, color: colors.rain }} />
                                                    <strong>Last Location Update:</strong>{' '}
                                                    {new Date(technician.location_updated_at).toLocaleString()}
                                                </Typography>
                                            )}
                                            {technician.last_activity_at && (
                                                <Typography variant="body2" display="flex" alignItems="center" gap={1}>
                                                    <CalendarIcon sx={{ fontSize: 16, color: colors.rain }} />
                                                    <strong>Last Activity:</strong>{' '}
                                                    {new Date(technician.last_activity_at).toLocaleString()}
                                                </Typography>
                                            )}
                                        </Box>
                                    </CardContent>
                                </Card>
                            </Stack>
                        </Grid>
                    </Grid>
                </Box>
            </Paper>

            {/* ─── Approval Confirmation Dialog ─────────────────────────── */}
            <Dialog
                open={approveDialogOpen}
                onClose={closeApproveDialog}
                aria-labelledby="approve-dialog-title"
                aria-describedby="approve-dialog-description"
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle id="approve-dialog-title" sx={{ fontWeight: 600, color: colors.dark }}>
                    Approve Technician
                </DialogTitle>
                <DialogContent>
                    <DialogContentText id="approve-dialog-description" sx={{ mb: 2 }}>
                        Are you sure you want to approve <strong>{user.name || 'this technician'}</strong>?
                        This will activate a <strong>1‑day free trial</strong> subscription.
                    </DialogContentText>
                    {/* Progress bar – only shown when processing */}
                    {approveProcessing && (
                        <Box sx={{ width: '100%', mt: 2 }}>
                            <Box display="flex" justifyContent="space-between" alignItems="center">
                                <Typography variant="body2" color="textSecondary">
                                    Approving...
                                </Typography>
                                <Typography variant="body2" fontWeight="600" color={colors.sea}>
                                    {Math.round(approveProgress)}%
                                </Typography>
                            </Box>
                            <LinearProgress
                                variant="determinate"
                                value={approveProgress}
                                sx={{
                                    height: 8,
                                    borderRadius: 4,
                                    mt: 0.5,
                                    backgroundColor: alpha(colors.middle, 0.3),
                                    '& .MuiLinearProgress-bar': {
                                        backgroundColor: colors.salat,
                                        borderRadius: 4,
                                    },
                                }}
                            />
                        </Box>
                    )}
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2 }}>
                    <Button onClick={closeApproveDialog} disabled={approveProcessing}>
                        Cancel
                    </Button>
                    <Button
                        onClick={confirmApprove}
                        variant="contained"
                        disabled={approveProcessing}
                        sx={{
                            backgroundColor: colors.salat,
                            '&:hover': { backgroundColor: colors.salatDark },
                            textTransform: 'none',
                            fontWeight: 600,
                        }}
                    >
                        {approveProcessing ? 'Processing...' : 'Yes, Approve'}
                    </Button>
                </DialogActions>
            </Dialog>

            {/* ─── Image Modal ───────────────────────────────────────────── */}
            <Dialog
                open={imageModalOpen}
                onClose={closeImageModal}
                maxWidth="lg"
                fullWidth
                PaperProps={{
                    sx: {
                        backgroundColor: 'rgba(0,0,0,0.9)',
                        borderRadius: 2,
                        overflow: 'hidden',
                    },
                }}
            >
                <IconButton
                    onClick={closeImageModal}
                    sx={{
                        position: 'absolute',
                        top: 16,
                        right: 16,
                        color: '#fff',
                        zIndex: 10,
                        backgroundColor: 'rgba(0,0,0,0.5)',
                        '&:hover': {
                            backgroundColor: 'rgba(0,0,0,0.7)',
                        },
                    }}
                >
                    <CloseIcon />
                </IconButton>
                <DialogContent
                    sx={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        minHeight: '80vh',
                        p: 2,
                    }}
                >
                    {imageModalSrc && (
                        <img
                            src={imageModalSrc}
                            alt={imageModalAlt || 'Image'}
                            style={{
                                maxWidth: '100%',
                                maxHeight: '85vh',
                                objectFit: 'contain',
                                borderRadius: 4,
                            }}
                        />
                    )}
                </DialogContent>
            </Dialog>
        </Box>
    );
};

export default TechnicianDetails;