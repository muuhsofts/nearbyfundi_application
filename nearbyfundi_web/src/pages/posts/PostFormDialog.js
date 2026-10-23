// src/components/posts/PostFormDialog.jsx
import React, { useEffect, useRef, useState } from 'react';
import {
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    Button,
    TextField,
    Box,
    Typography,
    IconButton,
    Stack,
    CircularProgress,
} from '@mui/material';
import {
    AddPhotoAlternate as AddPhotoIcon,
    Close as CloseIcon,
    Delete as DeleteIcon,
} from '@mui/icons-material';
import { getImageUrl, getPostImages } from 'utils/postMedia';

/**
 * Create/Edit post dialog with multi-image support.
 *
 * onSubmit receives:
 *  { title, content, youtube_url, images: File[], keep_images: string[] }
 */
const PostFormDialog = ({
                            open,
                            onClose,
                            onSubmit,
                            initialData = null,
                            submitting = false,
                            canEdit = true,
                        }) => {
    const isEdit = Boolean(initialData?.id);
    const [title, setTitle] = useState('');
    const [content, setContent] = useState('');
    const [youtubeUrl, setYoutubeUrl] = useState('');
    const [newFiles, setNewFiles] = useState([]);
    const [newPreviews, setNewPreviews] = useState([]);
    const [keepImages, setKeepImages] = useState([]);
    const fileInputRef = useRef(null);

    // Reset state when dialog opens
    useEffect(() => {
        if (!open) return;
        setTitle(initialData?.title || '');
        setContent(initialData?.content || '');
        setYoutubeUrl(initialData?.youtube_url || '');
        setNewFiles([]);
        setNewPreviews([]);
        setKeepImages(isEdit ? getPostImages(initialData) : []);
    }, [open, initialData, isEdit]);

    // Clean up object URLs on unmount / reset
    useEffect(() => {
        return () => {
            newPreviews.forEach((p) => URL.revokeObjectURL(p.url));
        };
    }, [newPreviews]);

    const handleFileChange = (e) => {
        const picked = Array.from(e.target.files || []);
        if (!picked.length) return;
        const previews = picked.map((file) => ({
            file,
            url: URL.createObjectURL(file),
        }));
        setNewFiles((prev) => [...prev, ...picked]);
        setNewPreviews((prev) => [...prev, ...previews]);
        if (fileInputRef.current) fileInputRef.current.value = '';
    };

    const removeNewFile = (idx) => {
        setNewPreviews((prev) => {
            const target = prev[idx];
            if (target) URL.revokeObjectURL(target.url);
            return prev.filter((_, i) => i !== idx);
        });
        setNewFiles((prev) => prev.filter((_, i) => i !== idx));
    };

    const removeKept = (url) => {
        setKeepImages((prev) => prev.filter((u) => u !== url));
    };

    const handleSubmit = () => {
        const payload = {
            title: title.trim(),
            content: content.trim(),
            youtube_url: youtubeUrl.trim() || null,
            images: newFiles,
            keep_images: keepImages,
        };
        onSubmit?.(payload);
    };

    const totalImages = keepImages.length + newFiles.length;

    return (
        <Dialog
            open={open}
            onClose={submitting ? undefined : onClose}
            fullWidth
            maxWidth="sm"
            PaperProps={{ sx: { borderRadius: 3 } }}
        >
            <DialogTitle sx={{ fontWeight: 700, pr: 6 }}>
                {isEdit ? 'Edit Post' : 'Create Post'}
                <IconButton
                    onClick={onClose}
                    size="small"
                    sx={{ position: 'absolute', right: 12, top: 12 }}
                    disabled={submitting}
                >
                    <CloseIcon />
                </IconButton>
            </DialogTitle>

            <DialogContent dividers>
                <Stack spacing={2}>
                    <TextField
                        label="Title"
                        fullWidth
                        size="small"
                        value={title}
                        onChange={(e) => setTitle(e.target.value)}
                    />
                    <TextField
                        label="Content"
                        fullWidth
                        multiline
                        minRows={4}
                        value={content}
                        onChange={(e) => setContent(e.target.value)}
                    />
                    <TextField
                        label="YouTube URL (optional)"
                        fullWidth
                        size="small"
                        value={youtubeUrl}
                        onChange={(e) => setYoutubeUrl(e.target.value)}
                    />

                    <Box>
                        <Typography
                            variant="subtitle2"
                            fontWeight={600}
                            gutterBottom
                        >
                            Images ({totalImages})
                        </Typography>

                        <Box
                            sx={{
                                display: 'grid',
                                gridTemplateColumns:
                                    'repeat(auto-fill, minmax(90px, 1fr))',
                                gap: 1,
                            }}
                        >
                            {keepImages.map((url) => (
                                <Box
                                    key={`kept-${url}`}
                                    sx={{
                                        position: 'relative',
                                        aspectRatio: '1 / 1',
                                        borderRadius: 1,
                                        overflow: 'hidden',
                                        bgcolor: 'action.hover',
                                    }}
                                >
                                    <Box
                                        component="img"
                                        src={getImageUrl(url)}
                                        alt=""
                                        sx={{
                                            width: '100%',
                                            height: '100%',
                                            objectFit: 'cover',
                                        }}
                                    />
                                    <IconButton
                                        size="small"
                                        onClick={() => removeKept(url)}
                                        sx={{
                                            position: 'absolute',
                                            top: 2,
                                            right: 2,
                                            bgcolor: 'rgba(0,0,0,0.55)',
                                            color: '#fff',
                                            '&:hover': {
                                                bgcolor: 'rgba(0,0,0,0.75)',
                                            },
                                        }}
                                    >
                                        <DeleteIcon fontSize="small" />
                                    </IconButton>
                                </Box>
                            ))}

                            {newPreviews.map((p, idx) => (
                                <Box
                                    key={`new-${p.url}`}
                                    sx={{
                                        position: 'relative',
                                        aspectRatio: '1 / 1',
                                        borderRadius: 1,
                                        overflow: 'hidden',
                                        bgcolor: 'action.hover',
                                    }}
                                >
                                    <Box
                                        component="img"
                                        src={p.url}
                                        alt=""
                                        sx={{
                                            width: '100%',
                                            height: '100%',
                                            objectFit: 'cover',
                                        }}
                                    />
                                    <IconButton
                                        size="small"
                                        onClick={() => removeNewFile(idx)}
                                        sx={{
                                            position: 'absolute',
                                            top: 2,
                                            right: 2,
                                            bgcolor: 'rgba(0,0,0,0.55)',
                                            color: '#fff',
                                            '&:hover': {
                                                bgcolor: 'rgba(0,0,0,0.75)',
                                            },
                                        }}
                                    >
                                        <DeleteIcon fontSize="small" />
                                    </IconButton>
                                </Box>
                            ))}

                            {canEdit && (
                                <Box
                                    onClick={() =>
                                        fileInputRef.current?.click()
                                    }
                                    sx={{
                                        aspectRatio: '1 / 1',
                                        borderRadius: 1,
                                        border: '2px dashed',
                                        borderColor: 'divider',
                                        display: 'flex',
                                        flexDirection: 'column',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        cursor: 'pointer',
                                        color: 'text.secondary',
                                        '&:hover': {
                                            borderColor: 'primary.main',
                                            color: 'primary.main',
                                        },
                                    }}
                                >
                                    <AddPhotoIcon />
                                    <Typography
                                        variant="caption"
                                        sx={{ mt: 0.5 }}
                                    >
                                        Add
                                    </Typography>
                                </Box>
                            )}
                        </Box>

                        <input
                            type="file"
                            hidden
                            multiple
                            accept="image/*"
                            ref={fileInputRef}
                            onChange={handleFileChange}
                        />
                    </Box>
                </Stack>
            </DialogContent>

            <DialogActions sx={{ p: 2 }}>
                <Button
                    onClick={onClose}
                    disabled={submitting}
                    sx={{ textTransform: 'none', fontWeight: 600 }}
                >
                    Cancel
                </Button>
                <Button
                    variant="contained"
                    onClick={handleSubmit}
                    disabled={submitting || (!title.trim() && !content.trim())}
                    sx={{ textTransform: 'none', fontWeight: 700, borderRadius: 2 }}
                >
                    {submitting ? (
                        <CircularProgress size={18} sx={{ color: '#fff' }} />
                    ) : isEdit ? (
                        'Save Changes'
                    ) : (
                        'Create'
                    )}
                </Button>
            </DialogActions>
        </Dialog>
    );
};

export default PostFormDialog;