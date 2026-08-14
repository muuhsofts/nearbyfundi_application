// screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/request_provider.dart';
import 'nearby_screen.dart';
import 'nearby_map_screen.dart';
import 'blogs_screen.dart';
import '../requests/my_requests_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/technician_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/chat_user.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  String _currentLocale = 'en';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _currentLocale = settings.locale;

      // Refresh services with current locale
      context.read<ServiceProvider>().fetchServices(locale: _currentLocale);
    });

    _screens = const [
      NearbyScreen(),
      BlogsScreen(),
      MyRequestsScreen(),
      ChatListScreen(),
      ProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
      _initializeChat();
    });
  }

  void _initializeChat() {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final user = authProvider.user;
    final token = authProvider.token;

    if (user != null && token != null) {
      chatProvider.initialize(
        token: token,
        currentUser: ChatUser(
          id: user.id,
          name: user.name,
          email: user.email,
          phone: user.phone,
          avatar: null,
        ),
      );
    }
  }

  void _loadNotifications() {
    context.read<NotificationProvider>().loadNotifications();
  }

  /// Refresh the current screen content
  Future<void> _refreshCurrentScreen() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      // Refresh based on current index
      switch (_currentIndex) {
        case 0: // Nearby
          await context.read<TechnicianProvider>().refreshLastSearch();
          break;

        case 1: // Blogs
          await context.read<PostProvider>().fetchPosts(refresh: true);
          break;

        case 2: // My Requests
          await context.read<RequestProvider>().loadMyRequests();
          break;

        case 3: // Chat
          await context.read<ChatProvider>().refreshConversations();
          break;

        case 4: // Profile
          await context.read<AuthProvider>().loadUser();
          break;
      }

      // Always refresh notifications and services
      await context.read<NotificationProvider>().loadNotifications();

      // Refresh services if locale changed
      final settings = context.read<SettingsProvider>();
      if (_currentLocale != settings.locale) {
        _currentLocale = settings.locale;
        await context.read<ServiceProvider>().fetchServices(locale: _currentLocale);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.refreshed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.refreshFailed),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showNotifications(BuildContext context) {
    final notificationProvider = context.read<NotificationProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.notifications,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          notificationProvider.markAllAsRead();
                          Navigator.pop(ctx);
                        },
                        child: Text(l10n.markAllAsRead),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer<NotificationProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
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
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.noNotificationsYet,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: provider.notifications.length,
                          itemBuilder: (context, index) {
                            final notification = provider.notifications[index];
                            return _NotificationTile(
                              notification: notification,
                              onTap: () {
                                provider.markAsRead(notification['id']);
                                Navigator.pop(ctx);
                                final type = notification['type'] ?? '';
                                if (type == 'chat_message') {
                                  setState(() => _currentIndex = 3);
                                } else if (type == 'new_request' ||
                                    type == 'request_accepted' ||
                                    type == 'request_rejected') {
                                  setState(() => _currentIndex = 2);
                                }
                              },
                              locale: _currentLocale,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Update locale when settings change
    final settings = context.watch<SettingsProvider>();
    if (_currentLocale != settings.locale) {
      _currentLocale = settings.locale;
      // Refresh services with new locale
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ServiceProvider>().fetchServices(locale: _currentLocale);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.onPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.handyman_rounded,
                  color: theme.primaryColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.appTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          // Refresh button
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: _refreshCurrentScreen,
            tooltip: l10n.refresh,
          ),
          // Notification bell
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final unreadCount = notificationProvider.unreadCount;
              return IconButton(
                icon: Stack(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: theme.colorScheme.onSurface,
                      size: 26,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => _showNotifications(context),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCurrentScreen,
        color: theme.primaryColor,
        backgroundColor: theme.colorScheme.surface,
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: theme.primaryColor,
              unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home_rounded),
                  label: l10n.nearby,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.article_outlined),
                  activeIcon: const Icon(Icons.article_rounded),
                  label: l10n.blog,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.list_alt_outlined),
                  activeIcon: const Icon(Icons.list_alt_rounded),
                  label: l10n.requests,
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded),
                      if (chatProvider.totalUnread > 0)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            chatProvider.totalUnread > 9
                                ? '9+'
                                : '${chatProvider.totalUnread}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                  activeIcon: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      const Icon(Icons.chat_bubble_rounded),
                      if (chatProvider.totalUnread > 0)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            chatProvider.totalUnread > 9
                                ? '9+'
                                : '${chatProvider.totalUnread}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                  label: l10n.chat,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person_rounded),
                  label: l10n.profile,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// Notification Tile with language support
// ================================================================
class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final String locale;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.locale,
  });

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'chat_message':
        return 'Chat';
      case 'new_request':
        return 'New Request';
      case 'request_accepted':
        return 'Request Accepted';
      case 'request_rejected':
        return 'Request Rejected';
      case 'request_in_progress':
        return 'In Progress';
      case 'request_completed':
        return 'Completed';
      default:
        return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = notification['is_read'] ?? false;
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isRead
            ? Colors.grey.shade200
            : theme.primaryColor.withOpacity(0.1),
        child: Icon(
          _getIcon(notification['type']),
          color: isRead ? Colors.grey.shade600 : theme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        notification['title'] ?? l10n.notification,
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification['body'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          if (notification['type'] != null)
            Text(
              _getTypeLabel(notification['type']),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
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
      default:
        return Icons.notifications_outlined;
    }
  }
}