// src/pages/posts/PostsList.js
import React, { useState, useEffect } from 'react';
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
    Pagination,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    useMediaQuery,
    useTheme,
    Divider,
    Skeleton,
    Tooltip,
    Fade,
    Grow,
    Autocomplete,
    Badge,
    alpha,
} from '@mui/material';
import {
    Close as CloseIcon,
    Search as SearchIcon,
    Refresh as RefreshIcon,
    Person as PersonIcon,
    Verified as VerifiedIcon,
    LocationOn as LocationIcon,
    Star as StarIcon,
    CalendarToday as CalendarIcon,
    Visibility as VisibilityIcon,
    Favorite as FavoriteIcon,
    Comment as CommentIcon,
    ZoomIn as ZoomInIcon,
    Image as ImageIcon,
    FilterList as FilterIcon,
    Clear as ClearIcon,
    Dashboard as DashboardIcon,
    TrendingUp as TrendingUpIcon,
    People as PeopleIcon,
    ChatBubble as ChatBubbleIcon,
} from '@mui/icons-material';
import { postService } from 'services/post.service';
import { technicianService } from 'services/technician.service';
import { format } from 'date-fns';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const PostsList = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));

    const [posts, setPosts] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [pagination, setPagination] = useState({ total: 0, per_page: 15, current_page: 1, last_page: 1 });

    const [search, setSearch] = useState('');
    const [selectedTechnician, setSelectedTechnician] = useState(null);
    const [technicians, setTechnicians] = useState([]);
    const [loadingTechnicians, setLoadingTechnicians] = useState(false);
    const [page, setPage] = useState(1);
    const [perPage, setPerPage] = useState(15);
    const [selectedPost, setSelectedPost] = useState(null);
    const [openViewDialog, setOpenViewDialog] = useState(false);
    const [imageLoaded, setImageLoaded] = useState({});
    const [hoveredCard, setHoveredCard] = useState(null);
    const [showFilters, setShowFilters] = useState(false);

    const loadTechnicians = async () => {
        setLoadingTechnicians(true);
        try {
            const response = await technicianService.getTechnicians({
                per_page: 100,
                status: 'active',
            });
            if (response?.data?.status === 'success') {
                const data = response.data.data;
                if (data && data.data) {
                    setTechnicians(data.data);
                } else if (Array.isArray(data)) {
                    setTechnicians(data);
                } else {
                    setTechnicians([]);
                }
            }
        } catch (err) {
            console.error('Error loading technicians:', err);
        } finally {
            setLoadingTechnicians(false);
        }
    };

    useEffect(() => {
        loadTechnicians();
    }, []);

    const loadPosts = async () => {
        setLoading(true);
        setError(null);
        try {
            const params = {
                page,
                per_page: perPage,
                search: search || undefined,
            };

            if (selectedTechnician) {
                params.technician_id = selectedTechnician.id;
            }

            const response = await postService.getAllPosts(params);

            if (response?.data?.status === 'success') {
                const data = response.data.data;

                let postsData = [];
                let paginationData = {};

                if (data && data.data) {
                    postsData = data.data;
                    paginationData = {
                        total: data.total || 0,
                        per_page: data.per_page || perPage,
                        current_page: data.current_page || 1,
                        last_page: data.last_page || 1,
                    };
                } else if (Array.isArray(data)) {
                    postsData = data;
                    paginationData = {
                        total: data.length,
                        per_page: perPage,
                        current_page: 1,
                        last_page: 1,
                    };
                } else {
                    postsData = [];
                }

                setPosts(postsData);
                setPagination(paginationData);
            } else {
                setPosts([]);
            }
        } catch (err) {
            console.error('Posts error:', err);
            setError(err.message || 'Failed to load posts');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadPosts();
    }, [page, perPage, search, selectedTechnician]);

    const handleRefresh = () => {
        loadPosts();
    };

    const handleViewPost = async (post) => {
        try {
            const response = await postService.getPost(post.id);
            if (response?.data?.status === 'success') {
                setSelectedPost(response.data.data);
            } else {
                setSelectedPost(post);
            }
        } catch (err) {
            console.error('Error fetching post details:', err);
            setSelectedPost(post);
        }
        setOpenViewDialog(true);
    };

    const handleCloseDialog = () => {
        setOpenViewDialog(false);
        setSelectedPost(null);
    };

    const handleImageLoad = (id) => {
        setImageLoaded(prev => ({ ...prev, [id]: true }));
    };

    const handleClearFilters = () => {
        setSelectedTechnician(null);
        setSearch('');
        setPage(1);
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

        return format(past, 'MMM d, yyyy');
    };

    const getImageUrl = (image) => {
        if (!image) return null;

        if (image.startsWith('http://') || image.startsWith('https://')) {
            return image;
        }

        const baseUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
        const cleanPath = image.replace(/^\/+/, '');
        return `${baseUrl}/storage/${cleanPath}`;
    };

    const groupPostsByTechnician = () => {
        const groups = {};
        posts.forEach(post => {
            const techId = post.technician?.id;
            if (!techId) {
                if (!groups['unknown']) {
                    groups['unknown'] = {
                        technician: null,
                        posts: []
                    };
                }
                groups['unknown'].posts.push(post);
                return;
            }
            if (!groups[techId]) {
                groups[techId] = {
                    technician: post.technician,
                    posts: []
                };
            }
            groups[techId].posts.push(post);
        });
        return Object.values(groups);
    };

    const technicianGroups = groupPostsByTechnician();

    const renderSkeletons = () => {
        const count = isMobile ? 2 : isTablet ? 4 : 6;
        return Array.from({ length: count }).map((_, index) => (
            <Grid item xs={12} sm={6} md={4} key={`skeleton-${index}`}>
                <Card sx={{ borderRadius: 3, overflow: 'hidden', height: '100%' }}>
                    <Skeleton variant="rectangular" height={250} animation="wave" />
                    <CardContent>
                        <Skeleton variant="text" width="80%" height={28} animation="wave" />
                        <Skeleton variant="text" width="100%" height={20} animation="wave" />
                        <Skeleton variant="text" width="60%" height={20} animation="wave" />
                        <Box sx={{ mt: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
                            <Skeleton variant="circular" width={32} height={32} animation="wave" />
                            <Skeleton variant="text" width="40%" height={20} animation="wave" />
                        </Box>
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
                        <Button color="inherit" size="small" onClick={() => { setError(null); loadPosts(); }}>
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
                            <CommentIcon sx={{ color: colors.sea, fontSize: 28 }} />
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
                                Posts
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
                                Technician posts and updates
                            </Typography>
                        </Box>
                    </Box>

                    <Box display="flex" gap={1.5} alignItems="center" flexWrap="wrap" sx={{ width: { xs: '100%', sm: 'auto' } }}>
                        <Button
                            variant="outlined"
                            startIcon={<FilterIcon />}
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
                                transition: 'all 0.2s ease',
                                '&:hover': {
                                    borderColor: colors.sea,
                                    backgroundColor: alpha(colors.sea, 0.06),
                                    transform: 'translateY(-1px)',
                                },
                            }}
                        >
                            {showFilters ? 'Hide Filters' : 'Show Filters'}
                            {(selectedTechnician || search) && (
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
                            placeholder="Search posts..."
                            size="small"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            InputProps={{
                                startAdornment: (
                                    <InputAdornment position="start">
                                        <SearchIcon fontSize="small" sx={{ color: colors.rain }} />
                                    </InputAdornment>
                                ),
                                endAdornment: search && (
                                    <InputAdornment position="end">
                                        <IconButton size="small" onClick={() => setSearch('')}>
                                            <ClearIcon fontSize="small" />
                                        </IconButton>
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
                {showFilters && (
                    <Fade in={showFilters}>
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
                                    Filters
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
                                    <TextField
                                        fullWidth
                                        placeholder="Search posts by title or content..."
                                        size="medium"
                                        value={search}
                                        onChange={(e) => setSearch(e.target.value)}
                                        InputProps={{
                                            startAdornment: (
                                                <InputAdornment position="start">
                                                    <SearchIcon fontSize="small" sx={{ color: colors.rain }} />
                                                </InputAdornment>
                                            ),
                                            endAdornment: search && (
                                                <InputAdornment position="end">
                                                    <IconButton size="small" onClick={() => setSearch('')}>
                                                        <ClearIcon fontSize="small" />
                                                    </IconButton>
                                                </InputAdornment>
                                            ),
                                        }}
                                        sx={{
                                            '& .MuiInputBase-root': {
                                                backgroundColor: '#ffffff',
                                                borderRadius: 2,
                                            },
                                            '& .MuiOutlinedInput-notchedOutline': {
                                                borderColor: alpha(colors.middle, 0.3),
                                            },
                                            '& .MuiInputBase-root:hover .MuiOutlinedInput-notchedOutline': {
                                                borderColor: colors.sea,
                                            },
                                            '& .MuiInputBase-root.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                                borderColor: colors.sea,
                                                borderWidth: 2,
                                            },
                                        }}
                                    />
                                </Grid>
                                <Grid item xs={12} md={6}>
                                    <Autocomplete
                                        fullWidth
                                        size="medium"
                                        options={technicians}
                                        loading={loadingTechnicians}
                                        value={selectedTechnician}
                                        onChange={(event, newValue) => {
                                            setSelectedTechnician(newValue);
                                            setPage(1);
                                        }}
                                        getOptionLabel={(option) => option.user?.name || option.name || ''}
                                        isOptionEqualToValue={(option, value) => option.id === value?.id}
                                        renderOption={(props, option) => (
                                            <Box component="li" {...props} sx={{ py: 1.5, px: 2 }}>
                                                <Box display="flex" alignItems="center" gap={2}>
                                                    <Avatar
                                                        src={option.profile_photo ? getImageUrl(option.profile_photo) : undefined}
                                                        sx={{ width: 36, height: 36, bgcolor: colors.sea, fontWeight: 600 }}
                                                    >
                                                        {getInitials(option.user?.name || option.name)}
                                                    </Avatar>
                                                    <Box>
                                                        <Typography variant="body2" sx={{ fontWeight: 600, color: colors.dark }}>
                                                            {option.user?.name || option.name}
                                                        </Typography>
                                                        {option.area && (
                                                            <Typography variant="caption" sx={{ color: colors.rain, display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                                                <LocationIcon sx={{ fontSize: 12 }} />
                                                                {option.area}
                                                            </Typography>
                                                        )}
                                                    </Box>
                                                    {option.verified && (
                                                        <VerifiedIcon sx={{ fontSize: 16, color: colors.salat }} />
                                                    )}
                                                </Box>
                                            </Box>
                                        )}
                                        renderInput={(params) => (
                                            <TextField
                                                {...params}
                                                placeholder="Filter by technician..."
                                                InputProps={{
                                                    ...params.InputProps,
                                                    startAdornment: (
                                                        <>
                                                            <InputAdornment position="start">
                                                                <PersonIcon fontSize="small" sx={{ color: colors.rain }} />
                                                            </InputAdornment>
                                                            {params.InputProps.startAdornment}
                                                        </>
                                                    ),
                                                    endAdornment: (
                                                        <>
                                                            {selectedTechnician && (
                                                                <IconButton
                                                                    size="small"
                                                                    onClick={() => setSelectedTechnician(null)}
                                                                    sx={{ mr: 0.5 }}
                                                                >
                                                                    <ClearIcon fontSize="small" />
                                                                </IconButton>
                                                            )}
                                                            {params.InputProps.endAdornment}
                                                        </>
                                                    ),
                                                }}
                                                sx={{
                                                    '& .MuiInputBase-root': {
                                                        backgroundColor: '#ffffff',
                                                        borderRadius: 2,
                                                    },
                                                    '& .MuiOutlinedInput-notchedOutline': {
                                                        borderColor: alpha(colors.middle, 0.3),
                                                    },
                                                    '& .MuiInputBase-root:hover .MuiOutlinedInput-notchedOutline': {
                                                        borderColor: colors.sea,
                                                    },
                                                    '& .MuiInputBase-root.Mui-focused .MuiOutlinedInput-notchedOutline': {
                                                        borderColor: colors.sea,
                                                        borderWidth: 2,
                                                    },
                                                }}
                                            />
                                        )}
                                    />
                                </Grid>
                            </Grid>

                            {/* Active filters chips */}
                            {(selectedTechnician || search) && (
                                <Box display="flex" gap={1.5} mt={2.5} flexWrap="wrap">
                                    {search && (
                                        <Chip
                                            label={`Search: "${search}"`}
                                            size="medium"
                                            onDelete={() => setSearch('')}
                                            sx={{
                                                backgroundColor: alpha(colors.sea, 0.12),
                                                color: colors.sea,
                                                fontWeight: 600,
                                            }}
                                        />
                                    )}
                                    {selectedTechnician && (
                                        <Chip
                                            avatar={
                                                <Avatar
                                                    src={selectedTechnician.profile_photo ? getImageUrl(selectedTechnician.profile_photo) : undefined}
                                                    sx={{ width: 24, height: 24 }}
                                                >
                                                    {getInitials(selectedTechnician.user?.name || selectedTechnician.name)}
                                                </Avatar>
                                            }
                                            label={selectedTechnician.user?.name || selectedTechnician.name}
                                            size="medium"
                                            onDelete={() => setSelectedTechnician(null)}
                                            sx={{
                                                backgroundColor: alpha(colors.sea, 0.12),
                                                color: colors.sea,
                                                fontWeight: 600,
                                            }}
                                        />
                                    )}
                                </Box>
                            )}
                        </Box>
                    </Fade>
                )}

                {/* ===== STATISTICS BANNER ===== */}
                {posts.length > 0 && (
                    <Box
                        sx={{
                            display: 'grid',
                            gridTemplateColumns: { xs: 'repeat(2, 1fr)', sm: 'repeat(4, 1fr)' },
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
                                <ChatBubbleIcon sx={{ fontSize: 22, color: colors.sea }} />
                            </Box>
                            <Box>
                                <Typography variant="h6" sx={{ color: colors.dark, fontWeight: 700, lineHeight: 1.2 }}>
                                    {pagination.total || posts.length}
                                </Typography>
                                <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                    Posts
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
                                    {technicianGroups.filter(g => g.technician !== null).length}
                                </Typography>
                                <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                    Technicians
                                </Typography>
                            </Box>
                        </Box>

                        <Box display="flex" alignItems="center" gap={1.5}>
                            <Box sx={{
                                p: 1,
                                borderRadius: 2,
                                background: alpha('#ef4444', 0.12),
                            }}>
                                <FavoriteIcon sx={{ fontSize: 22, color: '#ef4444' }} />
                            </Box>
                            <Box>
                                <Typography variant="h6" sx={{ color: colors.dark, fontWeight: 700, lineHeight: 1.2 }}>
                                    {posts.reduce((acc, p) => acc + (p.likes_count || 0), 0)}
                                </Typography>
                                <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                    Likes
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
                                    {posts.filter(p => p.created_at && new Date(p.created_at) > new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)).length}
                                </Typography>
                                <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                    This week
                                </Typography>
                            </Box>
                        </Box>
                    </Box>
                )}

                {/* ===== POSTS GRID ===== */}
                {loading && posts.length === 0 ? (
                    <Grid container spacing={3}>
                        {renderSkeletons()}
                    </Grid>
                ) : posts.length === 0 ? (
                    <Box
                        textAlign="center"
                        py={10}
                        sx={{
                            background: `linear-gradient(135deg, #f8fafc, #f1f5f9)`,
                            borderRadius: 3,
                            border: `2px dashed ${alpha(colors.middle, 0.3)}`,
                        }}
                    >
                        <CommentIcon sx={{ fontSize: 72, color: alpha(colors.middle, 0.5), mb: 2 }} />
                        <Typography variant="h5" sx={{ color: colors.dark, fontWeight: 600, mb: 1 }}>
                            No posts found
                        </Typography>
                        <Typography variant="body2" sx={{ color: colors.rain }}>
                            {search || selectedTechnician ? 'No results match your filters' : 'Posts will appear here once created'}
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
                                            src={group.technician?.profile_photo ? getImageUrl(group.technician.profile_photo) : undefined}
                                            sx={{
                                                width: 56,
                                                height: 56,
                                                bgcolor: colors.sea,
                                                fontSize: '1.2rem',
                                                fontWeight: 700,
                                                border: `3px solid ${alpha(colors.sea, 0.15)}`,
                                            }}
                                        >
                                            {group.technician ? getInitials(group.technician.user?.name || group.technician.name) : '?'}
                                        </Avatar>
                                        <Box>
                                            <Box display="flex" alignItems="center" gap={1.5}>
                                                <Typography variant="h6" fontWeight="700" sx={{ color: colors.dark, fontSize: '1.05rem' }}>
                                                    {group.technician?.user?.name || group.technician?.name || 'Unknown Technician'}
                                                </Typography>
                                                {group.technician?.verified && (
                                                    <VerifiedIcon sx={{ fontSize: 18, color: colors.salat }} />
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
                                            </Box>
                                        </Box>
                                    </Box>
                                    <Chip
                                        icon={<CommentIcon sx={{ fontSize: 18 }} />}
                                        label={`${group.posts.length} post${group.posts.length !== 1 ? 's' : ''}`}
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

                                {/* Posts Grid */}
                                <Grid container spacing={3}>
                                    {group.posts.map((post, index) => {
                                        const isHovered = hoveredCard === post.id;
                                        const imageUrl = post.image ? getImageUrl(post.image) : null;

                                        return (
                                            <Grid item xs={12} sm={6} md={4} key={post.id}>
                                                <Grow in={true} timeout={300 + (index * 50)}>
                                                    <Card
                                                        sx={{
                                                            borderRadius: 3,
                                                            overflow: 'hidden',
                                                            height: '100%',
                                                            display: 'flex',
                                                            flexDirection: 'column',
                                                            transition: 'all 0.4s cubic-bezier(0.4, 0, 0.2, 1)',
                                                            border: `1px solid ${alpha(colors.middle, 0.15)}`,
                                                            backgroundColor: '#ffffff',
                                                            '&:hover': {
                                                                transform: 'translateY(-6px)',
                                                                boxShadow: '0 12px 40px rgba(0,0,0,0.08)',
                                                                borderColor: alpha(colors.sea, 0.3),
                                                            },
                                                            cursor: 'pointer',
                                                        }}
                                                        onClick={() => handleViewPost(post)}
                                                        onMouseEnter={() => setHoveredCard(post.id)}
                                                        onMouseLeave={() => setHoveredCard(null)}
                                                    >
                                                        {/* Image Section */}
                                                        <Box
                                                            sx={{
                                                                position: 'relative',
                                                                width: '100%',
                                                                paddingTop: '56.25%',
                                                                backgroundColor: '#f8fafc',
                                                                overflow: 'hidden',
                                                                flexShrink: 0,
                                                            }}
                                                        >
                                                            {imageUrl ? (
                                                                <>
                                                                    {!imageLoaded[post.id] && (
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
                                                                        src={imageUrl}
                                                                        alt={post.title || 'Post image'}
                                                                        style={{
                                                                            position: 'absolute',
                                                                            top: 0,
                                                                            left: 0,
                                                                            width: '100%',
                                                                            height: '100%',
                                                                            objectFit: 'cover',
                                                                            display: 'block',
                                                                            transition: 'transform 0.6s ease',
                                                                            transform: isHovered ? 'scale(1.05)' : 'scale(1)',
                                                                        }}
                                                                        onLoad={() => handleImageLoad(post.id)}
                                                                        onError={(e) => {
                                                                            console.error('Image load error:', imageUrl);
                                                                            e.target.style.display = 'none';
                                                                            setImageLoaded(prev => ({ ...prev, [post.id]: true }));
                                                                        }}
                                                                    />
                                                                    <Box
                                                                        sx={{
                                                                            position: 'absolute',
                                                                            top: 0,
                                                                            left: 0,
                                                                            right: 0,
                                                                            bottom: 0,
                                                                            background: 'linear-gradient(to top, rgba(0,0,0,0.1), transparent)',
                                                                            opacity: isHovered ? 1 : 0,
                                                                            transition: 'opacity 0.4s ease',
                                                                            display: 'flex',
                                                                            alignItems: 'center',
                                                                            justifyContent: 'center',
                                                                            zIndex: 2,
                                                                        }}
                                                                    >
                                                                        <ZoomInIcon
                                                                            sx={{
                                                                                fontSize: 40,
                                                                                color: 'white',
                                                                                opacity: 0.7,
                                                                                transform: isHovered ? 'scale(1)' : 'scale(0.8)',
                                                                                transition: 'all 0.4s ease',
                                                                            }}
                                                                        />
                                                                    </Box>
                                                                </>
                                                            ) : (
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
                                                                        backgroundColor: '#f1f5f9',
                                                                    }}
                                                                >
                                                                    <ImageIcon sx={{ fontSize: 64, color: alpha(colors.middle, 0.5) }} />
                                                                </Box>
                                                            )}
                                                        </Box>

                                                        {/* Content */}
                                                        <CardContent sx={{ p: 2.5, flex: 1, display: 'flex', flexDirection: 'column' }}>
                                                            <Typography
                                                                variant="subtitle1"
                                                                fontWeight="700"
                                                                sx={{
                                                                    color: colors.dark,
                                                                    mb: 1,
                                                                    fontSize: '1.05rem',
                                                                    lineHeight: 1.3,
                                                                    display: '-webkit-box',
                                                                    WebkitLineClamp: 2,
                                                                    WebkitBoxOrient: 'vertical',
                                                                    overflow: 'hidden',
                                                                }}
                                                            >
                                                                {post.title || 'Untitled'}
                                                            </Typography>

                                                            <Typography
                                                                variant="body2"
                                                                sx={{
                                                                    color: colors.black,
                                                                    lineHeight: 1.7,
                                                                    fontSize: '0.875rem',
                                                                    flex: 1,
                                                                    mb: 1.5,
                                                                    display: '-webkit-box',
                                                                    WebkitLineClamp: 3,
                                                                    WebkitBoxOrient: 'vertical',
                                                                    overflow: 'hidden',
                                                                }}
                                                            >
                                                                {post.content}
                                                            </Typography>

                                                            <Divider sx={{ my: 1.5, borderColor: alpha(colors.middle, 0.15) }} />

                                                            {/* Footer */}
                                                            <Box
                                                                display="flex"
                                                                alignItems="center"
                                                                justifyContent="space-between"
                                                                flexWrap="wrap"
                                                                gap={1}
                                                            >
                                                                <Box display="flex" alignItems="center" gap={1}>
                                                                    <Avatar
                                                                        src={post.technician?.profile_photo ? getImageUrl(post.technician.profile_photo) : undefined}
                                                                        sx={{
                                                                            width: 28,
                                                                            height: 28,
                                                                            bgcolor: colors.sea,
                                                                            fontSize: '0.6rem',
                                                                            fontWeight: 700,
                                                                        }}
                                                                    >
                                                                        {getInitials(post.technician?.user?.name || post.technician?.name)}
                                                                    </Avatar>
                                                                    <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                                                        {post.technician?.user?.name || post.technician?.name || 'Unknown'}
                                                                    </Typography>
                                                                </Box>
                                                                <Box display="flex" alignItems="center" gap={0.75}>
                                                                    <CalendarIcon sx={{ fontSize: 14, color: colors.rain }} />
                                                                    <Typography variant="caption" sx={{ color: colors.rain, fontWeight: 500 }}>
                                                                        {formatDate(post.created_at)}
                                                                    </Typography>
                                                                </Box>
                                                            </Box>

                                                            {/* Stats */}
                                                            <Box
                                                                display="flex"
                                                                alignItems="center"
                                                                gap={2}
                                                                sx={{ mt: 1.5, pt: 1.5, borderTop: `1px solid ${alpha(colors.middle, 0.1)}` }}
                                                            >
                                                                {post.likes_count > 0 && (
                                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                                        <FavoriteIcon sx={{ fontSize: 16, color: '#ef4444' }} />
                                                                        <Typography variant="body2" sx={{ color: colors.rain, fontWeight: 600 }}>
                                                                            {post.likes_count}
                                                                        </Typography>
                                                                    </Box>
                                                                )}
                                                                {post.comments_count > 0 && (
                                                                    <Box display="flex" alignItems="center" gap={0.5}>
                                                                        <CommentIcon sx={{ fontSize: 16, color: colors.sea }} />
                                                                        <Typography variant="body2" sx={{ color: colors.rain, fontWeight: 600 }}>
                                                                            {post.comments_count}
                                                                        </Typography>
                                                                    </Box>
                                                                )}
                                                                {post.likes_count === 0 && post.comments_count === 0 && (
                                                                    <Typography variant="caption" sx={{ color: colors.rain, fontStyle: 'italic' }}>
                                                                        No interactions yet
                                                                    </Typography>
                                                                )}
                                                            </Box>
                                                        </CardContent>
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
                {posts.length > 0 && (
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
                                <MenuItem value={15}>15</MenuItem>
                                <MenuItem value={25}>25</MenuItem>
                                <MenuItem value={50}>50</MenuItem>
                            </Select>
                        </FormControl>
                        <Typography variant="body2" sx={{ color: colors.rain, fontWeight: 500 }}>
                            {pagination.total || posts.length} total posts
                        </Typography>
                    </Box>
                )}

                {/* ===== POST DETAIL DIALOG ===== */}
                <Dialog
                    open={openViewDialog}
                    onClose={handleCloseDialog}
                    maxWidth="md"
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
                    {selectedPost && (
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
                                            {selectedPost.title || 'Untitled'}
                                        </Typography>
                                        <Box display="flex" alignItems="center" gap={1.5} mt={1} flexWrap="wrap">
                                            <Avatar
                                                src={selectedPost.technician?.profile_photo ? getImageUrl(selectedPost.technician.profile_photo) : undefined}
                                                sx={{
                                                    width: 36,
                                                    height: 36,
                                                    bgcolor: colors.sea,
                                                    fontSize: '0.9rem',
                                                    fontWeight: 700,
                                                }}
                                            >
                                                {getInitials(selectedPost.technician?.user?.name || selectedPost.technician?.name)}
                                            </Avatar>
                                            <Typography variant="body1" sx={{ color: colors.black, fontWeight: 600 }}>
                                                {selectedPost.technician?.user?.name || selectedPost.technician?.name || 'Unknown'}
                                            </Typography>
                                            {selectedPost.technician?.verified && (
                                                <VerifiedIcon sx={{ fontSize: 18, color: colors.salat }} />
                                            )}
                                            {selectedPost.technician?.area && (
                                                <Chip
                                                    icon={<LocationIcon sx={{ fontSize: 14 }} />}
                                                    label={selectedPost.technician.area}
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
                                    <IconButton onClick={handleCloseDialog} sx={{ color: colors.rain }}>
                                        <CloseIcon />
                                    </IconButton>
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
                                    {selectedPost.image && (
                                        <Box
                                            sx={{
                                                width: '100%',
                                                maxHeight: 400,
                                                backgroundColor: '#f8fafc',
                                                borderRadius: 2.5,
                                                overflow: 'hidden',
                                                display: 'flex',
                                                justifyContent: 'center',
                                                alignItems: 'center',
                                                mb: 3,
                                                p: 2,
                                                border: `1px solid ${alpha(colors.middle, 0.1)}`,
                                            }}
                                        >
                                            <img
                                                src={getImageUrl(selectedPost.image)}
                                                alt={selectedPost.title || 'Post image'}
                                                style={{
                                                    maxWidth: '100%',
                                                    maxHeight: '400px',
                                                    width: 'auto',
                                                    height: 'auto',
                                                    objectFit: 'contain',
                                                    display: 'block',
                                                }}
                                                onError={(e) => {
                                                    console.error('Dialog image error:', getImageUrl(selectedPost.image));
                                                    e.target.style.display = 'none';
                                                }}
                                            />
                                        </Box>
                                    )}

                                    {selectedPost.content && (
                                        <Box>
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
                                                Content
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
                                                <Typography
                                                    variant="body1"
                                                    sx={{
                                                        color: colors.black,
                                                        lineHeight: 1.9,
                                                        whiteSpace: 'pre-wrap',
                                                    }}
                                                >
                                                    {selectedPost.content}
                                                </Typography>
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
                                                Posted
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
                                                {formatDate(selectedPost.created_at)}
                                            </Typography>
                                        </Grid>
                                        <Grid item xs={12}>
                                            <Box display="flex" gap={3}>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <FavoriteIcon sx={{ fontSize: 22, color: '#ef4444' }} />
                                                    <Typography variant="body1" sx={{ color: colors.dark, fontWeight: 600 }}>
                                                        {selectedPost.likes_count || 0} Likes
                                                    </Typography>
                                                </Box>
                                                <Box display="flex" alignItems="center" gap={1}>
                                                    <CommentIcon sx={{ fontSize: 22, color: colors.sea }} />
                                                    <Typography variant="body1" sx={{ color: colors.dark, fontWeight: 600 }}>
                                                        {selectedPost.comments_count || 0} Comments
                                                    </Typography>
                                                </Box>
                                            </Box>
                                        </Grid>
                                    </Grid>

                                    {/* Comments Section */}
                                    {selectedPost.comments && selectedPost.comments.length > 0 && (
                                        <>
                                            <Divider sx={{ my: 3, borderColor: alpha(colors.middle, 0.1) }} />
                                            <Typography
                                                variant="subtitle2"
                                                sx={{
                                                    color: colors.dark,
                                                    mb: 2,
                                                    fontWeight: 700,
                                                    fontSize: '0.95rem',
                                                }}
                                            >
                                                Comments ({selectedPost.comments.length})
                                            </Typography>
                                            <Stack spacing={2}>
                                                {selectedPost.comments.map((comment, idx) => (
                                                    <Paper
                                                        key={idx}
                                                        elevation={0}
                                                        sx={{
                                                            p: 2,
                                                            backgroundColor: '#ffffff',
                                                            borderRadius: 2.5,
                                                            border: `1px solid ${alpha(colors.middle, 0.1)}`,
                                                        }}
                                                    >
                                                        <Box display="flex" alignItems="flex-start" gap={1.5}>
                                                            <Avatar
                                                                src={comment.user?.profile_photo ? getImageUrl(comment.user.profile_photo) : undefined}
                                                                sx={{
                                                                    width: 32,
                                                                    height: 32,
                                                                    bgcolor: colors.sea,
                                                                    fontSize: '0.7rem',
                                                                    fontWeight: 700,
                                                                    flexShrink: 0,
                                                                }}
                                                            >
                                                                {getInitials(comment.user?.name || comment.name)}
                                                            </Avatar>
                                                            <Box flex={1}>
                                                                <Box display="flex" alignItems="center" gap={1.5}>
                                                                    <Typography variant="body2" sx={{ fontWeight: 700, color: colors.dark }}>
                                                                        {comment.user?.name || comment.name || 'Unknown'}
                                                                    </Typography>
                                                                    <Typography variant="caption" sx={{ color: colors.rain, fontSize: '0.65rem' }}>
                                                                        {formatDate(comment.created_at)}
                                                                    </Typography>
                                                                </Box>
                                                                <Typography variant="body2" sx={{ color: colors.black, mt: 0.5 }}>
                                                                    {comment.content || comment.comment}
                                                                </Typography>
                                                            </Box>
                                                        </Box>
                                                    </Paper>
                                                ))}
                                            </Stack>
                                        </>
                                    )}
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

export default PostsList;