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
} from '@mui/material';

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
    if (loading) {
        return (
            <Box display="flex" justifyContent="center" py={6}>
                <Typography color="text.secondary" fontWeight={500}>
                    Loading…
                </Typography>
            </Box>
        );
    }

    if (!rows || rows.length === 0) {
        return (
            <Paper
                elevation={0}
                sx={{
                    py: 8,
                    textAlign: 'center',
                    borderRadius: 3,
                    border: '1px dashed',
                    borderColor: 'divider',
                    bgcolor: 'action.hover',
                }}
            >
                <Typography color="text.secondary" fontWeight={500}>
                    {emptyMessage}
                </Typography>
            </Paper>
        );
    }

    return (
        <Paper
            elevation={0}
            sx={{
                width: '100%',
                overflow: 'hidden',
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'divider',
            }}
        >
            <TableContainer>
                <Table stickyHeader>
                    <TableHead>
                        <TableRow
                            sx={{
                                bgcolor: 'action.hover',
                                '& th': {
                                    fontWeight: 700,
                                    fontSize: '0.8125rem',
                                    color: 'text.secondary',
                                    textTransform: 'uppercase',
                                    letterSpacing: 0.6,
                                    borderBottom: '1px solid',
                                    borderColor: 'divider',
                                    py: 1.75,
                                    bgcolor: 'action.hover',
                                },
                            }}
                        >
                            {columns.map((col) => (
                                <TableCell key={col.key} sx={{ minWidth: col.minWidth || 'auto' }}>
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
                    borderTop: '1px solid',
                    borderColor: 'divider',
                    bgcolor: 'action.hover',
                    '.MuiTablePagination-selectLabel, .MuiTablePagination-displayedRows': {
                        fontWeight: 500,
                    },
                }}
            />
        </Paper>
    );
};

export default ReportTable;