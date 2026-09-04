import React from 'react';
import { Grid, Paper, Typography, Stack, Box, Avatar, Chip } from '@mui/material';
import { Person as PersonIcon } from '@mui/icons-material';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const BlogStats = ({ stats }) => {
    if (!stats) return null;

    return (
        <Grid container spacing={2.5} sx={{ mt: 1 }}>
            {/* Most Commented */}
            <Grid item xs={12} md={6}>
                <Paper
                    elevation={0}
                    sx={{
                        p: 2.5,
                        borderRadius: 3,
                        border: '1px solid',
                        borderColor: 'divider',
                        height: '100%',
                    }}
                >
                    <Typography variant="subtitle2" fontWeight={700} color="text.secondary" gutterBottom letterSpacing={0.5}>
                        MOST COMMENTED
                    </Typography>
                    <Stack spacing={1.5} mt={1.5}>
                        {stats.posts_with_most_comments?.map((post) => (
                            <Box key={post.id} display="flex" justifyContent="space-between" alignItems="center">
                                <Typography variant="body2" fontWeight={600} sx={{ pr: 1 }}>
                                    {post.title}
                                </Typography>
                                <Chip
                                    label={`${post.comments_count} comments`}
                                    size="small"
                                    sx={{
                                        fontWeight: 700,
                                        bgcolor: '#e0f2fe',
                                        color: '#0369a1',
                                        border: '1.5px solid #0ea5e9',
                                        height: 26,
                                        flexShrink: 0,
                                    }}
                                />
                            </Box>
                        ))}
                        {(!stats.posts_with_most_comments || stats.posts_with_most_comments.length === 0) && (
                            <Typography color="text.secondary" fontWeight={500}>
                                No posts found
                            </Typography>
                        )}
                    </Stack>
                </Paper>
            </Grid>

            {/* Most Liked */}
            <Grid item xs={12} md={6}>
                <Paper
                    elevation={0}
                    sx={{
                        p: 2.5,
                        borderRadius: 3,
                        border: '1px solid',
                        borderColor: 'divider',
                        height: '100%',
                    }}
                >
                    <Typography variant="subtitle2" fontWeight={700} color="text.secondary" gutterBottom letterSpacing={0.5}>
                        MOST LIKED
                    </Typography>
                    <Stack spacing={1.5} mt={1.5}>
                        {stats.posts_with_most_likes?.map((post) => (
                            <Box key={post.id} display="flex" justifyContent="space-between" alignItems="center">
                                <Typography variant="body2" fontWeight={600} sx={{ pr: 1 }}>
                                    {post.title}
                                </Typography>
                                <Chip
                                    label={`${post.likes_count} likes`}
                                    size="small"
                                    sx={{
                                        fontWeight: 700,
                                        bgcolor: '#fef3c7',
                                        color: '#b45309',
                                        border: '1.5px solid #f59e0b',
                                        height: 26,
                                        flexShrink: 0,
                                    }}
                                />
                            </Box>
                        ))}
                        {(!stats.posts_with_most_likes || stats.posts_with_most_likes.length === 0) && (
                            <Typography color="text.secondary" fontWeight={500}>
                                No posts found
                            </Typography>
                        )}
                    </Stack>
                </Paper>
            </Grid>

            {/* Top Commenters */}
            <Grid item xs={12}>
                <Paper
                    elevation={0}
                    sx={{
                        p: 2.5,
                        borderRadius: 3,
                        border: '1px solid',
                        borderColor: 'divider',
                    }}
                >
                    <Typography variant="subtitle2" fontWeight={700} color="text.secondary" gutterBottom letterSpacing={0.5}>
                        TOP COMMENTERS
                    </Typography>
                    <Stack spacing={1.5} mt={1.5}>
                        {stats.comments_by_user?.map((item) => (
                            <Box key={item.user_id} display="flex" justifyContent="space-between" alignItems="center">
                                <Box display="flex" alignItems="center" gap={1.25}>
                                    <Avatar
                                        sx={{
                                            width: 32,
                                            height: 32,
                                            bgcolor: colors.sea || '#0f766e',
                                            fontSize: 13,
                                            fontWeight: 700,
                                        }}
                                    >
                                        {item.user?.name?.charAt(0).toUpperCase() || <PersonIcon fontSize="small" />}
                                    </Avatar>
                                    <Typography variant="body2" fontWeight={600}>
                                        {item.user?.name || 'Unknown'}
                                    </Typography>
                                </Box>
                                <Chip
                                    label={`${item.count} comments`}
                                    size="small"
                                    sx={{
                                        fontWeight: 700,
                                        bgcolor: '#d1fae5',
                                        color: '#047857',
                                        border: '1.5px solid #10b981',
                                        height: 26,
                                    }}
                                />
                            </Box>
                        ))}
                        {(!stats.comments_by_user || stats.comments_by_user.length === 0) && (
                            <Typography color="text.secondary" fontWeight={500}>
                                No commenters found
                            </Typography>
                        )}
                    </Stack>
                </Paper>
            </Grid>
        </Grid>
    );
};

export default BlogStats;