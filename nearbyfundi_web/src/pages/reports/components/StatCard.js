import React from 'react';
import { Card, CardContent, Typography, Avatar, Box, alpha, useTheme } from '@mui/material';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const StatCard = ({ title, value, icon, color = colors.sea, subtitle }) => {
    const theme = useTheme();
    return (
        <Card
            sx={{
                height: '100%',
                borderRadius: 3,
                transition: 'all 0.3s',
                '&:hover': { transform: 'translateY(-4px)', boxShadow: 6 },
                border: `1px solid ${colors.middle}`,
            }}
        >
            <CardContent>
                <Box display="flex" alignItems="center" justifyContent="space-between">
                    <Box>
                        <Typography variant="caption" fontWeight="500" sx={{ color: colors.rain }}>
                            {title}
                        </Typography>
                        <Typography variant="h4" fontWeight="700" sx={{ mt: 1, color: colors.dark }}>
                            {value || 0}
                        </Typography>
                        {subtitle && (
                            <Typography variant="caption" display="block" sx={{ mt: 0.5, color: colors.rain }}>
                                {subtitle}
                            </Typography>
                        )}
                    </Box>
                    <Avatar
                        sx={{
                            width: 48,
                            height: 48,
                            bgcolor: alpha(color, 0.15),
                            color: color,
                        }}
                    >
                        {icon}
                    </Avatar>
                </Box>
            </CardContent>
        </Card>
    );
};

export default StatCard;