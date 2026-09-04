// src/pages/technicians/TechnicianDetails.js
import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    Box,
    Paper,
    Typography,
    Avatar,
    Chip,
    CircularProgress,
    Alert,
    Card,
    CardContent,
    Grid,
    Divider,
    Button,
    Stack,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogContentText,
    DialogActions,
    LinearProgress,
    IconButton,
    useMediaQuery,
    useTheme,
    alpha,
    Tooltip,
} from '@mui/material';
import {
    ArrowBack as ArrowBackIcon,
    Verified as VerifiedIcon,
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
    Refresh as RefreshIcon,
    Description as DescriptionIcon,
} from '@mui/icons-material';
import { technicianService } from 'services/technician.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
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

    const getStatusChip = () => {
        if (!technician) return null;
        const isVerified = technician.verified && technician.verification_status === 'approved';
        const status = technician.verification_status || 'pending';

        if (isVerified) {
            return (
                <Chip
                    label="Verified"
                    icon={<VerifiedIcon sx={{ fontSize: 16 }} />}
                    sx={{
                        fontWeight: 700,
                        bgcolor: '#d1fae5',
                        color: '#047857',
                        border: '1.5px solid #10b981',
                        height: 32,
                        '& .MuiChip-icon': { color: '#047857' },
                    }}
                />
            );
        }

        const statusMap = {
            approved: { label: 'Approved', color: '#047857', bg: '#d1fae5', border: '#10b981' },
            pending: { label: 'Pending', color: '#b45309', bg: '#fef3c7', border: '#f59e0b' },
            rejected: { label: 'Rejected', color: '#b91c1c', bg: '#fee2e2', border: '#ef4444' },
        };

        const s = statusMap[status] || statusMap.pending;
        return (
            <Chip
                label={s.label}
                sx={{
                    fontWeight: 700,
                    bgcolor: s.bg,
                    color: s.color,
                    border: `1.5px solid ${s.border}`,
                    height: 32,
                }}
            />
        );
    };

    const openApproveDialog = () => {
        setApproveDialogOpen(true);
        setApproveProgress(0);
        setApproveFeedback(null);
    };

    const closeApproveDialog = () => {
        if (!approveProcessing) {
            setApproveDialogOpen(false);
            setApproveProgress(0);
        }
    };

    const confirmApprove = async () => {
        setApproveProcessing(true);
        setApproveProgress(0);

        const interval = setInterval(() => {
            setApproveProgress((prev) => {
                if (prev < 90) {
                    return Math.min(prev + Math.random() * 10, 90);
                }
                return prev;
            });
        }, 300);

        try {
            const response = await technicianService.approveTechnician(id);
            clearInterval(interval);
            setApproveProgress(100);

            if (response?.data?.status === 'success') {
                setApproveFeedback({
                    type: 'success',
                    message: 'Technician approved successfully! Free trial activated.',
                });
                setTechnician((prev) => ({
                    ...prev,
                    verified: true,
                    verification_status: 'approved',
                }));
                await fetchTechnician();
                showSnackbar({ type: 'success', message: 'Technician approved successfully!' });
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
            setTimeout(() => {
                setApproveDialogOpen(false);
                setApproveProgress(0);
            }, 600);
        }
    };

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
                <CircularProgress size={40} thickness={4} sx={{ color: colors.sea }} />
            </Box>
        );
    }

    if (error) {
        return (
            <Box p={3}>
                <Alert severity="error" sx={{ borderRadius: 2, mb: 2 }}>
                    {error}
                </Alert>
                <Button
                    variant="contained"
                    startIcon={<ArrowBackIcon />}
                    onClick={() => navigate('/app/technicians')}
                    sx={{ borderRadius: 2, textTransform: 'none' }}
                >
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
        <Box sx={{ p: { xs: 1.5, sm: 2.5 }, m: 0, bgcolor: 'background.default', minHeight: '100vh' }}>
            <Paper
                elevation={0}
                sx={{
                    width: '100%',
                    borderRadius: 3,
                    overflow: 'hidden',
                    border: '1px solid',
                    borderColor: 'divider',
                    bgcolor: 'background.paper',
                }}
            >
                {/* ── HEADER ────────────────────────────────────────────── */}
                <Box
                    sx={{
                        px: { xs: 2, sm: 3 },
                        py: 2.5,
                        borderBottom: '1px solid',
                        borderColor: 'divider',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        flexWrap: 'wrap',
                        gap: 2,
                    }}
                >
                    <Button
                        startIcon={<ArrowBackIcon />}
                        onClick={() => navigate('/app/technicians')}
                        sx={{
                            color: colors.sea,
                            fontWeight: 600,
                            textTransform: 'none',
                            '&:hover': { bgcolor: alpha(colors.sea, 0.08) },
                        }}
                    >
                        Back to List
                    </Button>

                    <Stack direction="row" spacing={1.5}>
                        <Button
                            variant="outlined"
                            startIcon={<RefreshIcon />}
                            onClick={fetchTechnician}
                            disabled={loading}
                            size={isMobile ? 'small' : 'medium'}
                            sx={{
                                borderRadius: 2,
                                textTransform: 'none',
                                fontWeight: 600,
                                borderColor: 'divider',
                                '&:hover': { borderColor: colors.sea },
                            }}
                        >
                            Refresh
                        </Button>
                        {canApprove && !isVerified && (
                            <Button
                                variant="contained"
                                startIcon={<ApproveIcon />}
                                onClick={openApproveDialog}
                                sx={{
                                    borderRadius: 2,
                                    textTransform: 'none',
                                    fontWeight: 700,
                                    bgcolor: colors.salat || '#10b981',
                                    '&:hover': { bgcolor: colors.dark || '#047857' },
                                }}
                            >
                                Approve Technician
                            </Button>
                        )}
                    </Stack>
                </Box>

                {approveFeedback && (
                    <Box sx={{ px: { xs: 2, sm: 3 }, pt: 2 }}>
                        <Alert
                            severity={approveFeedback.type}
                            onClose={() => setApproveFeedback(null)}
                            sx={{ borderRadius: 2 }}
                        >
                            {approveFeedback.message}
                        </Alert>
                    </Box>
                )}

                {/* ─── PROFILE HEADER ──────────────────────────────────── */}
                <Box
                    sx={{
                        px: { xs: 2, sm: 3, md: 4 },
                        py: { xs: 2, sm: 3, md: 4 },
                        display: 'flex',
                        flexDirection: { xs: 'column', md: 'row' },
                        gap: 3,
                        alignItems: { xs: 'center', md: 'flex-start' },
                        borderBottom: '1px solid',
                        borderColor: 'divider',
                        background: alpha(colors.sea, 0.03),
                    }}
                >
                    <Box
                        sx={{
                            position: 'relative',
                            cursor: profilePhotoUrl ? 'pointer' : 'default',
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
                                border: `4px solid ${alpha(colors.sea, 0.15)}`,
                                boxShadow: '0 4px 20px rgba(0,0,0,0.06)',
                                transition: 'all 0.2s',
                                '&:hover': profilePhotoUrl && {
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
                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ xs: 'center', sm: 'flex-start' }} mb={1}>
                            <Typography variant="h4" fontWeight={700} color="text.primary">
                                {user.name || 'Unknown'}
                            </Typography>
                            {getStatusChip()}
                        </Stack>

                        <Stack direction="row" spacing={1} flexWrap="wrap" sx={{ mb: 1.5, justifyContent: { xs: 'center', md: 'flex-start' } }}>
                            <Chip
                                label={technician.registration_completed ? 'Registered' : 'Incomplete'}
                                size="small"
                                sx={{
                                    fontWeight: 600,
                                    bgcolor: technician.registration_completed ? '#d1fae5' : '#f3f4f6',
                                    color: technician.registration_completed ? '#047857' : '#4b5563',
                                    border: `1px solid ${technician.registration_completed ? '#10b981' : '#9ca3af'}`,
                                }}
                            />
                            <Chip
                                label={`Step ${technician.registration_step || 0}/4`}
                                size="small"
                                sx={{
                                    fontWeight: 600,
                                    bgcolor: 'action.hover',
                                }}
                            />
                        </Stack>

                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} flexWrap="wrap">
                            <Box display="flex" alignItems="center" gap={1}>
                                <EmailIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                <Typography variant="body2">{user.email || 'N/A'}</Typography>
                            </Box>
                            <Box display="flex" alignItems="center" gap={1}>
                                <PhoneIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                <Typography variant="body2">{user.phone || 'N/A'}</Typography>
                            </Box>
                            <Box display="flex" alignItems="center" gap={1}>
                                <LocationIcon sx={{ fontSize: 18, color: 'text.secondary' }} />
                                <Typography variant="body2">{technician.area || 'N/A'}</Typography>
                            </Box>
                        </Stack>

                        <Stack direction="row" spacing={2.5} flexWrap="wrap" sx={{ mt: 1.5, justifyContent: { xs: 'center', md: 'flex-start' } }}>
                            <Box display="flex" alignItems="center" gap={0.5}>
                                <StarIcon sx={{ fontSize: 20, color: '#f59e0b' }} />
                                <Typography variant="body2" fontWeight={700}>
                                    {technician.rating?.toFixed(1) || 'N/A'}
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    ({technician.completed_jobs_count || 0} jobs)
                                </Typography>
                            </Box>
                            {technician.experience !== undefined && technician.experience !== null && (
                                <Typography variant="body2">
                                    <strong>Experience:</strong> {technician.experience} years
                                </Typography>
                            )}
                            {technician.hourly_rate && (
                                <Typography variant="body2" fontWeight={700} color={colors.sea}>
                                    {technician.hourly_rate} TZS/hr
                                </Typography>
                            )}
                        </Stack>
                    </Box>
                </Box>

                {/* ─── DETAILS CONTENT ──────────────────────────────────── */}
                <Box sx={{ p: { xs: 2, sm: 3, md: 4 } }}>
                    <Grid container spacing={3}>
                        {/* Left Column */}
                        <Grid item xs={12} md={6}>
                            <Stack spacing={3}>
                                {/* Bio */}
                                <Card variant="outlined" sx={{ borderColor: 'divider' }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight={700} color="text.primary" mb={1.5}>
                                            <PersonIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Bio
                                        </Typography>
                                        <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.8 }}>
                                            {technician.bio || 'No bio provided.'}
                                        </Typography>
                                    </CardContent>
                                </Card>

                                {/* Identification */}
                                <Card variant="outlined" sx={{ borderColor: 'divider' }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight={700} color="text.primary" mb={1.5}>
                                            <DocumentIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Identification
                                        </Typography>
                                        {hasIdDocument ? (
                                            <Stack spacing={1.5}>
                                                {technician.nida && (
                                                    <Typography variant="body2">
                                                        <strong>NIDA:</strong> {technician.nida}
                                                    </Typography>
                                                )}
                                                <Typography variant="body2">
                                                    <strong>Document Type:</strong> {technician.id_document_type || 'N/A'}
                                                </Typography>
                                                <Typography variant="body2">
                                                    <strong>Verification Status:</strong> {technician.verification_status}
                                                </Typography>
                                                {idDocumentUrl && !imageErrors['id'] && (
                                                    <Box mt={1}>
                                                        <Typography variant="body2" fontWeight={600} mb={1}>
                                                            ID Document:
                                                        </Typography>
                                                        <Box
                                                            component="img"
                                                            src={idDocumentUrl}
                                                            alt="ID Document"
                                                            onClick={() => openImageModal(idDocumentUrl, 'ID Document')}
                                                            sx={{
                                                                maxWidth: '100%',
                                                                maxHeight: 250,
                                                                border: '1px solid',
                                                                borderColor: 'divider',
                                                                borderRadius: 2,
                                                                objectFit: 'contain',
                                                                bgcolor: 'action.hover',
                                                                p: 1,
                                                                cursor: 'pointer',
                                                                transition: 'all 0.2s',
                                                                '&:hover': {
                                                                    borderColor: colors.sea,
                                                                    transform: 'scale(1.02)',
                                                                },
                                                            }}
                                                            onError={() => handleImageError('id')}
                                                        />
                                                    </Box>
                                                )}
                                            </Stack>
                                        ) : (
                                            <Typography variant="body2" color="text.secondary">
                                                No ID documents uploaded yet.
                                            </Typography>
                                        )}
                                    </CardContent>
                                </Card>

                                {/* Services */}
                                <Card variant="outlined" sx={{ borderColor: 'divider' }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight={700} color="text.primary" mb={1.5}>
                                            <WorkIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Services & Pricing
                                        </Typography>
                                        {technician.service_prices && technician.service_prices.length > 0 ? (
                                            <Grid container spacing={1.5}>
                                                {technician.service_prices.map((service) => (
                                                    <Grid item xs={12} sm={6} key={service.id}>
                                                        <Box
                                                            sx={{
                                                                p: 2,
                                                                bgcolor: 'action.hover',
                                                                borderRadius: 2,
                                                                border: '1px solid',
                                                                borderColor: 'divider',
                                                                transition: 'all 0.2s',
                                                                '&:hover': {
                                                                    borderColor: colors.sea,
                                                                    bgcolor: alpha(colors.sea, 0.04),
                                                                },
                                                            }}
                                                        >
                                                            <Typography variant="body2" fontWeight={600} color="text.primary">
                                                                {service.name}
                                                            </Typography>
                                                            <Typography variant="body2" color="text.secondary">
                                                                Price: {service.pivot?.min_price || 0} – {service.pivot?.max_price || 0} TZS
                                                            </Typography>
                                                        </Box>
                                                    </Grid>
                                                ))}
                                            </Grid>
                                        ) : (
                                            <Typography variant="body2" color="text.secondary">
                                                No services assigned.
                                            </Typography>
                                        )}
                                    </CardContent>
                                </Card>

                                {/* Location */}
                                <Card variant="outlined" sx={{ borderColor: 'divider' }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight={700} color="text.primary" mb={1.5}>
                                            <LocationIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Location
                                        </Typography>
                                        <Stack spacing={1.5}>
                                            <Typography variant="body2">
                                                <strong>Area:</strong> {technician.area || 'N/A'}
                                            </Typography>
                                            {technician.latitude && technician.longitude && (
                                                <Typography variant="body2">
                                                    <strong>Coordinates:</strong> {technician.latitude}, {technician.longitude}
                                                </Typography>
                                            )}
                                            {technician.location_updated_at && (
                                                <Typography variant="body2" display="flex" alignItems="center" gap={1}>
                                                    <CalendarIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                                                    <strong>Last Location Update:</strong> {new Date(technician.location_updated_at).toLocaleString()}
                                                </Typography>
                                            )}
                                            {technician.last_activity_at && (
                                                <Typography variant="body2" display="flex" alignItems="center" gap={1}>
                                                    <CalendarIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                                                    <strong>Last Activity:</strong> {new Date(technician.last_activity_at).toLocaleString()}
                                                </Typography>
                                            )}
                                        </Stack>
                                    </CardContent>
                                </Card>
                            </Stack>
                        </Grid>

                        {/* Right Column */}
                        <Grid item xs={12} md={6}>
                            <Stack spacing={3}>
                                {/* Portfolio */}
                                {technician.portfolios && technician.portfolios.length > 0 && (
                                    <Card variant="outlined" sx={{ borderColor: 'divider' }}>
                                        <CardContent>
                                            <Typography variant="subtitle1" fontWeight={700} color="text.primary" mb={1.5}>
                                                <ImageIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                                Portfolio ({technician.portfolios.length})
                                            </Typography>
                                            <Grid container spacing={1.5}>
                                                {technician.portfolios.map((item) => {
                                                    const imgUrl = item.image ? getImageUrl(item.image) : null;
                                                    return (
                                                        <Grid item xs={12} sm={6} key={item.id}>
                                                            <Box
                                                                sx={{
                                                                    border: '1px solid',
                                                                    borderColor: 'divider',
                                                                    borderRadius: 2,
                                                                    overflow: 'hidden',
                                                                    bgcolor: 'action.hover',
                                                                    cursor: imgUrl ? 'pointer' : 'default',
                                                                    transition: 'all 0.2s',
                                                                    '&:hover': imgUrl && {
                                                                        borderColor: colors.sea,
                                                                        transform: 'scale(1.02)',
                                                                    },
                                                                }}
                                                                onClick={() => imgUrl && openImageModal(imgUrl, item.description || 'Portfolio')}
                                                            >
                                                                {imgUrl && !imageErrors[`portfolio-${item.id}`] ? (
                                                                    <img
                                                                        src={imgUrl}
                                                                        alt={item.description || 'Portfolio'}
                                                                        style={{
                                                                            width: '100%',
                                                                            height: 160,
                                                                            objectFit: 'cover',
                                                                            display: 'block',
                                                                        }}
                                                                        onError={() => handleImageError(`portfolio-${item.id}`)}
                                                                    />
                                                                ) : (
                                                                    <Box
                                                                        sx={{
                                                                            height: 160,
                                                                            display: 'flex',
                                                                            alignItems: 'center',
                                                                            justifyContent: 'center',
                                                                            bgcolor: 'action.hover',
                                                                            color: 'text.disabled',
                                                                        }}
                                                                    >
                                                                        <ImageIcon sx={{ fontSize: 48, opacity: 0.5 }} />
                                                                    </Box>
                                                                )}
                                                                {item.description && (
                                                                    <Box sx={{ p: 1.5, bgcolor: 'background.paper' }}>
                                                                        <Typography variant="caption" color="text.secondary">
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

                                {/* Subscription - Moved to Bottom */}
                                <Card variant="outlined" sx={{ borderColor: 'divider' }}>
                                    <CardContent>
                                        <Typography variant="subtitle1" fontWeight={700} color="text.primary" mb={1.5}>
                                            <SubscriptionsIcon sx={{ fontSize: 20, mr: 1, verticalAlign: 'middle', color: colors.sea }} />
                                            Subscription History
                                        </Typography>

                                        {user.subscriptions && user.subscriptions.length > 0 ? (
                                            <Stack spacing={1.5}>
                                                {user.subscriptions.map((sub) => (
                                                    <Box
                                                        key={sub.id}
                                                        sx={{
                                                            p: 2,
                                                            bgcolor: 'action.hover',
                                                            borderRadius: 2,
                                                            border: '1px solid',
                                                            borderColor: 'divider',
                                                        }}
                                                    >
                                                        <Grid container spacing={1}>
                                                            <Grid item xs={12} sm={6}>
                                                                <Typography variant="body2" fontWeight={600}>
                                                                    Plan: {sub.rate_card?.name || 'N/A'}
                                                                </Typography>
                                                                <Box display="flex" alignItems="center" gap={0.5} mt={0.5}>
                                                                    <Typography variant="body2">Status:</Typography>
                                                                    <Chip
                                                                        label={sub.status}
                                                                        size="small"
                                                                        color={
                                                                            sub.status === 'active' ? 'success' :
                                                                                sub.status === 'expired' ? 'error' :
                                                                                    sub.status === 'pending' ? 'warning' : 'default'
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
                                                                    <strong>Payment:</strong> {sub.payment_method}
                                                                    {sub.payment_reference ? ` (${sub.payment_reference})` : ''}
                                                                </Typography>
                                                            </Grid>
                                                        </Grid>
                                                    </Box>
                                                ))}
                                            </Stack>
                                        ) : (
                                            <Typography variant="body2" color="text.secondary">
                                                No subscription records found.
                                            </Typography>
                                        )}

                                        <Divider sx={{ my: 1.5 }} />

                                        <Stack spacing={0.5}>
                                            <Box display="flex" alignItems="center" gap={0.5}>
                                                <Typography variant="body2">
                                                    <strong>Current Status:</strong>
                                                </Typography>
                                                <Chip
                                                    label={user.subscription_status || 'N/A'}
                                                    size="small"
                                                    color={
                                                        user.subscription_status === 'active' ? 'success' :
                                                            user.subscription_status === 'expired' ? 'error' :
                                                                user.subscription_status === 'pending' ? 'warning' : 'default'
                                                    }
                                                />
                                            </Box>
                                            {user.subscription_expires_at && (
                                                <Typography variant="body2">
                                                    <strong>Current Expiry:</strong> {formatDate(user.subscription_expires_at)}
                                                </Typography>
                                            )}
                                        </Stack>
                                    </CardContent>
                                </Card>
                            </Stack>
                        </Grid>
                    </Grid>
                </Box>
            </Paper>

            {/* ─── APPROVAL CONFIRMATION DIALOG ────────────────────────── */}
            <Dialog
                open={approveDialogOpen}
                onClose={closeApproveDialog}
                maxWidth="sm"
                fullWidth
                PaperProps={{ sx: { borderRadius: 3 } }}
            >
                <DialogTitle sx={{ fontWeight: 700, color: 'text.primary' }}>
                    Approve Technician
                </DialogTitle>
                <DialogContent>
                    <DialogContentText color="text.secondary" sx={{ mb: 2 }}>
                        Are you sure you want to approve <strong>{user.name || 'this technician'}</strong>?
                        This will activate a <strong>1‑day free trial</strong> subscription.
                    </DialogContentText>
                    {approveProcessing && (
                        <Box sx={{ width: '100%', mt: 2 }}>
                            <Box display="flex" justifyContent="space-between" alignItems="center">
                                <Typography variant="body2" color="text.secondary">
                                    Approving...
                                </Typography>
                                <Typography variant="body2" fontWeight={600} color={colors.sea}>
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
                                    bgcolor: alpha(colors.middle, 0.3),
                                    '& .MuiLinearProgress-bar': {
                                        bgcolor: colors.salat || '#10b981',
                                        borderRadius: 4,
                                    },
                                }}
                            />
                        </Box>
                    )}
                </DialogContent>
                <DialogActions sx={{ px: 3, pb: 2.5, pt: 1 }}>
                    <Button onClick={closeApproveDialog} disabled={approveProcessing} sx={{ fontWeight: 600 }}>
                        Cancel
                    </Button>
                    <Button
                        onClick={confirmApprove}
                        variant="contained"
                        disabled={approveProcessing}
                        sx={{
                            borderRadius: 2,
                            fontWeight: 700,
                            textTransform: 'none',
                            bgcolor: colors.salat || '#10b981',
                            '&:hover': { bgcolor: colors.dark || '#047857' },
                        }}
                    >
                        {approveProcessing ? 'Processing...' : 'Yes, Approve'}
                    </Button>
                </DialogActions>
            </Dialog>

            {/* ─── IMAGE MODAL ──────────────────────────────────────────── */}
            <Dialog
                open={imageModalOpen}
                onClose={closeImageModal}
                maxWidth="lg"
                fullWidth
                PaperProps={{
                    sx: {
                        bgcolor: 'rgba(0,0,0,0.92)',
                        borderRadius: { xs: 0, sm: 3 },
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
                        bgcolor: 'rgba(0,0,0,0.5)',
                        '&:hover': { bgcolor: 'rgba(0,0,0,0.7)' },
                    }}
                >
                    <CloseIcon />
                </IconButton>
                <DialogContent
                    sx={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        minHeight: { xs: '60vh', sm: '80vh' },
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