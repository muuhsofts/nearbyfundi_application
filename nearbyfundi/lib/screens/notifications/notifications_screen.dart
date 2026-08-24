import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../config/app_routes.dart';
import '../../l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final provider = context.read<NotificationProvider>();
      await provider.loadNotifications();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load notifications';
        });
      }
    }
  }

  Future<void> _refreshNotifications() async {
    final provider = context.read<NotificationProvider>();
    await provider.loadNotifications();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final provider = context.read<NotificationProvider>();

    // Mark as read
    provider.markAsRead(notification['id']);

    // Pop the notifications screen first
    Navigator.pop(context);

    final type = notification['type'] ?? '';

    // Navigate based on notification type
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (type == 'chat_message') {
        Navigator.pushNamed(context, AppRoutes.chatList);
      } else if (type == 'new_request' ||
          type == 'request_accepted' ||
          type == 'request_rejected' ||
          type == 'request_in_progress' ||
          type == 'request_completed') {
        Navigator.pushNamed(context, AppRoutes.myRequests);
      } else if (type == 'subscription_approved' ||
          type == 'subscription_rejected' ||
          type == 'subscription_expired' ||
          type == 'subscription_expiring_soon') {
        Navigator.pop(context);
      } else if (type == 'new_post') {
        Navigator.pushNamed(context, AppRoutes.home);
      } else {
        Navigator.pop(context);
      }
    });
  }

  void _markAllAsRead() {
    final provider = context.read<NotificationProvider>();
    provider.markAllAsRead();
    if (mounted) {
      setState(() {});
    }
  }

  // ================================================================
  // FORMAT DATE TIME
  // ================================================================

  String _formatCreatedAt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }

    try {
      DateTime dateTime = DateTime.parse(value.toString());

      if (dateTime.isUtc) {
        dateTime = dateTime.toLocal();
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // Just now
      if (difference.inSeconds < 30) {
        return 'Just now';
      }

      // Minutes
      if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return '$minutes min${minutes == 1 ? '' : 's'} ago';
      }

      // Hours
      if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours hr${hours == 1 ? '' : 's'} ago';
      }

      // Days
      if (difference.inDays == 1) {
        return 'Yesterday';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      }

      // More than a week - show formatted date
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();

      final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final hour = hour12.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year • $hour:$minute $period';
    } catch (e) {
      debugPrint('Invalid notification created_at: $value');
      return value.toString();
    }
  }

  // ================================================================
  // GET ICON
  // ================================================================

  IconData _getIcon(String? type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      case 'new_request':
        return Icons.request_page_outlined;
      case 'request_accepted':
        return Icons.check_circle_outline_rounded;
      case 'request_rejected':
        return Icons.cancel_outlined;
      case 'request_in_progress':
        return Icons.hourglass_top_rounded;
      case 'request_completed':
        return Icons.task_alt_rounded;
      case 'subscription_approved':
        return Icons.verified_rounded;
      case 'subscription_rejected':
        return Icons.cancel_rounded;
      case 'subscription_expired':
        return Icons.warning_rounded;
      case 'subscription_expiring_soon':
        return Icons.timer_rounded;
      case 'new_post':
        return Icons.article_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  // ================================================================
  // GET ICON COLOR
  // ================================================================

  Color _getIconColor(String? type, ThemeData theme) {
    switch (type) {
      case 'request_accepted':
      case 'request_completed':
      case 'subscription_approved':
        return Colors.green.shade600;
      case 'request_rejected':
      case 'subscription_rejected':
        return Colors.red.shade600;
      case 'request_in_progress':
        return Colors.orange.shade700;
      case 'chat_message':
        return Colors.blue.shade600;
      case 'subscription_expired':
        return Colors.red.shade700;
      case 'subscription_expiring_soon':
        return Colors.amber.shade700;
      case 'new_request':
      case 'new_post':
        return theme.primaryColor;
      default:
        return theme.primaryColor;
    }
  }

  // ================================================================
  // GET TYPE LABEL
  // ================================================================

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'chat_message':
        return 'Chat';
      case 'new_request':
        return 'New Request';
      case 'request_accepted':
        return 'Accepted';
      case 'request_rejected':
        return 'Rejected';
      case 'request_in_progress':
        return 'In Progress';
      case 'request_completed':
        return 'Completed';
      case 'subscription_approved':
        return 'Approved';
      case 'subscription_rejected':
        return 'Rejected';
      case 'subscription_expired':
        return 'Expired';
      case 'subscription_expiring_soon':
        return 'Expiring Soon';
      case 'new_post':
        return 'New Post';
      default:
        return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<NotificationProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.notifications,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                l10n.markAllAsRead,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        color: theme.primaryColor,
        backgroundColor: theme.colorScheme.surface,
        child: _buildBody(context, provider),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationProvider provider) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading notifications...',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull to refresh or tap retry',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 48,
                color: theme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noNotificationsYet,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll notify you when something new arrives',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: provider.notifications.length,
      itemBuilder: (context, index) {
        final notification = provider.notifications[index];
        final isRead = notification['is_read'] ?? false;

        return _NotificationTile(
          notification: notification,
          isRead: isRead,
          onTap: () => _handleNotificationTap(notification),
        );
      },
    );
  }
}

