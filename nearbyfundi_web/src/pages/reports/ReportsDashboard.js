import React, { useState, useEffect } from 'react';
import {
    Box,
    Paper,
    Typography,
    Tabs,
    Tab,
    Grid,
    TextField,
    InputAdornment,
    Button,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    CircularProgress,
    Alert,
    useTheme,
    alpha,
    Chip,
    Avatar,
    Stack,
    LinearProgress,
    TableCell,
    TableRow,
} from '@mui/material';
import {
    People as PeopleIcon,
    Build as BuildIcon,
    Assignment as RequestIcon,
    Category as CategoryIcon,
    Comment as CommentIcon,
    Photo as PhotoIcon,
    Search as SearchIcon,
    Refresh as RefreshIcon,
    Download as DownloadIcon,
    Verified as VerifiedIcon,
    Star as StarIcon,
    Person as PersonIcon,
    CheckCircle as CheckCircleIcon,
    Cancel as CancelIcon,
    TrendingUp as TrendingUpIcon,
} from '@mui/icons-material';

import { reportService } from 'services/report.service';
import { usePermissions } from 'hooks/usePermissions';
import { showSnackbar } from 'utils/snackbar';
import * as XLSX from 'xlsx';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

import {
    ReportFilters,
    StatCard,
    StatusChip,
    TabPanel,
    ReportTable,
    ReportExportMenu,
    TrendChart,
    SummaryCards,
    BlogStats,
} from './components';

import appConfig from '../../config';

const colors = appConfig.app.colors;

const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    try {
        return new Date(dateStr).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
        });
    } catch {
        return '-';
    }
};

