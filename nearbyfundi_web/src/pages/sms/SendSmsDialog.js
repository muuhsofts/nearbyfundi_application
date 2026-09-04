// src/pages/sms/SendSmsDialog.jsx
import React, { useState, useEffect } from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    TextField,
    Box,
    Typography,
    CircularProgress,
    FormControl,
    InputLabel,
    Select,
    MenuItem,
    Chip,
    Alert,
    IconButton,
    InputAdornment,
} from '@mui/material';
import { Close as CloseIcon, Send as SendIcon } from '@mui/icons-material';
import { useUserManagement } from 'hooks/useUser';
import appConfig from '../../config';

const colors = appConfig.app.colors;

const SendSmsDialog = ({ open, onClose, onSend }) => {
    const [loading, setLoading] = useState(false);
    const [recipient, setRecipient] = useState('');
    const [message, setMessage] = useState('');
    const [charCount, setCharCount] = useState(0);
    const [error, setError] = useState('');
    const [selectedUser, setSelectedUser] = useState(null);
    const [users, setUsers] = useState([]);
    const [userSearch, setUserSearch] = useState('');

    const { getUsersDropdown } = useUserManagement();

    useEffect(() => {
        if (open) {
            loadUsers();
        }
    }, [open]);

    useEffect(() => {
        setCharCount(message.length);
    }, [message]);

    const loadUsers = async () => {
        try {
            const response = await getUsersDropdown({ search: userSearch });
            if (response?.data?.data) {
                setUsers(response.data.data);
            }
        } catch (err) {
            console.error('Failed to load users:', err);
        }
    };

    const handleSend = async () => {
        if (!recipient && !selectedUser) {
            setError('Please select a recipient');
            return;
        }
        if (!message.trim()) {
            setError('Please enter a message');
            return;
        }

        setLoading(true);
        setError('');

        try {
            const data = {
                recipient: selectedUser?.phone || recipient,
                message: message.trim(),
                user_id: selectedUser?.id || null,
            };
            await onSend(data);
        } catch (err) {
            setError(err.response?.data?.message || 'Failed to send SMS');
        } finally {
            setLoading(false);
        }
    };

    const handleRecipientChange = (value) => {
        setRecipient(value);
        setSelectedUser(null);
        setError('');
    };

    const handleUserSelect = (user) => {
        setSelectedUser(user);
        setRecipient(user.phone || '');
        setError('');
    };

    const handleClear = () => {
        setRecipient('');
        setMessage('');
        setSelectedUser(null);
        setError('');
        setCharCount(0);
    };

    const getCharCountColor = () => {
        if (charCount <= 160) return colors.salat;
        if (charCount <= 320) return colors.warning;
        return colors.error;
    };

    const getMessageParts = () => {
        if (charCount <= 160) return 1;
        return Math.ceil(charCount / 153);
    };

    return (
        <Dialog
            open={open}
            onClose={onClose}
            maxWidth="sm"
            fullWidth
            PaperProps={{ sx: { borderRadius: 2, backgroundColor: colors.light } }}
        >
            <DialogTitle sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: colors.dark }}>
                <Box display="flex" alignItems="center" gap={1}>
                    <SendIcon sx={{ color: colors.salat }} />
                    <Typography variant="h6">Send SMS</Typography>
                </Box>
                <IconButton onClick={onClose} size="small" sx={{ color: colors.rain }}>
                    <CloseIcon />
                </IconButton>
            </DialogTitle>

            <DialogContent>
                {error && (
                    <Alert severity="error" sx={{ mb: 2 }}>
                        {error}
                    </Alert>
                )}

                {/* User Selection */}
                <Box mb={2}>
                    <FormControl fullWidth size="small">
                        <InputLabel>Select User (Optional)</InputLabel>
                        <Select
                            value={selectedUser?.id || ''}
                            onChange={(e) => {
                                const user = users.find(u => u.id === e.target.value);
                                if (user) handleUserSelect(user);
                            }}
                            label="Select User (Optional)"
                            sx={{
                                backgroundColor: colors.sky,
                                borderRadius: 2,
                                '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                            }}
                        >
                            <MenuItem value="">None</MenuItem>
                            {users.map((user) => (
                                <MenuItem key={user.id} value={user.id}>
                                    {user.name} - {user.phone || user.email}
                                </MenuItem>
                            ))}
                        </Select>
                    </FormControl>
                    {selectedUser && (
                        <Box mt={1}>
                            <Chip
                                label={`Selected: ${selectedUser.name} (${selectedUser.phone || selectedUser.email})`}
                                onDelete={() => handleUserSelect(null)}
                                size="small"
                                sx={{ backgroundColor: colors.wave, color: colors.sea }}
                            />
                        </Box>
                    )}
                </Box>

                {/* Recipient */}
                <TextField
                    fullWidth
                    label="Recipient Phone Number"
                    placeholder="e.g., 255XXXXXXXXX"
                    value={recipient}
                    onChange={(e) => handleRecipientChange(e.target.value)}
                    disabled={!!selectedUser}
                    size="small"
                    sx={{
                        mb: 2,
                        '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                    }}
                />

                {/* Message */}
                <TextField
                    fullWidth
                    label="Message"
                    placeholder="Type your message here..."
                    multiline
                    rows={4}
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    size="small"
                    sx={{
                        '& .MuiInputBase-root': { backgroundColor: colors.sky, borderRadius: 2 },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: colors.middle },
                    }}
                    InputProps={{
                        endAdornment: (
                            <InputAdornment position="end" sx={{ alignItems: 'flex-end' }}>
                                <Typography
                                    variant="caption"
                                    sx={{
                                        color: getCharCountColor(),
                                        fontWeight: 500,
                                    }}
                                >
                                    {charCount} chars ({getMessageParts()} part{getMessageParts() > 1 ? 's' : ''})
                                </Typography>
                            </InputAdornment>
                        ),
                    }}
                />
            </DialogContent>

            <DialogActions sx={{ p: 2, pt: 0, gap: 1 }}>
                <Button
                    onClick={handleClear}
                    variant="outlined"
                    sx={{ borderColor: colors.middle, color: colors.rain }}
                >
                    Clear
                </Button>
                <Button
                    onClick={onClose}
                    sx={{ color: colors.rain }}
                >
                    Cancel
                </Button>
                <Button
                    onClick={handleSend}
                    variant="contained"
                    disabled={loading || !recipient || !message.trim()}
                    startIcon={loading ? <CircularProgress size={20} /> : <SendIcon />}
                    sx={{
                        backgroundColor: colors.salat,
                        '&:hover': { backgroundColor: colors.dark },
                        '&.Mui-disabled': { backgroundColor: colors.middle }
                    }}
                >
                    {loading ? 'Sending...' : 'Send SMS'}
                </Button>
            </DialogActions>
        </Dialog>
    );
};

export default SendSmsDialog;