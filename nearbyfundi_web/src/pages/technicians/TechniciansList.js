// src/pages/technicians/TechniciansList.js
import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Button,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TablePagination,
    TableSortLabel,
    TextField,
    InputAdornment,
    useMediaQuery,
    useTheme,
    Card,
    CardContent,
    Divider,
    Avatar,
    CircularProgress,
    Alert,
} from '@mui/material';
import {
    Search as SearchIcon,
    People as PeopleIcon,
    LocationOn as LocationIcon,
    Star as StarIcon,
    CheckCircle as VerifiedIcon,
} from '@mui/icons-material';
import { technicianService } from 'services/technician.service';
import { usePermissions } from 'hooks/usePermissions';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const headCells = [
    { id: 'name', label: 'Technician' },
    { id: 'services', label: 'Services' },
    { id: 'area', label: 'Location' },
    { id: 'rating', label: 'Rating' },
];

const TechniciansList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const showTableView = useMediaQuery(theme.breakpoints.up('md'));

    const [technicians, setTechnicians] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [pagination, setPagination] = useState({ total: 0, per_page: 10, current_page: 1, last_page: 1 });
    const { can } = usePermissions();

    const [search, setSearch] = useState('');
    const [serviceFilter, setServiceFilter] = useState('');
    const [order, setOrder] = useState('asc');
    const [orderBy, setOrderBy] = useState('name');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);

    const canView = can('technicians.view');

    const loadTechnicians = async () => {
        if (!canView) return;

        setLoading(true);
        setError(null);
        try {
            const response = await technicianService.getTechnicians({
                page: page + 1,
                per_page: rowsPerPage,
                search: search || undefined,
                service_id: serviceFilter || undefined,
            });

            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    setTechnicians(data.data);
                    setPagination({
                        total: data.total || 0,
                        per_page: data.per_page || rowsPerPage,
                        current_page: data.current_page || 1,
                        last_page: data.last_page || 1,
                    });
                } else if (Array.isArray(data)) {
                    setTechnicians(data);
                    setPagination({ total: data.length, per_page: rowsPerPage, current_page: 1, last_page: 1 });
                } else {
                    setTechnicians([]);
                }
            } else {
                setTechnicians([]);
            }
        } catch (err) {
            console.error('Technicians error:', err);
            setError(err.message || 'Failed to load technicians');
        } finally {
            setLoading(false);
        }
    };

    // Auto-load when filters change
    useEffect(() => {
        if (canView) {
            loadTechnicians();
        }
    }, [page, rowsPerPage, search, serviceFilter, canView]);

    const handleRequestSort = (property) => {
        const isAsc = orderBy === property && order === 'asc';
        setOrder(isAsc ? 'desc' : 'asc');
        setOrderBy(property);
    };

    const getServiceCount = (technician) => {
        if (!technician.services || !Array.isArray(technician.services)) {
            return 0;
        }
        return technician.services.length;
    };

    const sortData = (data) => {
        if (!data) return [];
        const sorted = [...data];
        sorted.sort((a, b) => {
            let aValue, bValue;

            switch (orderBy) {
                case 'name':
                    aValue = a.name || '';
                    bValue = b.name || '';
                    break;
                case 'area':
                    aValue = a.area || '';
                    bValue = b.area || '';
                    break;
                case 'rating':
                    aValue = a.rating || 0;
                    bValue = b.rating || 0;
                    break;
                default:
                    aValue = a[orderBy] || '';
                    bValue = b[orderBy] || '';
            }

            if (typeof aValue === 'string') {
                aValue = aValue.toLowerCase();
                bValue = bValue.toLowerCase();
            }

            if (aValue < bValue) return order === 'asc' ? -1 : 1;
            if (aValue > bValue) return order === 'asc' ? 1 : -1;
            return 0;
        });
        return sorted;
    };

    if (!canView) {
        return (
            <Box p={3}>
                <Paper sx={{ p: 3, textAlign: 'center', backgroundColor: colors.light }}>
                    <Typography color="error">You do not have permission to view technicians.</Typography>
                </Paper>
            </Box>
        );
    }

    if (error) {
        return (
            <Box p={3}>
                <Alert severity="error">
                    {error}
                </Alert>
            </Box>
        );
    }

    const currentData = Array.isArray(technicians) ? technicians : [];
    const sortedData = sortData(currentData);

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
                {/* Header Section */}
                <Box sx={{ p: { xs: 2, sm: 3 }, borderBottom: `1px solid ${colors.middle}` }}>
                    <Box display="flex" justifyContent="space-between" alignItems="center" mb={2} flexWrap="wrap" gap={1}>
                        <Typography variant="h5" fontWeight="600" sx={{ fontSize: { xs: '1.5rem', sm: '1.75rem' }, color: colors.dark }}>
                            Technicians
                        </Typography>
                    </Box>

                    {/* Filters */}
                    <Box display="flex" gap={2} flexWrap="wrap" alignItems="center">
                        <TextField
                            label="Search Technicians"
                            size="small"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            InputProps={{
                                startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>
                            }}
                            sx={{
                                minWidth: { xs: '100%', sm: 200 },
                                flexGrow: { xs: 1, sm: 0 },
                                '& .MuiInputBase-root': {
                                    backgroundColor: colors.sky,
                                    borderRadius: 2,
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle,
                                },
                            }}
                        />
                        <TextField
                            label="Filter by Service"
                            size="small"
                            value={serviceFilter}
                            onChange={(e) => setServiceFilter(e.target.value)}
                            placeholder="Service name or ID"
                            sx={{
                                minWidth: { xs: '100%', sm: 180 },
                                flexGrow: { xs: 1, sm: 0 },
                                '& .MuiInputBase-root': {
                                    backgroundColor: colors.sky,
                                    borderRadius: 2,
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle,
                                },
                            }}
                        />
                    </Box>
                </Box>

                {/* Table View (Desktop) */}
                {showTableView ? (
                    <TableContainer sx={{ width: '100%', overflowX: 'auto' }}>
                        <Table sx={{ width: '100%', minWidth: 600 }}>
                            <TableHead>
                                <TableRow sx={{ backgroundColor: colors.sky }}>
                                    {headCells.map((cell) => (
                                        <TableCell key={cell.id} sx={{ fontWeight: 'bold', color: colors.dark, whiteSpace: 'nowrap' }}>
                                            <TableSortLabel
                                                active={orderBy === cell.id}
                                                direction={orderBy === cell.id ? order : 'asc'}
                                                onClick={() => handleRequestSort(cell.id)}
                                                sx={{ color: colors.dark }}
                                            >
                                                {cell.label}
                                            </TableSortLabel>
                                        </TableCell>
                                    ))}
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {loading ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center">
                                            <CircularProgress size={32} sx={{ color: colors.sea, my: 3 }} />
                                        </TableCell>
                                    </TableRow>
                                ) : sortedData.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={headCells.length} align="center">
                                            <Typography sx={{ py: 3, color: colors.rain }}>
                                                No technicians found
                                            </Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sortedData.map((technician) => (
                                        <TableRow key={technician.id} hover>
                                            <TableCell>
                                                <Box display="flex" alignItems="center" gap={2}>
                                                    <Avatar
                                                        src={technician.profile_photo || undefined}
                                                        sx={{ width: 40, height: 40, bgcolor: colors.sea }}
                                                    >
                                                        {technician.name?.charAt(0).toUpperCase() || 'T'}
                                                    </Avatar>
                                                    <Box>
                                                        <Box display="flex" alignItems="center" gap={1}>
                                                            <Typography variant="body2" fontWeight="medium" sx={{ color: colors.dark }}>
                                                                {technician.name || 'Unknown'}
                                                            </Typography>
                                                            {technician.verified && (
                                                                <VerifiedIcon sx={{ fontSize: 16, color: colors.salat }} />
                                                            )}
                                                        </Box>
                                                        <Typography variant="caption" sx={{ color: colors.rain }}>
                                                            {technician.email || ''}
                                                        </Typography>
                                                    </Box>
                                                </Box>
                                            </TableCell>
                                            <TableCell>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <PeopleIcon fontSize="small" sx={{ color: colors.rain }} />
                                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                                        {getServiceCount(technician)} service{getServiceCount(technician) !== 1 ? 's' : ''}
                                                    </Typography>
                                                </Box>
                                                {technician.services && technician.services.length > 0 && (
                                                    <Typography variant="caption" sx={{ color: colors.rain }} display="block" mt={0.5}>
                                                        {technician.services.slice(0, 2).join(', ')}
                                                        {technician.services.length > 2 && ` +${technician.services.length - 2} more`}
                                                    </Typography>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <LocationIcon fontSize="small" sx={{ color: colors.rain }} />
                                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                                        {technician.area || 'N/A'}
                                                    </Typography>
                                                </Box>
                                                {technician.experience !== undefined && technician.experience !== null && (
                                                    <Typography variant="caption" sx={{ color: colors.rain }} display="block">
                                                        {technician.experience} yrs experience
                                                    </Typography>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                {technician.rating !== undefined && technician.rating !== null ? (
                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                        <StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />
                                                        <Typography variant="body2" fontWeight="medium" sx={{ color: colors.dark }}>
                                                            {technician.rating.toFixed(1)}
                                                        </Typography>
                                                        {technician.hourly_rate && (
                                                            <Typography variant="caption" sx={{ color: colors.rain }} ml={1}>
                                                                ${technician.hourly_rate}/hr
                                                            </Typography>
                                                        )}
                                                    </Box>
                                                ) : (
                                                    <Typography variant="body2" sx={{ color: colors.rain }}>
                                                        No rating
                                                    </Typography>
                                                )}
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                ) : (
                    // Mobile Card View
                    <Box sx={{ p: { xs: 2, sm: 3 } }}>
                        {loading ? (
                            <Box display="flex" justifyContent="center" py={4}>
                                <CircularProgress sx={{ color: colors.sea }} />
                            </Box>
                        ) : sortedData.length === 0 ? (
                            <Paper variant="outlined" sx={{ p: 4, textAlign: 'center', borderColor: colors.middle }}>
                                <Typography sx={{ color: colors.rain }}>
                                    No technicians found
                                </Typography>
                            </Paper>
                        ) : (
                            sortedData.map((technician) => (
                                <Card key={technician.id} sx={{
                                    mb: 2,
                                    borderRadius: 2,
                                    border: `1px solid ${colors.middle}`,
                                }}>
                                    <CardContent sx={{ p: 2 }}>
                                        <Box display="flex" alignItems="center" gap={2} mb={1.5}>
                                            <Avatar
                                                src={technician.profile_photo || undefined}
                                                sx={{ width: 48, height: 48, bgcolor: colors.sea }}
                                            >
                                                {technician.name?.charAt(0).toUpperCase() || 'T'}
                                            </Avatar>
                                            <Box>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <Typography variant="h6" fontSize="1rem" fontWeight="medium" sx={{ color: colors.dark }}>
                                                        {technician.name || 'Unknown'}
                                                    </Typography>
                                                    {technician.verified && (
                                                        <VerifiedIcon sx={{ fontSize: 16, color: colors.salat }} />
                                                    )}
                                                </Box>
                                                <Typography variant="caption" sx={{ color: colors.rain }}>
                                                    {technician.email || ''}
                                                </Typography>
                                            </Box>
                                        </Box>

                                        <Box display="flex" alignItems="center" gap={1} mb={1}>
                                            <LocationIcon fontSize="small" sx={{ color: colors.rain }} />
                                            <Typography variant="body2" sx={{ color: colors.black }}>
                                                {technician.area || 'N/A'}
                                            </Typography>
                                        </Box>

                                        <Box display="flex" alignItems="center" gap={2} mb={1}>
                                            <Box display="flex" alignItems="center" gap={0.5}>
                                                <PeopleIcon fontSize="small" sx={{ color: colors.rain }} />
                                                <Typography variant="body2" sx={{ color: colors.black }}>
                                                    {getServiceCount(technician)} services
                                                </Typography>
                                            </Box>
                                            {technician.rating !== undefined && technician.rating !== null && (
                                                <Box display="flex" alignItems="center" gap={0.5}>
                                                    <StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />
                                                    <Typography variant="body2" fontWeight="medium" sx={{ color: colors.dark }}>
                                                        {technician.rating.toFixed(1)}
                                                    </Typography>
                                                </Box>
                                            )}
                                            {technician.hourly_rate && (
                                                <Typography variant="body2" sx={{ color: colors.rain }}>
                                                    ${technician.hourly_rate}/hr
                                                </Typography>
                                            )}
                                        </Box>

                                        {technician.services && technician.services.length > 0 && (
                                            <>
                                                <Divider sx={{ my: 1, borderColor: colors.middle }} />
                                                <Typography variant="caption" sx={{ color: colors.rain }} display="block">
                                                    Services: {technician.services.join(', ')}
                                                </Typography>
                                            </>
                                        )}
                                    </CardContent>
                                </Card>
                            ))
                        )}
                    </Box>
                )}

                {/* Pagination */}
                <Box sx={{ borderTop: `1px solid ${colors.middle}`, py: { xs: 1, sm: 0 } }}>
                    <TablePagination
                        rowsPerPageOptions={[5, 10, 25, 50]}
                        component="div"
                        count={pagination.total || 0}
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
                            '.MuiTablePagination-actions': {
                                color: colors.sea,
                            },
                        }}
                    />
                </Box>
            </Paper>
        </Box>
    );
};

export default TechniciansList;