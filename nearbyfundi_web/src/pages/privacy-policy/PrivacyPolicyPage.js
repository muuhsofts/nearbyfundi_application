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
} from '@mui/material';
import {
    Edit as EditIcon,
    Refresh as RefreshIcon,
    Add as AddIcon,
    Delete as DeleteIcon,
    Search as SearchIcon,
} from '@mui/icons-material';
import { usePrivacyPolicyManagement } from 'hooks/usePrivacyPolicy';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import PrivacyPolicyFormModal from './componentS/PrivacyPolicyFormModal'; // adjust path if needed
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
        } catch (err) {
            showSnackbar({ type: 'error', message: err.response?.data?.message || 'Delete failed' });
        }
    };

    // Use the first policy as the current one (singleton)
    const policyData = Array.isArray(privacyPolicies) && privacyPolicies.length > 0 ? privacyPolicies[0] : null;

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
                <Alert
                    severity="error"
                    action={
                        <Button color="inherit" size="small" onClick={() => { clearError(); loadPolicy(); }}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            </Box>
        );
    }

    return (
        <Box sx={{ width: '100%', p: { xs: 1, sm: 2 }, m: 0 }}>
            <Paper
                sx={{
                    width: '100%',
                    borderRadius: { xs: 1, sm: 2 },
                    overflow: 'hidden',
                    boxShadow: { xs: 0, sm: 1 },
                    backgroundColor: colors.light,
                    border: `1px solid ${colors.middle}`,
                }}
            >
                <Box sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                    <Box
                        display="flex"
                        justifyContent="space-between"
                        alignItems="center"
                        mb={2}
                        flexWrap="wrap"
                        gap={1}
                    >
                        <Typography
                            variant="h5"
                            fontWeight="600"
                            sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem' }, color: colors.dark }}
                        >
                            Privacy Policy
                        </Typography>
                        <Box display="flex" gap={1}>
                            {!policyData ? (
                                <Button
                                    variant="contained"
                                    startIcon={<AddIcon />}
                                    onClick={() => handleOpenModal(null)}
                                    size={isMobile ? 'small' : 'medium'}
                                    sx={{
                                        borderRadius: 2,
                                        backgroundColor: colors.salat,
                                        '&:hover': { backgroundColor: colors.dark },
                                    }}
                                >
                                    Create
                                </Button>
                            ) : (
                                canEdit && (
                                    <>
                                        <Button
                                            variant="contained"
                                            startIcon={<EditIcon />}
                                            onClick={() => handleOpenModal(policyData)}
                                            size={isMobile ? 'small' : 'medium'}
                                            sx={{
                                                borderRadius: 2,
                                                backgroundColor: colors.sea,
                                                '&:hover': { backgroundColor: colors.dark },
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
                                                backgroundColor: colors.error || '#d32f2f',
                                                '&:hover': { backgroundColor: colors.dark },
                                            }}
                                        >
                                            Delete
                                        </Button>
                                    </>
                                )
                            )}
                            <Tooltip title="Refresh">
                                <IconButton
                                    onClick={loadPolicy}
                                    size={isMobile ? 'small' : 'medium'}
                                    sx={{ color: colors.sea, '&:hover': { backgroundColor: colors.wave } }}
                                >
                                    <RefreshIcon />
                                </IconButton>
                            </Tooltip>
                        </Box>
                    </Box>
                    <Box display="flex" gap={2} flexWrap="wrap" alignItems="center">
                        <TextField
                            label="Search"
                            size="small"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            InputProps={{
                                startAdornment: (
                                    <InputAdornment position="start">
                                        <SearchIcon fontSize="small" sx={{ color: colors.rain }} />
                                    </InputAdornment>
                                ),
                            }}
                            sx={{
                                minWidth: { xs: '100%', sm: 250 },
                                flexGrow: { xs: 1, sm: 0 },
                                '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                                '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                            }}
                        />
                    </Box>
                </Box>

                <Box sx={{ p: { xs: 2, sm: 3 } }}>
                    <Card variant="outlined" sx={{ borderColor: colors.middle, backgroundColor: colors.sky }}>
                        <CardContent>
                            <Typography
                                variant="body1"
                                component="div"
                                sx={{
                                    whiteSpace: 'pre-wrap',
                                    wordBreak: 'break-word',
                                    lineHeight: 1.8,
                                    minHeight: '100px',
                                    color: policyData?.content ? colors.black : colors.rain,
                                    fontStyle: policyData?.content ? 'normal' : 'italic',
                                }}
                            >
                                {policyData?.content ||
                                    'No privacy policy content available. Click Create to add content.'}
                            </Typography>
                        </CardContent>
                    </Card>
                    {policyData && (
                        <Box mt={2}>
                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                Last updated:{' '}
                                {policyData.updated_at
                                    ? new Date(policyData.updated_at).toLocaleString()
                                    : 'Never'}
                            </Typography>
                        </Box>
                    )}
                </Box>
            </Paper>

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