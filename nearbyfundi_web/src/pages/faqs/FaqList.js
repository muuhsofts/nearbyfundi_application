import React, { useState, useEffect } from 'react';
import {
    Box, Paper, Typography, Button, Table, TableBody, TableCell,
    TableContainer, TableHead, TableRow, IconButton, CircularProgress,
    Alert, Tooltip, useMediaQuery, useTheme, Card, CardContent,
    Divider, Chip, TextField, InputAdornment, Menu, MenuItem,
    TablePagination
} from '@mui/material';
import {
    Add as AddIcon, Edit as EditIcon, Refresh as RefreshIcon,
    Search as SearchIcon, MoreVert as MoreVertIcon,
    Description as DescriptionIcon
} from '@mui/icons-material';
import { useFaqManagement } from 'hooks/useFaq';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import FaqFormModal from './FaqFormModal';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'index', label: '#' },
    { id: 'question', label: 'Question' },
    { id: 'answer', label: 'Answer' },
    { id: 'actions', label: 'Actions', disableSort: true },
];

const FaqList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const { faqs, loading, error, getFaqs, createFaq, updateFaq, clearError } = useFaqManagement();
    const { can } = usePermissions();
    const canCreate = can('faqs.create');
    const canEdit = can('faqs.edit');

    const [openFormModal, setOpenFormModal] = useState(false);
    const [editingFaq, setEditingFaq] = useState(null);
    const [actionMenu, setActionMenu] = useState(null);
    const [selectedFaq, setSelectedFaq] = useState(null);
    const [search, setSearch] = useState('');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    const loadFaqs = async () => {
        try {
            await getFaqs({ page: page + 1, per_page: rowsPerPage, search: search || undefined });
        } catch {
            showSnackbar({ type: 'error', message: 'Failed to load FAQs' });
        }
    };

    useEffect(() => {
        loadFaqs();
    }, [page, rowsPerPage, search]);

    const handleMenuOpen = (event, faq) => {
        setSelectedFaq(faq);
        setActionMenu(event.currentTarget);
    };

    const handleMenuClose = () => setActionMenu(null);

    const handleEdit = () => {
        setEditingFaq(selectedFaq);
        setOpenFormModal(true);
        handleMenuClose();
    };

    const handleCreate = () => {
        setEditingFaq(null);
        setOpenFormModal(true);
    };

    const handleFormModalClose = (refresh = false) => {
        setOpenFormModal(false);
        setEditingFaq(null);
        if (refresh) loadFaqs();
    };

    if (error) {
        return (
            <Box p={3}>
                <Alert severity="error" action={<Button color="inherit" size="small" onClick={() => { clearError(); loadFaqs(); }}>Retry</Button>}>
                    {error}
                </Alert>
            </Box>
        );
    }

    const faqList = Array.isArray(faqs) ? faqs : [];

    const FaqCard = ({ faq, index }) => (
        <Card sx={{ mb: 2, borderRadius: 2, border: `1px solid ${colors.middle}` }}>
            <CardContent sx={{ p: 2, '&:last-child': { pb: 2 }, backgroundColor: colors.light }}>
                <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 1.5 }}>
                    <Chip label={`#${index + 1}`} size="small" sx={{ backgroundColor: colors.wave, color: colors.sea }} />
                    <IconButton size="small" onClick={(e) => handleMenuOpen(e, faq)} sx={{ color: colors.rain }}>
                        <MoreVertIcon fontSize="small" />
                    </IconButton>
                </Box>
                <Typography variant="body1" fontWeight="medium" sx={{ mb: 0.5, color: colors.dark }}>
                    {faq.question}
                </Typography>
                <Box sx={{ display: 'flex', alignItems: 'flex-start', gap: 1, mb: 1 }}>
                    <DescriptionIcon fontSize="small" sx={{ color: colors.rain, mt: 0.2 }} />
                    <Typography variant="body2" sx={{ color: colors.black }}>
                        {faq.answer}
                    </Typography>
                </Box>
                <Divider sx={{ my: 1, borderColor: colors.middle }} />
                <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    <Chip label={`Order: ${faq.order || 0}`} size="small" variant="outlined" sx={{ borderColor: colors.middle, color: colors.rain }} />
                    <Chip label={`Created: ${faq.created_at ? new Date(faq.created_at).toLocaleDateString() : 'N/A'}`} size="small" variant="outlined" sx={{ borderColor: colors.middle, color: colors.rain }} />
                </Box>
            </CardContent>
        </Card>
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
                            FAQs
                        </Typography>
                        {canCreate && (
                            <Button variant="contained" startIcon={<AddIcon />} onClick={handleCreate}
                                    size={isMobile ? 'small' : 'medium'}
                                    sx={{ borderRadius: 2, backgroundColor: colors.salat, '&:hover': { backgroundColor: colors.dark } }}>
                                Add FAQ
                            </Button>
                        )}
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
                        <Button variant="outlined" startIcon={<RefreshIcon />} onClick={loadFaqs}
                                size={isMobile ? 'small' : 'medium'}
                                sx={{ borderColor: colors.middle, color: colors.sea, '&:hover': { borderColor: colors.sea, backgroundColor: colors.wave } }}>
                            Refresh
                        </Button>
                    </Box>
                </Box>

                {showTableView ? (
                    <TableContainer sx={{ width: '100%', overflowX: 'auto' }}>
                        <Table sx={{ width: '100%', minWidth: 800 }}>
                            <TableHead>
                                <TableRow sx={{ backgroundColor: colors.sky }}>
                                    {headCells.map((cell) => (
                                        <TableCell key={cell.id} sx={{ fontWeight: 'bold', color: colors.dark }}>
                                            {cell.label}
                                        </TableCell>
                                    ))}
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {loading ? (
                                    <TableRow>
                                        <TableCell colSpan={4} align="center">
                                            <CircularProgress size={32} sx={{ color: colors.sea, my: 3 }} />
                                        </TableCell>
                                    </TableRow>
                                ) : faqList.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={4} align="center">
                                            <Typography sx={{ py: 3, color: colors.rain }}>No FAQs found</Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    faqList.map((faq, index) => (
                                        <TableRow key={faq.id} hover>
                                            <TableCell>{index + 1}</TableCell>
                                            <TableCell sx={{ color: colors.black }}>{faq.question}</TableCell>
                                            <TableCell sx={{ maxWidth: 300, wordBreak: 'break-word', color: colors.black }}>
                                                {faq.answer}
                                            </TableCell>
                                            <TableCell align="center">
                                                <IconButton size="small" onClick={(e) => handleMenuOpen(e, faq)} sx={{ color: colors.rain }}>
                                                    <MoreVertIcon />
                                                </IconButton>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                ) : (
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        {loading ? (
                            <Box display="flex" justifyContent="center" py={4}>
                                <CircularProgress sx={{ color: colors.sea }} />
                            </Box>
                        ) : faqList.length === 0 ? (
                            <Paper variant="outlined" sx={{ p: 4, textAlign: 'center', borderColor: colors.middle }}>
                                <Typography sx={{ color: colors.rain }}>No FAQs found</Typography>
                            </Paper>
                        ) : (
                            faqList.map((faq, index) => <FaqCard key={faq.id} faq={faq} index={index} />)
                        )}
                    </Box>
                )}

                <Box sx={{ borderTop: `1px solid ${colors.middle}`, py: { xs: 1, sm: 0 } }}>
                    <TablePagination
                        rowsPerPageOptions={[5, 10, 25, 50]}
                        component="div"
                        count={faqList.length}
                        rowsPerPage={rowsPerPage}
                        page={page}
                        onPageChange={(e, newPage) => setPage(newPage)}
                        onRowsPerPageChange={(e) => {
                            setRowsPerPage(parseInt(e.target.value, 10));
                            setPage(0);
                        }}
                        sx={{
                            '.MuiTablePagination-selectLabel, .MuiTablePagination-displayedRows': {
                                fontSize: { xs: '0.75rem', sm: '0.875rem' },
                                color: colors.black,
                            },
                            '.MuiTablePagination-actions': { color: colors.sea }
                        }}
                    />
                </Box>
            </Paper>

            <Menu
                anchorEl={actionMenu}
                open={Boolean(actionMenu)}
                onClose={handleMenuClose}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                transformOrigin={{ vertical: 'top', horizontal: 'right' }}
            >
                {canEdit && (
                    <MenuItem onClick={handleEdit} sx={{ color: colors.sea }}>
                        <EditIcon sx={{ mr: 1, fontSize: 20 }} /> Edit
                    </MenuItem>
                )}
            </Menu>

            <FaqFormModal
                open={openFormModal}
                onClose={handleFormModalClose}
                faq={editingFaq}
                createFaq={createFaq}
                updateFaq={updateFaq}
            />
        </Box>
    );
};

export default FaqList;