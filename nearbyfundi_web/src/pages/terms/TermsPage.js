import React, { useState, useEffect } from 'react';
import {
    Box, Paper, Typography, Button, CircularProgress, Alert,
    Card, CardContent, IconButton, Tooltip, TextField, InputAdornment,
    useMediaQuery, useTheme
} from '@mui/material';
import { Edit as EditIcon, Refresh as RefreshIcon, Add as AddIcon, Search as SearchIcon } from '@mui/icons-material';
import { useTermsManagement } from 'hooks/useTerms';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import TermsFormModal from './TermsFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const TermsPage = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const { terms, loading, error, getTerms, createTerms, updateTerms, clearError } = useTermsManagement();
    const { can } = usePermissions();
    const [modalOpen, setModalOpen] = useState(false);
    const [editingTerms, setEditingTerms] = useState(null);
    const [search, setSearch] = useState('');

    const canEdit = can('terms.edit');

    const loadTerms = async () => {
        try {
            await getTerms();
        } catch {
            showSnackbar({ type: 'error', message: 'Failed to load terms content' });
        }
    };

    useEffect(() => { loadTerms(); }, []);

    const handleOpenModal = (data = null) => {
        setEditingTerms(data);
        setModalOpen(true);
    };

    const handleCloseModal = (refresh = false) => {
        setModalOpen(false);
        setEditingTerms(null);
        if (refresh) loadTerms();
    };

    const termsData = Array.isArray(terms) && terms.length > 0 ? terms[0] : null;

    if (loading) return (
        <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
            <CircularProgress sx={{ color: colors.sea }} />
        </Box>
    );

    if (error) return (
        <Box p={3}>
            <Alert severity="error" action={<Button color="inherit" size="small" onClick={() => { clearError(); loadTerms(); }}>Retry</Button>}>
                {error}
            </Alert>
        </Box>
    );

    return (
        <Box sx={{ width: '100%', p: { xs: 1, sm: 2 }, m: 0 }}>
            <Paper sx={{
                width: '100%',
                borderRadius: { xs: 1, sm: 2 },
                overflow: 'hidden',
                boxShadow: { xs: 0, sm: 1 },
                backgroundColor: colors.light,
                border: `1px solid ${colors.middle}`,
            }}>
                <Box sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                    <Box display="flex" justifyContent="space-between" alignItems="center" mb={2} flexWrap="wrap" gap={1}>
                        <Typography variant="h5" fontWeight="600" sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem' }, color: colors.dark }}>
                            Terms & Conditions
                        </Typography>
                        <Box display="flex" gap={1}>
                            {!termsData ? (
                                <Button variant="contained" startIcon={<AddIcon />} onClick={() => handleOpenModal(null)}
                                        size={isMobile ? 'small' : 'medium'}
                                        sx={{ borderRadius: 2, backgroundColor: colors.salat, '&:hover': { backgroundColor: colors.dark } }}>
                                    Create
                                </Button>
                            ) : canEdit && (
                                <Button variant="contained" startIcon={<EditIcon />} onClick={() => handleOpenModal(termsData)}
                                        size={isMobile ? 'small' : 'medium'}
                                        sx={{ borderRadius: 2, backgroundColor: colors.sea, '&:hover': { backgroundColor: colors.dark } }}>
                                    Edit
                                </Button>
                            )}
                            <Tooltip title="Refresh">
                                <IconButton onClick={loadTerms} size={isMobile ? 'small' : 'medium'}
                                            sx={{ color: colors.sea, '&:hover': { backgroundColor: colors.wave } }}>
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
                            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" sx={{ color: colors.rain }} /></InputAdornment> }}
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
                            <Typography variant="body1" component="div" sx={{
                                whiteSpace: 'pre-wrap', wordBreak: 'break-word', lineHeight: 1.8,
                                minHeight: '100px',
                                color: termsData?.content ? colors.black : colors.rain,
                                fontStyle: termsData?.content ? 'normal' : 'italic',
                            }}>
                                {termsData?.content || 'No terms content available. Click Create to add content.'}
                            </Typography>
                        </CardContent>
                    </Card>
                    {termsData && (
                        <Box mt={2}>
                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                Last updated: {termsData.updated_at ? new Date(termsData.updated_at).toLocaleString() : 'Never'}
                            </Typography>
                        </Box>
                    )}
                </Box>
            </Paper>

            <TermsFormModal
                open={modalOpen}
                onClose={handleCloseModal}
                termsData={editingTerms}
                createTerms={createTerms}
                updateTerms={updateTerms}
            />
        </Box>
    );
};

export default TermsPage;