import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../models/chat_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/technician_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/fcm_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/notification_bell_icon.dart';
import '../../l10n/app_localizations.dart';

// Import screens
import 'fundi_posts_screen.dart';
import 'fundi_requests_screen.dart';
import 'fundi_portfolio_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_screen.dart';
import 'profile/fundi_profile_screen.dart';

class FundiHomeScreen extends StatefulWidget {
  const FundiHomeScreen({super.key});

  @override
  State<FundiHomeScreen> createState() => _FundiHomeScreenState();
}

class _FundiHomeScreenState extends State<FundiHomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const _HomeDashboardContent(),
      const FundiPostsScreen(),
      const FundiRequestsScreen(),
      const ChatListScreen(),
      const FundiProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TechnicianProvider>().fetchMyProfile();
      context.read<RequestProvider>().loadMyRequests();
      _initializeChat();
      _loadNotifications();
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

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

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
                            final notification = notificationProvider.notifications[index];
                            return _NotificationTile(
                              notification: notification,
                              onTap: () {
                                notificationProvider.markAsRead(notification['id']);
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

  void _showQuickAccessMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuTile(
              context,
              icon: Icons.settings_outlined,
              title: l10n.settings,
              onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
            ),
            _buildMenuTile(
              context,
              icon: Icons.photo_library_outlined,
              title: l10n.portfolio,
              onTap: () => Navigator.pushNamed(context, AppRoutes.portfolio),
            ),
            _buildMenuTile(
              context,
              icon: Icons.info_outline_rounded,
              title: l10n.aboutUs,
              onTap: () => Navigator.pushNamed(context, AppRoutes.about),
            ),
            _buildMenuTile(
              context,
              icon: Icons.description_outlined,
              title: l10n.terms,
              onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
            ),
            _buildMenuTile(
              context,
              icon: Icons.help_outline_rounded,
              title: l10n.faq,
              onTap: () => Navigator.pushNamed(context, AppRoutes.faq),
            ),
            _buildMenuTile(
              context,
              icon: Icons.contact_mail_outlined,
              title: l10n.contactUs,
              onTap: () => Navigator.pushNamed(context, AppRoutes.contactUs),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context,
      {required IconData icon, required String title, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.primaryColor, size: 24),
      title: Text(title, style: theme.textTheme.titleMedium),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

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
            onTap: () => _showNotifications(context),
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 26),
            onPressed: () => _showComingSoon(context, l10n.aiAssistant),
            tooltip: '${l10n.aiAssistant} (${l10n.comingSoon})',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onOpened: () => _showQuickAccessMenu(context),
            tooltip: l10n.more,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'portfolio',
                child: Row(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Portfolio'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _logoutWithConfirmation(context);
              } else if (value == 'settings') {
                Navigator.pushNamed(context, AppRoutes.settings);
              } else if (value == 'portfolio') {
                Navigator.pushNamed(context, AppRoutes.portfolio);
              }
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
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
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: theme.primaryColor,
              unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              backgroundColor: theme.cardColor,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home_rounded),
                  label: l10n.home,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.article_outlined),
                  activeIcon: const Icon(Icons.article_rounded),
                  label: l10n.blog,
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      const Icon(Icons.list_alt_outlined),
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
                      const Icon(Icons.list_alt_rounded),
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
// Notification Tile Widget
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
    final l10n = AppLocalizations.of(context)!;

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
        notification['title'] ?? l10n.notification,
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
      default:
        return Icons.notifications_outlined;
    }
  }
}

// ================================================================
// Home Dashboard Content
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;

    int gridColumns = 2;
    if (isLargeTablet) gridColumns = 4;
    else if (isTablet) gridColumns = 3;

    final double padding = isTablet ? 24.0 : 16.0;
    final double cardPadding = isTablet ? 24.0 : 16.0;
    final double gap = isTablet ? 16.0 : 12.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Card
          Container(
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.primaryColorDark ?? theme.primaryColor],
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
                    user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'F',
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
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (online) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.wifi_rounded, color: Colors.white, size: 14.0),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
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

          // Stats Row
          Row(
            children: [
              _buildStatCard(
                context,
                icon: Icons.list_alt_rounded,
                label: l10n.totalRequests,
                value: requests.length.toString(),
                color: Colors.blue,
                isTablet: isTablet,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                context,
                icon: Icons.pending_rounded,
                label: l10n.pending,
                value: pendingRequests.toString(),
                color: Colors.orange,
                isTablet: isTablet,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                context,
                icon: Icons.check_circle_rounded,
                label: l10n.completed,
                value: requests.where((r) => r.status == 'completed').length.toString(),
                color: Colors.green,
                isTablet: isTablet,
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

          // Quick Action Cards
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
          const SizedBox(height: 16),
        ],
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
      }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isTablet ? 22.0 : 18.0, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: isTablet ? 22.0 : 18.0,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: isTablet ? 12.0 : 11.0,
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
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