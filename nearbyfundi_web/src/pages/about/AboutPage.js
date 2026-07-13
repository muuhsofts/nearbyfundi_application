import React, { useState, useEffect } from 'react';
import {
    Box, Paper, Typography, Button, CircularProgress, Alert,
    Card, CardContent, IconButton, Tooltip, TextField, InputAdornment,
    useMediaQuery, useTheme
} from '@mui/material';
import { Edit as EditIcon, Refresh as RefreshIcon, Add as AddIcon, Search as SearchIcon } from '@mui/icons-material';
import { useAboutManagement } from 'hooks/useAbout';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import AboutFormModal from './AboutFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const AboutPage = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const { about, loading, error, getAbout, createAbout, updateAbout, clearError } = useAboutManagement();
    const { can } = usePermissions();
    const [modalOpen, setModalOpen] = useState(false);
    const [editingAbout, setEditingAbout] = useState(null);
    const [search, setSearch] = useState('');

    const canEdit = can('about.edit');

    const loadAbout = async () => {
        try {
            await getAbout();
        } catch {
            showSnackbar({ type: 'error', message: 'Failed to load about content' });
        }
    };

    useEffect(() => { loadAbout(); }, []);

    const handleOpenModal = (data = null) => {
        setEditingAbout(data);
        setModalOpen(true);
    };

    const handleCloseModal = (refresh = false) => {
        setModalOpen(false);
        setEditingAbout(null);
        if (refresh) loadAbout();
    };

    const aboutData = Array.isArray(about) && about.length > 0 ? about[0] : null;

    if (loading) return (
        <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
            <CircularProgress sx={{ color: colors.sea }} />
        </Box>
    );

    if (error) return (
        <Box p={3}>
            <Alert severity="error" action={<Button color="inherit" size="small" onClick={() => { clearError(); loadAbout(); }}>Retry</Button>}>
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
                            About Page
                        </Typography>
                        <Box display="flex" gap={1}>
                            {!aboutData ? (
                                <Button variant="contained" startIcon={<AddIcon />} onClick={() => handleOpenModal(null)}
                                        size={isMobile ? 'small' : 'medium'}
                                        sx={{ borderRadius: 2, backgroundColor: colors.salat, '&:hover': { backgroundColor: colors.dark } }}>
                                    Create
                                </Button>
                            ) : canEdit && (
                                <Button variant="contained" startIcon={<EditIcon />} onClick={() => handleOpenModal(aboutData)}
                                        size={isMobile ? 'small' : 'medium'}
                                        sx={{ borderRadius: 2, backgroundColor: colors.sea, '&:hover': { backgroundColor: colors.dark } }}>
                                    Edit
                                </Button>
                            )}
                            <Tooltip title="Refresh">
                                <IconButton onClick={loadAbout} size={isMobile ? 'small' : 'medium'}
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
                                color: aboutData?.content ? colors.black : colors.rain,
                                fontStyle: aboutData?.content ? 'normal' : 'italic',
                            }}>
                                {aboutData?.content || 'No about content available. Click Create to add content.'}
                            </Typography>
                        </CardContent>
                    </Card>
                    {aboutData && (
                        <Box mt={2}>
                            <Typography variant="caption" sx={{ color: colors.rain }}>
                                Last updated: {aboutData.updated_at ? new Date(aboutData.updated_at).toLocaleString() : 'Never'}
                            </Typography>
                        </Box>
                    )}
                </Box>
            </Paper>

            <AboutFormModal
                open={modalOpen}
                onClose={handleCloseModal}
                aboutData={editingAbout}
                createAbout={createAbout}
                updateAbout={updateAbout}
            />
        </Box>
    );
};

export default AboutPage;