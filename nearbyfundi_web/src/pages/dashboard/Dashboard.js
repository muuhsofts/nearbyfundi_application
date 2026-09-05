import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
    Box, Paper, Typography, Button, Grid, Card, CardContent, TextField, MenuItem,
    Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TablePagination,
    Chip, CircularProgress, Tooltip, Stack, Tabs, Tab, Divider, Skeleton, useMediaQuery,
} from '@mui/material';
import { useTheme } from '@mui/material/styles';
import {
    Refresh as RefreshIcon,
    Description as CsvIcon,
    TableChart as ExcelIcon,
    TrendingUp as TrendingUpIcon,
    TrendingDown as TrendingDownIcon,
    People as PeopleIcon,
    Assignment as RequestIcon,
    CardMembership as SubIcon,
    Engineering as TechIcon,
    Today as TodayIcon,
    DateRange as WeekIcon,
    ShowChart as LineIcon,
    BarChart as BarIcon,
} from '@mui/icons-material';
import {
    PieChart, Pie, Cell, Tooltip as ChartTooltip, Legend, ResponsiveContainer,
    XAxis, YAxis, CartesianGrid, Area, AreaChart, BarChart, Bar,
} from 'recharts';
import { usePermissions } from 'hooks/usePermissions';
import { useReportManagement } from 'hooks/useReport';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';

const colors = appConfig.app.colors || {
    middle: '#e2e8f0',
    primary: '#3b82f6',
};

// ---------------------------------------------------------------------------
// Domain config
// ---------------------------------------------------------------------------
const DOMAINS = {
    customers: {
        label: 'Customers',
        chartColor: '#3b82f6',
        icon: PeopleIcon,
        statuses: ['active', 'pending', 'suspended'],
        columns: ['Name', 'Email', 'Phone', 'Status', 'Active', 'Created'],
        renderRow: (row) => [
            <RowPrimary key="name" title={row.name} subtitle={row.email} />,
            row.email,
            row.phone || '-',
            <StatusChip key="status" value={row.status} />,
            row.is_active ? 'Yes' : 'No',
            formatDate(row.created_at),
        ],
    },
    requests: {
        label: 'Requests',
        chartColor: '#8b5cf6',
        icon: RequestIcon,
        statuses: ['pending', 'accepted', 'on_the_way', 'completed', 'rejected', 'cancelled'],
        columns: ['Customer', 'Technician', 'Service', 'Status', 'Description', 'Created'],
        renderRow: (row) => [
            row.customer?.name || '-',
            row.technician?.user?.name || '-',
            row.service?.name || '-',
            <StatusChip key="status" value={row.status} />,
            <Tooltip key="desc" title={row.description || ''}>
                <Typography variant="body2" noWrap sx={{ maxWidth: { xs: 120, sm: 220 } }}>
                    {row.description || '-'}
                </Typography>
            </Tooltip>,
            formatDate(row.created_at),
        ],
    },
    subscriptions: {
        label: 'Subscriptions',
        chartColor: '#10b981',
        icon: SubIcon,
        statuses: ['pending', 'active', 'expired', 'cancelled'],
        columns: ['User', 'Plan', 'Amount', 'Status', 'Payment Method', 'Created', 'Expiry'],
        renderRow: (row) => [
            <RowPrimary key="user" title={row.user?.name} subtitle={row.user?.email} />,
            row.rate_card?.name || '-',
            row.amount_paid != null ? `TZS ${Number(row.amount_paid).toLocaleString()}` : '-',
            <StatusChip key="status" value={row.status} />,
            row.payment_method || '-',
            formatDate(row.created_at),
            formatDate(row.expiry_date),
        ],
    },
    technicians: {
        label: 'Technicians',
        chartColor: '#f59e0b',
        icon: TechIcon,
        statuses: ['approved', 'pending', 'rejected'],
        columns: ['Name', 'Email', 'Area', 'Rating', 'Verification', 'Online', 'Created'],
        renderRow: (row) => [
            <RowPrimary key="name" title={row.user?.name} subtitle={row.user?.email} />,
            row.user?.email || '-',
            row.area || '-',
            row.rating ?? '-',
            <StatusChip key="status" value={row.verification_status} />,
            row.is_online ? 'Yes' : 'No',
            formatDate(row.created_at),
        ],
    },
};

const STATUS_COLORS = {
    active: { color: '#10b981', bg: '#d1fae5' },
    approved: { color: '#10b981', bg: '#d1fae5' },
    completed: { color: '#10b981', bg: '#d1fae5' },
    pending: { color: '#f59e0b', bg: '#fef3c7' },
    accepted: { color: '#3b82f6', bg: '#eff6ff' },
    on_the_way: { color: '#6366f1', bg: '#eef2ff' },
    expired: { color: '#ef4444', bg: '#fee2e2' },
    rejected: { color: '#ef4444', bg: '#fee2e2' },
    suspended: { color: '#ef4444', bg: '#fee2e2' },
    cancelled: { color: '#6b7280', bg: '#f3f4f6' },
};

