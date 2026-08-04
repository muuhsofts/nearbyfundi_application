import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../models/chat_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/technician_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/notification_bell_icon.dart';
import '../../l10n/app_localizations.dart';

// Screens
import 'fundi_posts_screen.dart';
import 'fundi_requests_screen.dart';
import '../chat/chat_list_screen.dart';
import 'profile/fundi_profile_screen.dart';

class FundiHomeScreen extends StatefulWidget {
  const FundiHomeScreen({super.key});

  @override
  State<FundiHomeScreen> createState() => _FundiHomeScreenState();
}

class _FundiHomeScreenState extends State<FundiHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      const _HomeDashboardContent(),
      const FundiPostsScreen(),
      const FundiRequestsScreen(),
      const ChatListScreen(),
      const FundiProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSubscriptionAndStartTimer();
      context.read<RequestProvider>().loadMyRequests();
      context.read<NotificationProvider>().loadNotifications();
    }
  }

  // ============================================================
  // INITIALIZE DATA
  // ============================================================
  void _initializeData() {
    context.read<TechnicianProvider>().fetchMyProfile();
    context.read<RequestProvider>().loadMyRequests();
    _checkSubscriptionAndStartTimer();
    _initializeChat();
    _loadNotifications();
  }

  // ============================================================
  // SUBSCRIPTION CHECK
  // ============================================================
  void _checkSubscriptionAndStartTimer() {
    final provider = context.read<SubscriptionProvider>();
    provider.checkSubscriptionStatus();
    provider.loadMySubscriptions();

    final isPending = provider.isPending;
    _refreshTimer?.cancel();
    if (isPending) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        provider.checkSubscriptionStatus();
        provider.loadMySubscriptions();
        if (!provider.isPending) {
          timer.cancel();
          if (mounted) setState(() {});
        }
      });
    }
  }

  Future<void> _manualRefresh() async {
    final provider = context.read<SubscriptionProvider>();
    await provider.checkSubscriptionStatus();
    await provider.loadMySubscriptions();
    if (!provider.isPending) {
      _refreshTimer?.cancel();
    }
    if (mounted) setState(() {});
  }

  // ============================================================
  // CHAT INITIALIZATION
  // ============================================================
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

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================
  void _showNotifications(BuildContext context) {
    final provider = context.read<NotificationProvider>();
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
                      color: theme.dividerColor,
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
                          provider.markAllAsRead();
                          Navigator.pop(ctx);
                        },
                        child: Text(l10n.markAllAsRead),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer<NotificationProvider>(
                      builder: (context, notificationProvider, child) {
                        if (notificationProvider.isLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (notificationProvider.notifications.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 64,
                                  color: theme.hintColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.noNotificationsYet,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: notificationProvider.notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notificationProvider
                                .notifications[index];
                            return _NotificationTile(
                              notification: notification,
                              onTap: () {
                                notificationProvider.markAsRead(
                                    notification['id']);
                                Navigator.pop(ctx);
                                final type = notification['type'] ?? '';
                                if (type == 'chat_message') {
                                  _navigateToTab(3);
                                } else if (type == 'new_request' ||
                                    type == 'request_accepted' ||
                                    type == 'request_rejected') {
                                  _navigateToTab(2);
                                } else {
                                  _navigateToTab(0);
                                }
                              },
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

  // ============================================================
  // COMING SOON
  // ============================================================
  void _showComingSoon(BuildContext context, String feature) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.construction_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$feature ${AppLocalizations.of(context)!.comingSoon} 🚀',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> _logoutWithConfirmation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showConfirmationDialog(
      context,
      l10n.logout,
      l10n.logoutConfirmation,
    );
    if (confirm == true) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  // ============================================================
  // SUBSCRIPTION REQUIRED DIALOG
  // ============================================================
  void _showSubscriptionRequiredDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Text(
              'Subscription Required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You need an active subscription to access this feature.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Subscribe now to unlock all Fundi features:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Manage your services'),
              ],
            ),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Accept and manage requests'),
              ],
            ),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Chat with customers'),
              ],
            ),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Showcase your portfolio'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AppRoutes.rateCards);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final subscription = context.watch<SubscriptionProvider>();
    final hasSubscription = subscription.hasActiveSubscription;
    final isPending = subscription.isPending;

    Widget body;
    if (hasSubscription) {
      body = _screens[_currentIndex];
    } else if (isPending) {
      body = const _LockedDashboardOverlay(isPending: true);
    } else {
      body = _buildLockedOverlay(context);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.fundiDashboard,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          NotificationBellIcon(
            onTap: hasSubscription
                ? () => _showNotifications(context)
                : () => _showSubscriptionRequiredDialog(context),
          ),
          IconButton(
            icon: Icon(
              Icons.smart_toy_rounded,
              color: hasSubscription ? Colors.white : Colors.white.withOpacity(0.5),
              size: 26,
            ),
            onPressed: hasSubscription
                ? () => _showComingSoon(context, l10n.aiAssistant)
                : () => _showSubscriptionRequiredDialog(context),
            tooltip: hasSubscription
                ? '${l10n.aiAssistant} (${l10n.comingSoon})'
                : '🔒 Subscription Required',
          ),
          // Menu button - opens from top right
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: hasSubscription ? Colors.white : Colors.white.withOpacity(0.5),
            ),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            onOpened: () {
              // If no subscription, close the menu immediately
              if (!hasSubscription) {
                // We need to close the menu and show dialog
                // Since we can't cancel from here directly, we'll use a workaround
                Future.microtask(() {
                  Navigator.of(context).maybePop();
                  _showSubscriptionRequiredDialog(context);
                });
              }
            },
            itemBuilder: (context) => _buildMenuItems(context, hasSubscription),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: theme.dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            return BottomNavigationBar(
              currentIndex: hasSubscription ? _currentIndex : 0,
              onTap: (i) {
                if (!hasSubscription) {
                  _showSubscriptionRequiredDialog(context);
                  return;
                }
                setState(() => _currentIndex = i);
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: hasSubscription ? theme.primaryColor : Colors.grey,
              unselectedItemColor:
              isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              backgroundColor: theme.cardColor,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.home_outlined,
                    color: hasSubscription ? null : Colors.grey,
                  ),
                  activeIcon: Icon(
                    Icons.home_rounded,
                    color: hasSubscription ? null : Colors.grey,
                  ),
                  label: hasSubscription ? l10n.home : '🔒 Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.article_outlined,
                    color: hasSubscription ? null : Colors.grey,
                  ),
                  activeIcon: Icon(
                    Icons.article_rounded,
                    color: hasSubscription ? null : Colors.grey,
                  ),
                  label: hasSubscription ? l10n.blog : '🔒 Blog',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Icon(
                        Icons.list_alt_outlined,
                        color: hasSubscription ? null : Colors.grey,
                      ),
                      if (hasSubscription && chatProvider.totalUnread > 0)
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
                            chatProvider.totalUnread > 9 ? '9+' : '${chatProvider.totalUnread}',
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
                      Icon(
                        Icons.list_alt_rounded,
                        color: hasSubscription ? null : Colors.grey,
                      ),
                      if (hasSubscription && chatProvider.totalUnread > 0)
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
                            chatProvider.totalUnread > 9 ? '9+' : '${chatProvider.totalUnread}',
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
                  label: hasSubscription ? l10n.requests : '🔒 Requests',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: hasSubscription ? null : Colors.grey,
                      ),
                      if (hasSubscription && chatProvider.totalUnread > 0)
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
                            chatProvider.totalUnread > 9 ? '9+' : '${chatProvider.totalUnread}',
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
                      Icon(
                        Icons.chat_bubble_rounded,
                        color: hasSubscription ? null : Colors.grey,
                      ),
                      if (hasSubscription && chatProvider.totalUnread > 0)
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
                            chatProvider.totalUnread > 9 ? '9+' : '${chatProvider.totalUnread}',
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
                  label: hasSubscription ? l10n.chat : '🔒 Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.person_outline,
                    color: hasSubscription ? null : Colors.grey,
                  ),
                  activeIcon: Icon(
                    Icons.person_rounded,
                    color: hasSubscription ? null : Colors.grey,
                  ),
                  label: hasSubscription ? l10n.profile : '🔒 Profile',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // BUILD MENU ITEMS
  // ============================================================
  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context, bool hasSubscription) {
    final l10n = AppLocalizations.of(context)!;

    return [
      _buildPopupMenuItem(
        context,
        key: 'settings',
        icon: Icons.settings_outlined,
        title: hasSubscription ? l10n.settings : '🔒 ${l10n.settings}',
        isLocked: !hasSubscription,
        onTap: () {
          if (hasSubscription) {
            Navigator.pushNamed(context, AppRoutes.settings);
          } else {
            _showSubscriptionRequiredDialog(context);
          }
        },
      ),
      _buildPopupMenuItem(
        context,
        key: 'portfolio',
        icon: Icons.photo_library_outlined,
        title: hasSubscription ? l10n.portfolio : '🔒 ${l10n.portfolio}',
        isLocked: !hasSubscription,
        onTap: () {
          if (hasSubscription) {
            Navigator.pushNamed(context, AppRoutes.portfolio);
          } else {
            _showSubscriptionRequiredDialog(context);
          }
        },
      ),
      _buildPopupMenuItem(
        context,
        key: 'subscriptions',
        icon: Icons.subscriptions_outlined,
        title: 'Subscriptions',
        isLocked: false,
        onTap: () => Navigator.pushNamed(context, AppRoutes.subscriptions),
      ),
      _buildPopupMenuItem(
        context,
        key: 'downloads',
        icon: Icons.file_download_rounded,
        title: hasSubscription ? 'Downloads' : '🔒 Downloads',
        isLocked: !hasSubscription,
        onTap: () {
          if (hasSubscription) {
            Navigator.pushNamed(context, AppRoutes.downloads);
          } else {
            _showSubscriptionRequiredDialog(context);
          }
        },
      ),
      const PopupMenuDivider(),
      _buildPopupMenuItem(
        context,
        key: 'about',
        icon: Icons.info_outline_rounded,
        title: hasSubscription ? l10n.aboutUs : '🔒 ${l10n.aboutUs}',
        isLocked: !hasSubscription,
        onTap: () {
          if (hasSubscription) {
            Navigator.pushNamed(context, AppRoutes.about);
          } else {
            _showSubscriptionRequiredDialog(context);
          }
        },
      ),
      _buildPopupMenuItem(
        context,
        key: 'terms',
        icon: Icons.description_outlined,
        title: hasSubscription ? l10n.terms : '🔒 ${l10n.terms}',
        isLocked: !hasSubscription,
        onTap: () {
          if (hasSubscription) {
            Navigator.pushNamed(context, AppRoutes.terms);
          } else {
            _showSubscriptionRequiredDialog(context);
          }
        },
      ),
      _buildPopupMenuItem(
        context,
        key: 'faq',
        icon: Icons.help_outline_rounded,
        title: hasSubscription ? l10n.faq : '🔒 ${l10n.faq}',
        isLocked: !hasSubscription,
        onTap: () {
          if (hasSubscription) {
            Navigator.pushNamed(context, AppRoutes.faq);
          } else {
            _showSubscriptionRequiredDialog(context);
          }
        },
      ),
      _buildPopupMenuItem(
        context,
        key: 'contact',
        icon: Icons.contact_mail_outlined,
        title: hasSubscription ? l10n.contactUs : '🔒 ${l10n.contactUs}',
        isLocked: !hasSubscription,
        onTap: () {
          if (hasSubscription) {
            Navigator.pushNamed(context, AppRoutes.contactUs);
          } else {
            _showSubscriptionRequiredDialog(context);
          }
        },
      ),
      const PopupMenuDivider(),
      _buildPopupMenuItem(
        context,
        key: 'logout',
        icon: Icons.logout_rounded,
        title: hasSubscription ? l10n.logout : '🔒 ${l10n.logout}',
        isLocked: !hasSubscription,
        onTap: () {
          if (hasSubscription) {
            _logoutWithConfirmation(context);
          } else {
            _showSubscriptionRequiredDialog(context);
          }
        },
        isDestructive: true,
      ),
    ];
  }

  PopupMenuItem<String> _buildPopupMenuItem(
      BuildContext context, {
        required String key,
        required IconData icon,
        required String title,
        required bool isLocked,
        required VoidCallback onTap,
        bool isDestructive = false,
      }) {
    final theme = Theme.of(context);
    final color = isDestructive ? Colors.red : theme.primaryColor;

    return PopupMenuItem<String>(
      value: key,
      onTap: onTap,
      enabled: !isLocked,
      child: Row(
        children: [
          Icon(
            icon,
            color: isLocked ? Colors.grey : color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isLocked ? Colors.grey : null,
                fontWeight: isDestructive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isLocked)
            const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  // ============================================================
  // LOCKED OVERLAY
  // ============================================================
  Widget _buildLockedOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Opacity(
          opacity: 0.5,
          child: IgnorePointer(
            ignoring: true,
            child: const _HomeDashboardContent(),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '🔒 Dashboard Locked',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subscribe to unlock all Fundi features and start managing your services.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.rateCards);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        'Subscribe Now',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.subscriptions);
                      },
                      child: const Text('View My Subscriptions'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// NOTIFICATION TILE WIDGET
// ================================================================
class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = notification['is_read'] ?? false;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isRead
            ? theme.dividerColor
            : theme.primaryColor.withOpacity(0.1),
        child: Icon(
          _getIcon(notification['type']),
          color: isRead ? theme.hintColor : theme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        notification['title'] ?? '',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        notification['body'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
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

// ================================================================
// LOCKED DASHBOARD OVERLAY - FIXED OVERFLOW
// ================================================================
class _LockedDashboardOverlay extends StatelessWidget {
  final bool isPending;

  const _LockedDashboardOverlay({
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<SubscriptionProvider>().checkSubscriptionStatus();
        await context.read<SubscriptionProvider>().loadMySubscriptions();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomPadding,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange.shade50 : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isPending ? Colors.orange : Colors.grey)
                          .withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  isPending ? Icons.hourglass_top_rounded : Icons.lock_outline,
                  size: 50,
                  color: isPending ? Colors.orange : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                isPending ? '⏳ Subscription Pending' : '🔒 Dashboard Locked',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPending ? Colors.orange : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                isPending
                    ? 'Your subscription is pending approval.\nPlease wait for admin confirmation.'
                    : 'Subscribe to unlock all Fundi features\nand start managing your services.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Contact Info (if pending)
              if (isPending) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'If approval takes more than 3-5 minutes,\nplease contact support:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      _buildContactRow(context, 'Airtel', '0682131140'),
                      _buildContactRow(context, 'M-Pesa', '074838838'),
                      _buildContactRow(context, 'Mix by Yas', '0673292922'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Features (if not pending)
              if (!isPending) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                          Icons.verified_rounded,
                          'Verified Technician Profile'),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                          Icons.list_alt_rounded,
                          'Manage Service Requests'),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                          Icons.chat_rounded,
                          'Chat with Customers'),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                          Icons.photo_library_rounded,
                          'Showcase Your Portfolio'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              // Action Button
              ElevatedButton(
                onPressed: () {
                  if (isPending) {
                    Navigator.pushNamed(context, AppRoutes.subscriptions);
                  } else {
                    Navigator.pushNamed(context, AppRoutes.rateCards);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending ? Colors.orange : theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  elevation: 4,
                ),
                child: Text(
                  isPending ? 'Check Status' : 'Subscribe Now',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isPending) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.subscriptions);
                  },
                  child: const Text('View My Subscriptions'),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, String name, String number) {
    return InkWell(
      onTap: () => _makePhoneCall(context, number),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              '$name: $number',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _makePhoneCall(BuildContext context, String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to make a call. Please dial manually.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// HOME DASHBOARD CONTENT - REDESIGNED TO FIX OVERFLOW
// ================================================================
class _HomeDashboardContent extends StatelessWidget {
  const _HomeDashboardContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final tech = context.watch<TechnicianProvider>().technician;
    final online = tech?.isOnline ?? false;
    final requests = context.watch<RequestProvider>().requests;
    final pendingRequests = requests.where((r) => r.status == 'pending').length;
    final completedRequests = requests.where((r) => r.status == 'completed')
        .length;

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;

    int gridColumns = 2;
    if (isLargeTablet) gridColumns = 4;
    else if (isTablet) gridColumns = 3;

    final double padding = isTablet ? 24.0 : 16.0;
    final double cardPadding = isTablet ? 24.0 : 16.0;
    final double gap = isTablet ? 16.0 : 12.0;

    return SafeArea(
      bottom: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available height
          final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;
          final availableHeight = constraints.maxHeight - bottomPadding;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: padding,
              right: padding,
              top: padding,
              bottom: bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Card
                Container(
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.primaryColor,
                        theme.primaryColorDark ?? theme.primaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: isTablet ? 36.0 : 30.0,
                        backgroundColor: Colors.white,
                        child: Text(
                          user?.name.isNotEmpty == true
                              ? user!.name[0].toUpperCase()
                              : 'F',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: isTablet ? 28.0 : 24.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.hello}, ${user?.name ?? 'Fundi'}! 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (online) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0, vertical: 2.0),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.wifi_rounded,
                                            color: Colors.white, size: 14.0),
                                        const SizedBox(width: 4),
                                        Text(
                                          l10n.online,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4.0, vertical: 1.0),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Auto',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8.0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (pendingRequests > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0, vertical: 2.0),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$pendingRequests ${l10n.pending}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 28.0,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap + 4),

                // Stats Row - Using Flexible to prevent overflow
                Row(
                  children: [
                    Flexible(
                      child: _buildStatCard(
                        context,
                        icon: Icons.list_alt_rounded,
                        label: l10n.totalRequests,
                        value: requests.length.toString(),
                        color: Colors.blue,
                        isTablet: isTablet,
                        onTap: () => _navigateToTab(context, 2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildStatCard(
                        context,
                        icon: Icons.pending_rounded,
                        label: l10n.pending,
                        value: pendingRequests.toString(),
                        color: Colors.orange,
                        isTablet: isTablet,
                        onTap: () => _navigateToTab(context, 2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildStatCard(
                        context,
                        icon: Icons.check_circle_rounded,
                        label: l10n.completed,
                        value: completedRequests.toString(),
                        color: Colors.green,
                        isTablet: isTablet,
                        onTap: () => _navigateToTab(context, 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: gap + 4),

                // Quick Actions Title
                Text(
                  l10n.quickActions,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                // Quick Action Cards - Using AspectRatio for consistent sizing
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: gridColumns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isTablet ? 1.2 : 1.1,
                  children: [
                    _buildActionCard(
                      context,
                      icon: Icons.article_rounded,
                      label: l10n.blog,
                      color: Colors.blue.shade400,
                      onTap: () => _navigateToTab(context, 1),
                      isTablet: isTablet,
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.list_alt_rounded,
                      label: l10n.requests,
                      color: Colors.orange.shade400,
                      onTap: () => _navigateToTab(context, 2),
                      isTablet: isTablet,
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.chat_bubble_outline_rounded,
                      label: l10n.chat,
                      color: Colors.green.shade400,
                      onTap: () => _navigateToTab(context, 3),
                      isTablet: isTablet,
                    ),
                    _buildActionCard(
                      context,
                      icon: Icons.photo_library_rounded,
                      label: l10n.portfolio,
                      color: Colors.purple.shade400,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.portfolio),
                      isTablet: isTablet,
                    ),
                  ],
                ),
                // Extra bottom space for safety
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    final homeState = context.findAncestorStateOfType<_FundiHomeScreenState>();
    homeState?._navigateToTab(index);
  }

  Widget _buildStatCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
        required Color color,
        required bool isTablet,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 14.0 : 12.0,
          horizontal: isTablet ? 12.0 : 8.0,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isTablet ? 20.0 : 16.0, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: isTablet ? 20.0 : 16.0,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: isTablet ? 11.0 : 10.0,
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
        required bool isTablet,
      }) {
    final theme = Theme.of(context);
    final double iconSize = isTablet ? 36.0 : 32.0;
    final double fontSize = isTablet ? 16.0 : 14.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}