// ================================================================
// Notification Tile
// ================================================================

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  // ================================================================
  // FORMAT DATE TIME
  // ================================================================

  String _formatCreatedAt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }

    try {
      DateTime dateTime = DateTime.parse(value.toString());

      if (dateTime.isUtc) {
        dateTime = dateTime.toLocal();
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // Just now
      if (difference.inSeconds < 30) {
        return 'Just now';
      }

      // Minutes
      if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return '$minutes min${minutes == 1 ? '' : 's'} ago';
      }

      // Hours
      if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours hr${hours == 1 ? '' : 's'} ago';
      }

      // Days
      if (difference.inDays == 1) {
        return 'Yesterday';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      }

      // More than a week - show formatted date
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();

      final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final hour = hour12.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year • $hour:$minute $period';
    } catch (e) {
      debugPrint('Invalid notification created_at: $value');
      return value.toString();
    }
  }

  // ================================================================
  // GET ICON
  // ================================================================

  IconData _getIcon(String? type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      case 'new_request':
        return Icons.request_page_outlined;
      case 'request_accepted':
        return Icons.check_circle_outline_rounded;
      case 'request_rejected':
        return Icons.cancel_outlined;
      case 'request_in_progress':
        return Icons.hourglass_top_rounded;
      case 'request_completed':
        return Icons.task_alt_rounded;
      case 'subscription_approved':
        return Icons.verified_rounded;
      case 'subscription_rejected':
        return Icons.cancel_rounded;
      case 'subscription_expired':
        return Icons.warning_rounded;
      case 'subscription_expiring_soon':
        return Icons.timer_rounded;
      case 'new_post':
        return Icons.article_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  // ================================================================
  // GET ICON COLOR
  // ================================================================

  Color _getIconColor(String? type, ThemeData theme) {
    switch (type) {
      case 'request_accepted':
      case 'request_completed':
      case 'subscription_approved':
        return Colors.green.shade600;
      case 'request_rejected':
      case 'subscription_rejected':
        return Colors.red.shade600;
      case 'request_in_progress':
        return Colors.orange.shade700;
      case 'chat_message':
        return Colors.blue.shade600;
      case 'subscription_expired':
        return Colors.red.shade700;
      case 'subscription_expiring_soon':
        return Colors.amber.shade700;
      case 'new_request':
      case 'new_post':
        return theme.primaryColor;
      default:
        return theme.primaryColor;
    }
  }

  // ================================================================
  // GET TYPE LABEL
  // ================================================================

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'chat_message':
        return 'Chat';
      case 'new_request':
        return 'New Request';
      case 'request_accepted':
        return 'Accepted';
      case 'request_rejected':
        return 'Rejected';
      case 'request_in_progress':
        return 'In Progress';
      case 'request_completed':
        return 'Completed';
      case 'subscription_approved':
        return 'Approved';
      case 'subscription_rejected':
        return 'Rejected';
      case 'subscription_expired':
        return 'Expired';
      case 'subscription_expiring_soon':
        return 'Expiring Soon';
      case 'new_post':
        return 'New Post';
      default:
        return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final type = notification['type']?.toString() ?? '';
    final title = notification['title']?.toString() ?? 'Notification';
    final body = notification['body']?.toString() ?? '';
    final createdAt = notification['created_at'];

    final iconColor = _getIconColor(type, theme);
    final relativeTime = _formatCreatedAt(createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isRead
                  ? theme.colorScheme.surface
                  : theme.primaryColor.withOpacity(0.055),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead
                    ? theme.dividerColor.withOpacity(0.30)
                    : theme.primaryColor.withOpacity(0.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =====================================================
                // ICON
                // =====================================================

                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getIcon(type),
                    color: iconColor,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // =====================================================
                // CONTENT
                // =====================================================

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =============================================
                      // TITLE + UNREAD DOT
                      // =============================================

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.25,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: isRead
                                    ? (isDark ? Colors.grey.shade400 : Colors.grey.shade700)
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),

                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(
                                left: 8,
                                top: 5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      // =============================================
                      // BODY
                      // =============================================

                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // =============================================
                      // TYPE + TIME
                      // =============================================

                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (type.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                _getTypeLabel(type),
                                style: TextStyle(
                                  color: iconColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                          if (relativeTime.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 13,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  relativeTime,
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade600,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      // =============================================
                      // EXACT DATE/TIME (for older notifications)
                      // =============================================

                      if (relativeTime.contains('/')) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                relativeTime,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}