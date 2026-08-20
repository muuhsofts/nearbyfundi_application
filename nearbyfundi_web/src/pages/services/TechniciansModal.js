// src/pages/services/TechniciansModal.js
import React, { useState, useEffect } from 'react';
import {
    Dialog, DialogTitle, DialogContent, DialogActions,
    Button, List, ListItem, ListItemAvatar, Avatar,
    ListItemText, CircularProgress, Typography, Box,
    IconButton, Chip, Rating,
} from '@mui/material';
import { Close as CloseIcon, Phone as PhoneIcon, Work as WorkIcon } from '@mui/icons-material';
import { serviceService } from 'services/service.service';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const TechniciansModal = ({ open, onClose, serviceId, serviceName }) => {
    const [technicians, setTechnicians] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    useEffect(() => {
        if (open && serviceId) {
            loadTechnicians();
        }
    }, [open, serviceId]);

    const loadTechnicians = async () => {
        setLoading(true);
        setError(null);
        try {
            const response = await serviceService.getTechniciansByService(serviceId);
            if (response?.data?.status === 'success') {
                const paginated = response.data.data;
                const techniciansList = paginated?.data || [];
                setTechnicians(Array.isArray(techniciansList) ? techniciansList : []);
            } else {
                setTechnicians([]);
            }
        } catch (err) {
            console.error('Error loading technicians:', err);
            setError('Failed to load technicians. Please try again later.');
            setTechnicians([]);
        } finally {
            setLoading(false);
        }
    };

    const getInitials = (name) => name ? name.charAt(0).toUpperCase() : '?';

    return (
        <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth PaperProps={{ sx: { borderRadius: 2 } }}>
            <DialogTitle sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                    <Typography variant="h6" component="span">Technicians for</Typography>
                    <Typography variant="h6" component="span" sx={{ ml: 1, color: colors.sea }}>{serviceName || 'Service'}</Typography>
                </Box>
                <IconButton onClick={onClose} size="small"><CloseIcon /></IconButton>
            </DialogTitle>
            <DialogContent dividers>
                {loading ? (
                    <Box display="flex" justifyContent="center" py={4}><CircularProgress sx={{ color: colors.sea }} /></Box>
                ) : error ? (
                    <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>
                ) : technicians.length === 0 ? (
                    <Box textAlign="center" py={3}>
                        <Typography sx={{ color: colors.rain }}>No technicians assigned to this service.</Typography>
                    </Box>
                ) : (
                    <List>
                        {technicians.map((tech) => {
                            const user = tech.user || {};
                            const servicesCount = tech.services?.length || 0;
                            const rating = parseFloat(tech.rating) || 0;
                            const phone = user.phone || 'N/A';
                            const area = tech.area || 'Unknown area';
                            const completedJobs = tech.completed_jobs_count || 0;

                            return (
                                <ListItem key={tech.id} divider alignItems="flex-start">
                                    <ListItemAvatar>
                                        <Avatar
                                            src={tech.profile_photo ? `${process.env.REACT_APP_API_URL}/storage/${tech.profile_photo}` : undefined}
                                            sx={{ bgcolor: colors.sea, color: colors.light, width: 50, height: 50 }}
                                        >
                                            {!tech.profile_photo && getInitials(user.name)}
                                        </Avatar>
                                    </ListItemAvatar>
                                    <ListItemText
                                        primary={
                                            <Box display="flex" alignItems="center" flexWrap="wrap" gap={1}>
                                                <Typography variant="subtitle1" fontWeight="bold" sx={{ color: colors.dark }}>
                                                    {user.name || 'Unknown'}
                                                </Typography>
                                                <Chip
                                                    label={`${servicesCount} service${servicesCount !== 1 ? 's' : ''}`}
                                                    size="small"
                                                    icon={<WorkIcon style={{ fontSize: 14 }} />}
                                                    sx={{ bgcolor: colors.wave, color: colors.dark }}
                                                />
                                                <Chip
                                                    label={`${completedJobs} job${completedJobs !== 1 ? 's' : ''}`}
                                                    size="small"
                                                    sx={{ bgcolor: colors.sky, color: colors.dark }}
                                                />
                                            </Box>
                                        }
                                        secondary={
                                            <Box component="span" sx={{ display: 'block', mt: 0.5 }}>
                                                <Typography variant="body2" sx={{ color: colors.black, display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                                    <PhoneIcon fontSize="small" sx={{ color: colors.rain }} />
                                                    {phone}
                                                </Typography>
                                                <Typography variant="body2" sx={{ color: colors.black, mt: 0.5 }}>
                                                    📍 {area}
                                                </Typography>
                                                <Box display="flex" alignItems="center" mt={0.5}>
                                                    <Rating
                                                        value={rating}
                                                        readOnly
                                                        precision={0.5}
                                                        size="small"
                                                        sx={{ color: colors.secondary || '#f5a623' }}
                                                    />
                                                    <Typography variant="body2" sx={{ ml: 1, color: colors.black }}>
                                                        ({rating.toFixed(1)})
                                                    </Typography>
                                                </Box>
                                            </Box>
                                        }
                                    />
                                </ListItem>
                            );
                        })}
                    </List>
                )}
            </DialogContent>
            <DialogActions>
                <Button onClick={onClose}>Close</Button>
            </DialogActions>
        </Dialog>
    );
};

export default TechniciansModal;