const ReportsDashboard = () => {
    const theme = useTheme();
    const { can } = usePermissions();
    const canViewReports = can('reports.view');

    const [tabValue, setTabValue] = useState(0);
    const [page, setPage] = useState(0);
    const [rowsPerPage, setRowsPerPage] = useState(10);
    const [search, setSearch] = useState('');
    const [filterStatus, setFilterStatus] = useState('');
    const [filterVerified, setFilterVerified] = useState('');
    const [filterArea, setFilterArea] = useState('');           // ✅ area filter
    const [filterRole, setFilterRole] = useState('');
    const [period, setPeriod] = useState('');
    const [periodDate, setPeriodDate] = useState(null);

    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [reportData, setReportData] = useState(null);
    const [exportMenuAnchor, setExportMenuAnchor] = useState(null);

    // ---------- Helpers ----------
    const getListData = () => {
        if (!reportData) return [];
        let data = [];
        switch (tabValue) {
            case 0: case 1: case 2:
                data = reportData?.data?.data;
                break;
            case 3:
                data = reportData?.data;
                break;
            case 4:
                data = [];
                break;
            case 5:
                data = reportData?.technicians_with_most_portfolios;
                break;
            default:
                data = [];
        }
        return Array.isArray(data) ? data : [];
    };

    const getTotalCount = () => {
        if (!reportData) return 0;
        if (tabValue <= 2) {
            return reportData?.data?.total || 0;
        } else if (tabValue === 3 || tabValue === 5) {
            return getListData().length;
        }
        return 0;
    };

    // ---------- Fetch ----------
    const fetchReportData = async () => {
        if (!canViewReports) return;
        setLoading(true);
        setError(null);

        const params = {
            page: page + 1,
            per_page: rowsPerPage,
            period: period || undefined,
            date: periodDate ? periodDate.toISOString().split('T')[0] : undefined,
        };
        if (search) params.search = search;
        if (filterStatus) params.status = filterStatus;
        if (filterVerified) params.verified = filterVerified;
        if (filterArea) params.area = filterArea;               // ✅ area filter
        if (filterRole) params.role = filterRole;

        try {
            let response;
            switch (tabValue) {
                case 0: response = await reportService.getUsersReport(params); break;
                case 1: response = await reportService.getTechniciansReport(params); break;
                case 2: response = await reportService.getRequestsReport(params); break;
                case 3: response = await reportService.getServicesReport(params); break;
                case 4: response = await reportService.getBlogReport(params); break;
                case 5: response = await reportService.getPortfolioReport(params); break;
                default: return;
            }
            if (response?.data?.status === 'success') {
                setReportData(response.data.data);
            } else {
                setReportData(null);
            }
        } catch (err) {
            setError(err.message || 'Failed to load report data');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (canViewReports) fetchReportData();
        // eslint-disable-next-line
    }, [
        tabValue, page, rowsPerPage, search, filterStatus,
        filterVerified, filterArea, filterRole, period, periodDate, canViewReports,
    ]);

    const handleRefresh = () => {
        fetchReportData();
        showSnackbar({ type: 'success', message: 'Report refreshed' });
    };

    const handleTabChange = (event, newValue) => {
        setTabValue(newValue);
        setPage(0);
    };
    const handleChangePage = (event, newPage) => setPage(newPage);
    const handleChangeRowsPerPage = (event) => {
        setRowsPerPage(parseInt(event.target.value, 10));
        setPage(0);
    };

    // ---------- Export ----------
    const getCurrentTabLabel = () => {
        const labels = ['Users', 'Technicians', 'Requests', 'Services', 'Blog', 'Portfolio'];
        return labels[tabValue] || 'Report';
    };

    const getExportData = () => {
        const list = getListData();
        let rows = [];
        if (tabValue === 0) {
            rows = list.map((u) => [
                u.name || 'N/A',
                u.email || 'N/A',
                u.phone || 'N/A',
                u.roles?.map((r) => r.name).join(', ') || 'N/A',
                u.status || 'inactive',
                formatDate(u.created_at),
            ]);
        } else if (tabValue === 1) {
            rows = list.map((t) => [
                t.user?.name || 'N/A',
                t.user?.email || 'N/A',
                t.area || 'N/A',
                t.rating || 0,
                t.verified ? 'Yes' : 'No',
                formatDate(t.created_at),
            ]);
        } else if (tabValue === 2) {
            rows = list.map((r) => [
                `#${r.id}`,
                r.customer?.name || 'N/A',
                r.technician?.user?.name || 'N/A',
                r.service?.name || 'N/A',
                r.status || 'N/A',
                formatDate(r.created_at),
            ]);
        } else if (tabValue === 3) {
            rows = list.map((s) => [s.name || 'N/A', s.requests_count || 0]);
        } else if (tabValue === 4) {
            const stats = reportData?.stats || {};
            rows = [
                ['Total Posts', stats.total_posts || 0],
                ['Total Comments', stats.total_comments || 0],
                ['Total Likes', stats.total_likes || 0],
                ['Avg Comments/Post', stats.avg_comments_per_post || 0],
            ];
        } else if (tabValue === 5) {
            rows = list.map((item) => [item.technician?.user?.name || 'Unknown', item.count || 0]);
        }
        return rows;
    };

    const getExportHeaders = () => {
        switch (tabValue) {
            case 0: return ['Name', 'Email', 'Phone', 'Role', 'Status', 'Created'];
            case 1: return ['Technician', 'Email', 'Area', 'Rating', 'Verified', 'Created'];
            case 2: return ['ID', 'Customer', 'Technician', 'Service', 'Status', 'Created'];
            case 3: return ['Service Name', 'Total Requests'];
            case 4: return ['Metric', 'Value'];
            case 5: return ['Technician', 'Portfolio Items'];
            default: return [];
        }
    };

    const exportToCSV = () => {
        const headers = getExportHeaders();
        const rows = getExportData();
        if (rows.length === 0) {
            showSnackbar({ type: 'warning', message: 'No data to export' });
            return;
        }
        const csvContent = [headers.join(','), ...rows.map((row) => row.join(','))].join('\n');
        const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `${getCurrentTabLabel()}_Report_${new Date().toISOString().split('T')[0]}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
        showSnackbar({ type: 'success', message: 'CSV exported successfully' });
        handleExportMenuClose();
    };

    const exportToExcel = () => {
        const headers = getExportHeaders();
        const rows = getExportData();
        if (rows.length === 0) {
            showSnackbar({ type: 'warning', message: 'No data to export' });
            return;
        }
        const wsData = [headers, ...rows];
        const ws = XLSX.utils.aoa_to_sheet(wsData);
        const wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, getCurrentTabLabel());
        XLSX.writeFile(wb, `${getCurrentTabLabel()}_Report_${new Date().toISOString().split('T')[0]}.xlsx`);
        showSnackbar({ type: 'success', message: 'Excel exported successfully' });
        handleExportMenuClose();
    };

    const exportToPDF = () => {
        const headers = getExportHeaders();
        const rows = getExportData();
        if (rows.length === 0) {
            showSnackbar({ type: 'warning', message: 'No data to export' });
            return;
        }
        const doc = new jsPDF('landscape', 'pt', 'a4');
        const pageWidth = doc.internal.pageSize.getWidth();
        doc.setFillColor('#006B5E');
        doc.rect(0, 0, pageWidth, 60, 'F');
        doc.setTextColor('#FFFFFF');
        doc.setFontSize(20);
        doc.text(`${getCurrentTabLabel()} Report`, 40, 40);
        doc.setTextColor('#666666');
        doc.setFontSize(10);
        doc.text(`Generated: ${new Date().toLocaleString()}`, pageWidth - 150, 40);

        autoTable(doc, {
            head: [headers],
            body: rows,
            startY: 80,
            styles: { fontSize: 9, cellPadding: 4 },
            headStyles: { fillColor: '#006B5E', textColor: '#FFFFFF', fontSize: 10, fontStyle: 'bold' },
            alternateRowStyles: { fillColor: '#f5f5f5' },
            margin: { left: 40, right: 40 },
            pageBreak: 'auto',
        });

        const finalY = doc.lastAutoTable?.finalY || 80;
        doc.setFontSize(8);
        doc.setTextColor('#999999');
        doc.text(`Generated by NearbyFundi • ${new Date().toISOString().split('T')[0]}`, 40, finalY + 20);
        doc.save(`${getCurrentTabLabel()}_Report_${new Date().toISOString().split('T')[0]}.pdf`);
        showSnackbar({ type: 'success', message: 'PDF exported successfully' });
        handleExportMenuClose();
    };

    const handleExportMenuOpen = (event) => setExportMenuAnchor(event.currentTarget);
    const handleExportMenuClose = () => setExportMenuAnchor(null);

    // ---------- Permission & Error ----------
    if (!canViewReports) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" minHeight="80vh">
                <Paper sx={{ p: 4, textAlign: 'center' }}>
                    <Typography variant="h5" color="error">Access Denied</Typography>
                </Paper>
            </Box>
        );
    }

    if (error) {
        return (
            <Box p={3}>
                <Alert severity="error" action={<Button color="inherit" size="small" onClick={() => { setError(null); fetchReportData(); }}>Retry</Button>}>
                    {error}
                </Alert>
            </Box>
        );
    }

    // ---------- Render ----------
    return (
        <Box sx={{ p: { xs: 2, sm: 3 } }}>
            <Paper sx={{ p: 3, borderRadius: 3, mb: 3, backgroundColor: colors.light, border: `1px solid ${colors.middle}` }}>
                <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={2}>
                    <Box>
                        <Typography variant="h4" fontWeight="700" sx={{ color: colors.dark }}>Reports Dashboard</Typography>
                        <Typography variant="body2" sx={{ color: colors.rain }}>Comprehensive reports with period filters and trends</Typography>
                    </Box>
                    <Box display="flex" gap={1}>
                        <Button variant="outlined" startIcon={<RefreshIcon />} onClick={handleRefresh} disabled={loading}
                                sx={{ borderColor: colors.middle, color: colors.sea, '&:hover': { borderColor: colors.sea, backgroundColor: colors.wave } }}>
                            Refresh
                        </Button>
                        <Button variant="contained" startIcon={<DownloadIcon />} onClick={handleExportMenuOpen}
                                sx={{ backgroundColor: colors.sea, '&:hover': { backgroundColor: colors.dark } }}>
                            Export
                        </Button>
                        <ReportExportMenu
                            anchorEl={exportMenuAnchor}
                            open={Boolean(exportMenuAnchor)}
                            onClose={handleExportMenuClose}
                            onExportCSV={exportToCSV}
                            onExportExcel={exportToExcel}
                            onExportPDF={exportToPDF}
                        />
                    </Box>
                </Box>
                <ReportFilters
                    period={period}
                    setPeriod={setPeriod}
                    periodDate={periodDate}
                    setPeriodDate={setPeriodDate}
                    onRefresh={handleRefresh}
                    loading={loading}
                />
            </Paper>

            <Paper sx={{ borderRadius: 3, overflow: 'hidden', backgroundColor: colors.light, border: `1px solid ${colors.middle}` }}>
                <Tabs value={tabValue} onChange={handleTabChange} variant="scrollable" scrollButtons="auto"
                      sx={{ borderBottom: `1px solid ${colors.middle}`, bgcolor: alpha(colors.sky, 0.6),
                          '& .MuiTab-root': { color: colors.rain, '&.Mui-selected': { color: colors.sea } },
                          '& .MuiTabs-indicator': { backgroundColor: colors.sea } }}>
                    <Tab icon={<PeopleIcon />} label="Users" />
                    <Tab icon={<BuildIcon />} label="Technicians" />
                    <Tab icon={<RequestIcon />} label="Requests" />
                    <Tab icon={<CategoryIcon />} label="Services" />
                    <Tab icon={<CommentIcon />} label="Blog" />
                    <Tab icon={<PhotoIcon />} label="Portfolio" />
                </Tabs>

                {loading && <Box display="flex" justifyContent="center" py={4}><CircularProgress sx={{ color: colors.sea }} /></Box>}

                {/* USERS TAB */}
                <TabPanel value={tabValue} index={0}>
                    <Box sx={{ p: 2 }}>
                        <SummaryCards items={[
                            { title: 'Total Users', value: reportData?.stats?.total || 0, icon: <PeopleIcon />, color: colors.sea },
                            { title: 'Active', value: reportData?.stats?.active || 0, icon: <CheckCircleIcon />, color: colors.salat },
                            { title: 'Inactive', value: reportData?.stats?.inactive || 0, icon: <CancelIcon />, color: colors.rain },
                            { title: 'New (Period)', value: reportData?.trend?.length || 0, icon: <TrendingUpIcon />, color: colors.sea },
                        ]} />
                        {reportData?.trend && reportData.trend.length > 0 && <TrendChart data={reportData.trend} label="New Users" />}
                        <Box display="flex" gap={2} flexWrap="wrap" my={2}>
                            <TextField size="small" placeholder="Search users..." value={search} onChange={(e) => setSearch(e.target.value)}
                                       InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment> }}
                                       sx={{ minWidth: 200, '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 }, '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle } }} />
                            <FormControl size="small" sx={{ minWidth: 130 }}>
                                <InputLabel sx={{ color: colors.rain }}>Role</InputLabel>
                                <Select value={filterRole} label="Role" onChange={(e) => setFilterRole(e.target.value)}
                                        sx={{ '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle }, '& .MuiInputBase-root': { backgroundColor: colors.sky } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="CUSTOMER">Customer</MenuItem>
                                    <MenuItem value="FUNDI">Fundi</MenuItem>
                                    <MenuItem value="ADMINISTRATOR">Admin</MenuItem>
                                    <MenuItem value="MANAGER">Manager</MenuItem>
                                </Select>
                            </FormControl>
                            <FormControl size="small" sx={{ minWidth: 130 }}>
                                <InputLabel sx={{ color: colors.rain }}>Status</InputLabel>
                                <Select value={filterStatus} label="Status" onChange={(e) => setFilterStatus(e.target.value)}
                                        sx={{ '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle }, '& .MuiInputBase-root': { backgroundColor: colors.sky } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="active">Active</MenuItem>
                                    <MenuItem value="inactive">Inactive</MenuItem>
                                    <MenuItem value="pending">Pending</MenuItem>
                                </Select>
                            </FormControl>
                        </Box>
                        <ReportTable columns={[
                            { key: 'user', label: 'User' },
                            { key: 'email', label: 'Email' },
                            { key: 'phone', label: 'Phone' },
                            { key: 'role', label: 'Role' },
                            { key: 'status', label: 'Status' },
                            { key: 'created', label: 'Created' },
                        ]} rows={getListData().map((user) => (
                            <TableRow key={user.id} hover>
                                <TableCell><Box display="flex" alignItems="center"><Avatar sx={{ width: 32, height: 32, bgcolor: colors.sea }}>{user.name?.charAt(0).toUpperCase() || <PersonIcon />}</Avatar>{user.name || 'N/A'}</Box></TableCell>
                                <TableCell>{user.email || 'N/A'}</TableCell>
                                <TableCell>{user.phone || 'N/A'}</TableCell>
                                <TableCell>{user.roles?.map(r => <Chip key={r.id} label={r.name} size="small" variant="outlined" sx={{ borderColor: colors.middle }} />)}</TableCell>
                                <TableCell><StatusChip status={user.status || 'inactive'} /></TableCell>
                                <TableCell>{formatDate(user.created_at)}</TableCell>
                            </TableRow>
                        ))} total={getTotalCount()} page={page} rowsPerPage={rowsPerPage} onPageChange={handleChangePage} onRowsPerPageChange={handleChangeRowsPerPage} loading={loading} emptyMessage="No users found" />
                    </Box>
                </TabPanel>

                {/* TECHNICIANS TAB – with Area filter */}
                <TabPanel value={tabValue} index={1}>
                    <Box sx={{ p: 2 }}>
                        <SummaryCards items={[
                            { title: 'Total Technicians', value: reportData?.stats?.total || 0, icon: <BuildIcon />, color: colors.sea },
                            { title: 'Verified', value: reportData?.stats?.verified || 0, icon: <VerifiedIcon />, color: colors.salat },
                            { title: 'New (Period)', value: reportData?.trend?.length || 0, icon: <TrendingUpIcon />, color: colors.sea },
                        ]} />
                        {reportData?.trend && reportData.trend.length > 0 && <TrendChart data={reportData.trend} label="New Technicians" color={colors.salat} />}
                        <Box display="flex" gap={2} flexWrap="wrap" my={2}>
                            <TextField size="small" placeholder="Search technicians..." value={search} onChange={(e) => setSearch(e.target.value)}
                                       InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment> }}
                                       sx={{ minWidth: 200, '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 }, '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle } }} />
                            <FormControl size="small" sx={{ minWidth: 130 }}>
                                <InputLabel sx={{ color: colors.rain }}>Verified</InputLabel>
                                <Select value={filterVerified} label="Verified" onChange={(e) => setFilterVerified(e.target.value)}
                                        sx={{ '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle }, '& .MuiInputBase-root': { backgroundColor: colors.sky } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="true">Verified</MenuItem>
                                    <MenuItem value="false">Unverified</MenuItem>
                                </Select>
                            </FormControl>
                            <TextField
                                size="small"
                                placeholder="Filter by area..."
                                value={filterArea}
                                onChange={(e) => setFilterArea(e.target.value)}
                                InputProps={{
                                    startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>,
                                }}
                                sx={{
                                    minWidth: 180,
                                    '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                                    '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                                }}
                            />
                        </Box>
                        <ReportTable columns={[
                            { key: 'technician', label: 'Technician' },
                            { key: 'email', label: 'Email' },
                            { key: 'area', label: 'Area' },
                            { key: 'rating', label: 'Rating' },
                            { key: 'verified', label: 'Verified' },
                            { key: 'created', label: 'Created' },
                        ]} rows={getListData().map((tech) => (
                            <TableRow key={tech.id} hover>
                                <TableCell><Box display="flex" alignItems="center"><Avatar src={tech.profile_photo} sx={{ width: 32, height: 32, bgcolor: colors.sea }}>{tech.user?.name?.charAt(0).toUpperCase() || <BuildIcon />}</Avatar>{tech.user?.name || 'N/A'}{tech.verified && <VerifiedIcon sx={{ fontSize: 14, color: colors.salat }} />}</Box></TableCell>
                                <TableCell>{tech.user?.email || 'N/A'}</TableCell>
                                <TableCell>{tech.area || 'N/A'}</TableCell>
                                <TableCell><Box display="flex" alignItems="center"><StarIcon sx={{ fontSize: 16, color: '#f59e0b' }} />{tech.rating || 0}</Box></TableCell>
                                <TableCell>{tech.verified ? 'Yes' : 'No'}</TableCell>
                                <TableCell>{formatDate(tech.created_at)}</TableCell>
                            </TableRow>
                        ))} total={getTotalCount()} page={page} rowsPerPage={rowsPerPage} onPageChange={handleChangePage} onRowsPerPageChange={handleChangeRowsPerPage} loading={loading} emptyMessage="No technicians found" />
                    </Box>
                </TabPanel>

                {/* REQUESTS TAB */}
                <TabPanel value={tabValue} index={2}>
                    <Box sx={{ p: 2 }}>
                        <SummaryCards items={[
                            { title: 'Total Requests', value: reportData?.stats?.total || 0, icon: <RequestIcon />, color: colors.sea },
                            ...(reportData?.stats?.by_status || []).map((s) => ({
                                title: s.status,
                                value: s.count,
                                icon: <CheckCircleIcon />,
                                color: colors.sea,
                                md: 1.5,
                            })),
                        ]} />
                        {reportData?.trend && reportData.trend.length > 0 && <TrendChart data={reportData.trend} label="Requests" />}
                        <Box display="flex" gap={2} flexWrap="wrap" my={2}>
                            <TextField size="small" placeholder="Search requests..." value={search} onChange={(e) => setSearch(e.target.value)}
                                       InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment> }}
                                       sx={{ minWidth: 200, '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 }, '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle } }} />
                            <FormControl size="small" sx={{ minWidth: 130 }}>
                                <InputLabel sx={{ color: colors.rain }}>Status</InputLabel>
                                <Select value={filterStatus} label="Status" onChange={(e) => setFilterStatus(e.target.value)}
                                        sx={{ '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle }, '& .MuiInputBase-root': { backgroundColor: colors.sky } }}>
                                    <MenuItem value="">All</MenuItem>
                                    <MenuItem value="pending">Pending</MenuItem>
                                    <MenuItem value="accepted">Accepted</MenuItem>
                                    <MenuItem value="in_progress">In Progress</MenuItem>
                                    <MenuItem value="completed">Completed</MenuItem>
                                    <MenuItem value="cancelled">Cancelled</MenuItem>
                                    <MenuItem value="rejected">Rejected</MenuItem>
                                </Select>
                            </FormControl>
                        </Box>
                        <ReportTable columns={[
                            { key: 'id', label: 'ID' },
                            { key: 'customer', label: 'Customer' },
                            { key: 'technician', label: 'Technician' },
                            { key: 'service', label: 'Service' },
                            { key: 'status', label: 'Status' },
                            { key: 'created', label: 'Created' },
                        ]} rows={getListData().map((req) => (
                            <TableRow key={req.id} hover>
                                <TableCell>#{req.id}</TableCell>
                                <TableCell>{req.customer?.name || 'N/A'}</TableCell>
                                <TableCell>{req.technician?.user?.name || 'N/A'}</TableCell>
                                <TableCell>{req.service?.name || 'N/A'}</TableCell>
                                <TableCell><StatusChip status={req.status} /></TableCell>
                                <TableCell>{formatDate(req.created_at)}</TableCell>
                            </TableRow>
                        ))} total={getTotalCount()} page={page} rowsPerPage={rowsPerPage} onPageChange={handleChangePage} onRowsPerPageChange={handleChangeRowsPerPage} loading={loading} emptyMessage="No requests found" />
                    </Box>
                </TabPanel>

                {/* SERVICES TAB */}
                <TabPanel value={tabValue} index={3}>
                    <Box sx={{ p: 2 }}>
                        <SummaryCards items={[
                            { title: 'Total Services', value: reportData?.stats?.total || 0, icon: <CategoryIcon />, color: colors.sea, md: 4 },
                            { title: 'Total Requests', value: reportData?.stats?.total_requests || 0, icon: <RequestIcon />, color: colors.salat, md: 4 },
                            { title: 'Avg Requests/Service', value: reportData?.stats?.avg_per_service || 0, icon: <TrendingUpIcon />, color: colors.sea, md: 4 },
                        ]} />
                        <ReportTable columns={[
                            { key: 'service', label: 'Service Name' },
                            { key: 'requests', label: 'Requests' },
                            { key: 'rank', label: 'Rank' },
                        ]} rows={getListData().map((service, index) => {
                            const maxRequests = getListData().reduce((max, s) => Math.max(max, s.requests_count || 0), 0);
                            return (
                                <TableRow key={service.id} hover>
                                    <TableCell><Box display="flex" alignItems="center"><CategoryIcon fontSize="small" sx={{ color: colors.sea, mr: 1 }} />{service.name}</Box></TableCell>
                                    <TableCell><Box display="flex" alignItems="center"><LinearProgress variant="determinate" value={maxRequests > 0 ? (service.requests_count / maxRequests) * 100 : 0} sx={{ width: 100, height: 8, borderRadius: 4, backgroundColor: colors.sky, mr: 2 }} />{service.requests_count}</Box></TableCell>
                                    <TableCell><Chip label={`#${index + 1}`} size="small" sx={{ backgroundColor: index < 3 ? colors.sea : colors.sky, color: index < 3 ? colors.light : colors.dark }} /></TableCell>
                                </TableRow>
                            );
                        })} total={getTotalCount()} page={page} rowsPerPage={rowsPerPage} onPageChange={handleChangePage} onRowsPerPageChange={handleChangeRowsPerPage} loading={loading} emptyMessage="No services found" />
                    </Box>
                </TabPanel>

                {/* BLOG TAB */}
                <TabPanel value={tabValue} index={4}>
                    <Box sx={{ p: 2 }}>
                        <SummaryCards items={[
                            { title: 'Total Posts', value: reportData?.stats?.total_posts || 0, icon: <CommentIcon />, color: colors.sea },
                            { title: 'Total Comments', value: reportData?.stats?.total_comments || 0, icon: <CommentIcon />, color: colors.sea },
                            { title: 'Total Likes', value: reportData?.stats?.total_likes || 0, icon: <StarIcon />, color: colors.sea },
                            { title: 'Avg Comments/Post', value: reportData?.stats?.avg_comments_per_post || 0, icon: <TrendingUpIcon />, color: colors.salat },
                        ]} />
                        {reportData?.trend && reportData.trend.length > 0 && <TrendChart data={reportData.trend} label="Blog Posts" color={colors.salat} />}
                        <BlogStats stats={reportData?.stats} />
                    </Box>
                </TabPanel>

                {/* PORTFOLIO TAB */}
                <TabPanel value={tabValue} index={5}>
                    <Box sx={{ p: 2 }}>
                        <SummaryCards items={[
                            { title: 'Total Portfolio Items', value: reportData?.total_portfolio_items || 0, icon: <PhotoIcon />, color: colors.sea, md: 6 },
                            { title: 'Technicians with Portfolios', value: getListData().length, icon: <BuildIcon />, color: colors.salat, md: 6 },
                        ]} />
                        <Typography variant="h6" fontWeight="600" sx={{ mb: 2, color: colors.dark }}>Technicians with Most Portfolios</Typography>
                        <ReportTable columns={[
                            { key: 'rank', label: '#' },
                            { key: 'technician', label: 'Technician' },
                            { key: 'items', label: 'Items' },
                        ]} rows={getListData().map((item, index) => (
                            <TableRow key={item.technician_id || index} hover>
                                <TableCell><Chip label={`#${index + 1}`} size="small" sx={{ backgroundColor: index < 3 ? colors.sea : colors.sky, color: index < 3 ? colors.light : colors.dark }} /></TableCell>
                                <TableCell><Box display="flex" alignItems="center"><Avatar sx={{ width: 24, height: 24, bgcolor: colors.sea }}>{item.technician?.user?.name?.charAt(0).toUpperCase() || <BuildIcon />}</Avatar>{item.technician?.user?.name || 'Unknown'}</Box></TableCell>
                                <TableCell><Chip label={item.count} size="small" sx={{ backgroundColor: colors.salat, color: colors.light }} /></TableCell>
                            </TableRow>
                        ))} total={getTotalCount()} page={page} rowsPerPage={rowsPerPage} onPageChange={handleChangePage} onRowsPerPageChange={handleChangeRowsPerPage} loading={loading} emptyMessage="No portfolio data" />
                    </Box>
                </TabPanel>
            </Paper>
        </Box>
    );
};

export default ReportsDashboard;