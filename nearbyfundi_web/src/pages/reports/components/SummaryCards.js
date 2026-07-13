import React from 'react';
import { Grid } from '@mui/material';
import StatCard from './StatCard';

const SummaryCards = ({ items }) => {
    return (
        <Grid container spacing={3} sx={{ mb: 3 }}>
            {items.map((item, index) => (
                <Grid item xs={12} sm={6} md={item.md || 3} key={index}>
                    <StatCard {...item} />
                </Grid>
            ))}
        </Grid>
    );
};

export default SummaryCards;