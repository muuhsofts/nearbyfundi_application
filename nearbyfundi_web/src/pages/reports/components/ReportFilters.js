import React from 'react';
import { Box, FormControl, InputLabel, Select, MenuItem, TextField, Button, useTheme } from '@mui/material';
import { Refresh as RefreshIcon } from '@mui/icons-material';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const ReportFilters = ({ period, setPeriod, periodDate, setPeriodDate, onRefresh, loading }) => {
    const theme = useTheme();

    const handlePeriodChange = (e) => {
        setPeriod(e.target.value);
        setPeriodDate(new Date());
    };

    const handleDateChange = (e) => {
        setPeriodDate(new Date(e.target.value));
    };

    return (
        <Box display="flex" gap={2} flexWrap="wrap" alignItems="center" sx={{ mt: 2 }}>
            <FormControl size="small" sx={{ minWidth: 120 }}>
                <InputLabel sx={{ color: colors.rain }}>Period</InputLabel>
                <Select
                    value={period}
                    label="Period"
                    onChange={handlePeriodChange}
                    sx={{
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                        backgroundColor: colors.sky,
                        borderRadius: 2,
                    }}
                >
                    <MenuItem value="">All time</MenuItem>
                    <MenuItem value="daily">Daily</MenuItem>
                    <MenuItem value="monthly">Monthly</MenuItem>
                    <MenuItem value="yearly">Yearly</MenuItem>
                </Select>
            </FormControl>

            {period === 'daily' && (
                <TextField
                    type="date"
                    size="small"
                    label="Date"
                    value={periodDate ? periodDate.toISOString().split('T')[0] : ''}
                    onChange={handleDateChange}
                    InputLabelProps={{ shrink: true }}
                    sx={{
                        '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                    }}
                />
            )}

            {period === 'monthly' && (
                <TextField
                    type="month"
                    size="small"
                    label="Month"
                    value={periodDate ? periodDate.toISOString().slice(0, 7) : ''}
                    onChange={handleDateChange}
                    InputLabelProps={{ shrink: true }}
                    sx={{
                        '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                    }}
                />
            )}

            {period === 'yearly' && (
                <TextField
                    type="number"
                    size="small"
                    label="Year"
                    value={periodDate ? periodDate.getFullYear() : ''}
                    onChange={(e) => setPeriodDate(new Date(parseInt(e.target.value, 10), 0, 1))}
                    InputLabelProps={{ shrink: true }}
                    sx={{
                        '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                    }}
                />
            )}

            <Button
                variant="outlined"
                startIcon={<RefreshIcon />}
                onClick={onRefresh}
                disabled={loading}
                sx={{
                    borderColor: colors.middle,
                    color: colors.sea,
                    '&:hover': { borderColor: colors.sea, backgroundColor: colors.wave },
                }}
            >
                Refresh
            </Button>
        </Box>
    );
};

export default ReportFilters;