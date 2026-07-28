// src/pages/monitoring/MonitoringMap.jsx
// Full-screen map showing TODAY's PENDING (red), ACCEPTED (green), and COMPLETED (blue) service requests.
// Pending requests from previous days show as orange.
//
// NEW IN THIS VERSION:
// 1. OSRM Route Fetching (router.project-osrm.org): real driving routes are drawn between a
//    selected request's technician and the customer location, instead of a straight line.
// 2. Route caching: routes are cached per (request, technician) pair so re-selecting the same
//    marker or polling refreshes doesn't refetch OSRM unnecessarily.
// 3. Map Navigation Controls: interactive Zoom (+ / -) and Recenter / Fit All floating buttons.
// 4. Interactive Focus: selecting a request marker highlights its route and fits the camera
//    bounds between the technician and the customer; other markers dim slightly for contrast.

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import {
    Box,
    Paper,
    Typography,
    Chip,
    IconButton,
    Button,
    Drawer,
    Avatar,
    Divider,
    CircularProgress,
    Alert,
    Snackbar,
    Fab,
    Zoom,
    useMediaQuery,
    useTheme,
    Tooltip,
    Menu,
    MenuItem,
    SwipeableDrawer,
} from '@mui/material';
import {
    Refresh as RefreshIcon,
    Phone as PhoneIcon,
    WhatsApp as WhatsAppIcon,
    Close as CloseIcon,
    Warning as WarningIcon,
    ArrowUpward as ArrowUpwardIcon,
    MyLocation as MyLocationIcon,
    Star as StarIcon,
    Person as PersonIcon,
    LocationOn as LocationOnIcon,
    Phone as PhoneIconSmall,
    CalendarToday as CalendarIcon,
    ExpandMore as ExpandMoreIcon,
    KeyboardArrowRight as KeyboardArrowRightIcon,
    Add as AddIcon,
    Remove as RemoveIcon,
    Route as RouteIcon,
    Timer as TimerIcon,
} from '@mui/icons-material';
import { usePermissions } from 'hooks';
import { monitoringService } from 'services/monitoring.service';
import { NotificationBell } from './components/NotificationBell';

// Constants
const RED = '#ea4335';
const GREEN = '#22c55e';
const BLUE = '#3b82f6';
const ORANGE = '#f59e0b';
const DAR_ES_SALAAM = [-6.7924, 39.2083];
const TIMEOUT_MINUTES = 5;
const POLL_MS = 15000;
const DEFAULT_PENDING_DAYS = 3;
const OSRM_BASE_URL = 'https://router.project-osrm.org/route/v1/driving';

// CSS for pulse animation
const pulseStyles = `
    @keyframes pulseRed {
        0% { box-shadow: 0 0 0 0 rgba(234, 67, 53, 0.7); }
        70% { box-shadow: 0 0 0 16px rgba(234, 67, 53, 0); }
        100% { box-shadow: 0 0 0 0 rgba(234, 67, 53, 0); }
    }
    @keyframes pulseGreen {
        0% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5); }
        70% { box-shadow: 0 0 0 12px rgba(34, 197, 94, 0); }
        100% { box-shadow: 0 0 0 0 rgba(34, 197, 94, 0); }
    }
    @keyframes pulseOrange {
        0% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0.6); }
        70% { box-shadow: 0 0 0 14px rgba(245, 158, 11, 0); }
        100% { box-shadow: 0 0 0 0 rgba(245, 158, 11, 0); }
    }
    .leaflet-container { 
        width: 100% !important; 
        height: 100% !important; 
    }
    .pending-old-marker {
        animation: pulseOrange 2s infinite !important;
    }
`;

// Helper functions
const getWhatsAppUrl = (phone) => {
    if (!phone) return '#';
    const clean = phone.replace(/\D/g, '');
    return `https://wa.me/${clean}`;
};

const getCallUrl = (phone) => {
    if (!phone) return '#';
    const clean = phone.replace(/\D/g, '');
    return `tel:+${clean}`;
};

const formatPhoneDisplay = (phone) => {
    if (!phone) return 'No phone';
    const clean = phone.replace(/\D/g, '');
    if (clean.length === 10) {
        return `0${clean.slice(1, 4)} ${clean.slice(4, 7)} ${clean.slice(7)}`;
    }
    if (clean.length === 9) {
        return `0${clean.slice(0, 3)} ${clean.slice(3, 6)} ${clean.slice(6)}`;
    }
    return phone;
};

const getDayLabel = (dayAgo) => {
    if (dayAgo === 0) return 'Today';
    if (dayAgo === 1) return 'Yesterday';
    if (dayAgo === 2) return '2 days ago';
    if (dayAgo === 3) return '3 days ago';
    return `${dayAgo} days ago`;
};

