import React, { useState, useEffect, useCallback } from 'react';
import {
    Box, Paper, Typography, Button, Grid, Card, CardContent, TextField, MenuItem,
    Table, TableBody, TableCell, TableContainer, TableHead, TableRow, TablePagination,
    Chip, CircularProgress, Tooltip, Stack,
} from '@mui/material';
import { Refresh as RefreshIcon, Description as CsvIcon, TableChart as ExcelIcon } from '@mui/icons-material';
import {
    PieChart, Pie, Cell, Tooltip as ChartTooltip, Legend, ResponsiveContainer,
    BarChart, Bar, XAxis, YAxis, CartesianGrid,
} from 'recharts';
import { usePermissions } from 'hooks/usePermissions';
import { useFinanceTechnicianManagement } from 'hooks/useFinanceTechnician';
import { showSnackbar } from 'utils/snackbar';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const STATUS_COLORS = {
    pending: '#f59e0b',
    approved: '#10b981',
    rejected: '#ef4444',
};

const FinanceTechnicians = () => {
    const { can } = usePermissions();
    const canView = can('finance.view');

    const {
        summary,
        trends,
        table,
        loadingSummary,
        loadingTrends,
        loadingTable,
        getSummary,
        getTrends,
        getTable,
        exportFinanceReport,
    } = useFinanceTechnicianManagement();

    const [range, setRange] = useState('year');
    const [granularity, setGranularity] = useState('');
    const [status, setStatus] = useState('all');
    const [dateFrom, setDateFrom] = useState('');
    const [dateTo, setDateTo] = useState('');
    const [search, setSearch] = useState('');
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [exportFmt, setExportFmt] = useState(null);
    const [dailyHistogramData, setDailyHistogramData] = useState([]);
    const [loadingDailyHistogram, setLoadingDailyHistogram] = useState(false);

    const baseParams = useCallback(() => {
        const params = { range, status };
        if (granularity) params.granularity = granularity;
        if (range === 'custom') {
            params.date_from = dateFrom;
            params.date_to = dateTo;
        }
        return params;
    }, [range, granularity, status, dateFrom, dateTo]);

    // Helper function to get current week/month dates in Africa/East timezone
    const getDateRangeForHistogram = useCallback(() => {
        const now = new Date();
        // Convert to Africa/East timezone (UTC+3)
        const eastAfricaTime = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Nairobi' }));

        let startDate, endDate;

        if (range === 'week' || range === 'this_week') {
            // Get current week (Monday to Sunday)
            const day = eastAfricaTime.getDay();
            const diff = eastAfricaTime.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
            startDate = new Date(eastAfricaTime);
            startDate.setDate(diff);
            startDate.setHours(0, 0, 0, 0);

            endDate = new Date(startDate);
            endDate.setDate(startDate.getDate() + 6);
            endDate.setHours(23, 59, 59, 999);
        } else if (range === 'month' || range === 'this_month') {
            // Get current month
            startDate = new Date(eastAfricaTime.getFullYear(), eastAfricaTime.getMonth(), 1);
            startDate.setHours(0, 0, 0, 0);

            endDate = new Date(eastAfricaTime.getFullYear(), eastAfricaTime.getMonth() + 1, 0);
            endDate.setHours(23, 59, 59, 999);
        } else if (range === 'custom') {
            // Use custom dates if provided
            if (dateFrom && dateTo) {
                startDate = new Date(dateFrom);
                startDate.setHours(0, 0, 0, 0);
                endDate = new Date(dateTo);
                endDate.setHours(23, 59, 59, 999);
            } else {
                // Fallback to current week if custom dates not set
                const day = eastAfricaTime.getDay();
                const diff = eastAfricaTime.getDate() - day + (day === 0 ? -6 : 1);
                startDate = new Date(eastAfricaTime);
                startDate.setDate(diff);
                startDate.setHours(0, 0, 0, 0);
                endDate = new Date(startDate);
                endDate.setDate(startDate.getDate() + 6);
                endDate.setHours(23, 59, 59, 999);
            }
        } else {
            // Default to current week
            const day = eastAfricaTime.getDay();
            const diff = eastAfricaTime.getDate() - day + (day === 0 ? -6 : 1);
            startDate = new Date(eastAfricaTime);
            startDate.setDate(diff);
            startDate.setHours(0, 0, 0, 0);
            endDate = new Date(startDate);
            endDate.setDate(startDate.getDate() + 6);
            endDate.setHours(23, 59, 59, 999);
        }

        return { startDate, endDate };
    }, [range, dateFrom, dateTo]);

    // Fetch daily histogram data
    const fetchDailyHistogram = useCallback(async () => {
        setLoadingDailyHistogram(true);
        try {
            const { startDate, endDate } = getDateRangeForHistogram();

            // Get current date in Africa/East timezone
            const now = new Date();
            const eastAfricaNow = new Date(now.toLocaleString('en-US', { timeZone: 'Africa/Nairobi' }));

            // Generate date range
            const dates = [];
            let currentDate = new Date(startDate);

            while (currentDate <= endDate) {
                const dateStr = currentDate.toISOString().split('T')[0];
                dates.push({
                    date: dateStr,
                    displayDate: currentDate.toLocaleDateString('en-US', {
                        weekday: 'short',
                        month: 'short',
                        day: 'numeric',
                        timeZone: 'Africa/Nairobi'
                    }),
                    count: 0,
                    // For week view, include day name
                    dayName: currentDate.toLocaleDateString('en-US', {
                        weekday: 'short',
                        timeZone: 'Africa/Nairobi'
                    }),
                    isToday: currentDate.toDateString() === eastAfricaNow.toDateString(),
                });
                currentDate.setDate(currentDate.getDate() + 1);
            }

            // If we have table data, aggregate by date
            if (table.data && table.data.length > 0) {
                const dateMap = {};
                table.data.forEach(item => {
                    if (item.created_at) {
                        const itemDate = new Date(item.created_at);
                        // Convert to Africa/East timezone for comparison
                        const eastAfricaItemDate = new Date(itemDate.toLocaleString('en-US', { timeZone: 'Africa/Nairobi' }));
                        const dateKey = eastAfricaItemDate.toISOString().split('T')[0];

                        if (dateMap[dateKey]) {
                            dateMap[dateKey].count += 1;
                        } else {
                            dateMap[dateKey] = {
                                count: 1
                            };
                        }
                    }
                });

                // Update dates with actual data
                dates.forEach(d => {
                    if (dateMap[d.date]) {
                        d.count = dateMap[d.date].count;
                    }
                });
            }

            setDailyHistogramData(dates);
        } catch (error) {
            console.error('Error fetching daily histogram:', error);
            showSnackbar({ type: 'error', message: 'Failed to load daily histogram data' });
        } finally {
            setLoadingDailyHistogram(false);
        }
    }, [getDateRangeForHistogram, table.data]);

    useEffect(() => {
        getSummary(baseParams());
        getTrends(baseParams());
    }, [baseParams, getSummary, getTrends]);

    useEffect(() => {
        getTable({
            ...baseParams(),
            search: search || undefined,
            page: page + 1,
            per_page: rowsPerPage,
        });
    }, [baseParams, search, page, rowsPerPage, getTable]);

    // Fetch daily histogram when table data or range changes
    useEffect(() => {
        fetchDailyHistogram();
    }, [fetchDailyHistogram, range, dateFrom, dateTo]);

    const refreshAll = () => {
        const params = baseParams();
        getSummary(params);
        getTrends(params);
        getTable({
            ...params,
            search: search || undefined,
            page: page + 1,
            per_page: rowsPerPage,
        });
        fetchDailyHistogram();
    };

    const handleExport = async (format) => {
        setExportFmt(format);
        try {
            const response = await exportFinanceReport({ ...baseParams(), format });
            const blob = new Blob([response.data], {
                type: format === 'xlsx' ? 'application/vnd.ms-excel' : 'text/csv',
            });
            const url = window.URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `finance_technicians_${new Date().toISOString().slice(0, 10)}.${format === 'xlsx' ? 'xls' : 'csv'}`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            window.URL.revokeObjectURL(url);
            showSnackbar({ type: 'success', message: 'Report exported successfully' });
        } catch {
            showSnackbar({ type: 'error', message: 'Export failed' });
        } finally {
            setExportFmt(null);
        }
    };

    const formatDate = (d) => {
        if (!d) return '-';
        try {
            return new Date(d).toLocaleDateString();
        } catch {
            return '-';
        }
    };

    const getStatusChip = (s) => {
        const map = {
            pending: { color: '#f59e0b', bg: '#fef3c7' },
            approved: { color: '#10b981', bg: '#d1fae5' },
            rejected: { color: '#ef4444', bg: '#fee2e2' },
        };
        const st = map[s] || { color: '#6b7280', bg: '#f3f4f6' };
        return (
            <Chip
                label={s || '-'}
                size="small"
                sx={{
                    backgroundColor: st.bg,
                    color: st.color,
                    fontWeight: 600,
                    textTransform: 'capitalize',
                }}
            />
        );
    };

    if (!canView) {
        return (
            <Paper sx={{ p: 3, textAlign: 'center' }}>
                <Typography color="error">You do not have permission to view Finance.</Typography>
            </Paper>
        );
    }

    const totals = summary.totals || {};

    return (
        <Box sx={{ width: '100%', maxWidth: '100%' }}>
            {/* Filters */}
            <Paper
                elevation={0}
                sx={{
                    p: 2,
                    mb: 3,
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                }}
            >
                <Stack direction="row" spacing={2} flexWrap="wrap" useFlexGap alignItems="center">
                    <TextField
                        select
                        label="Range"
                        size="small"
                        value={range}
                        onChange={(e) => setRange(e.target.value)}
                        sx={{ minWidth: 140 }}
                    >
                        <MenuItem value="week">This Week</MenuItem>
                        <MenuItem value="month">This Month</MenuItem>
                        <MenuItem value="year">This Year</MenuItem>
                        <MenuItem value="custom">Custom</MenuItem>
                    </TextField>

                    {range === 'custom' && (
                        <>
                            <TextField
                                label="From"
                                type="date"
                                size="small"
                                value={dateFrom}
                                onChange={(e) => setDateFrom(e.target.value)}
                                InputLabelProps={{ shrink: true }}
                            />
                            <TextField
                                label="To"
                                type="date"
                                size="small"
                                value={dateTo}
                                onChange={(e) => setDateTo(e.target.value)}
                                InputLabelProps={{ shrink: true }}
                            />
                        </>
                    )}

                    <TextField
                        select
                        label="Granularity"
                        size="small"
                        value={granularity}
                        onChange={(e) => setGranularity(e.target.value)}
                        sx={{ minWidth: 140 }}
                    >
                        <MenuItem value="">Auto</MenuItem>
                        <MenuItem value="daily">Daily</MenuItem>
                        <MenuItem value="weekly">Weekly</MenuItem>
                        <MenuItem value="monthly">Monthly</MenuItem>
                    </TextField>

                    <TextField
                        select
                        label="Status"
                        size="small"
                        value={status}
                        onChange={(e) => {
                            setStatus(e.target.value);
                            setPage(0);
                        }}
                        sx={{ minWidth: 140 }}
                    >
                        <MenuItem value="all">All</MenuItem>
                        <MenuItem value="pending">Pending</MenuItem>
                        <MenuItem value="approved">Approved</MenuItem>
                        <MenuItem value="rejected">Rejected</MenuItem>
                    </TextField>

                    <Box flexGrow={1} />

                    <Tooltip title="Export CSV">
                        <span>
                            <Button
                                size="small"
                                variant="outlined"
                                startIcon={<CsvIcon />}
                                onClick={() => handleExport('csv')}
                                disabled={!!exportFmt}
                            >
                                CSV
                            </Button>
                        </span>
                    </Tooltip>

                    <Tooltip title="Export Excel">
                        <span>
                            <Button
                                size="small"
                                variant="outlined"
                                startIcon={<ExcelIcon />}
                                onClick={() => handleExport('xlsx')}
                                disabled={!!exportFmt}
                            >
                                Excel
                            </Button>
                        </span>
                    </Tooltip>

                    <Button variant="contained" startIcon={<RefreshIcon />} onClick={refreshAll}>
                        Refresh
                    </Button>
                </Stack>
            </Paper>

            {/* Summary Cards (Online removed) */}
            <Grid container spacing={2} sx={{ mb: 3 }}>
                {[
                    { label: 'Total Technicians', value: totals.count || 0, color: '#3b82f6', bg: '#eff6ff' },
                    { label: 'Approved', value: totals.approved || 0, color: '#10b981', bg: '#ecfdf5' },
                    { label: 'Pending', value: totals.pending || 0, color: '#f59e0b', bg: '#fffbeb' },
                ].map((item, idx) => (
                    <Grid item xs={12} sm={6} md={4} key={idx}>
                        <Card
                            elevation={0}
                            sx={{
                                borderRadius: 3,
                                border: `1px solid ${colors.middle}`,
                                backgroundColor: item.bg,
                                height: '100%',
                            }}
                        >
                            <CardContent>
                                <Typography variant="body2" sx={{ color: item.color, fontWeight: 600, mb: 0.5 }}>
                                    {item.label}
                                </Typography>
                                <Typography variant="h4" sx={{ color: item.color, fontWeight: 700 }}>
                                    {item.value}
                                </Typography>
                            </CardContent>
                        </Card>
                    </Grid>
                ))}
            </Grid>

            {/* ========== DAILY HISTOGRAM CHART ========== */}
            <Paper
                elevation={0}
                sx={{
                    p: 3,
                    mb: 3,
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    height: 420,
                }}
            >
                <Typography variant="h6" fontWeight={600} mb={2}>
                    {range === 'week' || range === 'this_week' ? 'Daily Technician Registrations (This Week)' :
                        range === 'month' || range === 'this_month' ? 'Daily Technician Registrations (This Month)' :
                            'Daily Technician Registrations (Selected Range)'}
                </Typography>
                {loadingDailyHistogram ? (
                    <Box sx={{ height: '85%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <CircularProgress />
                    </Box>
                ) : dailyHistogramData.length === 0 ? (
                    <Box sx={{ height: '85%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Typography color="text.secondary">No data available for the selected period</Typography>
                    </Box>
                ) : (
                    <ResponsiveContainer width="100%" height="90%">
                        <BarChart data={dailyHistogramData} margin={{ top: 10, right: 30, left: 0, bottom: 20 }}>
                            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                            <XAxis
                                dataKey={range === 'week' || range === 'this_week' ? 'dayName' : 'displayDate'}
                                tick={{ fontSize: 12 }}
                                interval={0}
                                angle={range === 'month' || range === 'this_month' ? -45 : 0}
                                textAnchor={range === 'month' || range === 'this_month' ? 'end' : 'middle'}
                                height={range === 'month' || range === 'this_month' ? 60 : 30}
                            />
                            <YAxis tick={{ fontSize: 12 }} />
                            <ChartTooltip
                                formatter={(value) => value}
                                labelFormatter={(label) => {
                                    const item = dailyHistogramData.find(d =>
                                        (range === 'week' || range === 'this_week' ? d.dayName : d.displayDate) === label
                                    );
                                    return item ? `${item.dayName || ''} ${item.displayDate || ''}` : label;
                                }}
                            />
                            <Legend />
                            <Bar
                                dataKey="count"
                                name="Registrations"
                                fill="#3b82f6"
                                radius={[6, 6, 0, 0]}
                            >
                                {dailyHistogramData.map((entry, index) => (
                                    <Cell
                                        key={`cell-${index}`}
                                        fill={entry.isToday ? '#10b981' : '#3b82f6'}
                                        fillOpacity={entry.isToday ? 1 : 0.7}
                                    />
                                ))}
                            </Bar>
                        </BarChart>
                    </ResponsiveContainer>
                )}
            </Paper>

            {/* Pie Chart */}
            <Paper
                elevation={0}
                sx={{
                    p: 3,
                    mb: 3,
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    height: 420,
                }}
            >
                <Typography variant="h6" fontWeight={600} mb={2}>
                    By Verification Status
                </Typography>
                {loadingSummary ? (
                    <Box sx={{ height: '85%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <ResponsiveContainer width="100%" height="90%">
                        <PieChart>
                            <Pie
                                data={summary.status_breakdown || []}
                                dataKey="total"
                                nameKey="status"
                                cx="50%"
                                cy="50%"
                                outerRadius={140}
                                label={({ status, total }) => `${status}: ${total}`}
                            >
                                {(summary.status_breakdown || []).map((entry, idx) => (
                                    <Cell key={idx} fill={STATUS_COLORS[entry.status] || '#94a3b8'} />
                                ))}
                            </Pie>
                            <ChartTooltip />
                            <Legend verticalAlign="bottom" height={36} />
                        </PieChart>
                    </ResponsiveContainer>
                )}
            </Paper>

            {/* Trend Chart */}
            <Paper
                elevation={0}
                sx={{
                    p: 3,
                    mb: 3,
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    height: 400,
                }}
            >
                <Typography variant="h6" fontWeight={600} mb={2}>
                    Registrations Trend ({trends.granularity || 'auto'})
                </Typography>
                {loadingTrends ? (
                    <Box sx={{ height: '85%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <ResponsiveContainer width="100%" height="90%">
                        <BarChart data={trends.buckets || []} margin={{ top: 10, right: 30, left: 0, bottom: 5 }}>
                            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                            <XAxis dataKey="label" tick={{ fontSize: 13 }} />
                            <YAxis tick={{ fontSize: 13 }} />
                            <ChartTooltip />
                            <Legend />
                            <Bar dataKey="count" name="Registrations" fill="#3b82f6" radius={[6, 6, 0, 0]} />
                        </BarChart>
                    </ResponsiveContainer>
                )}
            </Paper>

            {/* Table (Online column removed) */}
            <Paper
                elevation={0}
                sx={{
                    borderRadius: 3,
                    border: `1px solid ${colors.middle}`,
                    overflow: 'hidden',
                }}
            >
                <Box
                    sx={{
                        p: 2.5,
                        borderBottom: `1px solid ${colors.middle}`,
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        flexWrap: 'wrap',
                        gap: 2,
                    }}
                >
                    <Typography variant="h6" fontWeight={600}>
                        Technician Records
                    </Typography>
                    <TextField
                        size="small"
                        placeholder="Search name / area..."
                        value={search}
                        onChange={(e) => {
                            setSearch(e.target.value);
                            setPage(0);
                        }}
                        sx={{ minWidth: 240 }}
                    />
                </Box>

                {loadingTable ? (
                    <Box sx={{ py: 6, textAlign: 'center' }}>
                        <CircularProgress />
                    </Box>
                ) : (
                    <TableContainer>
                        <Table>
                            <TableHead sx={{ backgroundColor: '#f8fafc' }}>
                                <TableRow>
                                    <TableCell sx={{ fontWeight: 700 }}>Name</TableCell>
                                    <TableCell sx={{ fontWeight: 700 }}>Area</TableCell>
                                    <TableCell sx={{ fontWeight: 700 }}>Rating</TableCell>
                                    <TableCell sx={{ fontWeight: 700 }}>Status</TableCell>
                                    <TableCell sx={{ fontWeight: 700 }}>Created</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {table.data?.length === 0 ? (
                                    <TableRow>
                                        <TableCell colSpan={5} align="center" sx={{ py: 5 }}>
                                            <Typography color="text.secondary">No records found</Typography>
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    table.data.map((row) => (
                                        <TableRow key={row.id} hover>
                                            <TableCell>
                                                <Typography variant="body2" fontWeight={500}>
                                                    {row.user?.name || '-'}
                                                </Typography>
                                                <Typography variant="caption" color="text.secondary">
                                                    {row.user?.email || ''}
                                                </Typography>
                                            </TableCell>
                                            <TableCell>{row.area || '-'}</TableCell>
                                            <TableCell>{row.rating ?? '-'}</TableCell>
                                            <TableCell>{getStatusChip(row.verification_status)}</TableCell>
                                            <TableCell>{formatDate(row.created_at)}</TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                )}

                <TablePagination
                    component="div"
                    count={table.pagination?.total || 0}
                    rowsPerPage={rowsPerPage}
                    page={page}
                    onPageChange={(e, newPage) => setPage(newPage)}
                    onRowsPerPageChange={(e) => {
                        setRowsPerPage(parseInt(e.target.value, 10));
                        setPage(0);
                    }}
                    rowsPerPageOptions={[5, 10, 25, 50]}
                />
            </Paper>
        </Box>
    );
};

export default FinanceTechnicians;