function formatDate(d) {
    if (!d) return '-';
    try {
        return new Date(d).toLocaleDateString();
    } catch {
        return '-';
    }
}

function StatusChip({ value }) {
    const st = STATUS_COLORS[value] || { color: '#6b7280', bg: '#f3f4f6' };
    const label = (value || '-').replace(/_/g, ' ');
    return (
        <Chip
            label={label}
            size="small"
            sx={{
                backgroundColor: st.bg,
                color: st.color,
                fontWeight: 600,
                textTransform: 'capitalize',
                height: 24,
            }}
        />
    );
}

function RowPrimary({ title, subtitle }) {
    return (
        <Box>
            <Typography variant="body2" fontWeight={600} noWrap>
                {title || '-'}
            </Typography>
            {subtitle && (
                <Typography variant="caption" color="text.secondary" noWrap>
                    {subtitle}
                </Typography>
            )}
        </Box>
    );
}

function GrowthPill({ value }) {
    if (value === undefined || value === null) return null;
    const isUp = value >= 0;
    const Icon = isUp ? TrendingUpIcon : TrendingDownIcon;
    const color = isUp ? '#10b981' : '#ef4444';
    return (
        <Stack direction="row" alignItems="center" spacing={0.5} sx={{ color, mt: 0.75 }}>
            <Icon sx={{ fontSize: 15 }} />
            <Typography variant="caption" fontWeight={700}>
                {isUp ? '+' : ''}
                {value}% vs last period
            </Typography>
        </Stack>
    );
}

// ---------------------------------------------------------------------------
// Daily insights from trend buckets
// ---------------------------------------------------------------------------
function buildDailyInsights(buckets = []) {
    if (!buckets.length) {
        return { today: null, yesterday: null, weekSoFar: null, lastLabel: null };
    }

    const sumKeys = (b) => ({
        customers: b?.customers ?? 0,
        requests: b?.requests ?? 0,
        subscriptions: b?.subscriptions ?? 0,
        subscriptions_revenue: b?.subscriptions_revenue ?? 0,
        technicians: b?.technicians ?? 0,
    });

    const last = buckets[buckets.length - 1];
    const prev = buckets.length > 1 ? buckets[buckets.length - 2] : null;

    const today = sumKeys(last);
    const yesterday = prev ? sumKeys(prev) : null;

    const weekBuckets = buckets.slice(-7);
    const weekSoFar = weekBuckets.reduce(
        (acc, b) => ({
            customers: acc.customers + (b.customers || 0),
            requests: acc.requests + (b.requests || 0),
            subscriptions: acc.subscriptions + (b.subscriptions || 0),
            subscriptions_revenue: acc.subscriptions_revenue + (b.subscriptions_revenue || 0),
            technicians: acc.technicians + (b.technicians || 0),
        }),
        { customers: 0, requests: 0, subscriptions: 0, subscriptions_revenue: 0, technicians: 0 }
    );

    return { today, yesterday, weekSoFar, lastLabel: last?.label };
}

