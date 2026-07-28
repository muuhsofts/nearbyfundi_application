// src/pages/portfolios/PortfoliosList.js
import React, { useState, useEffect, useCallback } from 'react';
import {
    Box,
    Paper,
    Typography,
    Grid,
    Card,
    CardContent,
    Avatar,
    Chip,
    IconButton,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    TextField,
    InputAdornment,
    CircularProgress,
    Alert,
    Stack,
    useMediaQuery,
    useTheme,
    Pagination,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Divider,
    Fade,
    Grow,
    Skeleton,
    Collapse,
    Tooltip,
    LinearProgress,
    Autocomplete,
    Badge,
    alpha,
    Link,
} from '@mui/material';
import {
    Close as CloseIcon,
    Delete as DeleteIcon,
    Search as SearchIcon,
    Refresh as RefreshIcon,
    Person as PersonIcon,
    Verified as VerifiedIcon,
    LocationOn as LocationIcon,
    Star as StarIcon,
    Image as ImageIcon,
    CalendarToday as CalendarIcon,
    Work as WorkIcon,
    ZoomIn as ZoomInIcon,
    PhotoLibrary as PhotoLibraryIcon,
    ExpandMore as ExpandMoreIcon,
    ExpandLess as ExpandLessIcon,
    Favorite as FavoriteIcon,
    Visibility as VisibilityIcon,
    AccessTime as AccessTimeIcon,
    FilterList as FilterListIcon,
    Clear as ClearIcon,
    Dashboard as DashboardIcon,
    TrendingUp as TrendingUpIcon,
    People as PeopleIcon,
    Instagram as InstagramIcon,
    Facebook as FacebookIcon,
    Twitter as TwitterIcon,
    Telegram as TelegramIcon,
    MusicNote as MusicNoteIcon,
    Link as LinkIcon,
} from '@mui/icons-material';
import { portfolioService } from 'services/portfolio.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';

const colors = appConfig.app.colors;

// ─── Social Link Component ──────────────────────────────────────────────
const SocialLink = ({ platform, url }) => {
    if (!url) return null;

    const getIcon = () => {
        switch (platform.toLowerCase()) {
            case 'instagram':
                return <InstagramIcon sx={{ fontSize: 18 }} />;
            case 'facebook':
                return <FacebookIcon sx={{ fontSize: 18 }} />;
            case 'tiktok':
                return <MusicNoteIcon sx={{ fontSize: 18 }} />;
            case 'twitter':
                return <TwitterIcon sx={{ fontSize: 18 }} />;
            case 'telegram':
                return <TelegramIcon sx={{ fontSize: 18 }} />;
            default:
                return <LinkIcon sx={{ fontSize: 18 }} />;
        }
    };

    const getColor = () => {
        switch (platform.toLowerCase()) {
            case 'instagram':
                return '#E4405F';
            case 'facebook':
                return '#1877F2';
            case 'tiktok':
                return '#000000';
            case 'twitter':
                return '#1DA1F2';
            case 'telegram':
                return '#0088CC';
            default:
                return colors.rain;
        }
    };

    const color = getColor();

    return (
        <Tooltip title={`Open ${platform}`}>
            <Link
                href={url}
                target="_blank"
                rel="noopener noreferrer"
                sx={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 0.5,
                    color: color,
                    textDecoration: 'none',
                    padding: '4px 10px',
                    borderRadius: '20px',
                    backgroundColor: alpha(color, 0.08),
                    border: `1px solid ${alpha(color, 0.15)}`,
                    transition: 'all 0.2s ease',
                    fontSize: '0.75rem',
                    fontWeight: 600,
                    '&:hover': {
                        backgroundColor: alpha(color, 0.15),
                        transform: 'translateY(-1px)',
                        boxShadow: `0 2px 8px ${alpha(color, 0.2)}`,
                    },
                }}
            >
                {getIcon()}
                {platform}
            </Link>
        </Tooltip>
    );
};

