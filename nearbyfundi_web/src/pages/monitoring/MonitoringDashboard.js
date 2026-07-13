// src/pages/monitoring/MonitoringDashboard.jsx
import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
    Box,
    Paper,
    Typography,
    Grid,
    Card,
    CardContent,
    Chip,
    IconButton,
    Button,
    TextField,
    InputAdornment,
    CircularProgress,
    Alert,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Avatar,
    Divider,
    Tooltip,
    LinearProgress,
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    useMediaQuery,
    useTheme,
    Drawer,
    Fab,
    Snackbar,
    Zoom,
    Pagination,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    Search as SearchIcon,
    Phone as PhoneIcon,
    WhatsApp as WhatsAppIcon,
    Person as PersonIcon,
    Build as BuildIcon,
    CheckCircle as CheckCircleIcon,
    Cancel as CancelIcon,
    Pending as PendingIcon,
    HourglassEmpty as HourglassIcon,
    Warning as WarningIcon,
    View as ViewIcon,
    Close as CloseIcon,
    Check as CheckIcon,
    MyLocation as RecenterIcon,
    ArrowUpward as ArrowUpwardIcon,
} from '@mui/icons-material';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useMonitoring } from 'context/MonitoringContext';
import { usePermissions } from 'hooks';
import { format, isToday } from 'date-fns';
import { NotificationBell } from './components/NotificationBell';

// ===== CONSTANTS =====
const COLORS = {
    primary: '#1a73e8',
    success: '#34a853',
    warning: '#fbbc04',
    error: '#ea4335',
    grey: '#9aa0a6',
    light: '#f8f9fa',
    dark: '#202124',
};

const RED = '#ea4335';
const GREEN = '#22c55e';
const DAR_ES_SALAAM = [-6.7924, 39.2083];

// ===== CSS STYLES =====
const pulseStyles = `
    @keyframes pulseRed {
        0% { box-shadow: 0 0 0 0 rgba(234, 67, 53, 0.7); }
        70% { box-shadow: 0 0 0 16px rgba(234, 67, 53, 0); }
        100% { box-shadow: 0 0 0 0 rgba(234, 67, 53, 0); }
    }
    @keyframes pulse {
        0% { opacity: 1; }
        50% { opacity: 0.5; }
        100% { opacity: 1; }
    }
    .leaflet-container { 
        width: 100% !important; 
        height: 100% !important; 
    }
`;

// ===== MAP MARKER ICON =====
const createIcon = (status, isTimeout) => {
    const color = status === 'accepted' ? GREEN : RED;
    const size = isTimeout ? 36 : 30;
    return L.divIcon({
        className: 'monitoring-marker',
        html: `<div style="
            background-color:${color};
            width:${size}px;height:${size};border-radius:50%;
            display:flex;align-items:center;justify-content:center;
            border:3px solid white;color:white;font-size:15px;
            box-shadow:0 2px 10px rgba(0,0,0,0.35);
            animation:${isTimeout ? 'pulseRed 1.8s infinite' : 'none'};
        ">${isTimeout ? '⚠️' : status === 'accepted' ? '✅' : '🔧'}</div>`,
        iconSize: [size, size],
        iconAnchor: [size / 2, size / 2],
        popupAnchor: [0, -size / 2],
    });
};

// ===== STATUS CHIP HELPER =====
const StatusChip = ({ status, isTimeout }) => {
    const statusMap = {
        'pending': { color: 'warning', icon: <PendingIcon sx={{ fontSize: 16 }} />, label: 'Pending' },
        'accepted': { color: 'success', icon: <CheckCircleIcon sx={{ fontSize: 16 }} />, label: 'Accepted' },
        'rejected': { color: 'error', icon: <CancelIcon sx={{ fontSize: 16 }} />, label: 'Rejected' },
        'cancelled': { color: 'default', icon: <CancelIcon sx={{ fontSize: 16 }} />, label: 'Cancelled' },
        'in_progress': { color: 'info', icon: <HourglassIcon sx={{ fontSize: 16 }} />, label: 'In Progress' },
        'completed': { color: 'success', icon: <CheckCircleIcon sx={{ fontSize: 16 }} />, label: 'Completed' },
    };
    const config = statusMap[status] || statusMap['pending'];

    if (isTimeout) {
        return (
            <Chip
                icon={<WarningIcon sx={{ fontSize: 16 }} />}
                label="Timeout"
                size="small"
                sx={{
                    backgroundColor: '#fee2e2',
                    color: '#991b1b',
                    borderColor: '#fca5a5',
                    fontWeight: 'bold',
                    animation: 'pulse 2s infinite',
                }}
            />
        );
    }

    return (
        <Chip
            icon={config.icon}
            label={config.label}
            size="small"
            sx={{
                backgroundColor: config.color === 'warning' ? '#fef3c7' :
                    config.color === 'success' ? '#d1fae5' :
                        config.color === 'error' ? '#fee2e2' :
                            config.color === 'info' ? '#dbeafe' :
                                '#f3f4f6',
                color: config.color === 'warning' ? '#92400e' :
                    config.color === 'success' ? '#065f46' :
                        config.color === 'error' ? '#991b1b' :
                            config.color === 'info' ? '#1e40af' :
                                '#374151',
            }}
        />
    );
};