const createIcon = (status, isTimeout, dayAgo, dimmed) => {
    let color = RED;
    let icon = '⚡';
    let size = 30;
    let className = '';
    let animation = 'none';

    if (status === 'accepted') {
        color = GREEN;
        icon = '✓';
        size = 30;
        animation = 'pulseGreen 2s infinite';
    } else if (status === 'completed') {
        color = BLUE;
        icon = '✅';
        size = 28;
        animation = 'none';
    } else if (status === 'pending') {
        if (dayAgo > 0) {
            color = ORANGE;
            icon = '⏳';
            size = 32;
            className = 'pending-old-marker';
            animation = 'pulseOrange 2s infinite';
        } else {
            color = RED;
            icon = isTimeout ? '⚠️' : '⚡';
            size = isTimeout ? 36 : 30;
            animation = isTimeout ? 'pulseRed 1.8s infinite' : 'none';
        }
    }

    const markerStyle = {
        backgroundColor: color,
        width: size + 'px',
        height: size + 'px',
        borderRadius: '50%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        border: '3px solid white',
        color: 'white',
        fontSize: (isTimeout ? '14' : '12') + 'px',
        boxShadow: '0 2px 10px rgba(0,0,0,0.35)',
        animation: animation,
        opacity: dimmed ? 0.45 : 1,
        transition: 'opacity 0.2s ease',
    };

    const styleString = Object.entries(markerStyle)
        .map(([key, value]) => `${key.replace(/([A-Z])/g, '-$1').toLowerCase()}:${value}`)
        .join(';');

    return L.divIcon({
        className: `monitoring-marker ${className}`,
        html: `<div style="${styleString}">${icon}</div>`,
        iconSize: [size, size],
        iconAnchor: [size / 2, size / 2],
        popupAnchor: [0, -size / 2],
    });
};

// Fetches a real driving route between two lat/lng points using the public OSRM demo server.
// Returns { coords, distanceKm, durationMin } or null if the route can't be resolved.
const fetchOsrmRoute = async (origin, destination) => {
    try {
        const url = `${OSRM_BASE_URL}/${origin.lng},${origin.lat};${destination.lng},${destination.lat}?overview=full&geometries=geojson`;
        const res = await fetch(url);
        if (!res.ok) throw new Error(`OSRM request failed with status ${res.status}`);
        const data = await res.json();
        if (data.code !== 'Ok' || !data.routes?.length) return null;

        const route = data.routes[0];
        const coords = route.geometry.coordinates.map(([lng, lat]) => [lat, lng]);

        return {
            coords,
            distanceKm: route.distance / 1000,
            durationMin: route.duration / 60,
        };
    } catch (err) {
        console.error('OSRM route fetch error:', err);
        return null;
    }
};

