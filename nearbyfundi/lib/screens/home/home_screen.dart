// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/post_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/technician_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/settings_provider.dart';

import '../../models/chat_user.dart';
import '../../l10n/app_localizations.dart';

import 'nearby_screen.dart';
import 'blogs_screen.dart';

import '../requests/my_requests_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';

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

    _screens = const [
      NearbyScreen(),
      BlogsScreen(),
      MyRequestsScreen(),
      ChatListScreen(),
      ProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final settings = context.read<SettingsProvider>();

      _currentLocale = settings.locale;

      context.read<ServiceProvider>().fetchServices(
        locale: _currentLocale,
      );

      _loadNotifications();
      _initializeChat();
    });
  }

  // ================================================================
  // CHAT INITIALIZATION
  // ================================================================

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

  // ================================================================
  // LOAD NOTIFICATIONS
  // ================================================================

  Future<void> _loadNotifications() async {
    try {
      await context
          .read<NotificationProvider>()
          .loadNotifications();
    } catch (e) {
      debugPrint(
        'Notification loading error: $e',
      );
    }
  }

  // ================================================================
  // REFRESH CURRENT SCREEN
  // ================================================================

  Future<void> _refreshCurrentScreen() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      switch (_currentIndex) {
        case 0:
          await context
              .read<TechnicianProvider>()
              .refreshLastSearch();
          break;

        case 1:
          await context
              .read<PostProvider>()
              .fetchPosts(refresh: true);
          break;

        case 2:
          await context
              .read<RequestProvider>()
              .loadMyRequests();
          break;

        case 3:
          await context
              .read<ChatProvider>()
              .refreshConversations();
          break;

        case 4:
          await context
              .read<AuthProvider>()
              .loadUser();
          break;
      }

      await context
          .read<NotificationProvider>()
          .loadNotifications();

      final settings =
      context.read<SettingsProvider>();

      if (_currentLocale != settings.locale) {
        _currentLocale = settings.locale;

        await context
            .read<ServiceProvider>()
            .fetchServices(
          locale: _currentLocale,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(l10n.refreshed),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF006B5E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Refresh error: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.refreshFailed,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
          Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ================================================================
  // PARTNERSHIPS
  // ================================================================

  void _showPartnershipsComingSoon() {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.handshake_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Partnerships Coming Soon! 🚀',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ================================================================
  // NOTIFICATION SHEET
  // ================================================================

  void _showNotifications(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.50,
          maxChildSize: 0.96,
          expand: false,
          builder: (
              sheetContext,
              scrollController,
              ) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // =================================================
                  // HANDLE
                  // =================================================

                  const SizedBox(height: 10),

                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme
                          .colorScheme
                          .onSurface
                          .withOpacity(0.18),
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                  ),

                  // =================================================
                  // HEADER
                  // =================================================

                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      20,
                      18,
                      12,
                      12,
                    ),
                    child: Consumer<
                        NotificationProvider>(
                      builder: (
                          context,
                          provider,
                          child,
                          ) {
                        final unread =
                            provider.unreadCount;

                        return Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: theme
                                    .primaryColor
                                    .withOpacity(0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons
                                    .notifications_rounded,
                                color:
                                theme.primaryColor,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    l10n.notifications,
                                    style: theme
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                      fontWeight:
                                      FontWeight
                                          .w700,
                                    ),
                                  ),
                                  if (unread > 0)
                                    Text(
                                      '$unread unread notification${unread == 1 ? '' : 's'}',
                                      style: theme
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                        color: theme
                                            .primaryColor,
                                        fontWeight:
                                        FontWeight
                                            .w500,
                                      ),
                                    )
                                  else
                                    Text(
                                      'You are all caught up',
                                      style: theme
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                        color: Colors
                                            .grey
                                            .shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            if (unread > 0)
                              TextButton(
                                onPressed: () async {
                                  await provider
                                      .markAllAsRead();
                                },
                                child: Text(
                                  l10n.markAllAsRead,
                                  style: TextStyle(
                                    color:
                                    theme.primaryColor,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  Divider(
                    height: 1,
                    color: theme.dividerColor
                        .withOpacity(0.4),
                  ),

                  // =================================================
                  // LIST
                  // =================================================

                  Expanded(
                    child: Consumer<
                        NotificationProvider>(
                      builder: (
                          context,
                          provider,
                          child,
                          ) {
                        if (provider.isLoading) {
                          return Center(
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 30,
                                  height: 30,
                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: theme
                                        .primaryColor,
                                  ),
                                ),
                                const SizedBox(
                                  height: 14,
                                ),
                                Text(
                                  'Loading notifications...',
                                  style: theme
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    color: Colors
                                        .grey
                                        .shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (provider.notifications
                            .isEmpty) {
                          return _EmptyNotifications(
                            theme: theme,
                            title:
                            l10n.noNotificationsYet,
                          );
                        }

                        return RefreshIndicator(
                          color:
                          theme.primaryColor,
                          onRefresh: provider
                              .loadNotifications,
                          child:
                          ListView.builder(
                            controller:
                            scrollController,
                            padding:
                            const EdgeInsets
                                .fromLTRB(
                              16,
                              14,
                              16,
                              30,
                            ),
                            itemCount: provider
                                .notifications.length,
                            itemBuilder:
                                (context, index) {
                              final notification =
                              provider
                                  .notifications[
                              index];

                              return Padding(
                                padding:
                                const EdgeInsets
                                    .only(
                                  bottom: 10,
                                ),
                                child:
                                _NotificationTile(
                                  notification:
                                  notification,
                                  locale:
                                  _currentLocale,
                                  onTap: () async {
                                    final id =
                                    notification[
                                    'id'];

                                    if (id != null) {
                                      await provider
                                          .markAsRead(
                                        id.toString(),
                                      );
                                    }

                                    if (!mounted) {
                                      return;
                                    }

                                    Navigator.pop(
                                      ctx,
                                    );

                                    _handleNotificationNavigation(
                                      notification,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
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

  // ================================================================
  // NOTIFICATION NAVIGATION
  // ================================================================

  void _handleNotificationNavigation(
      Map<String, dynamic> notification,
      ) {
    final type =
        notification['type']?.toString() ?? '';

    if (type == 'chat_message') {
      setState(() {
        _currentIndex = 3;
      });
      return;
    }

    if (type == 'new_request' ||
        type == 'request_accepted' ||
        type == 'request_rejected' ||
        type == 'request_in_progress' ||
        type == 'request_completed') {
      setState(() {
        _currentIndex = 2;
      });
      return;
    }
  }

  // ================================================================
  // DRAWER
  // ================================================================

  Widget _buildDrawer(
      BuildContext context,
      ThemeData theme,
      bool isDark,
      ) {
    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // =======================================================
            // DRAWER HEADER
            // =======================================================

            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF006B5E),
                    Color(0xFF004D40),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withOpacity(0.15),
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons
                              .handyman_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      const Spacer(),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'NearbyFundi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Find trusted technicians near you',
                    style: TextStyle(
                      color: Colors.white
                          .withOpacity(0.78),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // =======================================================
            // MENU
            // =======================================================

            Expanded(
              child: ListView(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                children: [
                  _DrawerItem(
                    icon: Icons
                        .handshake_rounded,
                    title: 'Partnerships',
                    color:
                    theme.primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      _showPartnershipsComingSoon();
                    },
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      'MORE',
                      style: theme
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                        color: Colors.grey.shade500,
                        fontWeight:
                        FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  _DrawerItem(
                    icon: Icons.more_horiz_rounded,
                    title: 'Others',
                    color: Colors.grey,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // =======================================================
            // FOOTER
            // =======================================================

            Padding(
              padding:
              const EdgeInsets.all(18),
              child: Text(
                'NearbyFundi',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final l10n =
    AppLocalizations.of(context)!;

    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    final settings =
    context.watch<SettingsProvider>();

    if (_currentLocale != settings.locale) {
      _currentLocale = settings.locale;

      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        if (!mounted) return;

        context
            .read<ServiceProvider>()
            .fetchServices(
          locale: _currentLocale,
        );
      });
    }

    return Scaffold(
      // ============================================================
      // LEFT DRAWER
      // ============================================================

      drawer: _buildDrawer(
        context,
        theme,
        isDark,
      ),

      // ============================================================
      // RIGHT DRAWER
      // ============================================================

      endDrawer: Drawer(
        backgroundColor:
        theme.colorScheme.surface,
        child: const SizedBox.shrink(),
      ),

      // ============================================================
      // APP BAR
      // ============================================================

      appBar: AppBar(
        backgroundColor:
        const Color(0xFF006B5E),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,

        iconTheme:
        const IconThemeData(
          color: Colors.white,
        ),

        titleSpacing: 8,

        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(0.14),
                borderRadius:
                BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.handyman_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              l10n.appTitle,
              style: const TextStyle(
                fontSize: 19,
                fontWeight:
                FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),

        actions: [
          // ========================================================
          // REFRESH
          // ========================================================

          IconButton(
            onPressed: _refreshCurrentScreen,
            tooltip: l10n.refresh,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 25,
            ),
          ),

          // ========================================================
          // NOTIFICATIONS
          // ========================================================

          Consumer<NotificationProvider>(
            builder: (
                context,
                notificationProvider,
                child,
                ) {
              final unreadCount =
                  notificationProvider
                      .unreadCount;

              return IconButton(
                onPressed: () =>
                    _showNotifications(context),
                tooltip: l10n.notifications,
                icon: Stack(
                  clipBehavior:
                  Clip.none,
                  children: [
                    const Icon(
                      Icons
                          .notifications_outlined,
                      size: 26,
                    ),

                    if (unreadCount > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          constraints:
                          const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 4,
                          ),
                          decoration:
                          const BoxDecoration(
                            color: Colors.red,
                            shape:
                            BoxShape.circle,
                          ),
                          alignment:
                          Alignment.center,
                          child: Text(
                            unreadCount > 9
                                ? '9+'
                                : '$unreadCount',
                            style:
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // ========================================================
          // MORE
          // ========================================================

          Builder(
            builder: (ctx) {
              return IconButton(
                onPressed: () {
                  Scaffold.of(ctx)
                      .openEndDrawer();
                },
                tooltip: 'More Options',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 26,
                ),
              );
            },
          ),

          const SizedBox(width: 4),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================

      body: RefreshIndicator(
        onRefresh: _refreshCurrentScreen,
        color: theme.primaryColor,
        backgroundColor:
        theme.colorScheme.surface,
        child: _screens[_currentIndex],
      ),

      // ============================================================
      // BOTTOM NAVIGATION
      // ============================================================

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              width: 0.6,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(
                isDark ? 0.25 : 0.07,
              ),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Consumer<ChatProvider>(
            builder: (
                context,
                chatProvider,
                child,
                ) {
              return BottomNavigationBar(
                currentIndex:
                _currentIndex,

                onTap: (index) {
                  if (_currentIndex ==
                      index) {
                    return;
                  }

                  setState(() {
                    _currentIndex =
                        index;
                  });
                },

                type:
                BottomNavigationBarType
                    .fixed,

                backgroundColor:
                theme.colorScheme.surface,

                elevation: 0,

                selectedItemColor:
                theme.primaryColor,

                unselectedItemColor:
                isDark
                    ? Colors.grey.shade500
                    : Colors.grey.shade600,

                selectedFontSize: 11,

                unselectedFontSize: 11,

                selectedLabelStyle:
                const TextStyle(
                  fontWeight:
                  FontWeight.w600,
                ),

                items: [
                  // =================================================
                  // NEARBY
                  // =================================================

                  BottomNavigationBarItem(
                    icon: const Icon(
                      Icons
                          .home_outlined,
                    ),
                    activeIcon:
                    const Icon(
                      Icons.home_rounded,
                    ),
                    label: l10n.nearby,
                  ),

                  // =================================================
                  // BLOG
                  // =================================================

                  BottomNavigationBarItem(
                    icon: const Icon(
                      Icons
                          .article_outlined,
                    ),
                    activeIcon:
                    const Icon(
                      Icons
                          .article_rounded,
                    ),
                    label: l10n.blog,
                  ),

                  // =================================================
                  // REQUESTS
                  // =================================================

                  BottomNavigationBarItem(
                    icon: const Icon(
                      Icons
                          .list_alt_outlined,
                    ),
                    activeIcon:
                    const Icon(
                      Icons
                          .list_alt_rounded,
                    ),
                    label: l10n.requests,
                  ),

                  // =================================================
                  // CHAT
                  // =================================================

                  BottomNavigationBarItem(
                    icon: _ChatIcon(
                      unread:
                      chatProvider
                          .totalUnread,
                      active: false,
                    ),
                    activeIcon: _ChatIcon(
                      unread:
                      chatProvider
                          .totalUnread,
                      active: true,
                    ),
                    label: l10n.chat,
                  ),

                  // =================================================
                  // PROFILE
                  // =================================================

                  BottomNavigationBarItem(
                    icon: const Icon(
                      Icons
                          .person_outline,
                    ),
                    activeIcon:
                    const Icon(
                      Icons.person_rounded,
                    ),
                    label: l10n.profile,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// DRAWER ITEM
// ==================================================================

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Container(
      margin:
      const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: ListTile(
        onTap: onTap,
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(14),
        ),
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 2,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius:
            BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: theme
              .textTheme
              .bodyLarge
              ?.copyWith(
            fontWeight:
            FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons
              .chevron_right_rounded,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

// ==================================================================
// CHAT ICON
// ==================================================================

class _ChatIcon extends StatelessWidget {
  final int unread;
  final bool active;

  const _ChatIcon({
    required this.unread,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          active
              ? Icons
              .chat_bubble_rounded
              : Icons
              .chat_bubble_outline_rounded,
        ),

        if (unread > 0)
          Positioned(
            right: -8,
            top: -7,
            child: Container(
              constraints:
              const BoxConstraints(
                minWidth: 15,
                minHeight: 15,
              ),
              padding:
              const EdgeInsets.symmetric(
                horizontal: 3,
              ),
              decoration:
              const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              alignment:
              Alignment.center,
              child: Text(
                unread > 9
                    ? '9+'
                    : '$unread',
                style:
                const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==================================================================
// EMPTY NOTIFICATIONS
// ==================================================================

class _EmptyNotifications
    extends StatelessWidget {
  final ThemeData theme;
  final String title;

  const _EmptyNotifications({
    required this.theme,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: theme
                    .primaryColor
                    .withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .notifications_none_rounded,
                size: 46,
                color:
                theme.primaryColor,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              title,
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'We will notify you when there is something new.',
              textAlign: TextAlign.center,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color:
                Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// NOTIFICATION TILE
// ==================================================================

class _NotificationTile
    extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final String locale;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.locale,
  });

  // ================================================================
  // TYPE LABEL
  // ================================================================

  String _getTypeLabel(
      String? type,
      ) {
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

  // ================================================================
  // ICON
  // ================================================================

  IconData _getIcon(
      String? type,
      ) {
    switch (type) {
      case 'chat_message':
        return Icons
            .chat_bubble_outline_rounded;

      case 'new_request':
        return Icons
            .request_page_outlined;

      case 'request_accepted':
        return Icons
            .check_circle_outline_rounded;

      case 'request_rejected':
        return Icons
            .cancel_outlined;

      case 'request_in_progress':
        return Icons
            .hourglass_top_rounded;

      case 'request_completed':
        return Icons
            .task_alt_rounded;

      default:
        return Icons
            .notifications_outlined;
    }
  }

  // ================================================================
  // ICON COLOR
  // ================================================================

  Color _getIconColor(
      String? type,
      ThemeData theme,
      ) {
    switch (type) {
      case 'request_accepted':
      case 'request_completed':
        return Colors.green.shade600;

      case 'request_rejected':
        return Colors.red.shade600;

      case 'request_in_progress':
        return Colors.orange.shade700;

      case 'chat_message':
        return Colors.blue.shade600;

      case 'new_request':
        return theme.primaryColor;

      default:
        return theme.primaryColor;
    }
  }

  // ================================================================
  // FORMAT DATE TIME
  // ================================================================

  String _formatCreatedAt(
      dynamic value,
      ) {
    if (value == null ||
        value.toString().trim().isEmpty) {
      return '';
    }

    try {
      DateTime dateTime =
      DateTime.parse(
        value.toString(),
      );

      if (dateTime.isUtc) {
        dateTime = dateTime.toLocal();
      }

      final day = dateTime.day
          .toString()
          .padLeft(2, '0');

      final month = dateTime.month
          .toString()
          .padLeft(2, '0');

      final year =
      dateTime.year.toString();

      final hour12 =
      dateTime.hour % 12 == 0
          ? 12
          : dateTime.hour % 12;

      final hour = hour12
          .toString()
          .padLeft(2, '0');

      final minute = dateTime.minute
          .toString()
          .padLeft(2, '0');

      final period =
      dateTime.hour >= 12
          ? 'PM'
          : 'AM';

      return '$day/$month/$year • $hour:$minute $period';
    } catch (e) {
      debugPrint(
        'Invalid notification created_at: $value',
      );

      return value.toString();
    }
  }

  // ================================================================
  // RELATIVE TIME
  // ================================================================

  String _getRelativeTime(
      dynamic value,
      ) {
    if (value == null) {
      return '';
    }

    try {
      DateTime dateTime =
      DateTime.parse(
        value.toString(),
      );

      if (dateTime.isUtc) {
        dateTime = dateTime.toLocal();
      }

      final now = DateTime.now();

      final difference =
      now.difference(dateTime);

      if (difference.inSeconds < 30) {
        return 'Just now';
      }

      if (difference.inMinutes < 60) {
        final minutes =
            difference.inMinutes;

        return '$minutes min ago';
      }

      if (difference.inHours < 24) {
        final hours =
            difference.inHours;

        return '$hours hr ago';
      }

      if (difference.inDays == 1) {
        return 'Yesterday';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      }

      return _formatCreatedAt(value);
    } catch (_) {
      return '';
    }
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final isReadValue =
    notification['is_read'];

    final isRead =
        isReadValue == true ||
            isReadValue == 1 ||
            isReadValue == '1';

    final title =
        notification['title']
            ?.toString() ??
            'Notification';

    final body =
        notification['body']
            ?.toString() ??
            '';

    final type =
        notification['type']
            ?.toString() ??
            '';

    final createdAt =
    notification['created_at'];

    final exactDate =
    _formatCreatedAt(
      createdAt,
    );

    final relativeTime =
    _getRelativeTime(
      createdAt,
    );

    final iconColor =
    _getIconColor(
      type,
      theme,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(16),
        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 200,
          ),
          padding:
          const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isRead
                ? theme
                .colorScheme
                .surface
                : theme
                .primaryColor
                .withOpacity(0.055),
            borderRadius:
            BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? theme.dividerColor
                  .withOpacity(0.30)
                  : theme.primaryColor
                  .withOpacity(0.16),
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // =====================================================
              // ICON
              // =====================================================

              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
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
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // =============================================
                    // TITLE + UNREAD DOT
                    // =============================================

                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.25,
                              fontWeight: isRead
                                  ? FontWeight
                                  .w500
                                  : FontWeight
                                  .w700,
                            ),
                          ),
                        ),

                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin:
                            const EdgeInsets
                                .only(
                              left: 8,
                              top: 5,
                            ),
                            decoration:
                            BoxDecoration(
                              color: theme
                                  .primaryColor,
                              shape:
                              BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    // =============================================
                    // BODY
                    // =============================================

                    if (body.isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        body,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          height: 1.35,
                          color: theme
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(
                            0.72,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 8,
                    ),

                    // =============================================
                    // TYPE + TIME
                    // =============================================

                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment:
                      WrapCrossAlignment
                          .center,
                      children: [
                        if (type.isNotEmpty)
                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration:
                            BoxDecoration(
                              color: iconColor
                                  .withOpacity(
                                0.08,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                7,
                              ),
                            ),
                            child: Text(
                              _getTypeLabel(
                                type,
                              ),
                              style: TextStyle(
                                color:
                                iconColor,
                                fontSize: 10,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                          ),

                        if (relativeTime
                            .isNotEmpty)
                          Row(
                            mainAxisSize:
                            MainAxisSize
                                .min,
                            children: [
                              Icon(
                                Icons
                                    .access_time_rounded,
                                size: 13,
                                color: Colors
                                    .grey
                                    .shade500,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Text(
                                relativeTime,
                                style: TextStyle(
                                  color: Colors
                                      .grey
                                      .shade600,
                                  fontSize: 10.5,
                                  fontWeight:
                                  FontWeight
                                      .w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // =============================================
                    // EXACT DATE/TIME
                    // =============================================

                    if (exactDate.isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons
                                .calendar_today_outlined,
                            size: 11,
                            color: Colors
                                .grey
                                .shade500,
                          ),
                          const SizedBox(
                            width: 4,
                          ),
                          Flexible(
                            child: Text(
                              exactDate,
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style: TextStyle(
                                color: Colors
                                    .grey
                                    .shade500,
                                fontSize: 9.5,
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
    );
  }
}