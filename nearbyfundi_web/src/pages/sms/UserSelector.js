// src/pages/sms/UserSelector.jsx
import React, { useState, useEffect } from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    TextField,
    InputAdornment,
    List,
    ListItem,
    ListItemText,
    ListItemAvatar,
    Avatar,
    Typography,
    CircularProgress,
    Box,
    IconButton,
    Divider,
    Chip,
} from '@mui/material';
import { Search as SearchIcon, Close as CloseIcon, Person as PersonIcon } from '@mui/icons-material';
import { useUserManagement } from 'hooks/useUser';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const UserSelector = ({ open, onClose, onSelect }) => {
    const [search, setSearch] = useState('');
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(false);
    const [selectedUser, setSelectedUser] = useState(null);

    const { getUsersDropdown } = useUserManagement();

    useEffect(() => {
        if (open) {
            loadUsers();
        }
    }, [open, search]);

    const loadUsers = async () => {
        setLoading(true);
        try {
            const response = await getUsersDropdown({
                search: search || undefined,
                per_page: 20,
            });
            if (response?.data?.data) {
                setUsers(response.data.data);
            }
        } catch (err) {
            console.error('Failed to load users:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleSelect = (user) => {
        setSelectedUser(user);
    };

    const handleConfirm = () => {
        if (selectedUser) {
            onSelect(selectedUser);
        }
    };

    const handleClose = () => {
        setSelectedUser(null);
        setSearch('');
        onClose();
    };

    return (
        <Dialog
            open={open}
            onClose={handleClose}
            maxWidth="sm"
            fullWidth
            PaperProps={{ sx: { borderRadius: 2, backgroundColor: colors.light, maxHeight: '80vh' } }}
        >
            <DialogTitle sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: colors.dark }}>
                <Typography variant="h6">Select User</Typography>
                <IconButton onClick={handleClose} size="small" sx={{ color: colors.rain }}>
                    <CloseIcon />
                </IconButton>
            </DialogTitle>

            <DialogContent>
                <TextField
                    fullWidth
                    placeholder="Search users by name, email, or phone..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    size="small"
                    sx={{
                        mb: 2,
                        '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                    }}
                    InputProps={{
                        startAdornment: (
                            <InputAdornment position="start">
                                <SearchIcon fontSize="small" sx={{ color: colors.rain }} />
                            </InputAdornment>
                        ),
                    }}
                />

                {loading ? (
                    <Box display="flex" justifyContent="center" py={3}>
                        <CircularProgress size={32} sx={{ color: colors.sea }} />
                    </Box>
                ) : users.length === 0 ? (
                    <Box textAlign="center" py={3}>
                        <Typography sx={{ color: colors.rain }}>No users found</Typography>
                    </Box>
                ) : (
                    <List sx={{ maxHeight: '50vh', overflow: 'auto' }}>
                        {users.map((user) => (
                            <ListItem
                                key={user.id}
                                button
                                selected={selectedUser?.id === user.id}
                                onClick={() => handleSelect(user)}
                                sx={{
                                    borderRadius: 1,
                                    mb: 0.5,
                                    '&.Mui-selected': {
                                        backgroundColor: colors.wave,
                                        '&:hover': { backgroundColor: colors.wave },
                                    },
                                    '&:hover': { backgroundColor: colors.sky },
                                }}
                            >
                                <ListItemAvatar>
                                    <Avatar sx={{ bgcolor: selectedUser?.id === user.id ? colors.salat : colors.rain }}>
                                        {user.name?.[0]?.toUpperCase() || <PersonIcon />}
                                    </Avatar>
                                </ListItemAvatar>
                                <ListItemText
                                    primary={
                                        <Box display="flex" alignItems="center" gap={1}>
                                            <Typography variant="body1" fontWeight={selectedUser?.id === user.id ? 600 : 400}>
                                                {user.name}
                                            </Typography>
                                            {user.status === 'active' && (
                                                <Chip
                                                    label="Active"
                                                    size="small"
                                                    sx={{ height: 18, fontSize: 10, backgroundColor: colors.salat, color: 'white' }}
                                                />
                                            )}
                                        </Box>
                                    }
                                    secondary={
                                        <Box>
                                            {user.email && (
                                                <Typography variant="body2" sx={{ color: colors.rain }}>
                                                    {user.email}
                                                </Typography>
                                            )}
                                            {user.phone && (
                                                <Typography variant="body2" sx={{ color: colors.rain }}>
                                                    {user.phone}
                                                </Typography>
                                            )}
                                        </Box>
                                    }
                                />
                            </ListItem>
                        ))}
                    </List>
                )}
            </DialogContent>

            <DialogActions sx={{ p: 2, pt: 0 }}>
                <Button onClick={handleClose} sx={{ color: colors.rain }}>
                    Cancel
                </Button>
                <Button
                    onClick={handleConfirm}
                    variant="contained"
                    disabled={!selectedUser}
                    sx={{
                        backgroundColor: colors.salat,
                        '&:hover': { backgroundColor: colors.dark },
                        '&.Mui-disabled': { backgroundColor: colors.middle }
                    }}
                >
                    Select User
                </Button>
            </DialogActions>
        </Dialog>
    );
};

export default UserSelector;