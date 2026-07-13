import React from 'react';
import { Grid, Paper, Typography, Stack, Box, Avatar, Chip } from '@mui/material';
import { Person as PersonIcon } from '@mui/icons-material';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const BlogStats = ({ stats }) => {
    if (!stats) return null;

    return (
        <Grid container spacing={3}>
            <Grid item xs={12} md={6}>
                <Paper sx={{ p: 2, borderRadius: 2, border: `1px solid ${colors.middle}` }}>
                    <Typography variant="subtitle2" sx={{ color: colors.rain }} gutterBottom>
                        Most Commented
                    </Typography>
                    <Stack spacing={1}>
                        {stats.posts_with_most_comments?.map((post) => (
                            <Box key={post.id} display="flex" justifyContent="space-between" alignItems="center">
                                <Typography variant="body2" sx={{ color: colors.black }}>
                                    {post.title}
                                </Typography>
                                <Chip
                                    label={`${post.comments_count} comments`}
                                    size="small"
                                    sx={{ backgroundColor: colors.wave, color: colors.sea }}
                                />
                            </Box>
                        ))}
                        {(!stats.posts_with_most_comments || stats.posts_with_most_comments.length === 0) && (
                            <Typography sx={{ color: colors.rain }}>No posts found</Typography>
                        )}
                    </Stack>
                </Paper>
            </Grid>
            <Grid item xs={12} md={6}>
                <Paper sx={{ p: 2, borderRadius: 2, border: `1px solid ${colors.middle}` }}>
                    <Typography variant="subtitle2" sx={{ color: colors.rain }} gutterBottom>
                        Most Liked
                    </Typography>
                    <Stack spacing={1}>
                        {stats.posts_with_most_likes?.map((post) => (
                            <Box key={post.id} display="flex" justifyContent="space-between" alignItems="center">
                                <Typography variant="body2" sx={{ color: colors.black }}>
                                    {post.title}
                                </Typography>
                                <Chip
                                    label={`${post.likes_count} likes`}
                                    size="small"
                                    sx={{ backgroundColor: colors.wave, color: colors.sea }}
                                />
                            </Box>
                        ))}
                        {(!stats.posts_with_most_likes || stats.posts_with_most_likes.length === 0) && (
                            <Typography sx={{ color: colors.rain }}>No posts found</Typography>
                        )}
                    </Stack>
                </Paper>
            </Grid>
            <Grid item xs={12}>
                <Paper sx={{ p: 2, borderRadius: 2, border: `1px solid ${colors.middle}` }}>
                    <Typography variant="subtitle2" sx={{ color: colors.rain }} gutterBottom>
                        Top Commenters
                    </Typography>
                    <Stack spacing={1}>
                        {stats.comments_by_user?.map((item) => (
                            <Box key={item.user_id} display="flex" justifyContent="space-between" alignItems="center">
                                <Box display="flex" alignItems="center" gap={1}>
                                    <Avatar sx={{ width: 24, height: 24, bgcolor: colors.sea }}>
                                        {item.user?.name?.charAt(0).toUpperCase() || <PersonIcon />}
                                    </Avatar>
                                    <Typography variant="body2" sx={{ color: colors.black }}>
                                        {item.user?.name || 'Unknown'}
                                    </Typography>
                                </Box>
                                <Chip
                                    label={`${item.count} comments`}
                                    size="small"
                                    sx={{ backgroundColor: colors.salat, color: colors.light }}
                                />
                            </Box>
                        ))}
                        {(!stats.comments_by_user || stats.comments_by_user.length === 0) && (
                            <Typography sx={{ color: colors.rain }}>No commenters found</Typography>
                        )}
                    </Stack>
                </Paper>
            </Grid>
        </Grid>
    );
};

export default BlogStats;