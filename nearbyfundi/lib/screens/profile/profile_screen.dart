import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../l10n/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    String initial = 'U';
    if (user != null && user.name.isNotEmpty) {
      initial = user.name[0].toUpperCase();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.profile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
        child: Column(
          children: [
            // Profile Card
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar with gradient border
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor,
                            theme.primaryColor.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.name ?? l10n.guest,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                        fontSize: 14,
                      ),
                    ),
                    if (user?.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: theme.hintColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user!.phone!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Active',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            _buildActionButton(
              context,
              icon: Icons.edit_outlined,
              label: l10n.editProfile,
              onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
              theme: theme,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.settings_outlined,
              label: l10n.settings,
              onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
              theme: theme,
            ),

            // Extra spacing to push logout button down (replaces Spacer)
            const SizedBox(height: 32),

            // Logout button
            _buildLogoutButton(context, auth, l10n, theme),
            const SizedBox(height: 8),

            // Version info
            Center(
              child: Text(
                'Version 0.0.1',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        required ThemeData theme,
      }) {
    return Container(
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
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 22),
        ),
        title: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: theme.hintColor,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildLogoutButton(
      BuildContext context,
      AuthProvider auth,
      AppLocalizations l10n,
      ThemeData theme,
      ) {
    return Container(
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
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.logout_rounded, color: theme.colorScheme.error, size: 22),
        ),
        title: Text(
          l10n.logout,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: theme.colorScheme.error,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: theme.colorScheme.error.withOpacity(0.5),
        ),
        onTap: () async {
          final confirm = await showConfirmationDialog(
            context,
            l10n.logout,
            l10n.logoutConfirmation,
          );
          if (confirm == true) {
            await auth.logout();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            }
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}