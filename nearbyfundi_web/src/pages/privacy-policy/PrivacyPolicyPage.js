// src/pages/privacy/PrivacyPolicyPage.js
import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Button,
    CircularProgress,
    Alert,
    Card,
    CardContent,
    IconButton,
    Tooltip,
    TextField,
    InputAdornment,
    useMediaQuery,
    useTheme,
    Stack,
    Grid,
    alpha,
} from '@mui/material';
import {
    Edit as EditIcon,
    Refresh as RefreshIcon,
    Add as AddIcon,
    Delete as DeleteIcon,
    Search as SearchIcon,
    Clear as ClearIcon,
    Description as DescriptionIcon,
    History as HistoryIcon,
    PrivacyTip as PrivacyTipIcon,
} from '@mui/icons-material';
import { usePrivacyPolicyManagement } from 'hooks/usePrivacyPolicy';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import PrivacyPolicyFormModal from './components/PrivacyPolicyFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const PrivacyPolicyPage = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

    const {
        privacyPolicies,
        loading,
        error,
        getPrivacyPolicy,
        createPrivacyPolicy,
        updatePrivacyPolicy,
        deletePrivacyPolicy,
        clearError,
    } = usePrivacyPolicyManagement();

    const { can } = usePermissions();
    const [modalOpen, setModalOpen] = useState(false);
    const [editingPolicy, setEditingPolicy] = useState(null);
    const [search, setSearch] = useState('');

    const canEdit = can('privacy.edit');

    const loadPolicy = async () => {
        try {
            await getPrivacyPolicy();
        } catch {
            showSnackbar({ type: 'error', message: 'Failed to load privacy policy' });
        }
    };

    useEffect(() => {
        loadPolicy();
    }, []);

    const handleOpenModal = (data = null) => {
        setEditingPolicy(data);
        setModalOpen(true);
    };

    const handleCloseModal = (refresh = false) => {
        setModalOpen(false);
        setEditingPolicy(null);
        if (refresh) loadPolicy();
    };

    const handleDelete = async (id) => {
        if (!window.confirm('Are you sure you want to delete this privacy policy?')) return;
        try {
            await deletePrivacyPolicy(id);
            showSnackbar({ type: 'success', message: 'Privacy policy deleted successfully' });
            loadPolicy();
        } catch (err) {
            showSnackbar({ type: 'error', message: err.response?.data?.message || 'Delete failed' });
        }
    };

    const policyData = Array.isArray(privacyPolicies) && privacyPolicies.length > 0 ? privacyPolicies[0] : null;

    // Search filter
    const filteredContent = search.trim()
        ? policyData?.content?.toLowerCase().includes(search.toLowerCase()) ? policyData : null
        : policyData;

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
                <Alert
                    severity="error"
                    action={
                        <Button color="inherit" size="small" onClick={() => { clearError(); loadPolicy(); }}>
                            Retry
                        </Button>
                    }
                    sx={{ borderRadius: 2 }}
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    return (
        <Box sx={{ width: '100%', p: { xs: 1.5, sm: 2.5 }, m: 0, bgcolor: 'background.default' }}>
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
                    }}
                >
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        justifyContent="space-between"
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        spacing={2}
                        mb={2.5}
                    >
                        <Box>
                            <Typography variant="h5" fontWeight={800} color="text.primary">
                                Privacy Policy
                            </Typography>
                            <Typography variant="body2" color="text.secondary" fontWeight={500}>
                                Manage your privacy policy content
                            </Typography>
                        </Box>

                        <Stack direction="row" spacing={1.5} alignItems="center" justifyContent={{ xs: 'space-between', sm: 'flex-end' }}>
                            {!policyData ? (
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => handleOpenModal(null)}
                                    size={isMobile ? 'small' : 'medium'}
                                    sx={{
                                        borderRadius: 2,
                                        fontWeight: 700,
                                        textTransform: 'none',
                                        px: 2.5,
                                        boxShadow: 'none',
                                        bgcolor: colors.salat || '#10b981',
                                        '&:hover': {
                                            bgcolor: colors.dark || '#047857',
                                            boxShadow: '0 4px 12px rgba(16,185,129,0.35)',
                                        },
                                    }}
                                >
                                    Create Policy
                                </Button>
                            ) : canEdit && (
                                <>
                                    <Button
                                        variant="contained"
                                        startIcon={<EditIcon />}
                                        onClick={() => handleOpenModal(policyData)}
                                        size={isMobile ? 'small' : 'medium'}
                                        sx={{
                                            borderRadius: 2,
                                            fontWeight: 700,
                                            textTransform: 'none',
                                            px: 2.5,
                                            boxShadow: 'none',
                                            bgcolor: colors.sea || '#0f766e',
                                            '&:hover': {
                                                bgcolor: colors.dark || '#0d5c56',
                                                boxShadow: '0 4px 12px rgba(15,118,110,0.35)',
                                            },
                                        }}
                                    >
                                        Edit
                                    </Button>
                                    <Button
                                        variant="contained"
                                        startIcon={<DeleteIcon />}
                                        onClick={() => handleDelete(policyData.id)}
                                        size={isMobile ? 'small' : 'medium'}
                                        sx={{
                                            borderRadius: 2,
                                            fontWeight: 700,
                                            textTransform: 'none',
                                            px: 2.5,
                                            boxShadow: 'none',
                                            bgcolor: '#ef4444',
                                            '&:hover': {
                                                bgcolor: '#b91c1c',
                                                boxShadow: '0 4px 12px rgba(239,68,68,0.35)',
                                            },
                                        }}
                                    >
                                        Delete
                                    </Button>
                                </>
                            )}

                            <Button
                                variant="outlined"
                                startIcon={<RefreshIcon />}
                                onClick={loadPolicy}
                                disabled={loading}
                                size={isMobile ? 'small' : 'medium'}
                                sx={{
                                    borderRadius: 2,
                                    fontWeight: 600,
                                    textTransform: 'none',
                                    borderColor: 'divider',
                                    color: 'text.primary',
                                    '&:hover': {
                                        borderColor: 'text.primary',
                                        bgcolor: 'action.hover',
                                    },
                                }}
                            >
                                Refresh
                            </Button>
                        </Stack>
                    </Stack>

                    {/* ── FILTERS ──────────────────────────────────────── */}
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        spacing={1.5}
                        alignItems={{ xs: 'stretch', sm: 'center' }}
                        flexWrap="wrap"
                    >
                        <TextField
                            placeholder="Search content..."
                            size="small"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            InputProps={{
                                startAdornment: (
                                    <InputAdornment position="start">
                                        <SearchIcon fontSize="small" color="action" />
                                    </InputAdornment>
                                ),
                                endAdornment: search ? (
                                    <InputAdornment position="end">
                                        <IconButton size="small" onClick={() => setSearch('')}>
                                            <ClearIcon fontSize="small" />
                                        </IconButton>
                                    </InputAdornment>
                                ) : null,
                            }}
                            sx={{
                                minWidth: { xs: '100%', sm: 260 },
                                flexGrow: { xs: 1, sm: 0 },
                                '& .MuiOutlinedInput-root': {
                                    borderRadius: 2,
                                    bgcolor: 'action.hover',
                                    '& fieldset': { borderColor: 'transparent' },
                                    '&:hover fieldset': { borderColor: 'divider' },
                                    '&.Mui-focused fieldset': { borderColor: 'primary.main' },
                                },
                            }}
                        />
                    </Stack>
                </Box>

                {/* ── SUMMARY CARDS ────────────────────────────────────── */}
                <Box sx={{ px: { xs: 2, sm: 3 }, pt: 2.5, pb: 1 }}>
                    <Grid container spacing={2}>
                        {[
                            { label: 'Status', value: policyData ? 'Published' : 'Not Created', color: policyData ? '#10b981' : '#f59e0b', bg: policyData ? '#ecfdf5' : '#fef3c7', icon: <PrivacyTipIcon sx={{ fontSize: 18 }} /> },
                            { label: 'Word Count', value: policyData?.content?.split(/\s+/).filter(Boolean).length || 0, color: '#3b82f6', bg: '#eff6ff', icon: <DescriptionIcon sx={{ fontSize: 18 }} /> },
                            { label: 'Last Updated', value: policyData?.updated_at ? new Date(policyData.updated_at).toLocaleDateString() : 'Never', color: '#8b5cf6', bg: '#f3e8ff', icon: <HistoryIcon sx={{ fontSize: 18 }} /> },
                        ].map((item, idx) => (
                            <Grid item xs={6} sm={4} key={idx}>
                                <Card
                                    elevation={0}
                                    sx={{
                                        borderRadius: 2,
                                        border: '1px solid',
                                        borderColor: 'divider',
                                        backgroundColor: item.bg,
                                        height: '100%',
                                    }}
                                >
                                    <CardContent sx={{ p: 2, '&:last-child': { pb: 2 } }}>
                                        <Box display="flex" alignItems="center" justifyContent="space-between">
                                            <Typography variant="caption" sx={{ color: item.color, fontWeight: 600 }}>
                                                {item.label}
                                            </Typography>
                                            {item.icon}
                                        </Box>
                                        <Typography variant="h4" sx={{ color: item.color, fontWeight: 700, fontSize: '1.3rem' }}>
                                            {item.value}
                                        </Typography>
                                    </CardContent>
                                </Card>
                            </Grid>
                        ))}
                    </Grid>
                </Box>

                {/* ── CONTENT DISPLAY ──────────────────────────────────── */}
                <Box sx={{ p: { xs: 2, sm: 3 } }}>
                    <Card
                        variant="outlined"
                        sx={{
                            borderColor: 'divider',
                            borderRadius: 2.5,
                            overflow: 'hidden',
                            bgcolor: alpha(colors.sea, 0.02),
                        }}
                    >
                        <CardContent sx={{ p: 3 }}>
                            {filteredContent ? (
                                <>
                                    <Typography
                                        variant="body1"
                                        component="div"
                                        sx={{
                                            whiteSpace: 'pre-wrap',
                                            wordBreak: 'break-word',
                                            lineHeight: 1.9,
                                            minHeight: '120px',
                                            color: 'text.primary',
                                        }}
                                    >
                                        {filteredContent.content}
                                    </Typography>

                                    <Box
                                        sx={{
                                            mt: 2.5,
                                            pt: 2,
                                            borderTop: '1px solid',
                                            borderColor: 'divider',
                                            display: 'flex',
                                            justifyContent: 'space-between',
                                            alignItems: 'center',
                                            flexWrap: 'wrap',
                                            gap: 1,
                                        }}
                                    >
                                        <Typography variant="caption" color="text.secondary">
                                            <HistoryIcon sx={{ fontSize: 14, mr: 0.5, verticalAlign: 'middle' }} />
                                            Last updated: {filteredContent.updated_at
                                            ? new Date(filteredContent.updated_at).toLocaleString()
                                            : 'Never'}
                                        </Typography>
                                        {filteredContent.created_at && (
                                            <Typography variant="caption" color="text.secondary">
                                                Created: {new Date(filteredContent.created_at).toLocaleString()}
                                            </Typography>
                                        )}
                                        <Typography variant="caption" color="text.secondary">
                                            {filteredContent.content.split(/\s+/).filter(Boolean).length} words
                                        </Typography>
                                    </Box>
                                </>
                            ) : search ? (
                                <Box textAlign="center" py={3}>
                                    <Typography color="text.secondary">
                                        No content matches your search.
                                    </Typography>
                                </Box>
                            ) : (
                                <Box textAlign="center" py={4}>
                                    <PrivacyTipIcon sx={{ fontSize: 56, color: 'text.disabled', mb: 1.5 }} />
                                    <Typography color="text.secondary" fontWeight={500}>
                                        No privacy policy content available.
                                    </Typography>
                                    {!policyData && canEdit && (
                                        <Button
                                            variant="contained"
                                            startIcon={<AddIcon />}
                                            onClick={() => handleOpenModal(null)}
                                            sx={{
                                                mt: 2,
                                                borderRadius: 2,
                                                textTransform: 'none',
                                                fontWeight: 600,
                                                bgcolor: colors.salat || '#10b981',
                                                '&:hover': { bgcolor: colors.dark || '#047857' },
                                            }}
                                        >
                                            Create Privacy Policy
                                        </Button>
                                    )}
                                </Box>
                            )}
                        </CardContent>
                    </Card>
                </Box>
            </Paper>

            {/* ─── PRIVACY POLICY FORM MODAL ───────────────────────────── */}
            <PrivacyPolicyFormModal
                open={modalOpen}
                onClose={handleCloseModal}
                policyData={editingPolicy}
                createPrivacyPolicy={createPrivacyPolicy}
                updatePrivacyPolicy={updatePrivacyPolicy}
            />
        </Box>
    );
};

export default PrivacyPolicyPage;