const MonitoringMap = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const { can } = usePermissions();

    const canView = can('monitoring.view');
    const canCall = can('technicians.call');

    const [requests, setRequests] = useState([]);
    const [counts, setCounts] = useState({});
    const [pendingCounts, setPendingCounts] = useState({});
    const [statusFilter, setStatusFilter] = useState('all');
    const [pendingDays, setPendingDays] = useState(DEFAULT_PENDING_DAYS);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [selected, setSelected] = useState(null);
    const [callInfo, setCallInfo] = useState(null);
    const [toast, setToast] = useState(null);
    const [showScrollTop, setShowScrollTop] = useState(false);
    const [anchorEl, setAnchorEl] = useState(null);

    // --- Route state ---
    const [routeInfo, setRouteInfo] = useState(null); // { coords, distanceKm, durationMin, requestId }
    const [routeLoading, setRouteLoading] = useState(false);
    const routeCacheRef = useRef({}); // key: `${requestId}-${technicianId}` -> route result

    const mapRef = useRef(null);

    const load = useCallback(async () => {
        setError(null);
        try {
            const statusParam = statusFilter === 'all' ? 'pending,accepted,completed' : statusFilter;
            const res = await monitoringService.getMap(statusParam, pendingDays);
            const data = res.data?.data || res.data || {};

            setRequests(data.requests || []);
            setCounts(data.counts || {});
            setPendingCounts(data.pending_counts || {});
        } catch (err) {
            console.error('Load error:', err);
            setError(err.response?.data?.message || err.message || 'Failed to load map data');
        } finally {
            setLoading(false);
        }
    }, [statusFilter, pendingDays]);

    useEffect(() => {
        setLoading(true);
        load();
        const interval = setInterval(load, POLL_MS);
        return () => clearInterval(interval);
    }, [load]);

    useEffect(() => {
        const handleScroll = () => {
            setShowScrollTop(window.scrollY > 400);
        };
        window.addEventListener('scroll', handleScroll);
        return () => window.removeEventListener('scroll', handleScroll);
    }, []);

    const handleScrollToTop = () => {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    };

    const fitToBounds = useCallback((points, options = {}) => {
        const map = mapRef.current;
        if (!map || !points || points.length === 0) return;
        if (points.length === 1) {
            map.flyTo(points[0], 15, { duration: 0.75 });
            return;
        }
        const bounds = L.latLngBounds(points);
        map.flyToBounds(bounds, { padding: [80, 80], maxZoom: 16, duration: 0.75, ...options });
    }, []);

    const handleRecenter = () => {
        const map = mapRef.current;
        if (!map) return;

        const mapRequests = requests.filter(r => r.latitude && r.longitude);
        if (mapRequests.length > 0) {
            fitToBounds(mapRequests.map((r) => [r.latitude, r.longitude]), { maxZoom: 15 });
        } else {
            map.flyTo(DAR_ES_SALAAM, 13, { duration: 0.75 });
        }
    };

    const handleZoomIn = () => {
        const map = mapRef.current;
        if (map) map.zoomIn(1);
    };

    const handleZoomOut = () => {
        const map = mapRef.current;
        if (map) map.zoomOut(1);
    };

    const handleCallTechnician = async (technicianId, requestId) => {
        if (!canCall) return;
        try {
            const res = await monitoringService.callTechnician(technicianId, requestId);
            setCallInfo(res.data.data);
        } catch (err) {
            setToast({
                severity: 'error',
                message: err.response?.data?.message || 'Failed to get call details'
            });
        }
    };

    const handleNotificationClick = (notification) => {
        if (notification?.viewAll) {
            load();
            return;
        }
        const request = requests.find(r => r.id === notification?.request_id);
        if (request) {
            setSelected(request);
            if (isMobile && mapRef.current && request.latitude && request.longitude) {
                setTimeout(() => {
                    mapRef.current.flyTo([request.latitude, request.longitude], 15, {
                        duration: 0.75
                    });
                }, 300);
            }
        }
    };

    const handleDaysClick = (event) => {
        setAnchorEl(event.currentTarget);
    };

    const handleDaysClose = () => {
        setAnchorEl(null);
    };

    const handleDaysSelect = (days) => {
        setPendingDays(days);
        handleDaysClose();
        load();
    };

    // Handle close drawer with escape key
    useEffect(() => {
        const handleEscape = (event) => {
            if (event.key === 'Escape' && selected) {
                setSelected(null);
            }
        };
        document.addEventListener('keydown', handleEscape);
        return () => document.removeEventListener('keydown', handleEscape);
    }, [selected]);

    // --- Route fetching: whenever the selected request changes, fetch (or reuse a cached)
    // driving route between the assigned technician and the customer location, then fit the
    // camera to that route. This is the "interactive focus" behavior.
    useEffect(() => {
        let cancelled = false;

        const loadRoute = async () => {
            const hasTechLocation = selected?.technician?.latitude && selected?.technician?.longitude;
            const hasDestLocation = selected?.latitude && selected?.longitude;

            if (!selected || !hasTechLocation || !hasDestLocation) {
                setRouteInfo(null);
                setRouteLoading(false);
                // Still focus the camera on the request itself even without a technician route.
                if (selected && hasDestLocation) {
                    fitToBounds([[selected.latitude, selected.longitude]], { maxZoom: 15 });
                }
                return;
            }

            const cacheKey = `${selected.id}-${selected.technician.id}`;
            const cached = routeCacheRef.current[cacheKey];

            if (cached) {
                setRouteInfo({ ...cached, requestId: selected.id });
                fitToBounds(cached.coords);
                return;
            }

            setRouteLoading(true);
            const origin = { lat: selected.technician.latitude, lng: selected.technician.longitude };
            const destination = { lat: selected.latitude, lng: selected.longitude };
            const result = await fetchOsrmRoute(origin, destination);

            if (cancelled) return;
            setRouteLoading(false);

            if (result) {
                routeCacheRef.current[cacheKey] = result;
                setRouteInfo({ ...result, requestId: selected.id });
                fitToBounds(result.coords);
            } else {
                setRouteInfo(null);
                // Fall back to fitting between the two raw points if OSRM couldn't resolve a route.
                fitToBounds([
                    [origin.lat, origin.lng],
                    [destination.lat, destination.lng],
                ]);
            }
        };

        loadRoute();
        return () => { cancelled = true; };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [selected?.id]);

    if (!canView) {
        return (
            <Box p={3}>
                <Alert severity="error">
                    You do not have permission to view the monitoring map.
                </Alert>
            </Box>
        );
    }

    const center = requests.length > 0 && requests[0].latitude && requests[0].longitude
        ? [requests[0].latitude, requests[0].longitude]
        : DAR_ES_SALAAM;

    const routeColor = selected?.status === 'accepted' ? GREEN
        : selected?.status === 'completed' ? BLUE
            : RED;

    return (
        <Box sx={{
            position: 'relative',
            width: '100%',
            height: '100vh',
            overflow: 'hidden',
            bgcolor: '#f5f5f5',
        }}>
            <style>{pulseStyles}</style>

            {loading && requests.length === 0 ? (
                <Box display="flex" justifyContent="center" alignItems="center" height="100%">
                    <CircularProgress />
                </Box>
            ) : (
                <MapContainer
                    center={center}
                    zoom={13}
                    style={{ height: '100%', width: '100%' }}
                    zoomControl={false}
                    ref={mapRef}
                >
                    <TileLayer
                        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                    />

                    {routeInfo?.coords?.length > 0 && (
                        <Polyline
                            positions={routeInfo.coords}
                            pathOptions={{
                                color: routeColor,
                                weight: 5,
                                opacity: 0.8,
                                dashArray: selected?.status === 'pending' ? '10, 8' : null,
                                lineCap: 'round',
                            }}
                        />
                    )}

                    {requests.map((r) => {
                        if (!r.latitude || !r.longitude) return null;
                        const dayAgo = r.status === 'pending' ? (r.day_ago || 0) : 0;
                        const dimmed = !!selected && selected.id !== r.id;
                        return (
                            <Marker
                                key={r.id}
                                position={[r.latitude, r.longitude]}
                                icon={createIcon(r.status, r.is_timeout, dayAgo, dimmed)}
                                eventHandlers={{ click: () => setSelected(r) }}
                            >
                                <Popup>
                                    <Box sx={{ minWidth: 200 }}>
                                        <Typography variant="subtitle2" fontWeight="bold">
                                            {r.customer?.name || 'Unknown Customer'}
                                        </Typography>
                                        <Typography variant="caption" color="text.secondary" display="block">
                                            {r.service?.name || 'Service'} · {r.status}
                                            {r.is_timeout ? ` · ⚠️ ${r.minutes_elapsed}m` : ''}
                                            {r.status === 'pending' && dayAgo > 0 ? ` · 📅 ${getDayLabel(dayAgo)}` : ''}
                                        </Typography>
                                        {r.technician ? (
                                            <Box sx={{ mt: 0.5, pt: 0.5, borderTop: '1px solid #e5e7eb' }}>
                                                <Box display="flex" alignItems="center" gap={0.5}>
                                                    <PersonIcon sx={{ fontSize: 12, color: '#6b7280' }} />
                                                    <Typography variant="caption" fontWeight="medium">
                                                        {r.technician.name || 'Unknown Technician'}
                                                    </Typography>
                                                </Box>
                                                {r.technician.area && (
                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                        <LocationOnIcon sx={{ fontSize: 12, color: '#6b7280' }} />
                                                        <Typography variant="caption" color="text.secondary">
                                                            {r.technician.area}
                                                        </Typography>
                                                    </Box>
                                                )}
                                                {r.technician.phone && (
                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                        <PhoneIconSmall sx={{ fontSize: 12, color: '#6b7280' }} />
                                                        <Typography variant="caption" color="text.secondary">
                                                            {formatPhoneDisplay(r.technician.phone)}
                                                        </Typography>
                                                    </Box>
                                                )}
                                            </Box>
                                        ) : (
                                            <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
                                                No technician assigned
                                            </Typography>
                                        )}
                                    </Box>
                                </Popup>
                            </Marker>
                        );
                    })}
                </MapContainer>
            )}

            {/* Top Overlay */}
            <Paper
                elevation={4}
                sx={{
                    position: 'absolute',
                    top: 16,
                    left: 16,
                    right: 16,
                    zIndex: 1000,
                    p: { xs: 1.5, sm: 2 },
                    borderRadius: 2,
                    bgcolor: 'rgba(255,255,255,0.97)',
                    maxHeight: { xs: 'auto', sm: 140 },
                    overflow: 'auto',
                }}
            >
                <Box display="flex" alignItems="center" justifyContent="space-between" flexWrap="wrap" gap={1}>
                    <Box display="flex" alignItems="center" gap={1} flexWrap="wrap">
                        <Typography variant="subtitle1" fontWeight="bold" sx={{ fontSize: { xs: '0.9rem', sm: '1.1rem' } }}>
                            🗺️ Monitoring
                        </Typography>
                        <Chip
                            label="All"
                            size="small"
                            color={statusFilter === 'all' ? 'primary' : 'default'}
                            onClick={() => setStatusFilter('all')}
                        />
                        <Chip
                            label={`🔴 Pending (${counts.pending || 0})`}
                            size="small"
                            color={statusFilter === 'pending' ? 'primary' : 'default'}
                            onClick={() => setStatusFilter('pending')}
                        />
                        <Chip
                            label={`🟢 Accepted (${counts.accepted || 0})`}
                            size="small"
                            color={statusFilter === 'accepted' ? 'primary' : 'default'}
                            onClick={() => setStatusFilter('accepted')}
                        />
                        <Chip
                            label={`🔵 Completed (${counts.completed || 0})`}
                            size="small"
                            color={statusFilter === 'completed' ? 'primary' : 'default'}
                            onClick={() => setStatusFilter('completed')}
                        />
                        {counts.timeout > 0 && (
                            <Chip
                                icon={<WarningIcon sx={{ fontSize: 16 }} />}
                                label={`${counts.timeout} waiting 5+ min`}
                                size="small"
                                sx={{ bgcolor: '#fee2e2', color: '#991b1b', fontWeight: 'bold' }}
                            />
                        )}
                    </Box>
                    <Box display="flex" alignItems="center" gap={1}>
                        <NotificationBell onNotificationClick={handleNotificationClick} />
                        <IconButton size="small" onClick={load} disabled={loading}>
                            <RefreshIcon fontSize="small" />
                        </IconButton>
                    </Box>
                </Box>

                {/* Stats Summary */}
                <Box display="flex" alignItems="center" gap={1.5} flexWrap="wrap" sx={{ mt: 0.5 }}>
                    <Typography variant="caption" color="text.secondary">
                        📅 {new Date().toLocaleDateString('en-US', {
                        weekday: 'short',
                        month: 'short',
                        day: 'numeric'
                    })}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                        Total: {counts.total || 0}
                    </Typography>
                    <Typography variant="caption" sx={{ color: '#f59e0b' }}>
                        Pending: {counts.pending || 0}
                    </Typography>
                    <Typography variant="caption" sx={{ color: '#10b981' }}>
                        Accepted: {counts.accepted || 0}
                    </Typography>
                    <Typography variant="caption" sx={{ color: '#3b82f6' }}>
                        Completed: {counts.completed || 0}
                    </Typography>
                    {counts.timeout > 0 && (
                        <Typography variant="caption" sx={{ color: '#ef4444' }}>
                            Timeout: {counts.timeout}
                        </Typography>
                    )}

                    <Box sx={{ ml: 'auto' }}>
                        <Button
                            size="small"
                            variant="outlined"
                            endIcon={<ExpandMoreIcon />}
                            onClick={handleDaysClick}
                            sx={{
                                fontSize: '0.7rem',
                                textTransform: 'none',
                                borderColor: '#d1d5db',
                            }}
                        >
                            <CalendarIcon sx={{ fontSize: 14, mr: 0.5 }} />
                            {pendingDays === 0 ? 'Today' : `${pendingDays}d`}
                        </Button>
                        <Menu
                            anchorEl={anchorEl}
                            open={Boolean(anchorEl)}
                            onClose={handleDaysClose}
                        >
                            <MenuItem onClick={() => handleDaysSelect(0)}>Today only</MenuItem>
                            <MenuItem onClick={() => handleDaysSelect(1)}>Last 1 day</MenuItem>
                            <MenuItem onClick={() => handleDaysSelect(3)}>Last 3 days</MenuItem>
                            <MenuItem onClick={() => handleDaysSelect(5)}>Last 5 days</MenuItem>
                            <MenuItem onClick={() => handleDaysSelect(7)}>Last 7 days</MenuItem>
                        </Menu>
                    </Box>
                </Box>

                {/* Pending counts by day */}
                {pendingCounts.total_pending > 0 && (
                    <Box display="flex" alignItems="center" gap={1} flexWrap="wrap" sx={{ mt: 0.5 }}>
                        <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 'bold' }}>
                            Pending:
                        </Typography>
                        {pendingCounts.today > 0 && (
                            <Chip
                                label={`Today: ${pendingCounts.today}`}
                                size="small"
                                sx={{ height: 22, fontSize: '0.6rem', bgcolor: '#fee2e2', color: '#991b1b', fontWeight: '600' }}
                            />
                        )}
                        {pendingCounts.day_1?.count > 0 && (
                            <Chip
                                label={`${pendingCounts.day_1.label}: ${pendingCounts.day_1.count}`}
                                size="small"
                                sx={{ height: 22, fontSize: '0.6rem', bgcolor: '#fef3c7', color: '#92400e', fontWeight: '600' }}
                            />
                        )}
                        {pendingCounts.day_2?.count > 0 && (
                            <Chip
                                label={`${pendingCounts.day_2.label}: ${pendingCounts.day_2.count}`}
                                size="small"
                                sx={{ height: 22, fontSize: '0.6rem', bgcolor: '#fef3c7', color: '#92400e', fontWeight: '600' }}
                            />
                        )}
                        {pendingCounts.day_3?.count > 0 && (
                            <Chip
                                label={`${pendingCounts.day_3.label}: ${pendingCounts.day_3.count}`}
                                size="small"
                                sx={{ height: 22, fontSize: '0.6rem', bgcolor: '#fef3c7', color: '#92400e', fontWeight: '600' }}
                            />
                        )}
                        {pendingCounts.total_pending > 0 && (
                            <Chip
                                label={`📋 Requests: ${pendingCounts.total_pending}`}
                                size="small"
                                sx={{ height: 22, fontSize: '0.65rem', bgcolor: '#e5e7eb', color: '#374151', fontWeight: '700' }}
                            />
                        )}
                    </Box>
                )}
            </Paper>

            {error && (
                <Alert
                    severity="error"
                    sx={{
                        position: 'absolute',
                        top: { xs: 140, sm: 160 },
                        left: 16,
                        right: 16,
                        zIndex: 1000
                    }}
                    action={
                        <Button color="inherit" size="small" onClick={load}>
                            Retry
                        </Button>
                    }
                >
                    {error}
                </Alert>
            )}

            {/* Route info badge (shown while a route is loading or resolved) */}
            {selected && (routeLoading || routeInfo) && (
                <Paper
                    elevation={3}
                    sx={{
                        position: 'absolute',
                        top: { xs: 'auto', sm: 170 },
                        bottom: { xs: 90, sm: 'auto' },
                        left: 16,
                        zIndex: 1000,
                        px: 1.5,
                        py: 1,
                        borderRadius: 2,
                        bgcolor: 'rgba(255,255,255,0.97)',
                        display: 'flex',
                        alignItems: 'center',
                        gap: 1,
                    }}
                >
                    {routeLoading ? (
                        <>
                            <CircularProgress size={14} />
                            <Typography variant="caption" color="text.secondary">
                                Calculating route…
                            </Typography>
                        </>
                    ) : (
                        <>
                            <RouteIcon sx={{ fontSize: 16, color: routeColor }} />
                            <Typography variant="caption" fontWeight="600">
                                {routeInfo.distanceKm.toFixed(1)} km
                            </Typography>
                            <TimerIcon sx={{ fontSize: 14, color: '#6b7280', ml: 0.5 }} />
                            <Typography variant="caption" color="text.secondary">
                                {Math.round(routeInfo.durationMin)} min
                            </Typography>
                        </>
                    )}
                </Paper>
            )}

            {/* Legend */}
            {!isMobile && (
                <Paper
                    elevation={3}
                    sx={{
                        position: 'absolute',
                        bottom: 20,
                        left: 20,
                        zIndex: 1000,
                        p: 1.5,
                        borderRadius: 2,
                        bgcolor: 'rgba(255,255,255,0.95)',
                    }}
                >
                    <Box display="flex" alignItems="center" gap={1.5}>
                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', bgcolor: RED }} />
                        <Typography variant="caption">Pending (Today)</Typography>
                    </Box>
                    <Box display="flex" alignItems="center" gap={1.5} sx={{ mt: 0.5 }}>
                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', bgcolor: ORANGE }} />
                        <Typography variant="caption">Pending (Older)</Typography>
                    </Box>
                    <Box display="flex" alignItems="center" gap={1.5} sx={{ mt: 0.5 }}>
                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', bgcolor: GREEN }} />
                        <Typography variant="caption">Accepted</Typography>
                    </Box>
                    <Box display="flex" alignItems="center" gap={1.5} sx={{ mt: 0.5 }}>
                        <Box sx={{ width: 12, height: 12, borderRadius: '50%', bgcolor: BLUE }} />
                        <Typography variant="caption">Completed</Typography>
                    </Box>
                    <Box display="flex" alignItems="center" gap={1.5} sx={{ mt: 0.5 }}>
                        <Typography variant="caption">⚠️</Typography>
                        <Typography variant="caption">Waiting 5+ min</Typography>
                    </Box>
                    <Box display="flex" alignItems="center" gap={1.5} sx={{ mt: 0.5 }}>
                        <Box sx={{ width: 16, height: 3, bgcolor: '#9ca3af', borderRadius: 1 }} />
                        <Typography variant="caption">Driving route</Typography>
                    </Box>
                </Paper>
            )}

            {/* Map Navigation Controls: Zoom, Recenter, Scroll to Top */}
            <Box
                sx={{
                    position: 'absolute',
                    bottom: { xs: 80, sm: 20 },
                    right: { xs: 16, sm: 20 },
                    zIndex: 1000,
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 1,
                }}
            >
                <Paper
                    elevation={3}
                    sx={{
                        borderRadius: 2,
                        overflow: 'hidden',
                        display: 'flex',
                        flexDirection: 'column',
                    }}
                >
                    <Tooltip title="Zoom in" placement="left">
                        <IconButton
                            size="small"
                            onClick={handleZoomIn}
                            sx={{ borderRadius: 0, py: 1 }}
                        >
                            <AddIcon fontSize="small" />
                        </IconButton>
                    </Tooltip>
                    <Divider />
                    <Tooltip title="Zoom out" placement="left">
                        <IconButton
                            size="small"
                            onClick={handleZoomOut}
                            sx={{ borderRadius: 0, py: 1 }}
                        >
                            <RemoveIcon fontSize="small" />
                        </IconButton>
                    </Tooltip>
                </Paper>

                <Tooltip title="Recenter / fit all" placement="left">
                    <Fab
                        size="small"
                        onClick={handleRecenter}
                        sx={{
                            bgcolor: '#ffffff',
                            color: '#1a73e8',
                            boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
                            '&:hover': { bgcolor: '#f1f5ff' },
                        }}
                    >
                        <MyLocationIcon />
                    </Fab>
                </Tooltip>

                <Zoom in={showScrollTop}>
                    <Fab
                        size="small"
                        onClick={handleScrollToTop}
                        sx={{
                            bgcolor: '#1a73e8',
                            color: 'white',
                            boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
                            '&:hover': { bgcolor: '#1557b0' },
                        }}
                    >
                        <ArrowUpwardIcon />
                    </Fab>
                </Zoom>
            </Box>

            {/* Detail Panel - Side Drawer with Close Button */}
            <Drawer
                anchor="right"
                open={!!selected}
                onClose={() => setSelected(null)}
                ModalProps={{
                    keepMounted: true,
                }}
                PaperProps={{
                    sx: {
                        width: { xs: '100vw', sm: 400, md: 420 },
                        maxWidth: { xs: '100vw', sm: 400, md: 420 },
                        borderRadius: { xs: 0, sm: '16px 0 0 16px' },
                        boxShadow: '0 10px 40px rgba(0,0,0,0.2)',
                        overflow: 'hidden',
                    }
                }}
            >
                {selected && (
                    <Box sx={{
                        p: { xs: 2, sm: 3 },
                        overflowY: 'auto',
                        height: '100%',
                        display: 'flex',
                        flexDirection: 'column',
                    }}>
                        {/* Header with Close Button - Sticky */}
                        <Box sx={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            mb: 2,
                            position: 'sticky',
                            top: 0,
                            bgcolor: 'white',
                            zIndex: 10,
                            py: 1,
                            borderBottom: '1px solid #f3f4f6',
                        }}>
                            <Box display="flex" alignItems="center" gap={1}>
                                <Typography variant="h6" sx={{ fontWeight: 600, fontSize: { xs: '1rem', sm: '1.25rem' } }}>
                                    {selected.customer?.name || 'Customer'}
                                </Typography>
                            </Box>
                            <IconButton
                                onClick={() => setSelected(null)}
                                sx={{
                                    bgcolor: '#f3f4f6',
                                    '&:hover': {
                                        bgcolor: '#e5e7eb',
                                        transform: 'scale(1.05)',
                                    },
                                    width: { xs: 32, sm: 36 },
                                    height: { xs: 32, sm: 36 },
                                    transition: 'all 0.2s ease',
                                    borderRadius: '50%',
                                }}
                                aria-label="Close"
                            >
                                <CloseIcon sx={{ fontSize: { xs: 18, sm: 20 } }} />
                            </IconButton>
                        </Box>

                        {/* Service & Status */}
                        <Box display="flex" alignItems="center" gap={1} flexWrap="wrap" mb={2}>
                            <Chip
                                label={selected.service?.name || 'Service'}
                                size="small"
                                variant="outlined"
                                sx={{ fontSize: '0.75rem' }}
                            />
                            <Chip
                                label={selected.status === 'accepted' ? '✅ Accepted' : selected.status === 'completed' ? '✅ Completed' : '🔴 Pending'}
                                sx={{
                                    bgcolor: selected.status === 'accepted' ? '#d1fae5' : selected.status === 'completed' ? '#dbeafe' : '#fee2e2',
                                    color: selected.status === 'accepted' ? '#065f46' : selected.status === 'completed' ? '#1e40af' : '#991b1b',
                                    fontSize: '0.7rem',
                                    height: 24,
                                }}
                            />
                            {selected.is_timeout && (
                                <Chip
                                    icon={<WarningIcon sx={{ fontSize: 14 }} />}
                                    label={`${selected.minutes_elapsed}m waiting`}
                                    size="small"
                                    sx={{ bgcolor: '#fee2e2', color: '#991b1b', fontSize: '0.65rem', height: 24 }}
                                />
                            )}
                            {selected.status === 'pending' && selected.day_ago > 0 && (
                                <Chip
                                    icon={<CalendarIcon sx={{ fontSize: 14 }} />}
                                    label={getDayLabel(selected.day_ago)}
                                    size="small"
                                    sx={{ bgcolor: '#fef3c7', color: '#92400e', fontSize: '0.65rem', height: 24 }}
                                />
                            )}
                        </Box>

                        {/* Route summary, when a technician route is available */}
                        {(routeLoading || routeInfo) && (
                            <Box
                                sx={{
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: 1,
                                    mb: 2,
                                    p: 1.25,
                                    borderRadius: 2,
                                    bgcolor: '#f9fafb',
                                    border: '1px solid #e5e7eb',
                                }}
                            >
                                <RouteIcon sx={{ fontSize: 18, color: routeColor }} />
                                {routeLoading ? (
                                    <Typography variant="body2" color="text.secondary">
                                        Calculating driving route…
                                    </Typography>
                                ) : (
                                    <Typography variant="body2">
                                        <strong>{routeInfo.distanceKm.toFixed(1)} km</strong> driving
                                        {' · '}
                                        <strong>{Math.round(routeInfo.durationMin)} min</strong> ETA
                                    </Typography>
                                )}
                            </Box>
                        )}

                        <Typography variant="subtitle2" color="text.secondary" sx={{ fontWeight: 600, mt: 1 }}>
                            Description
                        </Typography>
                        <Typography sx={{ mb: 2, fontSize: '0.9rem', color: '#374151' }}>
                            {selected.description || 'No description'}
                        </Typography>

                        <Divider sx={{ my: 2 }} />

                        {/* Customer Section */}
                        <Typography variant="subtitle2" color="text.secondary" sx={{ fontWeight: 600, mb: 1 }}>
                            Customer
                        </Typography>
                        <Box display="flex" alignItems="center" gap={2} mb={2}>
                            <Avatar sx={{ bgcolor: '#e5e7eb', width: 40, height: 40 }}>
                                {selected.customer?.name?.charAt(0) || '?'}
                            </Avatar>
                            <Box>
                                <Typography fontWeight="500" fontSize="0.95rem">
                                    {selected.customer?.name || 'Unknown'}
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                    {selected.customer?.phone || 'No phone'}
                                </Typography>
                            </Box>
                        </Box>

                        <Divider sx={{ my: 2 }} />

                        {/* Technician Section */}
                        <Typography variant="subtitle2" color="text.secondary" sx={{ fontWeight: 600, mb: 1 }}>
                            Technician
                        </Typography>
                        {selected.technician ? (
                            <>
                                <Box display="flex" alignItems="center" gap={2} mb={2}>
                                    <Avatar
                                        src={selected.technician.profile_photo}
                                        sx={{ bgcolor: '#e5e7eb', width: 40, height: 40 }}
                                    >
                                        {selected.technician.name?.charAt(0) || '?'}
                                    </Avatar>
                                    <Box>
                                        <Typography fontWeight="500" fontSize="0.95rem">
                                            {selected.technician.name}
                                        </Typography>
                                        {selected.technician.area && (
                                            <Typography variant="caption" color="text.secondary" display="block">
                                                📍 {selected.technician.area}
                                            </Typography>
                                        )}
                                        {selected.technician.phone && (
                                            <Typography variant="caption" color="text.secondary" display="block">
                                                📞 {formatPhoneDisplay(selected.technician.phone)}
                                            </Typography>
                                        )}
                                        {selected.technician.rating > 0 && (
                                            <Box display="flex" alignItems="center" gap={0.5}>
                                                <StarIcon sx={{ fontSize: 14, color: '#f59e0b' }} />
                                                <Typography variant="caption" fontWeight="500">
                                                    {selected.technician.rating.toFixed(1)}
                                                </Typography>
                                            </Box>
                                        )}
                                    </Box>
                                </Box>

                                {canCall && selected.technician.phone && (
                                    <Box display="flex" gap={1} mb={2}>
                                        <Button
                                            size="small"
                                            variant="contained"
                                            startIcon={<PhoneIcon />}
                                            onClick={() => handleCallTechnician(selected.technician.id, selected.id)}
                                            sx={{
                                                bgcolor: '#22c55e',
                                                '&:hover': { bgcolor: '#16a34a' },
                                                flex: 1,
                                                textTransform: 'none',
                                                fontWeight: 600,
                                                borderRadius: 2,
                                                py: 1,
                                            }}
                                        >
                                            Call Technician
                                        </Button>
                                        <Button
                                            size="small"
                                            variant="contained"
                                            startIcon={<WhatsAppIcon />}
                                            href={getWhatsAppUrl(selected.technician.phone)}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            sx={{
                                                bgcolor: '#25d366',
                                                '&:hover': { bgcolor: '#1da851' },
                                                flex: 1,
                                                textTransform: 'none',
                                                fontWeight: 600,
                                                borderRadius: 2,
                                                py: 1,
                                            }}
                                        >
                                            WhatsApp
                                        </Button>
                                    </Box>
                                )}
                            </>
                        ) : (
                            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                                No technician assigned yet
                            </Typography>
                        )}
                    </Box>
                )}
            </Drawer>

            {/* Call Technician Confirmation */}
            <Drawer anchor="bottom" open={!!callInfo} onClose={() => setCallInfo(null)}>
                {callInfo && (
                    <Box textAlign="center" p={4}>
                        <Avatar sx={{ width: 64, height: 64, mx: 'auto', mb: 2 }}>
                            {callInfo.technician_name?.charAt(0) || '?'}
                        </Avatar>
                        <Typography variant="h6">{callInfo.technician_name}</Typography>
                        {callInfo.technician?.area && (
                            <Typography variant="body2" color="text.secondary">
                                📍 {callInfo.technician.area}
                            </Typography>
                        )}
                        {callInfo.technician?.phone && (
                            <Typography variant="body2" color="text.secondary">
                                📞 {formatPhoneDisplay(callInfo.technician.phone)}
                            </Typography>
                        )}
                        <Typography variant="body2" color="text.secondary" gutterBottom>
                            {callInfo.phone_number}
                        </Typography>
                        <Box display="flex" gap={2} justifyContent="center" sx={{ mt: 2 }}>
                            <Button
                                variant="contained"
                                startIcon={<PhoneIcon />}
                                href={callInfo.call_url}
                                onClick={() => setCallInfo(null)}
                                sx={{ bgcolor: '#22c55e', '&:hover': { bgcolor: '#16a34a' } }}
                            >
                                Call
                            </Button>
                            <Button
                                variant="contained"
                                startIcon={<WhatsAppIcon />}
                                href={callInfo.whatsapp_url}
                                target="_blank"
                                rel="noopener noreferrer"
                                onClick={() => setCallInfo(null)}
                                sx={{ bgcolor: '#25d366', '&:hover': { bgcolor: '#1da851' } }}
                            >
                                WhatsApp
                            </Button>
                        </Box>
                    </Box>
                )}
            </Drawer>

            {/* Toast/Snackbar */}
            <Snackbar
                open={!!toast}
                autoHideDuration={4000}
                onClose={() => setToast(null)}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
            >
                {toast && (
                    <Alert severity={toast.severity} onClose={() => setToast(null)}>
                        {toast.message}
                    </Alert>
                )}
            </Snackbar>
        </Box>
    );
};

export default MonitoringMap;