// ---------------------------------------------------------------------------
// Main Dashboard
// ---------------------------------------------------------------------------
const Dashboard = () => {
    const theme = useTheme();
    const isMobile = useMediaQuery(theme.breakpoints.down('sm'));
    const isTablet = useMediaQuery(theme.breakpoints.down('md'));

    const { can } = usePermissions();
    const canView = can('reports.view');

    const {
        summary,
        trends,
        detailed,
        overview,
        loadingSummary,
        loadingTrends,
        loadingDetailed,
        loadingOverview,
        exporting,
        getSummary,
        getTrends,
        getDetailed,
        getOverview,
        exportFinanceReport,
    } = useReportManagement();

    // Filters
    const [range, setRange] = useState('week');
    const [granularity, setGranularity] = useState('');
    const [dateFrom, setDateFrom] = useState('');
    const [dateTo, setDateTo] = useState('');

    // Domain & table
    const [domain, setDomain] = useState('subscriptions');
    const [status, setStatus] = useState('all');
    const [search, setSearch] = useState('');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [exportFmt, setExportFmt] = useState(null);

    // Chart type
    const [chartType, setChartType] = useState('line'); // 'line' | 'bar'

    const domainConfig = DOMAINS[domain];

    // Auto daily for week/month
    const effectiveGranularity = useMemo(() => {
        if (granularity) return granularity;
        if (range === 'week' || range === 'month') return 'daily';
        if (range === 'year') return 'monthly';
        return 'daily';
    }, [range, granularity]);

    const rangeParams = useCallback(() => {
        const p = { range, granularity: effectiveGranularity };
        if (range === 'custom') {
            p.date_from = dateFrom;
            p.date_to = dateTo;
        }
        return p;
    }, [range, effectiveGranularity, dateFrom, dateTo]);

    // Data fetching
    useEffect(() => {
        getOverview(rangeParams());
    }, [rangeParams, getOverview]);

    useEffect(() => {
        getTrends(rangeParams());
    }, [rangeParams, getTrends]);

    useEffect(() => {
        setStatus('all');
        setPage(0);
    }, [domain]);

    useEffect(() => {
        getSummary({ ...rangeParams(), type: domain, status });
    }, [rangeParams, domain, status, getSummary]);

    useEffect(() => {
        getDetailed({
            ...rangeParams(),
            type: domain,
            status,
            search: search || undefined,
            page: page + 1,
            per_page: rowsPerPage,
        });
    }, [rangeParams, domain, status, search, page, rowsPerPage, getDetailed]);

    const refreshAll = () => {
        getOverview(rangeParams());
        getTrends(rangeParams());
        getSummary({ ...rangeParams(), type: domain, status });
        getDetailed({
            ...rangeParams(),
            type: domain,
            status,
            search: search || undefined,
            page: page + 1,
            per_page: rowsPerPage,
        });
    };

    const handleExport = async (format, scope = domain) => {
        setExportFmt(`${scope}-${format}`);
        try {
            const response = await exportFinanceReport({
                ...rangeParams(),
                type: scope,
                status: scope === 'all' ? undefined : status,
                format,
            });
            const blob = new Blob([response.data], {
                type:
                    format === 'xlsx'
                        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                        : 'text/csv',
            });
            const url = window.URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `finance_report_${scope}_${new Date().toISOString().slice(0, 10)}.${
                format === 'xlsx' ? 'xlsx' : 'csv'
            }`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            window.URL.revokeObjectURL(url);
            showSnackbar({ type: 'success', message: 'Report exported successfully' });
        } catch {
            // context already shows error
        } finally {
            setExportFmt(null);
        }
    };

    const headline = overview.headline || {};
    const trendBuckets = trends.buckets || [];
    const pieData = summary.status_breakdown || [];
    const dailyInsights = useMemo(() => buildDailyInsights(trendBuckets), [trendBuckets]);

    const headlineCards = useMemo(
        () => [
            {
                key: 'customers',
                label: 'Customers',
                color: DOMAINS.customers.chartColor,
                bg: 'linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%)',
                icon: PeopleIcon,
            },
            {
                key: 'requests',
                label: 'Requests',
                color: DOMAINS.requests.chartColor,
                bg: 'linear-gradient(135deg, #f5f3ff 0%, #ede9fe 100%)',
                icon: RequestIcon,
            },
            {
                key: 'subscriptions',
                label: 'Subscriptions',
                color: DOMAINS.subscriptions.chartColor,
                bg: 'linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%)',
                icon: SubIcon,
            },
            {
                key: 'technicians',
                label: 'Technicians',
                color: DOMAINS.technicians.chartColor,
                bg: 'linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%)',
                icon: TechIcon,
            },
        ],
        []
    );

    if (!canView) {
        return (
            <Paper sx={{ p: 4, textAlign: 'center', borderRadius: 3, m: 2 }}>
                <Typography color="error" variant="h6">
                    You do not have permission to view Reports.
                </Typography>
            </Paper>
        );
    }

    return (
        <Box
            sx={{
                width: '100%',
                maxWidth: '100%',
                px: { xs: 1.5, sm: 2, md: 3 },
                py: { xs: 2, md: 3 },
                bgcolor: '#f8fafc',
                minHeight: '100%',
            }}
        >
            {/* ===================== FILTER BAR ===================== */}
            <Paper
                elevation={0}
                sx={{
                    p: { xs: 2, sm: 2.5 },
                    mb: 3,
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    bgcolor: '#fff',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
                }}
            >
                <Stack
                    direction={{ xs: 'column', md: 'row' }}
                    spacing={2}
                    alignItems={{ xs: 'stretch', md: 'center' }}
                    flexWrap="wrap"
                    useFlexGap
                >
                    <TextField
                        select
                        label="Range"
                        size="small"
                        value={range}
                        onChange={(e) => setRange(e.target.value)}
                        sx={{ minWidth: { xs: '100%', sm: 140 } }}
                    >
                        <MenuItem value="week">This Week</MenuItem>
                        <MenuItem value="month">This Month</MenuItem>
                        <MenuItem value="year">This Year</MenuItem>
                        <MenuItem value="custom">Custom</MenuItem>
                    </TextField>

                    {range === 'custom' && (
                        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ width: { xs: '100%', sm: 'auto' } }}>
                            <TextField
                                label="From"
                                type="date"
                                size="small"
                                value={dateFrom}
                                onChange={(e) => setDateFrom(e.target.value)}
                                InputLabelProps={{ shrink: true }}
                                fullWidth={isMobile}
                            />
                            <TextField
                                label="To"
                                type="date"
                                size="small"
                                value={dateTo}
                                onChange={(e) => setDateTo(e.target.value)}
                                InputLabelProps={{ shrink: true }}
                                fullWidth={isMobile}
                            />
                        </Stack>
                    )}

                    <TextField
                        select
                        label="Granularity"
                        size="small"
                        value={granularity}
                        onChange={(e) => setGranularity(e.target.value)}
                        sx={{ minWidth: { xs: '100%', sm: 150 } }}
                        helperText={!granularity ? `Auto → ${effectiveGranularity}` : ' '}
                        FormHelperTextProps={{ sx: { mt: 0.25, mb: 0 } }}
                    >
                        <MenuItem value="">Auto ({effectiveGranularity})</MenuItem>
                        <MenuItem value="daily">Daily</MenuItem>
                        <MenuItem value="weekly">Weekly</MenuItem>
                        <MenuItem value="monthly">Monthly</MenuItem>
                    </TextField>

                    <Box flexGrow={1} sx={{ display: { xs: 'none', md: 'block' } }} />

                    <Stack direction="row" spacing={1.5} justifyContent={{ xs: 'flex-end', md: 'flex-start' }}>
                        <Tooltip title="Export all domains as one Excel workbook">
                            <span>
                                <Button
                                    size="small"
                                    variant="outlined"
                                    startIcon={<ExcelIcon />}
                                    onClick={() => handleExport('xlsx', 'all')}
                                    disabled={!!exportFmt}
                                    sx={{ borderRadius: 2 }}
                                >
                                    {isMobile ? 'All' : 'Export All'}
                                </Button>
                            </span>
                        </Tooltip>
                        <Button
                            variant="contained"
                            startIcon={<RefreshIcon />}
                            onClick={refreshAll}
                            disabled={loadingOverview || loadingTrends}
                            sx={{ borderRadius: 2 }}
                        >
                            Refresh
                        </Button>
                    </Stack>
                </Stack>
            </Paper>

            {/* ===================== DAILY SUMMARY ===================== */}
            {(range === 'week' || range === 'month' || effectiveGranularity === 'daily') && (
                <Paper
                    elevation={0}
                    sx={{
                        p: { xs: 2, sm: 2.5 },
                        mb: 3,
                        borderRadius: 3,
                        border: `1px solid ${colors.middle}`,
                        background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
                    }}
                >
                    <Stack direction="row" alignItems="center" spacing={1} mb={2}>
                        <TodayIcon sx={{ color: colors.primary, fontSize: 22 }} />
                        <Typography variant="h6" fontWeight={700}>
                            Daily Summary
                        </Typography>
                        {dailyInsights.lastLabel && (
                            <Chip
                                size="small"
                                label={`Latest: ${dailyInsights.lastLabel}`}
                                sx={{ height: 22, fontWeight: 600 }}
                            />
                        )}
                    </Stack>

                    {loadingTrends ? (
                        <Grid container spacing={2}>
                            {[1, 2, 3].map((i) => (
                                <Grid item xs={12} sm={4} key={i}>
                                    <Skeleton variant="rounded" height={110} sx={{ borderRadius: 2 }} />
                                </Grid>
                            ))}
                        </Grid>
                    ) : (
                        <Grid container spacing={2}>
                            {[
                                { title: 'Today / Latest Day', data: dailyInsights.today, icon: TodayIcon },
                                { title: 'Previous Day', data: dailyInsights.yesterday, icon: null },
                                { title: 'Last 7 Days (in range)', data: dailyInsights.weekSoFar, icon: WeekIcon },
                            ].map((block) => (
                                <Grid item xs={12} sm={4} key={block.title}>
                                    <Box
                                        sx={{
                                            p: 2,
                                            borderRadius: 2.5,
                                            bgcolor: '#fff',
                                            border: '1px solid #e2e8f0',
                                            height: '100%',
                                            boxShadow: '0 1px 2px rgba(0,0,0,0.03)',
                                        }}
                                    >
                                        <Stack direction="row" alignItems="center" spacing={0.75} mb={1}>
                                            {block.icon && <block.icon sx={{ fontSize: 16, color: 'text.secondary' }} />}
                                            <Typography
                                                variant="caption"
                                                color="text.secondary"
                                                fontWeight={700}
                                                textTransform="uppercase"
                                                letterSpacing={0.4}
                                            >
                                                {block.title}
                                            </Typography>
                                        </Stack>
                                        {block.data ? (
                                            <Stack spacing={0.4}>
                                                <Typography variant="body2">
                                                    Customers: <strong>{block.data.customers}</strong>
                                                </Typography>
                                                <Typography variant="body2">
                                                    Requests: <strong>{block.data.requests}</strong>
                                                </Typography>
                                                <Typography variant="body2">
                                                    Subscriptions: <strong>{block.data.subscriptions}</strong>
                                                </Typography>
                                                <Typography variant="body2">
                                                    Revenue:{' '}
                                                    <strong>
                                                        TZS {Number(block.data.subscriptions_revenue).toLocaleString()}
                                                    </strong>
                                                </Typography>
                                                <Typography variant="body2">
                                                    Technicians: <strong>{block.data.technicians}</strong>
                                                </Typography>
                                            </Stack>
                                        ) : (
                                            <Typography variant="body2" color="text.secondary">
                                                No data
                                            </Typography>
                                        )}
                                    </Box>
                                </Grid>
                            ))}
                        </Grid>
                    )}
                </Paper>
            )}

            {/* ===================== KPI CARDS ===================== */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                {headlineCards.map((item) => {
                    const Icon = item.icon;
                    return (
                        <Grid item xs={12} sm={6} lg={3} key={item.key}>
                            <Card
                                elevation={0}
                                sx={{
                                    borderRadius: 3,
                                    border: `1px solid ${colors.middle}`,
                                    background: item.bg,
                                    height: '100%',
                                    transition: 'all 0.22s ease',
                                    '&:hover': {
                                        boxShadow: '0 8px 20px rgba(0,0,0,0.07)',
                                        transform: 'translateY(-2px)',
                                    },
                                }}
                            >
                                <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
                                    <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                                        <Box sx={{ flex: 1, minWidth: 0 }}>
                                            <Typography
                                                variant="body2"
                                                sx={{ color: item.color, fontWeight: 700, mb: 0.5 }}
                                            >
                                                {item.label}
                                            </Typography>
                                            {loadingOverview ? (
                                                <Skeleton width={70} height={38} />
                                            ) : (
                                                <>
                                                    <Typography
                                                        variant="h4"
                                                        sx={{
                                                            color: item.color,
                                                            fontWeight: 800,
                                                            lineHeight: 1.15,
                                                            fontSize: { xs: '1.75rem', sm: '2rem' },
                                                        }}
                                                    >
                                                        {headline[item.key]?.count ?? 0}
                                                    </Typography>
                                                    <GrowthPill value={headline[item.key]?.growth} />
                                                    {item.key === 'subscriptions' && (
                                                        <Typography
                                                            variant="caption"
                                                            color="text.secondary"
                                                            display="block"
                                                            mt={0.75}
                                                            fontWeight={500}
                                                        >
                                                            Revenue: TZS{' '}
                                                            {Number(headline.subscriptions?.revenue || 0).toLocaleString()}
                                                            {headline.subscriptions?.revenue_growth != null && (
                                                                <Box component="span" ml={0.75}>
                                                                    (
                                                                    {headline.subscriptions.revenue_growth >= 0 ? '+' : ''}
                                                                    {headline.subscriptions.revenue_growth}%)
                                                                </Box>
                                                            )}
                                                        </Typography>
                                                    )}
                                                </>
                                            )}
                                        </Box>
                                        <Box
                                            sx={{
                                                width: 44,
                                                height: 44,
                                                borderRadius: 2.5,
                                                bgcolor: 'rgba(255,255,255,0.75)',
                                                display: 'flex',
                                                alignItems: 'center',
                                                justifyContent: 'center',
                                                flexShrink: 0,
                                                ml: 1,
                                            }}
                                        >
                                            <Icon sx={{ color: item.color, fontSize: 24 }} />
                                        </Box>
                                    </Stack>
                                </CardContent>
                            </Card>
                        </Grid>
                    );
                })}
            </Grid>

            {/* ===================== COMBINED TREND (Line + Histogram) ===================== */}
            <Paper
                elevation={0}
                sx={{
                    p: { xs: 2, sm: 3 },
                    mb: 3,
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    bgcolor: '#fff',
                    minHeight: { xs: 420, sm: 480 },
                }}
            >
                <Stack
                    direction={{ xs: 'column', sm: 'row' }}
                    justifyContent="space-between"
                    alignItems={{ xs: 'flex-start', sm: 'center' }}
                    spacing={1.5}
                    mb={2.5}
                >
                    <Box>
                        <Typography variant="h6" fontWeight={700}>
                            Combined Trend
                            <Typography
                                component="span"
                                variant="body2"
                                color="text.secondary"
                                ml={1}
                                fontWeight={500}
                            >
                                ({trends.granularity || effectiveGranularity})
                            </Typography>
                        </Typography>
                        {(range === 'week' || range === 'month') && (
                            <Chip
                                size="small"
                                label="Daily view"
                                color="primary"
                                variant="outlined"
                                sx={{ mt: 0.75, height: 22, fontWeight: 600 }}
                            />
                        )}
                    </Box>

                    <Stack direction="row" spacing={1}>
                        <Button
                            size="small"
                            variant={chartType === 'line' ? 'contained' : 'outlined'}
                            startIcon={<LineIcon />}
                            onClick={() => setChartType('line')}
                            sx={{ borderRadius: 2, textTransform: 'none', px: 1.5 }}
                        >
                            Line
                        </Button>
                        <Button
                            size="small"
                            variant={chartType === 'bar' ? 'contained' : 'outlined'}
                            startIcon={<BarIcon />}
                            onClick={() => setChartType('bar')}
                            sx={{ borderRadius: 2, textTransform: 'none', px: 1.5 }}
                        >
                            Histogram
                        </Button>
                    </Stack>
                </Stack>

                {loadingTrends ? (
                    <Box sx={{ height: 360, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <CircularProgress />
                    </Box>
                ) : trendBuckets.length === 0 ? (
                    <Box sx={{ height: 360, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Typography color="text.secondary">No data available for the selected period</Typography>
                    </Box>
                ) : chartType === 'line' ? (
                    <ResponsiveContainer width="100%" height={isMobile ? 300 : 380}>
                        <AreaChart data={trendBuckets} margin={{ top: 8, right: 12, left: -10, bottom: 0 }}>
                            <defs>
                                {Object.values(DOMAINS).map((d) => (
                                    <linearGradient key={d.label} id={`grad-${d.label}`} x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor={d.chartColor} stopOpacity={0.3} />
                                        <stop offset="95%" stopColor={d.chartColor} stopOpacity={0} />
                                    </linearGradient>
                                ))}
                            </defs>
                            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                            <XAxis dataKey="label" tick={{ fontSize: 11 }} axisLine={false} tickLine={false} />
                            <YAxis tick={{ fontSize: 11 }} axisLine={false} tickLine={false} />
                            <ChartTooltip
                                contentStyle={{
                                    borderRadius: 10,
                                    border: '1px solid #e2e8f0',
                                    boxShadow: '0 4px 14px rgba(0,0,0,0.08)',
                                }}
                            />
                            <Legend wrapperStyle={{ paddingTop: 14 }} />
                            <Area
                                type="monotone"
                                dataKey="customers"
                                name="Customers"
                                stroke={DOMAINS.customers.chartColor}
                                fill={`url(#grad-${DOMAINS.customers.label})`}
                                strokeWidth={2.5}
                                dot={false}
                                activeDot={{ r: 5 }}
                            />
                            <Area
                                type="monotone"
                                dataKey="requests"
                                name="Requests"
                                stroke={DOMAINS.requests.chartColor}
                                fill={`url(#grad-${DOMAINS.requests.label})`}
                                strokeWidth={2.5}
                                dot={false}
                                activeDot={{ r: 5 }}
                            />
                            <Area
                                type="monotone"
                                dataKey="subscriptions"
                                name="Subscriptions"
                                stroke={DOMAINS.subscriptions.chartColor}
                                fill={`url(#grad-${DOMAINS.subscriptions.label})`}
                                strokeWidth={2.5}
                                dot={false}
                                activeDot={{ r: 5 }}
                            />
                            <Area
                                type="monotone"
                                dataKey="technicians"
                                name="Technicians"
                                stroke={DOMAINS.technicians.chartColor}
                                fill={`url(#grad-${DOMAINS.technicians.label})`}
                                strokeWidth={2.5}
                                dot={false}
                                activeDot={{ r: 5 }}
                            />
                        </AreaChart>
                    </ResponsiveContainer>
                ) : (
                    <ResponsiveContainer width="100%" height={isMobile ? 300 : 380}>
                        <BarChart
                            data={trendBuckets}
                            margin={{ top: 8, right: 12, left: -10, bottom: 0 }}
                            barCategoryGap="16%"
                            barGap={2}
                        >
                            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                            <XAxis dataKey="label" tick={{ fontSize: 11 }} axisLine={false} tickLine={false} />
                            <YAxis tick={{ fontSize: 11 }} axisLine={false} tickLine={false} />
                            <ChartTooltip
                                contentStyle={{
                                    borderRadius: 10,
                                    border: '1px solid #e2e8f0',
                                    boxShadow: '0 4px 14px rgba(0,0,0,0.08)',
                                }}
                                cursor={{ fill: 'rgba(0,0,0,0.04)' }}
                            />
                            <Legend wrapperStyle={{ paddingTop: 14 }} />
                            <Bar
                                dataKey="customers"
                                name="Customers"
                                fill={DOMAINS.customers.chartColor}
                                radius={[4, 4, 0, 0]}
                                maxBarSize={26}
                            />
                            <Bar
                                dataKey="requests"
                                name="Requests"
                                fill={DOMAINS.requests.chartColor}
                                radius={[4, 4, 0, 0]}
                                maxBarSize={26}
                            />
                            <Bar
                                dataKey="subscriptions"
                                name="Subscriptions"
                                fill={DOMAINS.subscriptions.chartColor}
                                radius={[4, 4, 0, 0]}
                                maxBarSize={26}
                            />
                            <Bar
                                dataKey="technicians"
                                name="Technicians"
                                fill={DOMAINS.technicians.chartColor}
                                radius={[4, 4, 0, 0]}
                                maxBarSize={26}
                            />
                        </BarChart>
                    </ResponsiveContainer>
                )}
            </Paper>

            {/* ===================== DOMAIN TABS + PIE + TOTALS ===================== */}
            <Paper
                elevation={0}
                sx={{
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    mb: 3,
                    overflow: 'hidden',
                    bgcolor: '#fff',
                }}
            >
                <Tabs
                    value={domain}
                    onChange={(e, v) => setDomain(v)}
                    variant="scrollable"
                    scrollButtons="auto"
                    allowScrollButtonsMobile
                    sx={{
                        borderBottom: `1px solid ${colors.middle}`,
                        px: 1,
                        minHeight: 48,
                        '& .MuiTab-root': { fontWeight: 600, textTransform: 'none', minHeight: 48 },
                    }}
                >
                    {Object.entries(DOMAINS).map(([key, cfg]) => (
                        <Tab key={key} value={key} label={cfg.label} />
                    ))}
                </Tabs>

                <Grid container>
                    {/* Pie Chart */}
                    <Grid
                        item
                        xs={12}
                        md={5}
                        sx={{
                            p: { xs: 2, sm: 3 },
                            borderRight: { md: `1px solid ${colors.middle}` },
                            borderBottom: { xs: `1px solid ${colors.middle}`, md: 'none' },
                        }}
                    >
                        <Typography variant="h6" fontWeight={700} mb={2}>
                            {domainConfig.label} by Status
                        </Typography>
                        {loadingSummary ? (
                            <Box sx={{ height: 280, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                <CircularProgress />
                            </Box>
                        ) : pieData.length === 0 ? (
                            <Box sx={{ height: 280, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                <Typography color="text.secondary">No data for this period</Typography>
                            </Box>
                        ) : (
                            <ResponsiveContainer width="100%" height={280}>
                                <PieChart>
                                    <Pie
                                        data={pieData}
                                        dataKey="total"
                                        nameKey="status"
                                        cx="50%"
                                        cy="50%"
                                        outerRadius={isMobile ? 80 : 95}
                                        label={({ status, total }) =>
                                            `${(status || '').replace(/_/g, ' ')}: ${total}`
                                        }
                                    >
                                        {pieData.map((entry, idx) => (
                                            <Cell
                                                key={idx}
                                                fill={(STATUS_COLORS[entry.status] || {}).color || '#94a3b8'}
                                            />
                                        ))}
                                    </Pie>
                                    <ChartTooltip />
                                    <Legend verticalAlign="bottom" height={36} />
                                </PieChart>
                            </ResponsiveContainer>
                        )}
                    </Grid>

                    {/* Totals + Export */}
                    <Grid item xs={12} md={7} sx={{ p: { xs: 2, sm: 3 } }}>
                        <Typography variant="h6" fontWeight={700} mb={2}>
                            Totals
                        </Typography>
                        <Grid container spacing={1.5}>
                            {Object.entries(summary.totals || {}).map(([key, value]) => (
                                <Grid item xs={6} sm={4} key={key}>
                                    <Box
                                        sx={{
                                            p: 1.75,
                                            borderRadius: 2.5,
                                            bgcolor: '#f8fafc',
                                            border: `1px solid ${colors.middle}`,
                                            height: '100%',
                                        }}
                                    >
                                        <Typography
                                            variant="caption"
                                            color="text.secondary"
                                            sx={{ textTransform: 'capitalize', fontWeight: 600 }}
                                        >
                                            {key.replace(/_/g, ' ')}
                                        </Typography>
                                        <Typography variant="subtitle1" fontWeight={800} mt={0.25}>
                                            {typeof value === 'number' && key.toLowerCase().includes('revenue')
                                                ? `TZS ${Number(value).toLocaleString()}`
                                                : value}
                                        </Typography>
                                    </Box>
                                </Grid>
                            ))}
                        </Grid>

                        <Divider sx={{ my: 2.5 }} />

                        <Stack direction="row" spacing={1.5} flexWrap="wrap" useFlexGap>
                            <Tooltip title={`Export ${domainConfig.label} as CSV`}>
                                <span>
                                    <Button
                                        size="small"
                                        variant="outlined"
                                        startIcon={<CsvIcon />}
                                        onClick={() => handleExport('csv')}
                                        disabled={!!exportFmt}
                                        sx={{ borderRadius: 2 }}
                                    >
                                        CSV
                                    </Button>
                                </span>
                            </Tooltip>
                            <Tooltip title={`Export ${domainConfig.label} as Excel`}>
                                <span>
                                    <Button
                                        size="small"
                                        variant="outlined"
                                        startIcon={<ExcelIcon />}
                                        onClick={() => handleExport('xlsx')}
                                        disabled={!!exportFmt}
                                        sx={{ borderRadius: 2 }}
                                    >
                                        Excel
                                    </Button>
                                </span>
                            </Tooltip>
                        </Stack>
                    </Grid>
                </Grid>
            </Paper>

            {/* ===================== DETAILED TABLE ===================== */}
            <Paper
                elevation={0}
                sx={{
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    overflow: 'hidden',
                    bgcolor: '#fff',
                }}
            >
                <Box
                    sx={{
                        p: { xs: 2, sm: 2.5 },
                        borderBottom: `1px solid ${colors.middle}`,
                        display: 'flex',
                        flexDirection: { xs: 'column', sm: 'row' },
                        justifyContent: 'space-between',
                        alignItems: { xs: 'stretch', sm: 'center' },
                        gap: 2,
                    }}
                >
                    <Typography variant="h6" fontWeight={700}>
                        {domainConfig.label} Records
                    </Typography>
                    <Stack
                        direction={{ xs: 'column', sm: 'row' }}
                        spacing={1.5}
                        sx={{ width: { xs: '100%', sm: 'auto' } }}
                    >
                        <TextField
                            select
                            label="Status"
                            size="small"
                            value={status}
                            onChange={(e) => {
                                setStatus(e.target.value);
                                setPage(0);
                            }}
                            sx={{ minWidth: { xs: '100%', sm: 150 } }}
                        >
                            <MenuItem value="all">All</MenuItem>
                            {domainConfig.statuses.map((s) => (
                                <MenuItem key={s} value={s} sx={{ textTransform: 'capitalize' }}>
                                    {s.replace(/_/g, ' ')}
                                </MenuItem>
                            ))}
                        </TextField>
                        <TextField
                            size="small"
                            placeholder="Search..."
                            value={search}
                            onChange={(e) => {
                                setSearch(e.target.value);
                                setPage(0);
                            }}
                            sx={{ minWidth: { xs: '100%', sm: 220 } }}
                        />
                    </Stack>
                </Box>

                {loadingDetailed ? (
                    <Box sx={{ py: 8, textAlign: 'center' }}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <TableContainer sx={{ maxWidth: '100%', overflowX: 'auto' }}>
                        <Table size={isMobile ? 'small' : 'medium'}>
                            <TableHead sx={{ backgroundColor: '#f8fafc' }}>
                                <TableRow>
                                    {domainConfig.columns.map((col) => (
                                        <TableCell key={col} sx={{ fontWeight: 700, whiteSpace: 'nowrap' }}>
                                            {col}
                                        </TableCell>
                                    ))}
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {(detailed.data || []).length === 0 ? (
                                    <TableRow>
                                        <TableCell
                                            colSpan={domainConfig.columns.length}
                                            align="center"
                                            sx={{ py: 6 }}
                                        >
                                            <Typography color="text.secondary">No records found</Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    detailed.data.map((row) => (
                                        <TableRow key={row.id} hover>
                                            {domainConfig.renderRow(row).map((cell, idx) => (
                                                <TableCell key={idx} sx={{ whiteSpace: 'nowrap' }}>
                                                    {cell}
                                                </TableCell>
                                            ))}
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                )}

                <TablePagination
                    component="div"
                    count={detailed.pagination?.total || 0}
                    rowsPerPage={rowsPerPage}
                    page={page}
                    onPageChange={(e, p) => setPage(p)}
                    onRowsPerPageChange={(e) => {
                        setRowsPerPage(parseInt(e.target.value, 10));
                        setPage(0);
                    }}
                    rowsPerPageOptions={[5, 10, 25, 50]}
                    sx={{ borderTop: `1px solid ${colors.middle}` }}
                />
            </Paper>
        </Box>
    );
};

export default Dashboard;