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
          style: TextStyle(
            color: isDark ? Colors.white : Colors.white,
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
        child: _buildBody(context, provider),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationProvider provider) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
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
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noNotificationsYet,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isRead
            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
            : theme.primaryColor.withOpacity(0.1),
        child: Icon(
          _getIcon(notification['type']),
          color: isRead
              ? (isDark ? Colors.grey.shade500 : Colors.grey.shade600)
              : theme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        notification['title'] ?? 'Notification',
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          color: isRead
              ? (isDark ? Colors.grey.shade400 : Colors.grey.shade700)
              : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        notification['body'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        ),
      ),
      trailing: isRead
          ? null
          : Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
      isThreeLine: false,
      dense: true,
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble_outline;
      case 'new_request':
        return Icons.request_page_outlined;
      case 'request_accepted':
        return Icons.check_circle_outline;
      case 'request_rejected':
        return Icons.cancel_outlined;
      case 'request_in_progress':
        return Icons.hourglass_top_outlined;
      case 'request_completed':
        return Icons.check_circle_outline;
      case 'subscription_approved':
        return Icons.verified_rounded;
      case 'subscription_rejected':
        return Icons.cancel_rounded;
      case 'subscription_expired':
        return Icons.warning_rounded;
      case 'subscription_expiring_soon':
        return Icons.timer_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }
}