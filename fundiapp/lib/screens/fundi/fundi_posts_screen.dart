import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../providers/post_provider.dart';
import '../../config/app_theme.dart';
import '../../utils/image_utils.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_routes.dart';

// ─────────────────────────── CONSTANTS ─────────────────────────────────────
const int _imageQuality = 85;
const double _imagePreviewSize = 52;
const double _youtubePlayerHeight = 220;
const double _imagePlaceholderSize = 60;
const double _avatarSize = 40;
const double _avatarSizeTablet = 46;

// ═══════════════════════════ MAIN SCREEN ═══════════════════════════════════
class FundiPostsScreen extends StatefulWidget {
  const FundiPostsScreen({super.key});

  @override
  State<FundiPostsScreen> createState() => _FundiPostsScreenState();
}

class _FundiPostsScreenState extends State<FundiPostsScreen> {
  final TextEditingController _filterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _filterQuery = '';
  bool _searchExpanded = false;

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
    _scrollController.dispose();
    super.dispose();
  }

  List get _filteredPosts {
    final posts = context.read<PostProvider>().posts;
    if (_filterQuery.isEmpty) return posts;
    final q = _filterQuery.toLowerCase();
    return posts
        .where((post) =>
    post.title.toLowerCase().contains(q) ||
        (post.content?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _showImageDialog(BuildContext context, String imageUrl, String heroTag) {
    final theme = Theme.of(context);
    final fullUrl = ImageUtils.getFullImageUrl(imageUrl);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullscreenImageViewer(
          imageUrl: fullUrl,
          heroTag: heroTag,
          theme: theme,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostProvider>();
    final filteredPosts = _filteredPosts;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.fetchMyPosts(),
          color: AppTheme.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              _buildSliverAppBar(context, l10n, provider),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              if (provider.isLoading && provider.posts.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.posts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context, l10n),
                )
              else if (filteredPosts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoResultsState(context),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 0,
                      vertical: 4,
                    ),
                    sliver: isTablet
                        ? _buildTabletGrid(context, provider, filteredPosts)
                        : _buildMobileList(context, provider, filteredPosts),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────── SLIVER APP BAR ─────────────
  // Pinned only (no floating/snap) so the title and the Create action are
  // always visible immediately, without needing to scroll to trigger them.
  Widget _buildSliverAppBar(
      BuildContext context, AppLocalizations l10n, PostProvider provider) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 4,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: theme.dividerColor),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: theme.colorScheme.onSurface),
        ),
        onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
      ),
      title: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.6)],
        ).createShader(bounds),
        child: Text(
          l10n.myPosts,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      centerTitle: false,
      actions: [
        // Create-post action lives in the top bar now (not a bottom FAB).
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextButton.icon(
            onPressed: () => _showPostForm(context, isEdit: false),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.createPost,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor),
            ),
            child: provider.isLoading
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primary),
            )
                : Icon(Icons.refresh_rounded,
                size: 18, color: theme.colorScheme.onSurface),
          ),
          onPressed: () => provider.fetchMyPosts(),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ───────────── SEARCH BAR ─────────────
  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final postCount = context.watch<PostProvider>().posts.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: _searchExpanded
                      ? AppTheme.primary.withOpacity(0.5)
                      : theme.dividerColor,
                  width: _searchExpanded ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _filterController,
                style: theme.textTheme.bodyMedium,
                onTap: () => setState(() => _searchExpanded = true),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search your posts...',
                  hintStyle: theme.textTheme.bodySmall,
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppTheme.primary),
                  suffixIcon: _filterQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        size: 18,
                        color:
                        theme.colorScheme.onSurface.withOpacity(0.5)),
                    onPressed: () {
                      _filterController.clear();
                      setState(() => _filterQuery = '');
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) => setState(() => _filterQuery = value),
              ),
            ),
          ),
          if (postCount > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Text(
                '$postCount',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────── LISTS / GRID ─────────────
  Widget _buildMobileList(
      BuildContext context, PostProvider provider, List posts) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (ctx, i) {
          final post = posts[i];
          return _PostCard(
            key: ValueKey(post.id),
            post: post,
            onImageTap: post.image != null
                ? (tag) => _showImageDialog(context, post.image!, tag)
                : null,
            onEdit: () => _showPostForm(context, post: post, isEdit: true),
            onDelete: () => _deletePost(context, post.id),
            onLike: () => context.read<PostProvider>().likePost(post.id),
          );
        },
        childCount: posts.length,
      ),
    );
  }

  Widget _buildTabletGrid(
      BuildContext context, PostProvider provider, List posts) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      delegate: SliverChildBuilderDelegate(
            (ctx, i) {
          final post = posts[i];
          return _PostCard(
            key: ValueKey(post.id),
            post: post,
            isGrid: true,
            onImageTap: post.image != null
                ? (tag) => _showImageDialog(context, post.image!, tag)
                : null,
            onEdit: () => _showPostForm(context, post: post, isEdit: true),
            onDelete: () => _deletePost(context, post.id),
            onLike: () => context.read<PostProvider>().likePost(post.id),
          );
        },
        childCount: posts.length,
      ),
    );
  }

  // ───────────── EMPTY STATES ─────────────
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.15),
                    AppTheme.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.dynamic_feed_rounded,
                  size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noPosts,
              style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Share your work with photos and videos to build your portfolio.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showPostForm(context, isEdit: false),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.createPost),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: theme.colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No posts match "$_filterQuery"',
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ───────────── FORM SHEET ─────────────
  void _showPostForm(BuildContext context, {bool isEdit = false, dynamic post}) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) {
        final formKey = GlobalKey<FormState>();
        final titleController = TextEditingController(text: post?.title ?? '');
        final contentController =
        TextEditingController(text: post?.content ?? '');
        final youtubeController =
        TextEditingController(text: post?.youtubeUrl ?? '');
        String? localImagePath;
        String? existingImageUrl = post?.image;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      _PostFormContent(
                        isEdit: isEdit,
                        titleController: titleController,
                        contentController: contentController,
                        youtubeController: youtubeController,
                        localImagePath: localImagePath,
                        existingImageUrl: existingImageUrl,
                        onImagePicked: (path) =>
                            setModalState(() => localImagePath = path),
                        onImageRemoved: () =>
                            setModalState(() => localImagePath = null),
                        onSave: () async {
                          if (!formKey.currentState!.validate()) return;
                          HapticFeedback.lightImpact();

                          final provider = context.read<PostProvider>();
                          final data = {
                            'title': titleController.text.trim(),
                            'content': contentController.text.trim(),
                            'youtube_url':
                            youtubeController.text.trim().isNotEmpty
                                ? youtubeController.text.trim()
                                : null,
                          };

                          if (localImagePath != null &&
                              localImagePath!.isNotEmpty) {
                            data['image'] = localImagePath!;
                          }

                          final success = isEdit
                              ? await provider.updatePost(post.id, data)
                              : await provider.createPost(data);

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _showSaveResult(
                              context, success, isEdit, provider.error);
                        },
                      ),
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

  void _showSaveResult(
      BuildContext context, bool success, bool isEdit, String? error) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success
                    ? (isEdit ? l10n.postUpdated : l10n.postCreated)
                    : 'Error: ${error ?? "Failed to save post"}',
              ),
            ),
          ],
        ),
        backgroundColor: success ? AppTheme.primary : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _deletePost(BuildContext context, int id) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.delete_outline_rounded, color: AppTheme.error),
        ),
        title: Text(l10n.deletePost,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        content: Text(l10n.areYouSure,
            style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }
}

