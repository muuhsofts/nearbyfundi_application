import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/post_provider.dart';
import '../../models/post.dart';
import '../../config/app_theme.dart';
import '../../utils/image_utils.dart';
import '../modals.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_routes.dart';

class BlogsScreen extends StatefulWidget {
  const BlogsScreen({super.key});

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostProvider>().fetchPosts(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 32.0 : 16.0;
    final cardMargin = isTablet ? 16.0 : 10.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.blog,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => provider.fetchPosts(refresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchPosts(refresh: true),
        color: AppTheme.primary,
        child: provider.isLoading && provider.posts.isEmpty
            ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : provider.posts.isEmpty
            ? Center(
          child: Text(
            l10n.noBlogPosts,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor,
              fontSize: 18,
            ),
          ),
        )
            : ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          itemCount: provider.posts.length,
          itemBuilder: (ctx, i) {
            final post = provider.posts[i];
            return _BlogPostCard(post: post, margin: cardMargin);
          },
        ),
      ),
    );
  }
}

// ─── Light Card with no black background ────────────────────────────────
class _BlogPostCard extends StatelessWidget {
  final Post post;
  final double margin;

  const _BlogPostCard({required this.post, this.margin = 10});

  void _openPostModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostModal(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 600;

    return GestureDetector(
      onTap: () => _openPostModal(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 0, vertical: margin),
        decoration: BoxDecoration(
          color: theme.cardColor, // Light card color (white in light theme)
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: post.technicianAvatar != null
                        ? CachedNetworkImageProvider(ImageUtils.getFullImageUrl(post.technicianAvatar!))
                        : null,
                    child: post.technicianAvatar == null
                        ? Text(
                      post.technicianName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _formatDate(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_horiz, size: 22, color: theme.hintColor),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // ─── Image ──────────────────────────────────────────────────
            if (post.image != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: CachedNetworkImage(
                  imageUrl: ImageUtils.getFullImageUrl(post.image!),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  height: isTablet ? 380 : 280,
                  placeholder: (context, url) => Container(
                    height: isTablet ? 380 : 280,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: isTablet ? 380 : 280,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.broken_image, size: 60, color: theme.hintColor),
                  ),
                ),
              )
            else
              Container(
                height: isTablet ? 260 : 200,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    post.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // ─── Actions ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      post.likedByUser ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: post.likedByUser ? Colors.red : theme.hintColor,
                    ),
                    onPressed: () => context.read<PostProvider>().likePost(post.id),
                  ),
                  Text('${post.likesCount}', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: Icon(Icons.comment_rounded, color: theme.hintColor),
                    onPressed: () => _openPostModal(context),
                  ),
                  Text('${post.commentsCount}', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),

            // ─── Caption ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                  children: [
                    TextSpan(
                      text: '${post.technicianName} ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: post.content.length > 120
                          ? '${post.content.substring(0, 120)}...'
                          : post.content,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}