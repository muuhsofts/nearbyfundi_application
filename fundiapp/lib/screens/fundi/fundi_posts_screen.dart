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
                  child: Icon(Icons.broken_image, size: 60, color: theme.hintColor),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
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
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
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
          ),
        ],
      ),
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : provider.posts.isEmpty
          ? _buildEmptyState(context)
          : Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: filteredPosts.length,
              itemBuilder: (ctx, i) {
                final post = filteredPosts[i];
                return _InstagramPostCard(
                  post: post,
                  onImageTap: () => _showImageDialog(context, post.image!),
                  onEdit: () => _showPostForm(context, post: post, isEdit: true),
                  onDelete: () => _deletePost(context, post.id),
                  onLike: () => context.read<PostProvider>().likePost(post.id),
                );
              },
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
              color: theme.dividerColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.article_outlined,
              size: 48,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noPosts,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showPostForm(context, isEdit: false),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.createPost),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _filterController,
          decoration: InputDecoration(
            hintText: 'Filter by title or content...',
            hintStyle: TextStyle(color: theme.hintColor),
            prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor, size: 20),
            suffixIcon: _filterQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear_rounded, color: theme.hintColor, size: 18),
              onPressed: () {
                _filterController.clear();
                setState(() => _filterQuery = '');
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          onChanged: (value) => setState(() => _filterQuery = value),
        ),
      ),
    );
  }

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
      backgroundColor: theme.cardColor,
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
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isEdit ? Icons.edit_outlined : Icons.post_add_rounded,
                                  color: theme.primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isEdit ? l10n.editPostTitle : l10n.createPostTitle,
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: theme.hintColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          labelStyle: TextStyle(color: theme.hintColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Title is required',
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Content',
                          labelStyle: TextStyle(color: theme.hintColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Content is required',
                      ),
                      const SizedBox(height: 20),

                      // Image Picker
                      GestureDetector(
                        onTap: () async {
                          final XFile? file = await picker.pickImage(source: ImageSource.gallery);
                          if (file != null) {
                            setModalState(() => _imagePath = file.path);
                          }
                        },
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surface,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _imagePath == null ? Icons.add_photo_alternate : Icons.check_circle,
                                color: _imagePath == null ? theme.hintColor : Colors.green,
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
                                    color: _imagePath == null ? theme.hintColor : theme.colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: theme.dividerColor),
                                ),
                              ),
                              child: Text(
                                l10n.cancel,
                                style: TextStyle(color: theme.hintColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomButton(
                              text: isEdit ? l10n.update : l10n.create,
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) return;

                                final provider = context.read<PostProvider>();
                                final data = {
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
                                      content: Text(isEdit ? l10n.postUpdated : l10n.postCreated),
                                      backgroundColor: theme.primaryColor,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${provider.error ?? "Failed to save post"}'),
                                      backgroundColor: theme.colorScheme.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                              isLoading: context.watch<PostProvider>().isLoading,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deletePost(BuildContext context, int id) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.deletePost,
          style: theme.textTheme.titleLarge,
        ),
        content: Text(l10n.areYouSure, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: TextStyle(color: theme.hintColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _InstagramPostCard extends StatelessWidget {
  final dynamic post;
  final VoidCallback onImageTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLike;

  const _InstagramPostCard({
    required this.post,
    required this.onImageTap,
    required this.onEdit,
    required this.onDelete,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: isTablet ? 22 : 18,
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  backgroundImage: post.technicianAvatar != null
                      ? NetworkImage(ImageUtils.getFullImageUrl(post.technicianAvatar!))
                      : null,
                  child: post.technicianAvatar == null
                      ? Text(
                    post.technicianName.isNotEmpty ? post.technicianName[0].toUpperCase() : 'F',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 14,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
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
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
                      icon: Icon(Icons.edit_outlined, color: theme.primaryColor, size: 20),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),

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
                    color: theme.dividerColor,
                    child: Icon(Icons.broken_image, size: 60, color: theme.hintColor),
                  ),
                ),
              ),
            ),

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
                        color: post.likedByUser ? Colors.red : theme.hintColor,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: theme.hintColor, size: 22),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
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
          Divider(
            height: 0,
            color: theme.dividerColor,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 7) return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}