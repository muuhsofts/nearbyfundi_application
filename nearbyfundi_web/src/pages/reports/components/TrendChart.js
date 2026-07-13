import React from 'react';
import { Box, Paper, Typography, alpha, useTheme } from '@mui/material';
import { Line } from 'react-chartjs-2';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const TrendChart = ({ data, label, color = colors.sea, height = 200 }) => {
    const theme = useTheme();

    if (!data || data.length === 0) {
        return (
            <Paper sx={{ p: 2, borderRadius: 2, border: `1px solid ${colors.middle}` }}>
                <Typography variant="subtitle1" sx={{ color: colors.dark }} gutterBottom>
                    {label} Trend
                </Typography>
                <Box display="flex" justifyContent="center" py={2}>
                    <Typography color={colors.rain}>No trend data available</Typography>
                </Box>
            </Paper>
        );
    }

    const chartData = {
        labels: data.map((d) => d.date),
        datasets: [
            {
                label: label,
                data: data.map((d) => d.total || d.posts || 0),
                borderColor: color,
                backgroundColor: alpha(color, 0.1),
                fill: true,
                tension: 0.4,
                pointBackgroundColor: color,
                pointBorderColor: '#fff',
                pointBorderWidth: 2,
                pointRadius: 4,
            },
        ],
    };

    const options = {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { display: false },
        },
        scales: {
            y: {
                beginAtZero: true,
                ticks: { stepSize: 1 },
                grid: { color: alpha(colors.middle, 0.3) },
            },
            x: {
                grid: { display: false },
            },
        },
    };

    return (
        <Paper sx={{ p: 2, borderRadius: 2, border: `1px solid ${colors.middle}` }}>
            <Typography variant="subtitle1" sx={{ color: colors.dark }} gutterBottom>
                {label} Trend
            </Typography>
            <Box sx={{ height }}>
                <Line data={chartData} options={options} />
            </Box>
        </Paper>
    );
};

export default TrendChart;