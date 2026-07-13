import React from 'react';
import {
    Table,
    TableBody,
    TableCell,
    TableContainer,
    TableHead,
    TableRow,
    TablePagination,
    Paper,
    Typography,
    Box,
    Avatar,
    Chip,
    Stack,
    LinearProgress,
    useTheme,
} from '@mui/material';
import {
    Person as PersonIcon,
    Build as BuildIcon,
    Verified as VerifiedIcon,
    OnlinePrediction as OnlineIcon,
    OfflineBolt as OfflineIcon,
    Star as StarIcon,
    Category as CategoryIcon,
} from '@mui/icons-material';
import StatusChip from './StatusChip';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const ReportTable = ({
                         columns,
                         rows,
                         total,
                         page,
                         rowsPerPage,
                         onPageChange,
                         onRowsPerPageChange,
                         loading,
                         emptyMessage = 'No data found',
                     }) => {
    const theme = useTheme();

    if (loading) {
        return (
            <Box display="flex" justifyContent="center" py={4}>
                <Typography color={colors.rain}>Loading...</Typography>
            </Box>
        );
    }

    if (!rows || rows.length === 0) {
        return (
            <Box display="flex" justifyContent="center" py={4}>
                <Typography color={colors.rain}>{emptyMessage}</Typography>
            </Box>
        );
    }

    return (
        <Paper sx={{ width: '100%', overflow: 'hidden', border: `1px solid ${colors.middle}` }}>
            <TableContainer>
                <Table stickyHeader>
                    <TableHead>
                        <TableRow sx={{ backgroundColor: colors.sky }}>
                            {columns.map((col) => (
                                <TableCell
                                    key={col.key}
                                    sx={{ fontWeight: 'bold', color: colors.dark, minWidth: col.minWidth || 'auto' }}
                                >
                                    {col.label}
                                </TableCell>
                            ))}
                        </TableRow>
                    </TableHead>
                    <TableBody>{rows}</TableBody>
                </Table>
            </TableContainer>
            <TablePagination
                rowsPerPageOptions={[5, 10, 25, 50]}
                component="div"
                count={total || 0}
                rowsPerPage={rowsPerPage}
                page={page}
                onPageChange={onPageChange}
                onRowsPerPageChange={onRowsPerPageChange}
                sx={{
                    '.MuiTablePagination-selectLabel, .MuiTablePagination-displayedRows': {
                        color: colors.black,
                    },
                    '.MuiTablePagination-actions': { color: colors.sea },
                }}
            />
        </Paper>
    );
};

export default ReportTable;