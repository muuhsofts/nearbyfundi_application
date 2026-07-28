import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/post_provider.dart';
import '../../config/app_theme.dart';
import '../../utils/image_utils.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_routes.dart';

class FundiPostsScreen extends StatefulWidget {
  const FundiPostsScreen({super.key});

  @override
  State<FundiPostsScreen> createState() => _FundiPostsScreenState();
}

class _FundiPostsScreenState extends State<FundiPostsScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().fetchMyPosts();
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredPosts {
    final posts = context.read<PostProvider>().posts;
    if (_filterQuery.isEmpty) return posts;
    return posts.where((post) =>
    post.title.toLowerCase().contains(_filterQuery.toLowerCase()) ||
        (post.content?.toLowerCase().contains(_filterQuery.toLowerCase()) ?? false)).toList();
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                ImageUtils.getFullImageUrl(imageUrl),
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surface,
                  child: Icon(Icons.broken_image, size: 60,
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostProvider>();
    final filteredPosts = _filteredPosts;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.myPosts,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: () => _showPostForm(context, isEdit: false),
            tooltip: 'Create Post',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => provider.fetchMyPosts(),
            tooltip: 'Refresh',
          ),
        ],
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.posts.isEmpty
          ? _buildEmptyState(context)
          : Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchMyPosts(),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: filteredPosts.length,
                itemBuilder: (ctx, i) {
                  final post = filteredPosts[i];
                  return _PostCard(
                    post: post,
                    onImageTap: () => _showImageDialog(context, post.image!),
                    onEdit: () => _showPostForm(context, post: post, isEdit: true),
                    onDelete: () => _deletePost(context, post.id),
                    onLike: () => context.read<PostProvider>().likePost(post.id),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor),
            ),
            child: Icon(
              Icons.article_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noPosts,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showPostForm(context, isEdit: false),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.createPost),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
        ),
        child: TextField(
          controller: _filterController,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Filter by title or content...',
            hintStyle: theme.textTheme.bodySmall,
            prefixIcon: Icon(Icons.search_rounded,
                color: theme.colorScheme.primary),
            suffixIcon: _filterQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.5)),
              onPressed: () {
                _filterController.clear();
                setState(() => _filterQuery = '');
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          onChanged: (value) => setState(() => _filterQuery = value),
        ),
      ),
    );
  }

  // ─── FORM (CREATE / EDIT) ──────────────────────────────────────────────
  void _showPostForm(BuildContext context, {bool isEdit = false, dynamic post}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: theme.colorScheme.surface,
      builder: (BuildContext bottomSheetContext) {
        final _formKey = GlobalKey<FormState>();
        final _titleController = TextEditingController(text: post?.title ?? '');
        final _contentController = TextEditingController(text: post?.content ?? '');
        String? _imagePath = post?.image;
        final picker = ImagePicker();

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── HEADER ──────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isEdit
                                        ? Icons.edit_outlined
                                        : Icons.post_add_rounded,
                                    color: AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isEdit ? l10n.editPostTitle : l10n.createPostTitle,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ─── TITLE ───────────────────────────────────────
                        TextFormField(
                          controller: _titleController,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            labelStyle: theme.textTheme.bodySmall,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          validator: (v) =>
                          v != null && v.trim().isNotEmpty ? null : 'Title is required',
                        ),
                        const SizedBox(height: 16),

                        // ─── CONTENT ─────────────────────────────────────
                        TextFormField(
                          controller: _contentController,
                          maxLines: 5,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'Content',
                            labelStyle: theme.textTheme.bodySmall,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: theme.dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          validator: (v) =>
                          v != null && v.trim().isNotEmpty ? null : 'Content is required',
                        ),
                        const SizedBox(height: 16),

                        // ─── IMAGE PICKER ───────────────────────────────
                        GestureDetector(
                          onTap: () async {
                            final XFile? file =
                            await picker.pickImage(source: ImageSource.gallery);
                            if (file != null) {
                              setModalState(() => _imagePath = file.path);
                            }
                          },
                          child: Container(
                            height: 64,
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                              color: theme.colorScheme.surface,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _imagePath == null
                                      ? Icons.add_photo_alternate
                                      : Icons.check_circle,
                                  color: _imagePath == null
                                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                                      : Colors.green,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _imagePath == null
                                        ? 'Add Image (optional)'
                                        : _imagePath!.startsWith('http')
                                        ? 'Current Image'
                                        : _imagePath!.split('/').last,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: _imagePath == null
                                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                                          : theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ─── BUTTONS ─────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(l10n.cancel,
                                    style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomButton(
                                text: isEdit ? l10n.update : l10n.create,
                                onPressed: () async {
                                  if (!_formKey.currentState!.validate()) return;

                                  final provider = context.read<PostProvider>();
                                  final Map<String, dynamic> data = {
                                    'title': _titleController.text.trim(),
                                    'content': _contentController.text.trim(),
                                    'image': _imagePath,
                                  };

                                  bool success = isEdit
                                      ? await provider.updatePost(post.id, data)
                                      : await provider.createPost(data);

                                  if (!context.mounted) return;
                                  Navigator.pop(context);

                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            isEdit ? l10n.postUpdated : l10n.postCreated),
                                        backgroundColor: AppTheme.primary,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Error: ${provider.error ?? "Failed to save post"}'),
                                        backgroundColor: AppTheme.error,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                },
                                isLoading: context.watch<PostProvider>().isLoading,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── DELETE ──────────────────────────────────────────────────────────────
  void _deletePost(BuildContext context, int id) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.deletePost,
          style: theme.textTheme.titleMedium,
        ),
        content: Text(l10n.areYouSure, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await context.read<PostProvider>().deletePost(id);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.postDeleted),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

// ─── POST CARD WIDGET ──────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final dynamic post;
  final VoidCallback onImageTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLike;

  const _PostCard({
    required this.post,
    required this.onImageTap,
    required this.onEdit,
    required this.onDelete,
    required this.onLike,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 7)
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.darkCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HEADER ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: isTablet ? 22 : 18,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  backgroundImage: post.technicianAvatar != null
                      ? NetworkImage(ImageUtils.getFullImageUrl(post.technicianAvatar!))
                      : null,
                  child: post.technicianAvatar == null
                      ? Text(
                    post.technicianName.isNotEmpty
                        ? post.technicianName[0].toUpperCase()
                        : 'F',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.technicianName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── IMAGE ─────────────────────────────────────────────────────
          if (post.image != null)
            GestureDetector(
              onTap: onImageTap,
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.surface,
                child: Image.network(
                  ImageUtils.getFullImageUrl(post.image),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    color: theme.colorScheme.surface,
                    child: Icon(Icons.broken_image, size: 50,
                        color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ),
              ),
            ),

          // ─── CONTENT ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  post.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // ─── FOOTER (Likes, Comments) ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onLike,
                  child: Row(
                    children: [
                      Icon(
                        post.likedByUser ? Icons.favorite : Icons.favorite_border,
                        color: post.likedByUser ? Colors.red : theme.colorScheme.onSurface
                            .withOpacity(0.5),
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        color: theme.colorScheme.onSurface.withOpacity(0.5), size: 22),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _formatTime(post.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Divider(height: 0, color: theme.dividerColor),
        ],
      ),
    );
  }
}