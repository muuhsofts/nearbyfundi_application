import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/post_provider.dart';
import '../../models/post.dart';
import '../../config/app_theme.dart';
import '../../utils/image_utils.dart';
import '../modals.dart';
import '../../l10n/app_localizations.dart';

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
        title: Text(l10n.blog, style: theme.appBarTheme.titleTextStyle),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onPrimary),
            onPressed: () => provider.fetchPosts(refresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchPosts(refresh: true),
        child: provider.isLoading && provider.posts.isEmpty
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : provider.posts.isEmpty
            ? Center(
          child: Text(
            l10n.noBlogPosts,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, fontSize: 18),
          ),
        )
            : ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          itemCount: provider.posts.length,
          itemBuilder: (ctx, i) {
            final post = provider.posts[i];
            return _InstagramPostCard(post: post, margin: cardMargin);
          },
        ),
      ),
    );
  }
}

class _InstagramPostCard extends StatelessWidget {
  final Post post;
  final double margin;

  const _InstagramPostCard({required this.post, this.margin = 10});

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
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: theme.shadowColor.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                        ? Text(post.technicianName[0].toUpperCase(), style: const TextStyle(fontSize: 16))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.technicianName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(_formatDate(post.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(Icons.more_horiz, size: 22, color: theme.hintColor), onPressed: () {}),
                ],
              ),
            ),

            // Image
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
                    child: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
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
                  child: Text(post.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                ),
              ),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(post.likedByUser ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: post.likedByUser ? Colors.red : theme.hintColor),
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

            // Caption
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                  children: [
                    TextSpan(text: '${post.technicianName} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: post.content.length > 120 ? '${post.content.substring(0, 120)}...' : post.content),
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