// src/utils/postMedia.js

const API_BASE =
    process.env.REACT_APP_API_URL || 'http://192.168.100.144:8000';

/**
 * Build a full URL for a storage path or return the URL as-is.
 * Matches Flutter's behavior (supports `/storage/...`, plain paths, and full URLs).
 */
export const getImageUrl = (path) => {
    if (!path) return null;
    const str = String(path).trim();
    if (!str) return null;
    if (/^https?:\/\//i.test(str)) return str;
    if (str.startsWith('data:') || str.startsWith('blob:')) return str;

    const clean = str.replace(/^\/+/, '');
    if (clean.startsWith('storage/')) return `${API_BASE}/${clean}`;
    return `${API_BASE}/storage/${clean}`;
};

/**
 * Normalize the list of images for a post.
 * Backend may return: image_urls[], images[], or legacy single `image`.
 */
export const getPostImages = (post) => {
    if (!post) return [];
    const raw =
        post.image_urls ??
        post.images ??
        (post.image ? [post.image] : []);
    if (!Array.isArray(raw)) return [];
    return raw.filter((x) => x != null && String(x).trim() !== '');
};

/**
 * Normalize a post object so `images` and `technician` fields are predictable
 * throughout the web app.
 */
export const normalizePost = (post) => {
    if (!post) return post;
    const images = getPostImages(post);
    const tech = post.technician
        ? {
            ...post.technician,
            name:
                post.technician.user?.name ||
                post.technician.name ||
                'Fundi',
            avatar:
                post.technician.profile_photo ||
                post.technician.user?.profile_photo ||
                null,
        }
        : null;

    return {
        ...post,
        images,
        image: images[0] || null, // backward-compatible single image
        technician: tech,
    };
};

export const normalizePosts = (list) =>
    Array.isArray(list) ? list.map(normalizePost) : [];

/** Extract a YouTube ID from many URL variants (matches Flutter logic). */
export const getYouTubeId = (input) => {
    if (!input) return null;
    let working = String(input).trim();
    if (!working) return null;

    if (working.toLowerCase().includes('<iframe')) {
        const m = working.match(/src=["']([^"']+)["']/i);
        if (m) working = m[1];
    }

    const m = working.match(
        /(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/)|youtube-nocookie\.com\/embed\/)([_\-\w]{11})/i
    );
    if (m) return m[1];

    if (
        working.length === 11 &&
        !working.includes('/') &&
        !working.includes('?')
    ) {
        return working;
    }
    return null;
};

/** Get a playable video source URL (prefers youtube_url, then youtube_embed). */
export const getVideoSource = (post) => {
    if (!post) return null;
    const url = (post.youtube_url || '').trim();
    if (url) return url;
    const embed = (post.youtube_embed || '').trim();
    return embed || null;
};