import React from 'react';
import { Card, CardContent, Typography, Avatar, Box, alpha } from '@mui/material';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const StatCard = ({ title, value, icon, color = colors.sea || '#0f766e', subtitle }) => {
    return (
        <Card
            elevation={0}
            sx={{
                height: '100%',
                borderRadius: 3,
                border: '1px solid',
                borderColor: 'divider',
                background: `linear-gradient(135deg, ${alpha(color, 0.08)} 0%, ${alpha(color, 0.02)} 100%)`,
                transition: 'all 0.25s ease',
                '&:hover': {
                    transform: 'translateY(-4px)',
                    boxShadow: `0 8px 24px ${alpha(color, 0.18)}`,
                    borderColor: alpha(color, 0.3),
                },
            }}
        >
            <CardContent sx={{ p: 2.5 }}>
                <Box display="flex" alignItems="center" justifyContent="space-between">
                    <Box>
                        <Typography
                            variant="overline"
                            fontWeight={700}
                            letterSpacing={0.8}
                            sx={{ color: 'text.secondary', fontSize: '0.7rem' }}
                        >
                            {title}
                        </Typography>
                        <Typography
                            variant="h4"
                            fontWeight={800}
                            sx={{ mt: 0.5, color: color, lineHeight: 1.15 }}
                        >
                            {value ?? 0}
                        </Typography>
                        {subtitle && (
                            <Typography variant="caption" display="block" sx={{ mt: 0.5, color: 'text.secondary', fontWeight: 500 }}>
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
                            boxShadow: `0 4px 12px ${alpha(color, 0.25)}`,
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