// ===== DATE FORMATTER =====
const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    try {
        return format(new Date(dateStr), 'MMM d, HH:mm');
    } catch {
        return '-';
    }
};

// ===== MAIN COMPONENT =====
const MonitoringDashboard = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const { can } = usePermissions();

    const canView = can('monitoring.view');
    const canCallTechnician = can('technicians.call');
    const canUpdateStatus = can('requests.status.update');

    // ===== CONTEXT =====
    const {
        dashboard,
        requests,
        technicians,
        loading,
        error,
        notifications,
        pagination,
        filters,
        setFilters,
        autoRefresh,
        setAutoRefresh,
        loadDashboard,
        loadRequests,
        updateRequestStatus,
        callTechnician,
        fetchNotifications,
    } = useMonitoring();

    // ===== LOCAL STATE =====
    const [selectedRequest, setSelectedRequest] = useState(null);
    const [openDetailDialog, setOpenDetailDialog] = useState(false);
    const [openStatusDialog, setOpenStatusDialog] = useState(false);
    const [selectedTechnician, setSelectedTechnician] = useState(null);
    const [statusAction, setStatusAction] = useState({ id: null, status: '', notes: '' });
    const [selectedMarker, setSelectedMarker] = useState(null);
    const [mapFilter, setMapFilter] = useState('all');
    const [toast, setToast] = useState(null);
    const [actionLoading, setActionLoading] = useState(false);
    const [showScrollTop, setShowScrollTop] = useState(false);

    const mapRef = useRef(null);
    const pageRef = useRef(null);

    // ===== DERIVED DATA =====
    const todayRequests = requests.filter(r => {
        if (!r.created_at) return false;
        return isToday(new Date(r.created_at));
    });

    const todayStats = {
        total: todayRequests.length,
        pending: todayRequests.filter(r => r.status === 'pending').length,
        accepted: todayRequests.filter(r => r.status === 'accepted').length,
        timeout: todayRequests.filter(r => r.is_timeout).length,
        completed: todayRequests.filter(r => r.status === 'completed').length,
        inProgress: todayRequests.filter(r => r.status === 'in_progress').length,
        rejected: todayRequests.filter(r => r.status === 'rejected').length,
    };

    const mapRequests = todayRequests
        .filter(r => {
            if (mapFilter === 'pending') return r.status === 'pending';
            if (mapFilter === 'accepted') return r.status === 'accepted';
            return r.status === 'pending' || r.status === 'accepted';
        })
        .filter(r => r.latitude && r.longitude);

    // ===== EFFECTS =====
    useEffect(() => {
        if (autoRefresh) {
            const interval = setInterval(() => {
                loadDashboard();
                loadRequests();
                fetchNotifications();
            }, 30000);
            return () => clearInterval(interval);
        }
    }, [autoRefresh, loadDashboard, loadRequests, fetchNotifications]);

    useEffect(() => {
        const handleScroll = () => {
            setShowScrollTop(window.scrollY > 400);
        };
        window.addEventListener('scroll', handleScroll);
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    // ===== HANDLERS =====
    const handleScrollToTop = () => {
        if (pageRef.current) {
            pageRef.current.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
        window.scrollTo({ top: 0, behavior: 'smooth' });
    };

    const handlePageChange = (event, newPage) => {
        loadRequests(newPage);
    };

    const handleFilterChange = (key, value) => {
        setFilters(prev => ({ ...prev, [key]: value }));
        loadRequests(1);
    };

    const handleStatusUpdate = async () => {
        if (!canUpdateStatus) return;
        if (!statusAction.id || !statusAction.status) return;
        try {
            await updateRequestStatus(statusAction.id, statusAction.status, statusAction.notes);
            setOpenStatusDialog(false);
            setStatusAction({ id: null, status: '', notes: '' });
            loadRequests();
            loadDashboard();
            setToast({ severity: 'success', message: 'Status updated successfully' });
        } catch (error) {
            setToast({ severity: 'error', message: 'Failed to update status' });
        }
    };

    const handleCallTechnician = async (technicianId, requestId) => {
        if (!canCallTechnician) return;
        try {
            const data = await callTechnician(technicianId, requestId);
            if (data.phone_number) {
                setSelectedTechnician(data);
            }
        } catch (error) {
            setToast({ severity: 'error', message: 'Failed to get call details' });
        }
    };

    const handleAccept = async (id) => {
        if (!canUpdateStatus) return;
        setActionLoading(true);
        try {
            await updateRequestStatus(id, 'accepted', 'Accepted from map');
            setToast({ severity: 'success', message: `Request #${id} accepted` });
            setSelectedMarker(null);
            loadRequests();
            loadDashboard();
        } catch (err) {
            setToast({ severity: 'error', message: 'Failed to accept' });
        } finally {
            setActionLoading(false);
        }
    };

    const handleReject = async (id) => {
        if (!canUpdateStatus) return;
        setActionLoading(true);
        try {
            await updateRequestStatus(id, 'rejected', 'Rejected from map');
            setToast({ severity: 'success', message: `Request #${id} rejected` });
            setSelectedMarker(null);
            loadRequests();
            loadDashboard();
        } catch (err) {
            setToast({ severity: 'error', message: 'Failed to reject' });
        } finally {
            setActionLoading(false);
        }
    };

    const handleRecenter = () => {
        const map = mapRef.current;
        if (!map) return;

        if (mapRequests.length > 0) {
            const bounds = L.latLngBounds(mapRequests.map((r) => [r.latitude, r.longitude]));
            map.flyToBounds(bounds, { padding: [60, 60], maxZoom: 15, duration: 0.75 });
        } else {
            map.flyTo(DAR_ES_SALAAM, 13, { duration: 0.75 });
        }
    };

    const handleNotificationClick = (notification) => {
        if (notification?.viewAll) {
            window.scrollTo({ top: 400, behavior: 'smooth' });
            return;
        }

        const request = todayRequests.find(r => r.id === notification?.request_id);
        if (request) {
            setSelectedRequest(request);
            setOpenDetailDialog(true);
        }
    };

    const clearFilters = () => {
        setFilters({
            status: '',
            search: '',
            date_from: '',
            date_to: '',
            sort_by: 'created_at',
            sort_order: 'desc',
        });
        setMapFilter('all');
        loadRequests(1);
    };

    // ===== PERMISSION CHECK =====
    if (!canView) {
        return (
            <Box p={3}>
                <Paper sx={{ p: 3, textAlign: 'center', backgroundColor: COLORS.light }}>
                    <Typography color="error">
                        You do not have permission to view the monitoring dashboard.
                    </Typography>
                </Paper>
            </Box>
        );
    }

    if (loading && !dashboard) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="80vh">
                <CircularProgress />
            </Box>
        );
    }

    const mapCenter = mapRequests.length > 0
        ? [mapRequests[0].latitude, mapRequests[0].longitude]
        : DAR_ES_SALAAM;

    // ===== STATS CARDS =====
    const statsCards = [
        { label: "Today's Requests", value: todayStats.total, color: '#3b82f6', icon: <BuildIcon /> },
        { label: 'Pending', value: todayStats.pending, color: '#f59e0b', icon: <PendingIcon /> },
        { label: '⚠️ Timeout', value: todayStats.timeout, color: '#ef4444', icon: <WarningIcon /> },
        { label: 'Accepted', value: todayStats.accepted, color: '#10b981', icon: <CheckCircleIcon /> },
        { label: 'In Progress', value: todayStats.inProgress, color: '#8b5cf6', icon: <HourglassIcon /> },
        { label: 'Completed', value: todayStats.completed, color: '#22c55e', icon: <CheckCircleIcon /> },
    ];

    // ===== RENDER =====
    return (
        <Box
            ref={pageRef}
            sx={{
                width: '100%',
                p: { xs: 1, sm: 2, md: 3 },
                bgcolor: '#f5f5f5',
                minHeight: '100vh',
                position: 'relative'
            }}
        >
            <style>{pulseStyles}</style>

            {/* ===== HEADER ===== */}
            <Paper sx={{ p: 3, mb: 3, borderRadius: 2, bgcolor: COLORS.dark, color: 'white' }}>
                <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={2}>
                    <Box display="flex" alignItems="center" gap={2}>
                        <Typography variant="h5" fontWeight="bold">
                            📊 Monitoring Dashboard
                        </Typography>
                    </Box>
                    <Box display="flex" gap={2} alignItems="center">
                        <NotificationBell onNotificationClick={handleNotificationClick} />
                        <Chip
                            label={autoRefresh ? '🔄 Auto-refresh ON' : '⏸️ Auto-refresh OFF'}
                            color={autoRefresh ? 'success' : 'default'}
                            onClick={() => setAutoRefresh(!autoRefresh)}
                            sx={{
                                color: 'white',
                                '& .MuiChip-label': { color: 'white' },
                                bgcolor: autoRefresh ? 'rgba(52, 168, 83, 0.3)' : 'rgba(255,255,255,0.1)',
                            }}
                        />
                        <Button
                            variant="contained"
                            startIcon={<RefreshIcon />}
                            onClick={() => {
                                loadDashboard();
                                loadRequests();
                                fetchNotifications();
                            }}
                            sx={{ bgcolor: 'rgba(255,255,255,0.2)', '&:hover': { bgcolor: 'rgba(255,255,255,0.3)' } }}
                        >
                            Refresh
                        </Button>
                    </Box>
                </Box>
                <Typography variant="body2" sx={{ opacity: 0.8, mt: 1 }}>
                    Today: {format(new Date(), 'EEEE, MMMM d, yyyy')} • {todayStats.total} requests today
                </Typography>
            </Paper>

            {/* ===== STATS CARDS ===== */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                {statsCards.map((stat, index) => (
                    <Grid item xs={6} sm={4} md={2} key={index}>
                        <Card sx={{
                            borderRadius: 2,
                            border: `1px solid ${stat.color}20`,
                            position: 'relative',
                            overflow: 'hidden',
                        }}>
                            <Box sx={{
                                position: 'absolute',
                                top: 0,
                                right: 0,
                                width: 60,
                                height: 60,
                                bgcolor: stat.color + '10',
                                borderRadius: '0 0 0 60px',
                            }} />
                            <CardContent>
                                <Box display="flex" alignItems="center" gap={1}>
                                    <Box sx={{ color: stat.color }}>{stat.icon}</Box>
                                    <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                        {stat.label}
                                    </Typography>
                                </Box>
                                <Typography variant="h4" fontWeight="bold" sx={{ mt: 1, color: stat.color }}>
                                    {stat.value}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                ))}
            </Grid>

            {/* ===== ALERTS ===== */}
            {notifications && notifications.length > 0 && (
                <Paper sx={{ p: 2, mb: 3, bgcolor: '#fffbeb', border: '1px solid #fcd34d' }}>
                    <Typography variant="subtitle2" color="#92400e" gutterBottom>
                        🔔 Alerts ({notifications.length})
                    </Typography>
                    <Box display="flex" flexWrap="wrap" gap={1}>
                        {notifications.slice(0, 5).map((note, index) => (
                            <Chip
                                key={index}
                                icon={note.is_timeout ? <WarningIcon /> : <CheckIcon />}
                                label={
                                    note.is_timeout
                                        ? `⚠️ #${note.request_id} - ${note.minutes_elapsed}m waiting`
                                        : `📌 #${note.request_id} - ${note.customer_name}`
                                }
                                color={note.is_timeout ? 'error' : 'info'}
                                size="small"
                                onClick={() => {
                                    setSelectedRequest({ id: note.request_id });
                                    setOpenDetailDialog(true);
                                }}
                            />
                        ))}
                    </Box>
                </Paper>
            )}

            {/* ===== FILTERS ===== */}
            <Paper sx={{ p: 2, mb: 3, borderRadius: 2 }}>
                <Grid container spacing={2} alignItems="center">
                    <Grid item xs={12} sm={3}>
                        <TextField
                            fullWidth
                            size="small"
                            placeholder="Search today's requests..."
                            value={filters.search}
                            onChange={(e) => handleFilterChange('search', e.target.value)}
                            InputProps={{
                                startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>,
                            }}
                        />
                    </Grid>
                    <Grid item xs={6} sm={2}>
                        <FormControl fullWidth size="small">
                            <InputLabel>Status</InputLabel>
                            <Select
                                value={filters.status}
                                label="Status"
                                onChange={(e) => handleFilterChange('status', e.target.value)}
                            >
                                <MenuItem value="">All</MenuItem>
                                <MenuItem value="pending">Pending</MenuItem>
                                <MenuItem value="timeout">⚠️ Timeout</MenuItem>
                                <MenuItem value="accepted">Accepted</MenuItem>
                                <MenuItem value="rejected">Rejected</MenuItem>
                                <MenuItem value="in_progress">In Progress</MenuItem>
                                <MenuItem value="completed">Completed</MenuItem>
                            </Select>
                        </FormControl>
                    </Grid>
                    <Grid item xs={6} sm={2}>
                        <FormControl fullWidth size="small">
                            <InputLabel>Map Filter</InputLabel>
                            <Select
                                value={mapFilter}
                                label="Map Filter"
                                onChange={(e) => setMapFilter(e.target.value)}
                            >
                                <MenuItem value="all">All</MenuItem>
                                <MenuItem value="pending">🔴 Pending</MenuItem>
                                <MenuItem value="accepted">🟢 Accepted</MenuItem>
                            </Select>
                        </FormControl>
                    </Grid>
                    <Grid item xs={6} sm={3}>
                        <Typography variant="caption" color="text.secondary">
                            Showing {todayRequests.length} requests today • {mapRequests.length} on map
                        </Typography>
                    </Grid>
                    <Grid item xs={6} sm={2}>
                        <Button fullWidth variant="outlined" onClick={clearFilters}>
                            Clear Filters
                        </Button>
                    </Grid>
                </Grid>
            </Paper>

            {/* ===== MAP SECTION ===== */}
            <Grid container spacing={3}>
                <Grid item xs={12}>
                    <Paper sx={{
                        borderRadius: 2,
                        overflow: 'hidden',
                        height: { xs: 400, sm: 500, md: 600 },
                        position: 'relative',
                    }}>
                        <Box sx={{
                            p: 2,
                            borderBottom: '1px solid #e5e7eb',
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            flexWrap: 'wrap',
                            gap: 1,
                            bgcolor: 'white',
                        }}>
                            <Typography variant="h6" fontWeight="bold">
                                🗺️ Today's Requests
                            </Typography>
                            <Box display="flex" gap={1} flexWrap="wrap">
                                <Chip label={`${todayStats.pending} Pending`} color="warning" size="small" />
                                <Chip label={`${todayStats.accepted} Accepted`} color="success" size="small" />
                                {todayStats.timeout > 0 && (
                                    <Chip label={`⚠️ ${todayStats.timeout} Timeout`} color="error" size="small" />
                                )}
                            </Box>
                        </Box>
                        <Box sx={{
                            height: { xs: 330, sm: 420, md: 520 },
                            width: '100%',
                            position: 'relative',
                        }}>
                            {loading ? (
                                <Box display="flex" justifyContent="center" alignItems="center" height="100%">
                                    <CircularProgress />
                                </Box>
                            ) : (
                                <MapContainer
                                    center={mapCenter}
                                    zoom={13}
                                    style={{ height: '100%', width: '100%' }}
                                    whenCreated={(map) => { mapRef.current = map; }}
                                >
                                    <TileLayer
                                        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                                        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                                    />
                                    {mapRequests.map((r) => (
                                        <Marker
                                            key={r.id}
                                            position={[r.latitude, r.longitude]}
                                            icon={createIcon(r.status, r.is_timeout)}
                                            eventHandlers={{ click: () => setSelectedMarker(r) }}
                                        >
                                            <Popup>
                                                <Typography variant="subtitle2" fontWeight="bold">
                                                    #{r.id} · {r.customer?.name || 'Unknown'}
                                                </Typography>
                                                <Typography variant="caption" color="text.secondary" display="block">
                                                    {r.service?.name || 'Service'} · {r.status}
                                                    {r.is_timeout ? ` · ⚠️ ${r.minutes_elapsed}m waiting` : ''}
                                                </Typography>
                                            </Popup>
                                        </Marker>
                                    ))}
                                </MapContainer>
                            )}

                            {/* Recenter Button */}
                            <Tooltip title="Recenter map" placement="left">
                                <Fab
                                    size="small"
                                    onClick={handleRecenter}
                                    sx={{
                                        position: 'absolute',
                                        bottom: 16,
                                        right: 16,
                                        zIndex: 1000,
                                        bgcolor: '#ffffff',
                                        color: '#1a73e8',
                                        boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
                                        '&:hover': { bgcolor: '#f1f5ff' },
                                    }}
                                >
                                    <RecenterIcon />
                                </Fab>
                            </Tooltip>

                            {/* Map Legend */}
                            {!isMobile && (
                                <Paper
                                    elevation={2}
                                    sx={{
                                        position: 'absolute',
                                        bottom: 16,
                                        left: 16,
                                        zIndex: 1000,
                                        p: 1.5,
                                        borderRadius: 2,
                                        bgcolor: 'rgba(255,255,255,0.95)',
                                    }}
                                >
                                    <Box display="flex" alignItems="center" gap={1.5}>
                                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', bgcolor: RED }} />
                                        <Typography variant="caption">Pending</Typography>
                                    </Box>
                                    <Box display="flex" alignItems="center" gap={1.5} sx={{ mt: 0.5 }}>
                                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', bgcolor: GREEN }} />
                                        <Typography variant="caption">Accepted</Typography>
                                    </Box>
                                    <Box display="flex" alignItems="center" gap={1.5} sx={{ mt: 0.5 }}>
                                        <Typography variant="caption">⚠️</Typography>
                                        <Typography variant="caption">Waiting 5+ min</Typography>
                                    </Box>
                                </Paper>
                            )}
                        </Box>
                    </Paper>
                </Grid>
            </Grid>

            {/* ===== TABLE SECTION ===== */}
            <Grid container spacing={3} sx={{ mt: 2 }}>
                <Grid item xs={12}>
                    <Paper sx={{ borderRadius: 2, overflow: 'hidden' }}>
                        <Box sx={{ p: 2, borderBottom: '1px solid #e5e7eb', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <Typography variant="h6" fontWeight="bold">
                                📋 Today's Requests ({todayRequests.length})
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                                Updated {format(new Date(), 'HH:mm')}
                            </Typography>
                        </Box>

                        {loading ? (
                            <Box p={3}><LinearProgress /></Box>
                        ) : todayRequests.length === 0 ? (
                            <Box p={3} textAlign="center">
                                <Typography color="text.secondary">No requests found for today</Typography>
                            </Box>
                        ) : (
                            <>
                                <TableContainer sx={{ maxHeight: 500 }}>
                                    <Table stickyHeader>
                                        <TableHead>
                                            <TableRow>
                                                <TableCell>ID</TableCell>
                                                <TableCell>Customer</TableCell>
                                                <TableCell>Service</TableCell>
                                                <TableCell>Status</TableCell>
                                                <TableCell>Time</TableCell>
                                                <TableCell align="center">Actions</TableCell>
                                            </TableRow>
                                        </TableHead>
                                        <TableBody>
                                            {todayRequests.map((request) => (
                                                <TableRow
                                                    key={request.id}
                                                    sx={{
                                                        '&:hover': { bgcolor: '#f8fafc' },
                                                        ...(request.is_timeout && { bgcolor: '#fef2f2' }),
                                                    }}
                                                >
                                                    <TableCell>
                                                        <Typography variant="body2" fontWeight="500">
                                                            #{request.id}
                                                        </Typography>
                                                    </TableCell>
                                                    <TableCell>
                                                        <Box display="flex" alignItems="center" gap={1}>
                                                            <Avatar sx={{ width: 28, height: 28, fontSize: 12, bgcolor: COLORS.primary }}>
                                                                {request.customer?.name?.charAt(0) || '?'}
                                                            </Avatar>
                                                            <Box>
                                                                <Typography variant="body2" noWrap sx={{ maxWidth: 100 }}>
                                                                    {request.customer?.name || 'Unknown'}
                                                                </Typography>
                                                                <Typography variant="caption" color="text.secondary">
                                                                    {request.customer?.phone || ''}
                                                                </Typography>
                                                            </Box>
                                                        </Box>
                                                    </TableCell>
                                                    <TableCell>{request.service?.name || 'N/A'}</TableCell>
                                                    <TableCell>
                                                        <StatusChip status={request.status} isTimeout={request.is_timeout} />
                                                        {request.is_timeout && (
                                                            <Typography variant="caption" color="error" display="block">
                                                                {request.minutes_elapsed} min
                                                            </Typography>
                                                        )}
                                                    </TableCell>
                                                    <TableCell>
                                                        <Typography variant="caption">
                                                            {formatDate(request.created_at)}
                                                        </Typography>
                                                    </TableCell>
                                                    <TableCell align="center">
                                                        <Box display="flex" justifyContent="center" gap={0.5}>
                                                            <Tooltip title="View Details">
                                                                <IconButton
                                                                    size="small"
                                                                    onClick={() => {
                                                                        setSelectedRequest(request);
                                                                        setOpenDetailDialog(true);
                                                                    }}
                                                                    sx={{ color: COLORS.primary }}
                                                                >
                                                                    <ViewIcon fontSize="small" />
                                                                </IconButton>
                                                            </Tooltip>
                                                            {canCallTechnician && request.technician?.id && (
                                                                <Tooltip title="Call Technician">
                                                                    <IconButton
                                                                        size="small"
                                                                        onClick={() => handleCallTechnician(request.technician.id, request.id)}
                                                                        sx={{ color: '#22c55e' }}
                                                                    >
                                                                        <PhoneIcon fontSize="small" />
                                                                    </IconButton>
                                                                </Tooltip>
                                                            )}
                                                            {canUpdateStatus && request.status === 'pending' && (
                                                                <Tooltip title="Update Status">
                                                                    <IconButton
                                                                        size="small"
                                                                        onClick={() => {
                                                                            setStatusAction({ id: request.id, status: '', notes: '' });
                                                                            setOpenStatusDialog(true);
                                                                        }}
                                                                        sx={{ color: COLORS.warning }}
                                                                    >
                                                                        <PendingIcon fontSize="small" />
                                                                    </IconButton>
                                                                </Tooltip>
                                                            )}
                                                        </Box>
                                                    </TableCell>
                                                </TableRow>
                                            ))}
                                        </TableBody>
                                    </Table>
                                </TableContainer>
                                <Box sx={{ p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                    <Typography variant="caption" color="text.secondary">
                                        Total: {todayRequests.length} requests today
                                    </Typography>
                                    <Pagination
                                        count={pagination.last_page}
                                        page={pagination.current_page}
                                        onChange={handlePageChange}
                                        size="small"
                                    />
                                </Box>
                            </>
                        )}
                    </Paper>
                </Grid>
            </Grid>

            {/* ===== SCROLL TO TOP ===== */}
            <Zoom in={showScrollTop}>
                <Tooltip title="Scroll to top" placement="left">
                    <Fab
                        color="primary"
                        size="medium"
                        onClick={handleScrollToTop}
                        sx={{
                            position: 'fixed',
                            bottom: { xs: 80, sm: 24 },
                            right: { xs: 16, sm: 24 },
                            zIndex: 1000,
                            bgcolor: COLORS.primary,
                            color: 'white',
                            boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
                            '&:hover': { bgcolor: '#1557b0' },
                        }}
                    >
                        <ArrowUpwardIcon />
                    </Fab>
                </Tooltip>
            </Zoom>

            {/* ===== DIALOGS & DRAWERS ===== */}

            {/* Request Detail Dialog */}
            <Dialog
                open={openDetailDialog}
                onClose={() => setOpenDetailDialog(false)}
                maxWidth="md"
                fullWidth
                fullScreen={isMobile}
            >
                {selectedRequest && (
                    <>
                        <DialogTitle>
                            <Box display="flex" justifyContent="space-between" alignItems="center">
                                <Typography variant="h6">Request #{selectedRequest.id}</Typography>
                                <IconButton onClick={() => setOpenDetailDialog(false)}>
                                    <CloseIcon />
                                </IconButton>
                            </Box>
                        </DialogTitle>
                        <DialogContent dividers>
                            <Grid container spacing={2}>
                                <Grid item xs={12}>
                                    <Typography variant="subtitle2" color="text.secondary">Description</Typography>
                                    <Typography>{selectedRequest.description || 'No description'}</Typography>
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="subtitle2" color="text.secondary">Status</Typography>
                                    <StatusChip status={selectedRequest.status} isTimeout={selectedRequest.is_timeout} />
                                </Grid>
                                <Grid item xs={6}>
                                    <Typography variant="subtitle2" color="text.secondary">Created</Typography>
                                    <Typography variant="body2">{formatDate(selectedRequest.created_at)}</Typography>
                                </Grid>
                                <Grid item xs={12}>
                                    <Divider sx={{ my: 1 }} />
                                    <Typography variant="subtitle2" color="text.secondary">Customer</Typography>
                                    <Box display="flex" alignItems="center" gap={2} sx={{ mt: 1 }}>
                                        <Avatar>{selectedRequest.customer?.name?.charAt(0) || '?'}</Avatar>
                                        <Box>
                                            <Typography>{selectedRequest.customer?.name || 'Unknown'}</Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                {selectedRequest.customer?.phone || 'No phone'}
                                            </Typography>
                                        </Box>
                                    </Box>
                                </Grid>
                                <Grid item xs={12}>
                                    <Divider sx={{ my: 1 }} />
                                    <Typography variant="subtitle2" color="text.secondary">Technician</Typography>
                                    {selectedRequest.technician ? (
                                        <Box display="flex" alignItems="center" gap={2} sx={{ mt: 1 }}>
                                            <Avatar src={selectedRequest.technician.profile_photo}>
                                                {selectedRequest.technician.name?.charAt(0) || '?'}
                                            </Avatar>
                                            <Box>
                                                <Typography>{selectedRequest.technician.name}</Typography>
                                                <Typography variant="caption" color="text.secondary">
                                                    {selectedRequest.technician.area || 'No area'} ·
                                                    {selectedRequest.technician.is_online ? ' Online' : ' Offline'}
                                                </Typography>
                                            </Box>
                                        </Box>
                                    ) : (
                                        <Typography variant="body2" color="text.secondary">No technician assigned</Typography>
                                    )}
                                </Grid>
                                {canCallTechnician && selectedRequest.technician?.phone && (
                                    <Grid item xs={12}>
                                        <Box display="flex" gap={2}>
                                            <Button
                                                variant="contained"
                                                startIcon={<PhoneIcon />}
                                                onClick={() => window.location.href = `tel:${selectedRequest.technician.phone}`}
                                                sx={{ bgcolor: '#22c55e', '&:hover': { bgcolor: '#16a34a' } }}
                                            >
                                                Call
                                            </Button>
                                            <Button
                                                variant="contained"
                                                startIcon={<WhatsAppIcon />}
                                                onClick={() => {
                                                    const phone = selectedRequest.technician.phone.replace(/\D/g, '');
                                                    window.open(`https://wa.me/${phone}`, '_blank');
                                                }}
                                                sx={{ bgcolor: '#25d366', '&:hover': { bgcolor: '#1da851' } }}
                                            >
                                                WhatsApp
                                            </Button>
                                        </Box>
                                    </Grid>
                                )}
                            </Grid>
                        </DialogContent>
                        <DialogActions>
                            <Button onClick={() => setOpenDetailDialog(false)}>Close</Button>
                        </DialogActions>
                    </>
                )}
            </Dialog>

            {/* Status Update Dialog */}
            <Dialog open={openStatusDialog && canUpdateStatus} onClose={() => setOpenStatusDialog(false)} maxWidth="xs" fullWidth>
                <DialogTitle>Update Status</DialogTitle>
                <DialogContent>
                    <FormControl fullWidth sx={{ mt: 1 }}>
                        <InputLabel>New Status</InputLabel>
                        <Select
                            value={statusAction.status}
                            label="New Status"
                            onChange={(e) => setStatusAction(prev => ({ ...prev, status: e.target.value }))}
                        >
                            <MenuItem value="accepted">✅ Accepted</MenuItem>
                            <MenuItem value="rejected">❌ Rejected</MenuItem>
                            <MenuItem value="in_progress">⏳ In Progress</MenuItem>
                            <MenuItem value="completed">✅ Completed</MenuItem>
                        </Select>
                    </FormControl>
                    <TextField
                        fullWidth
                        multiline
                        rows={2}
                        label="Notes"
                        value={statusAction.notes}
                        onChange={(e) => setStatusAction(prev => ({ ...prev, notes: e.target.value }))}
                        sx={{ mt: 2 }}
                    />
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setOpenStatusDialog(false)}>Cancel</Button>
                    <Button variant="contained" onClick={handleStatusUpdate} disabled={!statusAction.status}>
                        Update
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Call Technician Dialog */}
            <Dialog open={!!selectedTechnician && canCallTechnician} onClose={() => setSelectedTechnician(null)} maxWidth="xs" fullWidth>
                <DialogTitle>Call Technician</DialogTitle>
                <DialogContent>
                    {selectedTechnician && (
                        <Box textAlign="center" py={2}>
                            <Avatar sx={{ width: 64, height: 64, mx: 'auto', mb: 2 }}>
                                {selectedTechnician.technician_name?.charAt(0) || '?'}
                            </Avatar>
                            <Typography variant="h6">{selectedTechnician.technician_name}</Typography>
                            <Typography variant="body2" color="text.secondary">
                                {selectedTechnician.phone_number}
                            </Typography>
                            <Box display="flex" gap={2} justifyContent="center" sx={{ mt: 3 }}>
                                <Button
                                    variant="contained"
                                    startIcon={<PhoneIcon />}
                                    onClick={() => {
                                        window.location.href = selectedTechnician.call_url;
                                        setSelectedTechnician(null);
                                    }}
                                    sx={{ bgcolor: '#22c55e', '&:hover': { bgcolor: '#16a34a' } }}
                                >
                                    Call
                                </Button>
                                <Button
                                    variant="contained"
                                    startIcon={<WhatsAppIcon />}
                                    onClick={() => {
                                        window.open(selectedTechnician.whatsapp_url, '_blank');
                                        setSelectedTechnician(null);
                                    }}
                                    sx={{ bgcolor: '#25d366', '&:hover': { bgcolor: '#1da851' } }}
                                >
                                    WhatsApp
                                </Button>
                            </Box>
                        </Box>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setSelectedTechnician(null)}>Close</Button>
                </DialogActions>
            </Dialog>

            {/* Map Marker Detail Drawer */}
            <Drawer anchor="right" open={!!selectedMarker} onClose={() => setSelectedMarker(null)}>
                {selectedMarker && (
                    <Box sx={{ width: { xs: '100vw', sm: 340 }, p: 3 }}>
                        <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
                            <Typography variant="h6">Request #{selectedMarker.id}</Typography>
                            <IconButton onClick={() => setSelectedMarker(null)}><CloseIcon /></IconButton>
                        </Box>

                        <StatusChip status={selectedMarker.status} isTimeout={selectedMarker.is_timeout} />

                        {selectedMarker.is_timeout && (
                            <Alert severity="warning" sx={{ mt: 2 }}>
                                Waiting {selectedMarker.minutes_elapsed} minutes
                            </Alert>
                        )}

                        <Typography variant="subtitle2" color="text.secondary" sx={{ mt: 2 }}>Service</Typography>
                        <Typography sx={{ mb: 2 }}>{selectedMarker.service?.name || 'N/A'}</Typography>

                        <Typography variant="subtitle2" color="text.secondary">Description</Typography>
                        <Typography sx={{ mb: 2 }}>{selectedMarker.description || 'No description'}</Typography>

                        <Divider sx={{ my: 2 }} />

                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>Customer</Typography>
                        <Box display="flex" alignItems="center" gap={2} mb={2}>
                            <Avatar>{selectedMarker.customer?.name?.charAt(0) || '?'}</Avatar>
                            <Box>
                                <Typography>{selectedMarker.customer?.name || 'Unknown'}</Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {selectedMarker.customer?.phone || 'No phone'}
                                </Typography>
                            </Box>
                        </Box>
                        {selectedMarker.customer?.phone && (
                            <Box display="flex" gap={1} mb={2}>
                                <Button
                                    size="small" variant="outlined" startIcon={<PhoneIcon />}
                                    href={`tel:${selectedMarker.customer.phone}`}
                                    sx={{ color: '#22c55e', borderColor: '#22c55e' }}
                                >
                                    Call
                                </Button>
                                <Button
                                    size="small" variant="outlined" startIcon={<WhatsAppIcon />}
                                    href={`https://wa.me/${selectedMarker.customer.phone.replace(/\D/g, '')}`}
                                    target="_blank"
                                    sx={{ color: '#25d366', borderColor: '#25d366' }}
                                >
                                    WhatsApp
                                </Button>
                            </Box>
                        )}

                        <Divider sx={{ my: 2 }} />

                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>Technician</Typography>
                        {selectedMarker.technician ? (
                            <>
                                <Box display="flex" alignItems="center" gap={2} mb={2}>
                                    <Avatar src={selectedMarker.technician.profile_photo}>
                                        {selectedMarker.technician.name?.charAt(0) || '?'}
                                    </Avatar>
                                    <Box>
                                        <Typography>{selectedMarker.technician.name}</Typography>
                                        <Typography variant="caption" color="text.secondary">
                                            {selectedMarker.technician.area || 'No area'} ·
                                            {selectedMarker.technician.is_online ? ' Online' : ' Offline'}
                                        </Typography>
                                    </Box>
                                </Box>
                                {canCallTechnician && selectedMarker.technician.phone && (
                                    <Box display="flex" gap={1} mb={2}>
                                        <Button
                                            size="small" variant="contained" startIcon={<PhoneIcon />}
                                            onClick={() => handleCallTechnician(selectedMarker.technician.id, selectedMarker.id)}
                                            sx={{ bgcolor: '#22c55e', '&:hover': { bgcolor: '#16a34a' } }}
                                        >
                                            Call
                                        </Button>
                                        <Button
                                            size="small" variant="contained" startIcon={<WhatsAppIcon />}
                                            href={`https://wa.me/${selectedMarker.technician.phone.replace(/\D/g, '')}`}
                                            target="_blank"
                                            sx={{ bgcolor: '#25d366', '&:hover': { bgcolor: '#1da851' } }}
                                        >
                                            WhatsApp
                                        </Button>
                                    </Box>
                                )}
                            </>
                        ) : (
                            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                                No technician assigned
                            </Typography>
                        )}

                        {canUpdateStatus && selectedMarker.status === 'pending' && (
                            <>
                                <Divider sx={{ my: 2 }} />
                                <Box display="flex" gap={1}>
                                    <Button
                                        fullWidth variant="contained" color="success" startIcon={<CheckIcon />}
                                        disabled={actionLoading}
                                        onClick={() => handleAccept(selectedMarker.id)}
                                    >
                                        Accept
                                    </Button>
                                    <Button
                                        fullWidth variant="outlined" color="error" startIcon={<CancelIcon />}
                                        disabled={actionLoading}
                                        onClick={() => handleReject(selectedMarker.id)}
                                    >
                                        Reject
                                    </Button>
                                </Box>
                            </>
                        )}
                    </Box>
                )}
            </Drawer>

            {/* ===== TOAST ===== */}
            <Snackbar
                open={!!toast}
                autoHideDuration={4000}
                onClose={() => setToast(null)}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
            >
                {toast && <Alert severity={toast.severity} onClose={() => setToast(null)}>{toast.message}</Alert>}
            </Snackbar>
        </Box>
    );
};

export default MonitoringDashboard;