// ═══════════════════════ FULLSCREEN IMAGE VIEWER ═══════════════════════════
class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final ThemeData theme;

  const _FullscreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image,
                          size: _imagePlaceholderSize, color: Colors.white54),
                      const SizedBox(height: 8),
                      const Text('Image not available',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════ FORM ══════════════════════════════════════
class _PostFormContent extends StatelessWidget {
  final bool isEdit;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final TextEditingController youtubeController;
  final String? localImagePath;
  final String? existingImageUrl;
  final Function(String?) onImagePicked;
  final VoidCallback onImageRemoved;
  final VoidCallback onSave;

  const _PostFormContent({
    required this.isEdit,
    required this.titleController,
    required this.contentController,
    required this.youtubeController,
    required this.localImagePath,
    required this.existingImageUrl,
    required this.onImagePicked,
    required this.onImageRemoved,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final picker = ImagePicker();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, theme, l10n),
        const SizedBox(height: 22),
        _buildTitleField(theme),
        const SizedBox(height: 14),
        _buildContentField(theme),
        const SizedBox(height: 14),
        _buildYoutubeField(theme),
        const SizedBox(height: 14),
        _buildImagePicker(theme, picker),
        const SizedBox(height: 24),
        _buildActionButtons(context, l10n),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHeader(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.15),
                    AppTheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isEdit ? Icons.edit_outlined : Icons.post_add_rounded,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isEdit ? l10n.editPostTitle : l10n.createPostTitle,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.close_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.5)),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  InputDecoration _decoration(ThemeData theme, String label, {Widget? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: theme.textTheme.bodySmall,
      prefixIcon: icon,
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTitleField(ThemeData theme) {
    return TextFormField(
      controller: titleController,
      style: theme.textTheme.bodyLarge,
      decoration: _decoration(theme, 'Title'),
      validator: (v) =>
      v != null && v.trim().isNotEmpty ? null : 'Title is required',
    );
  }

  Widget _buildContentField(ThemeData theme) {
    return TextFormField(
      controller: contentController,
      maxLines: 5,
      style: theme.textTheme.bodyLarge,
      decoration: _decoration(theme, 'Content'),
      validator: (v) =>
      v != null && v.trim().isNotEmpty ? null : 'Content is required',
    );
  }

  Widget _buildYoutubeField(ThemeData theme) {
    return TextFormField(
      controller: youtubeController,
      style: theme.textTheme.bodyLarge,
      decoration: _decoration(
        theme,
        'YouTube URL (optional)',
        icon: Icon(Icons.play_circle_outline, color: Colors.red.shade700),
      ).copyWith(
        hintText: 'https://youtu.be/... or https://youtube.com/watch?v=...',
      ),
    );
  }

  Widget _buildImagePicker(ThemeData theme, ImagePicker picker) {
    return GestureDetector(
      onTap: () async {
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: _imageQuality,
        );
        if (file != null) onImagePicked(file.path);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          border: Border.all(color: theme.dividerColor, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildImagePreview(theme),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getImageLabel(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _hasNoImage()
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (localImagePath != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onImageRemoved,
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: localImagePath != null
          ? Image.file(
        File(localImagePath!),
        width: _imagePreviewSize,
        height: _imagePreviewSize,
        fit: BoxFit.cover,
      )
          : (existingImageUrl != null && existingImageUrl!.isNotEmpty)
          ? Image.network(
        ImageUtils.getFullImageUrl(existingImageUrl),
        width: _imagePreviewSize,
        height: _imagePreviewSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: _imagePreviewSize,
          height: _imagePreviewSize,
          color: theme.colorScheme.surface,
          child: const Icon(Icons.broken_image, size: 20),
        ),
      )
          : Container(
        width: _imagePreviewSize,
        height: _imagePreviewSize,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.add_photo_alternate_rounded,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  String _getImageLabel() {
    if (localImagePath != null) return localImagePath!.split('/').last;
    if (existingImageUrl != null && existingImageUrl!.isNotEmpty) {
      return 'Current image (tap to replace)';
    }
    return 'Add Image (optional)';
  }

  bool _hasNoImage() =>
      localImagePath == null &&
          (existingImageUrl == null || existingImageUrl!.isEmpty);

  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor:
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(l10n.cancel,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: CustomButton(
            text: isEdit ? l10n.update : l10n.create,
            onPressed: onSave,
            isLoading: context.watch<PostProvider>().isLoading,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════ CARD ══════════════════════════════════════
class _PostCard extends StatefulWidget {
  final dynamic post;
  final bool isGrid;
  final void Function(String heroTag)? onImageTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLike;

  const _PostCard({
    super.key,
    required this.post,
    this.isGrid = false,
    this.onImageTap,
    required this.onEdit,
    required this.onDelete,
    required this.onLike,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  bool _showBigHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleDoubleTapLike() {
    if (!widget.post.likedByUser) {
      widget.onLike();
    }
    setState(() => _showBigHeart = true);
    _heartController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showBigHeart = false);
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = widget.post;
    final heroTag = 'post-image-${post.id}';

    final imageUrl = (post.image != null && post.image.toString().isNotEmpty)
        ? ImageUtils.getFullImageUrl(post.image)
        : null;

    final hasVideo = post.hasYoutubeVideo == true &&
        post.youtubeUrl != null &&
        post.youtubeUrl.toString().trim().isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: widget.isGrid ? 0 : 12,
        vertical: widget.isGrid ? 0 : 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: widget.isGrid ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _PostHeader(post: post, onEdit: widget.onEdit, onDelete: widget.onDelete),
          if (imageUrl != null || hasVideo)
            Expanded(
              flex: widget.isGrid ? 3 : 0,
              child: GestureDetector(
                onDoubleTap: imageUrl != null ? _handleDoubleTapLike : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _MediaSection(
                      imageUrl: imageUrl,
                      videoUrl: hasVideo ? post.youtubeUrl.toString() : null,
                      heroTag: heroTag,
                      isGrid: widget.isGrid,
                      onImageTap: widget.onImageTap != null
                          ? () => widget.onImageTap!(heroTag)
                          : null,
                    ),
                    AnimatedOpacity(
                      opacity: _showBigHeart ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.6, end: 1.15)
                            .animate(CurvedAnimation(
                          parent: _heartController,
                          curve: const Interval(0, 0.5, curve: Curves.easeOut),
                        )),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 90,
                          shadows: [
                            Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: widget.isGrid ? 2 : 0,
            child: Column(
              mainAxisSize: widget.isGrid ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PostFooterActions(post: post, onLike: widget.onLike),
                Flexible(
                  child: _PostContent(
                    title: post.title,
                    content: post.content,
                    isGrid: widget.isGrid,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────── POST HEADER ─────────────
class _PostHeader extends StatelessWidget {
  final dynamic post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostHeader({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  void _showMenu(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_outlined, color: AppTheme.primary),
                title: const Text('Edit post'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                title: Text('Delete post',
                    style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.4)],
              ),
            ),
            child: CircleAvatar(
              radius: _avatarSize / 2,
              backgroundColor: theme.colorScheme.surface,
              child: CircleAvatar(
                radius: (_avatarSize / 2) - 2,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                backgroundImage: post.technicianAvatar != null
                    ? NetworkImage(
                    ImageUtils.getFullImageUrl(post.technicianAvatar!))
                    : null,
                child: post.technicianAvatar == null
                    ? Text(
                  post.technicianName.isNotEmpty
                      ? post.technicianName[0].toUpperCase()
                      : 'F',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.technicianName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(Icons.public_rounded,
                        size: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    const SizedBox(width: 3),
                    Text(
                      _formatTime(post.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.6)),
            onPressed: () => _showMenu(context),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ───────────── MEDIA SECTION ─────────────
class _MediaSection extends StatelessWidget {
  final String? imageUrl;
  final String? videoUrl;
  final String heroTag;
  final bool isGrid;
  final VoidCallback? onImageTap;

  const _MediaSection({
    required this.imageUrl,
    required this.videoUrl,
    required this.heroTag,
    required this.isGrid,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final hasVideo = videoUrl != null && videoUrl!.trim().isNotEmpty;

    if (!hasImage && !hasVideo) return const SizedBox.shrink();

    // Prefer showing the video thumbnail if there's no image, otherwise
    // show the image with a small video pill so the card stays feed-like.
    if (hasImage) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          _PostImage(
            imageUrl: imageUrl!,
            heroTag: heroTag,
            isGrid: isGrid,
            onImageTap: onImageTap,
          ),
          if (hasVideo)
            Positioned(
              top: 10,
              right: 10,
              child: _VideoPill(videoUrl: videoUrl!),
            ),
        ],
      );
    }

    return _YouTubeThumbnail(
      videoUrl: videoUrl!,
      height: isGrid ? double.infinity : _youtubePlayerHeight,
    );
  }
}

class _VideoPill extends StatelessWidget {
  final String videoUrl;
  const _VideoPill({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _YouTubeThumbnail(videoUrl: videoUrl, height: 260),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('Video',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ───────────── IMAGE ─────────────
class _PostImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final bool isGrid;
  final VoidCallback? onImageTap;

  const _PostImage({
    required this.imageUrl,
    required this.heroTag,
    required this.isGrid,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onImageTap,
      child: Hero(
        tag: heroTag,
        child: AspectRatio(
          aspectRatio: isGrid ? 1 : 4 / 3,
          child: Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image,
                      size: 40,
                      color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  const SizedBox(height: 6),
                  Text(
                    'Image not available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────── YOUTUBE THUMBNAIL ─────────────
class _YouTubeThumbnail extends StatelessWidget {
  final String videoUrl;
  final double height;

  const _YouTubeThumbnail({
    required this.videoUrl,
    this.height = _youtubePlayerHeight,
  });

  String? _extractVideoId(String input) {
    if (input.trim().isEmpty) return null;
    String working = input.trim();

    if (working.toLowerCase().contains('<iframe')) {
      final match = RegExp(r'''src=["']([^"']+)["']''', caseSensitive: false)
          .firstMatch(working);
      if (match != null) working = match.group(1) ?? working;
    }

    String? id = YoutubePlayer.convertUrlToId(working);
    if (id != null && id.length == 11) return id;

    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/)|youtube-nocookie\.com\/embed\/)([_\-a-zA-Z0-9]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(working);
    if (match != null) return match.group(1);

    if (working.length == 11 && !working.contains('/') && !working.contains('?')) {
      return working;
    }
    return null;
  }

  Future<void> _openYoutube(BuildContext context) async {
    final videoId = _extractVideoId(videoUrl);
    if (videoId == null) return;
    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoId = _extractVideoId(videoUrl);

    if (videoId == null) {
      return Container(
        height: height,
        color: Colors.grey.shade900,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white54, size: 36),
              SizedBox(height: 8),
              Text('Invalid YouTube URL',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    final fallbackThumbnail = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    return GestureDetector(
      onTap: () => _openYoutube(context),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.network(
                fallbackThumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(Icons.play_circle_outline,
                        color: Colors.white54, size: 60),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 52),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tap to play on YouTube',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────── FOOTER ACTIONS (like/comment row, IG-style) ─────────────
class _PostFooterActions extends StatelessWidget {
  final dynamic post;
  final VoidCallback onLike;

  const _PostFooterActions({required this.post, required this.onLike});

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final likes = (post.likesCount ?? 0) as int;
    final comments = (post.commentsCount ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          _ActionIcon(
            icon: post.likedByUser ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: post.likedByUser
                ? Colors.red
                : theme.colorScheme.onSurface.withOpacity(0.75),
            onTap: () {
              HapticFeedback.selectionClick();
              onLike();
            },
          ),
          const SizedBox(width: 4),
          _ActionIcon(
            icon: Icons.chat_bubble_outline_rounded,
            color: theme.colorScheme.onSurface.withOpacity(0.75),
            onTap: () {},
          ),
          const SizedBox(width: 4),
          _ActionIcon(
            icon: Icons.share_outlined,
            color: theme.colorScheme.onSurface.withOpacity(0.75),
            onTap: () {},
          ),
          const Spacer(),
          if (likes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${_compact(likes)} ${likes == 1 ? 'like' : 'likes'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

// ───────────── CONTENT ─────────────
class _PostContent extends StatefulWidget {
  final String title;
  final String content;
  final bool isGrid;

  const _PostContent({
    required this.title,
    required this.content,
    required this.isGrid,
  });

  @override
  State<_PostContent> createState() => _PostContentState();
}

class _PostContentState extends State<_PostContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLong = widget.content.length > 90;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: SingleChildScrollView(
        physics: widget.isGrid
            ? const NeverScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              maxLines: widget.isGrid ? 1 : null,
              overflow: widget.isGrid ? TextOverflow.ellipsis : null,
            ),
            const SizedBox(height: 3),
            GestureDetector(
              onTap: isLong ? () => setState(() => _expanded = !_expanded) : null,
              child: RichText(
                maxLines: (widget.isGrid && !_expanded) ? 2 : (_expanded ? null : 2),
                overflow: (_expanded)
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                  children: [
                    TextSpan(text: widget.content),
                    if (isLong)
                      TextSpan(
                        text: _expanded ? '  Show less' : '  more',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}