import React from 'react';
import { Box, Paper, Typography, alpha } from '@mui/material';
import { Line } from 'react-chartjs-2';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const TrendChart = ({ data, label, color = colors.sea || '#0f766e', height = 220 }) => {
    if (!data || data.length === 0) {
        return (
            <Paper
                elevation={0}
                sx={{
                    p: 2.5,
                    borderRadius: 3,
                    border: '1px solid',
                    borderColor: 'divider',
                    mb: 3,
                }}
            >
                <Typography variant="subtitle1" fontWeight={700} gutterBottom>
                    {label} Trend
                </Typography>
                <Box display="flex" justifyContent="center" py={3}>
                    <Typography color="text.secondary" fontWeight={500}>
                        No trend data available
                    </Typography>
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
                backgroundColor: alpha(color, 0.12),
                fill: true,
                tension: 0.4,
                pointBackgroundColor: color,
                pointBorderColor: '#fff',
                pointBorderWidth: 2,
                pointRadius: 5,
                pointHoverRadius: 7,
                borderWidth: 2.5,
            },
        ],
    };

    const options = {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { display: false },
            tooltip: {
                backgroundColor: '#0f172a',
                titleFont: { weight: '700' },
                bodyFont: { weight: '500' },
                padding: 12,
                cornerRadius: 8,
            },
        },
        scales: {
            y: {
                beginAtZero: true,
                ticks: { stepSize: 1, font: { weight: '500' } },
                grid: { color: alpha('#94a3b8', 0.15) },
                border: { display: false },
            },
            x: {
                grid: { display: false },
                ticks: { font: { weight: '500' } },
                border: { display: false },
            },
        },
    };

    return (
        <Paper
            elevation={0}
            sx={{
                p: 2.5,
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'divider',
                mb: 3,
            }}
        >
            <Typography variant="subtitle1" fontWeight={700} gutterBottom>
                {label} Trend
            </Typography>
            <Box sx={{ height }}>
                <Line data={chartData} options={options} />
            </Box>
        </Paper>
    );
};

export default TrendChart;