const PortfoliosList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));

    const [portfolios, setPortfolios] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [pagination, setPagination] = useState({ total: 0, per_page: 20, current_page: 1, last_page: 1 });

    const { can } = usePermissions();
    const canDelete = can('portfolios.delete');

    const [search, setSearch] = useState('');
    const [page, setPage] = useState(1);
    const [perPage, setPerPage] = useState(20);
    const [selectedPortfolio, setSelectedPortfolio] = useState(null);
    const [openViewDialog, setOpenViewDialog] = useState(false);
    const [imageLoaded, setImageLoaded] = useState({});
    const [expandedDescriptions, setExpandedDescriptions] = useState({});
    const [hoveredCard, setHoveredCard] = useState(null);

    const [selectedTechnician, setSelectedTechnician] = useState(null);
    const [technicians, setTechnicians] = useState([]);
    const [showFilters, setShowFilters] = useState(false);

    useEffect(() => {
        if (portfolios.length > 0) {
            const uniqueTechnicians = portfolios
                .map(p => p.technician)
                .filter((tech, index, self) =>
                    tech && self.findIndex(t => t?.id === tech.id) === index
                )
                .filter(tech => tech !== null && tech !== undefined);
            setTechnicians(uniqueTechnicians);
        }
    }, [portfolios]);

    const loadPortfolios = async () => {
        setLoading(true);
        setError(null);
        try {
            const response = await portfolioService.getPortfolios({
                page,
                per_page: perPage,
                search: search || undefined,
            });

            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    let filteredData = data.data;
                    if (selectedTechnician) {
                        filteredData = filteredData.filter(
                            portfolio => portfolio.technician?.id === selectedTechnician.id
                        );
                    }
                    setPortfolios(filteredData);
                    setPagination({
                        total: filteredData.length || 0,
                        per_page: data.per_page || perPage,
                        current_page: data.current_page || 1,
                        last_page: data.last_page || 1,
                    });
                } else if (Array.isArray(data)) {
                    let filteredData = data;
                    if (selectedTechnician) {
                        filteredData = data.filter(
                            portfolio => portfolio.technician?.id === selectedTechnician.id
                        );
                    }
                    setPortfolios(filteredData);
                } else {
                    setPortfolios([]);
                }
            } else {
                setPortfolios([]);
            }
        } catch (err) {
            console.error('Portfolios error:', err);
            setError(err.message || 'Failed to load portfolios');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadPortfolios();
    }, [page, perPage, search, selectedTechnician]);

    const handleRefresh = () => {
        loadPortfolios();
    };

    const handleDeletePortfolio = async (id) => {
        if (!window.confirm('Are you sure you want to delete this portfolio item?')) return;
        try {
            await portfolioService.deletePortfolio(id);
            showSnackbar({ type: 'success', message: 'Portfolio deleted successfully' });
            loadPortfolios();
        } catch (error) {
            showSnackbar({ type: 'error', message: 'Failed to delete portfolio' });
        }
    };

    const handleViewPortfolio = (portfolio) => {
        setSelectedPortfolio(portfolio);
        setOpenViewDialog(true);
    };

    const handleCloseDialog = () => {
        setOpenViewDialog(false);
        setSelectedPortfolio(null);
    };

    const handleImageLoad = (id) => {
        setImageLoaded(prev => ({ ...prev, [id]: true }));
    };

    const toggleDescription = (id) => {
        setExpandedDescriptions(prev => ({
            ...prev,
            [id]: !prev[id]
        }));
    };

    const handleClearFilters = () => {
        setSelectedTechnician(null);
        setSearch('');
        setPage(1);
    };

    const formatDate = (date) => {
        if (!date) return 'N/A';
        const now = new Date();
        const past = new Date(date);
        const diffTime = Math.abs(now - past);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

        if (diffDays === 0) return 'Today';
        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays} days ago`;
        if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
        return past.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
        });
    };

    const truncateText = (text, maxLength = 80) => {
        if (!text) return '';
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength) + '...';
    };

    const getInitials = (name) => {
        if (!name) return '?';
        return name
            .split(' ')
            .map(word => word[0])
            .join('')
            .toUpperCase()
            .substring(0, 2);
    };

    // ─── Get social links from portfolio ────────────────────────────────
    const getSocialLinks = (portfolio) => {
        // Check if social_links exists directly or in the response
        const socialLinks = portfolio.social_links || portfolio.socialLinks || {};
        const links = [];

        const platforms = ['instagram', 'facebook', 'tiktok', 'twitter', 'telegram'];
        platforms.forEach(platform => {
            if (socialLinks[platform]) {
                links.push({ platform, url: socialLinks[platform] });
            }
        });

        return links;
    };

    const hasSocialLinks = (portfolio) => {
        return getSocialLinks(portfolio).length > 0;
    };

    const groupPortfoliosByTechnician = () => {
        const groups = {};
        portfolios.forEach(portfolio => {
            const techId = portfolio.technician?.id;
            if (!techId) return;
            if (!groups[techId]) {
                groups[techId] = {
                    technician: portfolio.technician,
                    portfolios: []
                };
            }
            groups[techId].portfolios.push(portfolio);
        });
        return Object.values(groups);
    };

    const technicianGroups = groupPortfoliosByTechnician();

    const renderSkeletons = () => {
        const count = isMobile ? 2 : 4;
        return Array.from({ length: count }).map((_, index) => (
            <Grid item xs={12} sm={6} key={`skeleton-${index}`}>
                <Card sx={{ borderRadius: 3, overflow: 'hidden', height: '100%' }}>
                    <Skeleton variant="rectangular" height={200} animation="wave" />
                    <CardContent>
                        <Skeleton variant="text" width="60%" height={24} animation="wave" />
                        <Skeleton variant="text" width="40%" height={20} animation="wave" />
                    </CardContent>
                </Card>
            </Grid>
        ));
    };

    if (error) {
        return (
            <Box p={3}>
                <Alert
                    severity="error"
                    action={
                        <Button color="inherit" size="small" onClick={() => { setError(null); loadPortfolios(); }}>
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
        <Box sx={{
            width: '100%',
            p: { xs: 1.5, sm: 2.5, md: 3.5 },
            background: `linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)`,
            minHeight: '100vh',
        }}>
            {/* Main Container */}
            <Paper sx={{
                width: '100%',
                borderRadius: { xs: 2, sm: 3 },
                overflow: 'hidden',
                boxShadow: '0 8px 40px rgba(0,0,0,0.06)',
                p: { xs: 2, sm: 3, md: 4 },
                backgroundColor: 'rgba(255,255,255,0.95)',
                backdropFilter: 'blur(10px)',
                border: '1px solid rgba(0,0,0,0.04)',
            }}>
                {/* ===== HEADER SECTION ===== */}
                <Box
                    sx={{
                        display: 'flex',
                        alignItems: { xs: 'flex-start', sm: 'center' },
                        justifyContent: 'space-between',
                        flexDirection: { xs: 'column', sm: 'row' },
                        gap: 2,
                        mb: 3,
                    }}
                >
                    <Box display="flex" alignItems="center" gap={2}>
                        <Box
                            sx={{
                                width: 52,
                                height: 52,
                                borderRadius: 2.5,
                                background: `linear-gradient(135deg, ${colors.sea}15, ${colors.sea}08)`,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                border: `1px solid ${colors.sea}20`,
                            }}
                        >
                            <PhotoLibraryIcon sx={{ color: colors.sea, fontSize: 28 }} />
                        </Box>
                        <Box>
                            <Typography
                                variant="h5"
                                fontWeight="800"
                                sx={{
                                    fontSize: { xs: '1.3rem', sm: '1.6rem', md: '1.9rem' },
                                    color: colors.dark,
                                    letterSpacing: '-0.5px',
                                    lineHeight: 1.2,
                                }}
                            >
                                Portfolios
                            </Typography>
                            <Typography
                                variant="body2"
                                sx={{
                                    color: colors.rain,
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: 0.5,
                                    mt: 0.25,
                                }}
                            >
                                Showcasing technician work and expertise
                            </Typography>
                        </Box>
                    </Box>

                    <Box display="flex" gap={1.5} alignItems="center" flexWrap="wrap" sx={{ width: { xs: '100%', sm: 'auto' } }}>
                        <Button
                            variant="outlined"
                            startIcon={<FilterListIcon />}
                            onClick={() => setShowFilters(!showFilters)}
                            size="medium"
                            sx={{
                                borderColor: showFilters ? colors.sea : colors.middle,
                                color: showFilters ? colors.sea : colors.rain,
                                height: 44,
                                borderRadius: 2.5,
                                textTransform: 'none',
                                fontWeight: 600,
                                fontSize: '0.875rem',
                                px: 2.5,
                                transition: 'all 0.2s',
                                '&:hover': {
                                    borderColor: colors.sea,
                                    backgroundColor: alpha(colors.sea, 0.06),
                                    transform: 'translateY(-1px)',
                                },
                            }}
                        >
                            {showFilters ? 'Hide Filters' : 'Filters'}
                            {selectedTechnician && (
                                <Badge
                                    badgeContent={1}
                                    color="primary"
                                    sx={{
                                        '& .MuiBadge-badge': {
                                            backgroundColor: colors.sea,
                                            fontSize: '0.6rem',
                                            height: 18,
                                            minWidth: 18,
                                        },
                                    }}
                                />
                            )}
                        </Button>
                        <TextField
                            placeholder="Search portfolios..."
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
                                width: { xs: '100%', sm: 200, md: 260 },
                                '& .MuiInputBase-root': {
                                    backgroundColor: '#f8fafc',
                                    borderRadius: 2.5,
                                    height: 44,
                                    transition: 'all 0.25s ease',
                                    '&:hover': {
                                        backgroundColor: '#f1f5f9',
                                    },
                                    '&.Mui-focused': {
                                        backgroundColor: '#ffffff',
                                        boxShadow: `0 0 0 3px ${alpha(colors.sea, 0.15)}`,
                                        transform: 'scale(1.01)',
                                    },
                                },
                                '& .MuiOutlinedInput-notchedOutline': {
                                    borderColor: colors.middle + '50',
                                },
                            }}
                        />
                        <Button
                            variant="contained"
                            startIcon={<RefreshIcon />}
                            onClick={handleRefresh}
                            disabled={loading}
                            sx={{
                                background: `linear-gradient(135deg, ${colors.sea}, ${colors.dark})`,
                                height: 44,
                                minWidth: 110,
                                borderRadius: 2.5,
                                textTransform: 'none',
                                fontWeight: 700,
                                fontSize: '0.875rem',
                                boxShadow: `0 4px 16px ${alpha(colors.sea, 0.3)}`,
                                '&:hover': {
                                    transform: 'translateY(-2px)',
                                    boxShadow: `0 8px 24px ${alpha(colors.sea, 0.4)}`,
                                },
                                transition: 'all 0.25s ease',
                            }}
                        >
                            Refresh
                        </Button>
                    </Box>
                </Box>

                {/* ===== FILTERS SECTION ===== */}
                <Collapse in={showFilters}>
                    <Box
                        sx={{
                            p: 3,
                            mb: 3,
                            background: `linear-gradient(135deg, #f8fafc, #f1f5f9)`,
                            borderRadius: 2.5,
                            border: `1px solid ${alpha(colors.middle, 0.2)}`,
                        }}
                    >
                        <Box display="flex" alignItems="center" justifyContent="space-between" mb={2.5}>
                            <Typography variant="subtitle1" sx={{ fontWeight: 700, color: colors.dark }}>
                                Filter Portfolios
                            </Typography>
                            {(selectedTechnician || search) && (
                                <Button
                                    size="small"
                                    startIcon={<ClearIcon />}
                                    onClick={handleClearFilters}
                                    sx={{
                                        color: colors.rain,
                                        textTransform: 'none',
                                        fontWeight: 600,
                                        '&:hover': {
                                            color: colors.dark,
                                            backgroundColor: alpha(colors.dark, 0.04),
                                        },
                                    }}
                                >
                                    Clear All
                                </Button>
                            )}
                        </Box>

                        <Grid container spacing={2.5}>
                            <Grid item xs={12} md={6}>
                                <Autocomplete
                                    options={technicians}
                                    getOptionLabel={(option) => option?.name || ''}
                                    value={selectedTechnician}
                                    onChange={(event, newValue) => {
                                        setSelectedTechnician(newValue);
                                        setPage(1);
                                    }}
                                    renderInput={(params) => (
                                        <TextField
                                            {...params}
                                            label="Filter by Technician"
                                            variant="outlined"
                                            size="medium"
                                            placeholder="Select technician..."
                                            InputProps={{
                                                ...params.InputProps,
                                                startAdornment: (
                                                    <>
                                                        <InputAdornment position="start">
                                                            <PersonIcon sx={{ color: colors.rain, fontSize: 20 }} />
                                                        </InputAdornment>
                                                        {params.InputProps.startAdornment}
                                                    </>
                                                ),
                                            }}
                                            sx={{
                                                '& .MuiOutlinedInput-root': {
                                                    backgroundColor: '#ffffff',
                                                    borderRadius: 2,
                                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                                        borderColor: colors.sea,
                                                        borderWidth: 2,
                                                    },
                                                    '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                                        borderColor: colors.sea,
                                                        borderWidth: 2,
                                                    },
                                                },
                                                '& .MuiInputLabel-root': {
                                                    color: colors.rain,
                                                    '&.Mui-focused': {
                                                        color: colors.sea,
                                                    },
                                                },
                                            }}
                                        />
                                    )}
                                    renderOption={(props, option) => (
                                        <Box component="li" {...props} sx={{ py: 1.5, px: 2 }}>
                                            <Box display="flex" alignItems="center" gap={2} width="100%">
                                                <Avatar
                                                    src={option?.profile_photo || undefined}
                                                    sx={{
                                                        width: 36,
                                                        height: 36,
                                                        bgcolor: colors.sea,
                                                        fontSize: '0.85rem',
                                                        fontWeight: 600,
                                                    }}
                                                >
                                                    {getInitials(option?.name)}
                                                </Avatar>
                                                <Box flex={1}>
                                                    <Typography variant="body2" sx={{ fontWeight: 600, color: colors.dark }}>
                                                        {option?.name || 'Unknown'}
                                                    </Typography>
                                                    {option?.area && (
                                                        <Typography variant="caption" sx={{ color: colors.rain, display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                                            <LocationIcon sx={{ fontSize: 12 }} />
                                                            {option.area}
                                                        </Typography>
                                                    )}
                                                </Box>
                                                {option?.verified && (
                                                    <VerifiedIcon sx={{ fontSize: 18, color: colors.salat }} />
                                                )}
                                                {option?.rating > 0 && (
                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                        <StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />
                                                        <Typography variant="caption" sx={{ fontWeight: 700 }}>
                                                            {option.rating.toFixed(1)}
                                                        </Typography>
                                                    </Box>
                                                )}
                                            </Box>
                                        </Box>
                                    )}
                                    isOptionEqualToValue={(option, value) => option?.id === value?.id}
                                />
                            </Grid>

                            <Grid item xs={12} md={6}>
                                <Box display="flex" alignItems="center" gap={1.5} flexWrap="wrap" sx={{ height: '100%' }}>
                                    <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 600 }}>
                                        Active Filters:
                                    </Typography>
                                    {selectedTechnician && (
                                        <Chip
                                            avatar={
                                                <Avatar
                                                    src={selectedTechnician?.profile_photo || undefined}
                                                    sx={{ width: 24, height: 24 }}
                                                >
                                                    {getInitials(selectedTechnician?.name)}
                                                </Avatar>
                                            }
                                            label={selectedTechnician.name}
                                            onDelete={() => {
                                                setSelectedTechnician(null);
                                                setPage(1);
                                            }}
                                            sx={{
                                                backgroundColor: alpha(colors.sea, 0.12),
                                                color: colors.sea,
                                                fontWeight: 600,
                                                '& .MuiChip-deleteIcon': {
                                                    color: colors.sea,
                                                    fontSize: 18,
                                                },
                                            }}
                                        />
                                    )}
                                    {!selectedTechnician && !search && (
                                        <Typography variant="caption" sx={{ color: colors.rain, fontStyle: 'italic' }}>
                                            No filters applied
                                        </Typography>
                                    )}
                                </Box>
                            </Grid>
                        </Grid>
                    </Box>
                </Collapse>

                {/* ===== STATISTICS BANNER ===== */}
                {portfolios.length > 0 && (
                    <Box
                        sx={{
                            display: 'grid',
                            gridTemplateColumns: { xs: 'repeat(2, 1fr)', sm: 'repeat(3, 1fr)', md: 'repeat(4, 1fr)' },
                            gap: 2,
                            mb: 4,
                            p: 2.5,
                            background: `linear-gradient(135deg, ${alpha(colors.sea, 0.04)}, ${alpha(colors.sea, 0.01)})`,
                            borderRadius: 2.5,
                            border: `1px solid ${alpha(colors.middle, 0.15)}`,
                        }}
                    >
                        <Box display="flex" alignItems="center" gap={1.5}>
                            <Box sx={{
                                p: 1,
                                borderRadius: 2,
                                background: alpha(colors.sea, 0.12),
                            }}>
                                <PhotoLibraryIcon sx={{ fontSize: 22, color: colors.sea }} />
                            </Box>
                            <Box>
                                <Typography variant="h6" sx={{ color: colors.dark, fontWeight: 700, lineHeight: 1.2 }}>
                                    {portfolios.length}
                                </Typography>
                                <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                    Portfolio{portfolios.length !== 1 ? 's' : ''}
                                </Typography>
                            </Box>
                        </Box>

                        <Box display="flex" alignItems="center" gap={1.5}>
                            <Box sx={{
                                p: 1,
                                borderRadius: 2,
                                background: alpha('#8b5cf6', 0.12),
                            }}>
                                <PeopleIcon sx={{ fontSize: 22, color: '#8b5cf6' }} />
                            </Box>
                            <Box>
                                <Typography variant="h6" sx={{ color: colors.dark, fontWeight: 700, lineHeight: 1.2 }}>
                                    {technicianGroups.length}
                                </Typography>
                                <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                    Technician{technicianGroups.length !== 1 ? 's' : ''}
                                </Typography>
                            </Box>
                        </Box>

                        <Box display="flex" alignItems="center" gap={1.5}>
                            <Box sx={{
                                p: 1,
                                borderRadius: 2,
                                background: alpha('#f59e0b', 0.12),
                            }}>
                                <TrendingUpIcon sx={{ fontSize: 22, color: '#f59e0b' }} />
                            </Box>
                            <Box>
                                <Typography variant="h6" sx={{ color: colors.dark, fontWeight: 700, lineHeight: 1.2 }}>
                                    {portfolios.filter(p => p.created_at && new Date(p.created_at) > new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)).length}
                                </Typography>
                                <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                    Last 30 days
                                </Typography>
                            </Box>
                        </Box>

                        {selectedTechnician && (
                            <Box display="flex" alignItems="center" gap={1.5}>
                                <Box sx={{
                                    p: 1,
                                    borderRadius: 2,
                                    background: alpha(colors.salat, 0.12),
                                }}>
                                    <PersonIcon sx={{ fontSize: 22, color: colors.salat }} />
                                </Box>
                                <Box flex={1} minWidth={0}>
                                    <Typography variant="h6" sx={{ color: colors.dark, fontWeight: 700, lineHeight: 1.2, fontSize: '0.95rem' }}>
                                        {selectedTechnician.name}
                                    </Typography>
                                    <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                        Filtered view
                                    </Typography>
                                </Box>
                            </Box>
                        )}
                    </Box>
                )}

                {/* ===== PORTFOLIO GRID ===== */}
                {loading && portfolios.length === 0 ? (
                    <Grid container spacing={3}>
                        {renderSkeletons()}
                    </Grid>
                ) : portfolios.length === 0 ? (
                    <Box
                        textAlign="center"
                        py={10}
                        sx={{
                            background: `linear-gradient(135deg, #f8fafc, #f1f5f9)`,
                            borderRadius: 3,
                            border: `2px dashed ${alpha(colors.middle, 0.3)}`,
                        }}
                    >
                        <PhotoLibraryIcon sx={{ fontSize: 72, color: alpha(colors.middle, 0.5), mb: 2 }} />
                        <Typography variant="h5" sx={{ color: colors.dark, fontWeight: 600, mb: 1 }}>
                            No portfolios found
                        </Typography>
                        <Typography variant="body2" sx={{ color: colors.rain }}>
                            {search || selectedTechnician ? 'No results match your filters' : 'Portfolios will appear here once created'}
                        </Typography>
                        {(search || selectedTechnician) && (
                            <Button
                                variant="outlined"
                                onClick={handleClearFilters}
                                sx={{
                                    mt: 3,
                                    borderColor: colors.middle,
                                    borderRadius: 2.5,
                                    textTransform: 'none',
                                    fontWeight: 600,
                                    '&:hover': {
                                        borderColor: colors.sea,
                                        backgroundColor: alpha(colors.sea, 0.06),
                                    },
                                }}
                            >
                                Clear Filters
                            </Button>
                        )}
                    </Box>
                ) : (
                    <Stack spacing={4}>
                        {technicianGroups.map((group, groupIndex) => (
                            <Box key={groupIndex}>
                                {/* Technician Header */}
                                <Paper
                                    elevation={0}
                                    sx={{
                                        p: 2.5,
                                        mb: 2.5,
                                        background: `linear-gradient(135deg, #f8fafc, #ffffff)`,
                                        borderRadius: 2.5,
                                        border: `1px solid ${alpha(colors.middle, 0.15)}`,
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'space-between',
                                        flexWrap: 'wrap',
                                        gap: 2,
                                        transition: 'all 0.3s ease',
                                        '&:hover': {
                                            borderColor: alpha(colors.sea, 0.3),
                                            boxShadow: '0 4px 20px rgba(0,0,0,0.04)',
                                        },
                                    }}
                                >
                                    <Box display="flex" alignItems="center" gap={2.5}>
                                        <Avatar
                                            src={group.technician?.profile_photo || undefined}
                                            sx={{
                                                width: 64,
                                                height: 64,
                                                bgcolor: colors.sea,
                                                fontSize: '1.4rem',
                                                fontWeight: 700,
                                                border: `3px solid ${alpha(colors.sea, 0.15)}`,
                                            }}
                                        >
                                            {getInitials(group.technician?.name)}
                                        </Avatar>
                                        <Box>
                                            <Box display="flex" alignItems="center" gap={1.5}>
                                                <Typography variant="h6" fontWeight="700" sx={{ color: colors.dark }}>
                                                    {group.technician?.name || 'Unknown'}
                                                </Typography>
                                                {group.technician?.verified && (
                                                    <VerifiedIcon sx={{ fontSize: 20, color: colors.salat }} />
                                                )}
                                            </Box>
                                            <Box display="flex" alignItems="center" gap={2.5} flexWrap="wrap" sx={{ mt: 0.75 }}>
                                                {group.technician?.area && (
                                                    <Box display="flex" alignItems="center" gap={0.75}>
                                                        <LocationIcon sx={{ fontSize: 16, color: colors.rain }} />
                                                        <Typography variant="body2" sx={{ color: colors.rain }}>
                                                            {group.technician.area}
                                                        </Typography>
                                                    </Box>
                                                )}
                                                {group.technician?.rating > 0 && (
                                                    <Box display="flex" alignItems="center" gap={0.75}>
                                                        <StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />
                                                        <Typography variant="body2" sx={{ color: colors.dark, fontWeight: 600 }}>
                                                            {group.technician.rating.toFixed(1)}
                                                        </Typography>
                                                    </Box>
                                                )}
                                                {group.technician?.services && group.technician.services.length > 0 && (
                                                    <Box display="flex" alignItems="center" gap={0.75}>
                                                        <WorkIcon sx={{ fontSize: 16, color: colors.rain }} />
                                                        <Typography variant="body2" sx={{ color: colors.rain }}>
                                                            {group.technician.services.slice(0, 3).join(', ')}
                                                            {group.technician.services.length > 3 && ` +${group.technician.services.length - 3}`}
                                                        </Typography>
                                                    </Box>
                                                )}
                                            </Box>
                                        </Box>
                                    </Box>
                                    <Chip
                                        icon={<PhotoLibraryIcon sx={{ fontSize: 18 }} />}
                                        label={`${group.portfolios.length} Portfolio${group.portfolios.length !== 1 ? 's' : ''}`}
                                        sx={{
                                            backgroundColor: alpha(colors.sea, 0.12),
                                            color: colors.sea,
                                            fontWeight: 700,
                                            fontSize: '0.85rem',
                                            height: 36,
                                            '& .MuiChip-icon': {
                                                color: colors.sea,
                                            },
                                        }}
                                    />
                                </Paper>

                                {/* Portfolios Grid */}
                                <Grid container spacing={3}>
                                    {group.portfolios.map((portfolio, index) => {
                                        const isExpanded = expandedDescriptions[portfolio.id] || false;
                                        const isHovered = hoveredCard === portfolio.id;
                                        const description = portfolio.description || 'No description available';
                                        const shouldTruncate = description.length > 80;
                                        const socialLinks = getSocialLinks(portfolio);

                                        return (
                                            <Grid
                                                item
                                                xs={12}
                                                sm={6}
                                                md={4}
                                                lg={3}
                                                key={portfolio.id}
                                                sx={{ display: 'flex' }}
                                            >
                                                <Grow in={true} timeout={300 + (index * 60)} style={{ width: '100%' }}>
                                                    <Card
                                                        sx={{
                                                            borderRadius: 3,
                                                            overflow: 'hidden',
                                                            width: '100%',
                                                            display: 'flex',
                                                            flexDirection: 'column',
                                                            transition: 'all 0.4s cubic-bezier(0.4, 0, 0.2, 1)',
                                                            border: `1px solid ${alpha(colors.middle, 0.15)}`,
                                                            backgroundColor: '#ffffff',
                                                            '&:hover': {
                                                                transform: 'translateY(-8px)',
                                                                boxShadow: '0 16px 48px rgba(0,0,0,0.08)',
                                                                borderColor: alpha(colors.sea, 0.3),
                                                            },
                                                            position: 'relative',
                                                        }}
                                                        onMouseEnter={() => setHoveredCard(portfolio.id)}
                                                        onMouseLeave={() => setHoveredCard(null)}
                                                    >
                                                        {/* Image Section */}
                                                        <Box
                                                            sx={{
                                                                position: 'relative',
                                                                width: '100%',
                                                                paddingTop: '75%',
                                                                backgroundColor: '#f8fafc',
                                                                overflow: 'hidden',
                                                                cursor: 'pointer',
                                                                flexShrink: 0,
                                                            }}
                                                            onClick={() => handleViewPortfolio(portfolio)}
                                                        >
                                                            {!imageLoaded[portfolio.id] && (
                                                                <Box
                                                                    sx={{
                                                                        position: 'absolute',
                                                                        top: 0,
                                                                        left: 0,
                                                                        width: '100%',
                                                                        height: '100%',
                                                                        display: 'flex',
                                                                        alignItems: 'center',
                                                                        justifyContent: 'center',
                                                                        backgroundColor: '#f8fafc',
                                                                        zIndex: 1,
                                                                    }}
                                                                >
                                                                    <CircularProgress size={40} sx={{ color: colors.sea }} />
                                                                </Box>
                                                            )}
                                                            <img
                                                                src={portfolio.image || '/placeholder-image.jpg'}
                                                                alt={portfolio.description || 'Portfolio item'}
                                                                style={{
                                                                    position: 'absolute',
                                                                    top: 0,
                                                                    left: 0,
                                                                    width: '100%',
                                                                    height: '100%',
                                                                    objectFit: 'cover',
                                                                    display: 'block',
                                                                    transition: 'transform 0.6s ease',
                                                                    transform: isHovered ? 'scale(1.06)' : 'scale(1)',
                                                                }}
                                                                onLoad={() => handleImageLoad(portfolio.id)}
                                                            />

                                                            {/* Gradient Overlay */}
                                                            <Box
                                                                sx={{
                                                                    position: 'absolute',
                                                                    bottom: 0,
                                                                    left: 0,
                                                                    right: 0,
                                                                    height: '45%',
                                                                    background: 'linear-gradient(to top, rgba(0,0,0,0.5) 0%, transparent 100%)',
                                                                    opacity: isHovered ? 1 : 0.7,
                                                                    transition: 'opacity 0.4s ease',
                                                                }}
                                                            />

                                                            {/* Quick Actions */}
                                                            <Box
                                                                sx={{
                                                                    position: 'absolute',
                                                                    top: 10,
                                                                    right: 10,
                                                                    display: 'flex',
                                                                    gap: 0.5,
                                                                    zIndex: 2,
                                                                }}
                                                            >
                                                                <Tooltip title="View Details">
                                                                    <IconButton
                                                                        size="small"
                                                                        sx={{
                                                                            backgroundColor: 'rgba(0,0,0,0.5)',
                                                                            color: 'white',
                                                                            backdropFilter: 'blur(8px)',
                                                                            width: 32,
                                                                            height: 32,
                                                                            transition: 'all 0.2s ease',
                                                                            '&:hover': {
                                                                                backgroundColor: 'rgba(0,0,0,0.7)',
                                                                                transform: 'scale(1.1)',
                                                                            },
                                                                        }}
                                                                        onClick={(e) => {
                                                                            e.stopPropagation();
                                                                            handleViewPortfolio(portfolio);
                                                                        }}
                                                                    >
                                                                        <ZoomInIcon sx={{ fontSize: 16 }} />
                                                                    </IconButton>
                                                                </Tooltip>
                                                                {canDelete && (
                                                                    <Tooltip title="Delete">
                                                                        <IconButton
                                                                            size="small"
                                                                            sx={{
                                                                                backgroundColor: 'rgba(220,38,38,0.7)',
                                                                                color: 'white',
                                                                                backdropFilter: 'blur(8px)',
                                                                                width: 32,
                                                                                height: 32,
                                                                                transition: 'all 0.2s ease',
                                                                                '&:hover': {
                                                                                    backgroundColor: 'rgb(220,38,38)',
                                                                                    transform: 'scale(1.1)',
                                                                                },
                                                                            }}
                                                                            onClick={(e) => {
                                                                                e.stopPropagation();
                                                                                handleDeletePortfolio(portfolio.id);
                                                                            }}
                                                                        >
                                                                            <DeleteIcon sx={{ fontSize: 16 }} />
                                                                        </IconButton>
                                                                    </Tooltip>
                                                                )}
                                                            </Box>

                                                            {/* Verified Badge */}
                                                            {portfolio.technician?.verified && (
                                                                <Box
                                                                    sx={{
                                                                        position: 'absolute',
                                                                        top: 10,
                                                                        left: 10,
                                                                        zIndex: 2,
                                                                    }}
                                                                >
                                                                    <Tooltip title="Verified Technician">
                                                                        <VerifiedIcon sx={{ color: colors.salat, fontSize: 20 }} />
                                                                    </Tooltip>
                                                                </Box>
                                                            )}
                                                        </Box>

                                                        {/* Card Content */}
                                                        <Box
                                                            sx={{
                                                                flex: 1,
                                                                display: 'flex',
                                                                flexDirection: 'column',
                                                                p: 2.5,
                                                                pb: 1.5,
                                                            }}
                                                        >
                                                            {portfolio.technician?.rating > 0 && (
                                                                <Box display="flex" alignItems="center" gap={0.75} mb={1}>
                                                                    <StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />
                                                                    <Typography variant="body2" sx={{ fontWeight: 700, color: colors.dark }}>
                                                                        {portfolio.technician.rating.toFixed(1)}
                                                                    </Typography>
                                                                    <Typography variant="caption" sx={{ color: colors.rain }}>
                                                                        rating
                                                                    </Typography>
                                                                </Box>
                                                            )}

                                                            <Typography
                                                                variant="body2"
                                                                sx={{
                                                                    color: colors.black,
                                                                    lineHeight: 1.7,
                                                                    fontSize: '0.85rem',
                                                                    mb: 0.5,
                                                                    flex: 1,
                                                                }}
                                                            >
                                                                {isExpanded ? description : truncateText(description, 80)}
                                                            </Typography>

                                                            {isExpanded && group.technician?.services?.length > 0 && (
                                                                <Box sx={{ mt: 1.5, mb: 1 }}>
                                                                    <Typography
                                                                        variant="caption"
                                                                        sx={{
                                                                            color: colors.rain,
                                                                            fontWeight: 600,
                                                                            display: 'block',
                                                                            mb: 0.75,
                                                                            fontSize: '0.7rem',
                                                                            textTransform: 'uppercase',
                                                                            letterSpacing: '0.5px',
                                                                        }}
                                                                    >
                                                                        Services
                                                                    </Typography>
                                                                    <Box display="flex" gap={0.75} flexWrap="wrap">
                                                                        {group.technician.services.slice(0, 4).map((service, idx) => (
                                                                            <Chip
                                                                                key={idx}
                                                                                label={service}
                                                                                size="small"
                                                                                sx={{
                                                                                    backgroundColor: alpha(colors.sea, 0.08),
                                                                                    color: colors.sea,
                                                                                    fontSize: '0.65rem',
                                                                                    height: 24,
                                                                                    fontWeight: 600,
                                                                                }}
                                                                            />
                                                                        ))}
                                                                        {group.technician.services.length > 4 && (
                                                                            <Chip
                                                                                label={`+${group.technician.services.length - 4}`}
                                                                                size="small"
                                                                                sx={{
                                                                                    backgroundColor: alpha(colors.middle, 0.15),
                                                                                    color: colors.rain,
                                                                                    fontSize: '0.65rem',
                                                                                    height: 24,
                                                                                    fontWeight: 600,
                                                                                }}
                                                                            />
                                                                        )}
                                                                    </Box>
                                                                </Box>
                                                            )}

                                                            {shouldTruncate && (
                                                                <Button
                                                                    size="small"
                                                                    onClick={() => toggleDescription(portfolio.id)}
                                                                    sx={{
                                                                        color: colors.sea,
                                                                        textTransform: 'none',
                                                                        fontWeight: 700,
                                                                        fontSize: '0.75rem',
                                                                        p: 0,
                                                                        minWidth: 'auto',
                                                                        alignSelf: 'flex-start',
                                                                        '&:hover': {
                                                                            backgroundColor: 'transparent',
                                                                            color: colors.dark,
                                                                        },
                                                                    }}
                                                                    endIcon={isExpanded ? <ExpandLessIcon fontSize="small" /> : <ExpandMoreIcon fontSize="small" />}
                                                                >
                                                                    {isExpanded ? 'Read Less' : 'Read More'}
                                                                </Button>
                                                            )}

                                                            {/* ─── SOCIAL LINKS ──────────────────────────────── */}
                                                            {socialLinks.length > 0 && (
                                                                <Box sx={{ mt: 1.5, mb: 0.5 }}>
                                                                    <Typography
                                                                        variant="caption"
                                                                        sx={{
                                                                            color: colors.rain,
                                                                            fontWeight: 600,
                                                                            display: 'block',
                                                                            mb: 0.75,
                                                                            fontSize: '0.7rem',
                                                                            textTransform: 'uppercase',
                                                                            letterSpacing: '0.5px',
                                                                        }}
                                                                    >
                                                                        Connect
                                                                    </Typography>
                                                                    <Box display="flex" gap={1} flexWrap="wrap">
                                                                        {socialLinks.map((link, idx) => (
                                                                            <SocialLink
                                                                                key={idx}
                                                                                platform={link.platform}
                                                                                url={link.url}
                                                                            />
                                                                        ))}
                                                                    </Box>
                                                                </Box>
                                                            )}
                                                        </Box>

                                                        {/* Card Footer */}
                                                        <Box
                                                            sx={{
                                                                p: 2,
                                                                pt: 1.5,
                                                                borderTop: `1px solid ${alpha(colors.middle, 0.08)}`,
                                                                display: 'flex',
                                                                justifyContent: 'space-between',
                                                                alignItems: 'center',
                                                                flexShrink: 0,
                                                            }}
                                                        >
                                                            <Box display="flex" alignItems="center" gap={0.75}>
                                                                <AccessTimeIcon sx={{ fontSize: 14, color: colors.rain }} />
                                                                <Typography variant="caption" sx={{ color: colors.rain, fontSize: '0.7rem', fontWeight: 500 }}>
                                                                    {formatDate(portfolio.created_at)}
                                                                </Typography>
                                                            </Box>
                                                            {portfolio.technician?.area && (
                                                                <Box display="flex" alignItems="center" gap={0.75}>
                                                                    <LocationIcon sx={{ fontSize: 14, color: colors.rain }} />
                                                                    <Typography variant="caption" sx={{ color: colors.rain, fontSize: '0.7rem', fontWeight: 500 }}>
                                                                        {portfolio.technician.area}
                                                                    </Typography>
                                                                </Box>
                                                            )}
                                                            <Tooltip title="View Details">
                                                                <IconButton
                                                                    size="small"
                                                                    onClick={() => handleViewPortfolio(portfolio)}
                                                                    sx={{
                                                                        color: colors.rain,
                                                                        padding: 0.5,
                                                                        transition: 'all 0.2s ease',
                                                                        '&:hover': {
                                                                            backgroundColor: alpha(colors.sea, 0.08),
                                                                            color: colors.sea,
                                                                            transform: 'scale(1.1)',
                                                                        },
                                                                    }}
                                                                >
                                                                    <VisibilityIcon sx={{ fontSize: 18 }} />
                                                                </IconButton>
                                                            </Tooltip>
                                                        </Box>

                                                        {/* Hover Indicator */}
                                                        <LinearProgress
                                                            variant="determinate"
                                                            value={isHovered ? 100 : 0}
                                                            sx={{
                                                                height: 3,
                                                                backgroundColor: 'transparent',
                                                                '& .MuiLinearProgress-bar': {
                                                                    background: `linear-gradient(90deg, ${colors.sea}, ${colors.dark})`,
                                                                    transition: 'transform 0.4s ease',
                                                                },
                                                                position: 'absolute',
                                                                bottom: 0,
                                                                left: 0,
                                                                right: 0,
                                                                borderRadius: 0,
                                                            }}
                                                        />
                                                    </Card>
                                                </Grow>
                                            </Grid>
                                        );
                                    })}
                                </Grid>
                            </Box>
                        ))}
                    </Stack>
                )}

                {/* ===== PAGINATION ===== */}
                {portfolios.length > 0 && (
                    <Box
                        display="flex"
                        justifyContent="center"
                        alignItems="center"
                        mt={4.5}
                        gap={2.5}
                        flexWrap="wrap"
                        sx={{
                            pt: 3.5,
                            borderTop: `1px solid ${alpha(colors.middle, 0.15)}`,
                        }}
                    >
                        <Pagination
                            count={pagination.last_page || 1}
                            page={page}
                            onChange={(e, value) => setPage(value)}
                            sx={{
                                '& .MuiPaginationItem-root': {
                                    borderRadius: 2,
                                    fontWeight: 600,
                                    fontSize: '0.9rem',
                                    transition: 'all 0.2s ease',
                                    '&:hover': {
                                        backgroundColor: alpha(colors.sea, 0.08),
                                    },
                                },
                                '& .Mui-selected': {
                                    background: `linear-gradient(135deg, ${colors.sea}, ${colors.dark}) !important`,
                                    color: '#ffffff !important',
                                    boxShadow: `0 4px 16px ${alpha(colors.sea, 0.3)}`,
                                    '&:hover': {
                                        transform: 'translateY(-2px)',
                                        boxShadow: `0 8px 24px ${alpha(colors.sea, 0.4)}`,
                                    },
                                },
                            }}
                            size={isMobile ? "small" : "medium"}
                        />
                        <FormControl size="small" sx={{ minWidth: 110 }}>
                            <InputLabel sx={{ color: colors.rain, fontWeight: 500 }}>Per Page</InputLabel>
                            <Select
                                value={perPage}
                                label="Per Page"
                                onChange={(e) => {
                                    setPerPage(e.target.value);
                                    setPage(1);
                                }}
                                sx={{
                                    borderRadius: 2.5,
                                    fontWeight: 600,
                                    '& .MuiOutlinedInput-notchedOutline': {
                                        borderColor: alpha(colors.middle, 0.3),
                                    },
                                    '&:hover .MuiOutlinedInput-notchedOutline': {
                                        borderColor: colors.sea,
                                    },
                                }}
                            >
                                <MenuItem value={10}>10</MenuItem>
                                <MenuItem value={20}>20</MenuItem>
                                <MenuItem value={50}>50</MenuItem>
                                <MenuItem value={100}>100</MenuItem>
                            </Select>
                        </FormControl>
                        <Typography variant="body2" sx={{ color: colors.rain, fontWeight: 500 }}>
                            {portfolios.length} total portfolio{portfolios.length !== 1 ? 's' : ''}
                        </Typography>
                    </Box>
                )}

                {/* ===== DETAIL DIALOG ===== */}
                <Dialog
                    open={openViewDialog}
                    onClose={handleCloseDialog}
                    maxWidth="lg"
                    fullWidth
                    fullScreen={isMobile}
                    TransitionComponent={Fade}
                    PaperProps={{
                        sx: {
                            borderRadius: { xs: 0, sm: 3 },
                            backgroundColor: '#ffffff',
                            maxHeight: '95vh',
                            overflow: 'hidden',
                        }
                    }}
                >
                    {selectedPortfolio && (
                        <>
                            <DialogTitle sx={{
                                color: colors.dark,
                                borderBottom: `1px solid ${alpha(colors.middle, 0.15)}`,
                                pb: 2,
                                backgroundColor: '#ffffff',
                                px: { xs: 2, sm: 3 },
                            }}>
                                <Box display="flex" justifyContent="space-between" alignItems="flex-start">
                                    <Box minWidth={0} flex={1}>
                                        <Typography variant="h6" sx={{ color: colors.dark, fontWeight: 700 }}>
                                            Portfolio Details
                                        </Typography>
                                        <Box display="flex" alignItems="center" gap={1.5} mt={1} flexWrap="wrap">
                                            <Avatar
                                                src={selectedPortfolio.technician?.profile_photo || undefined}
                                                sx={{
                                                    width: 36,
                                                    height: 36,
                                                    bgcolor: colors.sea,
                                                    fontSize: '0.9rem',
                                                    fontWeight: 700,
                                                }}
                                            >
                                                {getInitials(selectedPortfolio.technician?.name)}
                                            </Avatar>
                                            <Typography variant="body1" sx={{ color: colors.black, fontWeight: 600 }}>
                                                {selectedPortfolio.technician?.name || 'Unknown'}
                                            </Typography>
                                            {selectedPortfolio.technician?.verified && (
                                                <VerifiedIcon sx={{ fontSize: 18, color: colors.salat }} />
                                            )}
                                            {selectedPortfolio.technician?.area && (
                                                <Chip
                                                    icon={<LocationIcon sx={{ fontSize: 14 }} />}
                                                    label={selectedPortfolio.technician.area}
                                                    size="small"
                                                    variant="outlined"
                                                    sx={{
                                                        borderColor: alpha(colors.middle, 0.3),
                                                        fontWeight: 500,
                                                    }}
                                                />
                                            )}
                                        </Box>
                                    </Box>
                                    <Box display="flex" gap={0.5}>
                                        {canDelete && (
                                            <Tooltip title="Delete">
                                                <IconButton
                                                    onClick={() => {
                                                        handleCloseDialog();
                                                        handleDeletePortfolio(selectedPortfolio.id);
                                                    }}
                                                    sx={{
                                                        color: 'error.main',
                                                        transition: 'all 0.2s ease',
                                                        '&:hover': {
                                                            backgroundColor: alpha('#ef4444', 0.08),
                                                            transform: 'scale(1.1)',
                                                        },
                                                    }}
                                                >
                                                    <DeleteIcon />
                                                </IconButton>
                                            </Tooltip>
                                        )}
                                        <IconButton onClick={handleCloseDialog} sx={{ color: colors.rain }}>
                                            <CloseIcon />
                                        </IconButton>
                                    </Box>
                                </Box>
                            </DialogTitle>
                            <DialogContent
                                dividers
                                sx={{
                                    borderColor: alpha(colors.middle, 0.15),
                                    backgroundColor: '#fafbfc',
                                    p: { xs: 2, sm: 3, md: 4 },
                                }}
                            >
                                <Box>
                                    {/* Full size image */}
                                    <Box
                                        sx={{
                                            width: '100%',
                                            height: { xs: 250, sm: 350, md: 420 },
                                            backgroundColor: '#f8fafc',
                                            borderRadius: 2.5,
                                            overflow: 'hidden',
                                            display: 'flex',
                                            justifyContent: 'center',
                                            alignItems: 'center',
                                            position: 'relative',
                                            border: `1px solid ${alpha(colors.middle, 0.1)}`,
                                        }}
                                    >
                                        <img
                                            src={selectedPortfolio.image || '/placeholder-image.jpg'}
                                            alt={selectedPortfolio.description || 'Portfolio item'}
                                            style={{
                                                width: '100%',
                                                height: '100%',
                                                objectFit: 'contain',
                                                display: 'block',
                                            }}
                                        />
                                    </Box>

                                    {selectedPortfolio.description && (
                                        <Box sx={{ mt: 3 }}>
                                            <Typography
                                                variant="subtitle2"
                                                sx={{
                                                    color: colors.rain,
                                                    mb: 1.5,
                                                    fontWeight: 700,
                                                    textTransform: 'uppercase',
                                                    letterSpacing: '0.5px',
                                                    fontSize: '0.75rem',
                                                }}
                                            >
                                                Description
                                            </Typography>
                                            <Paper
                                                elevation={0}
                                                sx={{
                                                    p: 2.5,
                                                    backgroundColor: '#ffffff',
                                                    borderRadius: 2.5,
                                                    border: `1px solid ${alpha(colors.middle, 0.1)}`,
                                                }}
                                            >
                                                <Typography variant="body1" sx={{ color: colors.black, lineHeight: 1.9 }}>
                                                    {selectedPortfolio.description}
                                                </Typography>
                                            </Paper>
                                        </Box>
                                    )}

                                    {/* ─── SOCIAL LINKS (Dialog) ────────────────────────────── */}
                                    {hasSocialLinks(selectedPortfolio) && (
                                        <Box sx={{ mt: 3 }}>
                                            <Typography
                                                variant="subtitle2"
                                                sx={{
                                                    color: colors.rain,
                                                    mb: 1.5,
                                                    fontWeight: 700,
                                                    textTransform: 'uppercase',
                                                    letterSpacing: '0.5px',
                                                    fontSize: '0.75rem',
                                                }}
                                            >
                                                Social Links
                                            </Typography>
                                            <Paper
                                                elevation={0}
                                                sx={{
                                                    p: 2.5,
                                                    backgroundColor: '#ffffff',
                                                    borderRadius: 2.5,
                                                    border: `1px solid ${alpha(colors.middle, 0.1)}`,
                                                }}
                                            >
                                                <Box display="flex" gap={1.5} flexWrap="wrap">
                                                    {getSocialLinks(selectedPortfolio).map((link, idx) => (
                                                        <SocialLink
                                                            key={idx}
                                                            platform={link.platform}
                                                            url={link.url}
                                                        />
                                                    ))}
                                                </Box>
                                            </Paper>
                                        </Box>
                                    )}

                                    <Divider sx={{ my: 3, borderColor: alpha(colors.middle, 0.1) }} />

                                    <Grid container spacing={3}>
                                        <Grid item xs={12} sm={6}>
                                            <Typography
                                                variant="caption"
                                                sx={{
                                                    color: colors.rain,
                                                    display: 'block',
                                                    fontWeight: 700,
                                                    textTransform: 'uppercase',
                                                    letterSpacing: '0.5px',
                                                    fontSize: '0.7rem',
                                                }}
                                            >
                                                Uploaded
                                            </Typography>
                                            <Typography
                                                variant="body2"
                                                sx={{
                                                    color: colors.dark,
                                                    display: 'flex',
                                                    alignItems: 'center',
                                                    gap: 1,
                                                    mt: 0.75,
                                                    fontWeight: 500,
                                                }}
                                            >
                                                <CalendarIcon sx={{ fontSize: 18, color: colors.rain }} />
                                                {formatDate(selectedPortfolio.created_at)}
                                            </Typography>
                                        </Grid>
                                        <Grid item xs={12} sm={6}>
                                            <Typography
                                                variant="caption"
                                                sx={{
                                                    color: colors.rain,
                                                    display: 'block',
                                                    fontWeight: 700,
                                                    textTransform: 'uppercase',
                                                    letterSpacing: '0.5px',
                                                    fontSize: '0.7rem',
                                                }}
                                            >
                                                Technician
                                            </Typography>
                                            <Typography
                                                variant="body2"
                                                sx={{
                                                    color: colors.dark,
                                                    display: 'flex',
                                                    alignItems: 'center',
                                                    gap: 1,
                                                    mt: 0.75,
                                                    fontWeight: 500,
                                                }}
                                            >
                                                <PersonIcon sx={{ fontSize: 18, color: colors.rain }} />
                                                {selectedPortfolio.technician?.name || 'Unknown'}
                                            </Typography>
                                        </Grid>
                                        {selectedPortfolio.technician?.email && (
                                            <Grid item xs={12} sm={6}>
                                                <Typography
                                                    variant="caption"
                                                    sx={{
                                                        color: colors.rain,
                                                        display: 'block',
                                                        fontWeight: 700,
                                                        textTransform: 'uppercase',
                                                        letterSpacing: '0.5px',
                                                        fontSize: '0.7rem',
                                                    }}
                                                >
                                                    Email
                                                </Typography>
                                                <Typography variant="body2" sx={{ color: colors.dark, mt: 0.75, fontWeight: 500 }}>
                                                    {selectedPortfolio.technician.email}
                                                </Typography>
                                            </Grid>
                                        )}
                                        {selectedPortfolio.technician?.phone && (
                                            <Grid item xs={12} sm={6}>
                                                <Typography
                                                    variant="caption"
                                                    sx={{
                                                        color: colors.rain,
                                                        display: 'block',
                                                        fontWeight: 700,
                                                        textTransform: 'uppercase',
                                                        letterSpacing: '0.5px',
                                                        fontSize: '0.7rem',
                                                    }}
                                                >
                                                    Phone
                                                </Typography>
                                                <Typography variant="body2" sx={{ color: colors.dark, mt: 0.75, fontWeight: 500 }}>
                                                    {selectedPortfolio.technician.phone}
                                                </Typography>
                                            </Grid>
                                        )}
                                        {selectedPortfolio.technician?.area && (
                                            <Grid item xs={12} sm={6}>
                                                <Typography
                                                    variant="caption"
                                                    sx={{
                                                        color: colors.rain,
                                                        display: 'block',
                                                        fontWeight: 700,
                                                        textTransform: 'uppercase',
                                                        letterSpacing: '0.5px',
                                                        fontSize: '0.7rem',
                                                    }}
                                                >
                                                    Area
                                                </Typography>
                                                <Typography variant="body2" sx={{ color: colors.dark, mt: 0.75, fontWeight: 500 }}>
                                                    {selectedPortfolio.technician.area}
                                                </Typography>
                                            </Grid>
                                        )}
                                        {selectedPortfolio.technician?.services && selectedPortfolio.technician.services.length > 0 && (
                                            <Grid item xs={12}>
                                                <Typography
                                                    variant="caption"
                                                    sx={{
                                                        color: colors.rain,
                                                        display: 'block',
                                                        fontWeight: 700,
                                                        textTransform: 'uppercase',
                                                        letterSpacing: '0.5px',
                                                        fontSize: '0.7rem',
                                                        mb: 1,
                                                    }}
                                                >
                                                    Services Offered
                                                </Typography>
                                                <Box display="flex" gap={1} flexWrap="wrap">
                                                    {selectedPortfolio.technician.services.map((service, idx) => (
                                                        <Chip
                                                            key={idx}
                                                            label={service}
                                                            size="medium"
                                                            sx={{
                                                                backgroundColor: alpha(colors.sea, 0.08),
                                                                color: colors.sea,
                                                                fontWeight: 600,
                                                            }}
                                                        />
                                                    ))}
                                                </Box>
                                            </Grid>
                                        )}
                                        {selectedPortfolio.technician?.rating > 0 && (
                                            <Grid item xs={12}>
                                                <Typography
                                                    variant="caption"
                                                    sx={{
                                                        color: colors.rain,
                                                        display: 'block',
                                                        fontWeight: 700,
                                                        textTransform: 'uppercase',
                                                        letterSpacing: '0.5px',
                                                        fontSize: '0.7rem',
                                                        mb: 0.75,
                                                    }}
                                                >
                                                    Rating
                                                </Typography>
                                                <Box display="flex" alignItems="center" gap={1.5}>
                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                        <StarIcon sx={{ color: '#f59e0b', fontSize: 22 }} />
                                                        <Typography variant="h6" sx={{ color: colors.dark, fontWeight: 700 }}>
                                                            {selectedPortfolio.technician.rating.toFixed(1)}
                                                        </Typography>
                                                    </Box>
                                                    <Typography variant="body2" sx={{ color: colors.rain }}>
                                                        out of 5.0
                                                    </Typography>
                                                </Box>
                                            </Grid>
                                        )}
                                    </Grid>
                                </Box>
                            </DialogContent>
                            <DialogActions sx={{
                                p: 2.5,
                                gap: 1.5,
                                backgroundColor: '#ffffff',
                                borderTop: `1px solid ${alpha(colors.middle, 0.1)}`,
                            }}>
                                <Button
                                    onClick={handleCloseDialog}
                                    variant="contained"
                                    sx={{
                                        background: `linear-gradient(135deg, ${colors.sea}, ${colors.dark})`,
                                        px: 4,
                                        py: 1.2,
                                        borderRadius: 2.5,
                                        textTransform: 'none',
                                        fontWeight: 700,
                                        fontSize: '0.9rem',
                                        boxShadow: `0 4px 16px ${alpha(colors.sea, 0.3)}`,
                                        '&:hover': {
                                            transform: 'translateY(-2px)',
                                            boxShadow: `0 8px 24px ${alpha(colors.sea, 0.4)}`,
                                        },
                                        transition: 'all 0.25s ease',
                                    }}
                                >
                                    Close
                                </Button>
                            </DialogActions>
                        </>
                    )}
                </Dialog>
            </Paper>
        </Box>
    );
};

export default PortfoliosList;