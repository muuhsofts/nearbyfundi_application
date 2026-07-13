import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/app_config.dart';
import '../../config/app_routes.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings, style: TextStyle(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SwitchListTile(
              title: Text(l10n.pushNotifications, style: theme.textTheme.titleMedium),
              subtitle: Text(l10n.receiveAlerts, style: theme.textTheme.bodySmall),
              value: settings.notificationsEnabled,
              onChanged: (val) => settings.updateNotificationStatus(val),
              activeColor: theme.primaryColor,
            ),
            const Divider(),
            ListTile(
              title: Text(l10n.language, style: theme.textTheme.titleMedium),
              trailing: DropdownButton<String>(
                value: settings.locale,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English 🇬🇧')),
                  DropdownMenuItem(value: 'sw', child: Text('Kiswahili 🇹🇿')),
                ],
                onChanged: (val) async {
                  if (val != null) {
                    await settings.updateLocale(val);
                    await auth.updateLocale(val);
                  }
                },
                style: theme.textTheme.bodyMedium,
              ),
            ),
            ListTile(
              title: const Text('Theme'),
              trailing: DropdownButton<ThemeMode>(
                value: themeProvider.themeMode,
                items: const [
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light ☀️')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark 🌙')),
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System ⚙️')),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    themeProvider.setThemeMode(mode);
                  }
                },
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const Divider(),
            ListTile(
              title: Text(l10n.aboutUs, style: theme.textTheme.titleMedium),
              onTap: () => Navigator.pushNamed(context, AppRoutes.about),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
            ),
            ListTile(
              title: Text(l10n.faq, style: theme.textTheme.titleMedium),
              onTap: () => Navigator.pushNamed(context, AppRoutes.faq),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
            ),
            ListTile(
              title: Text(l10n.terms, style: theme.textTheme.titleMedium),
              onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
            ),
            ListTile(
              title: Text(l10n.contactUs, style: theme.textTheme.titleMedium),
              onTap: () => Navigator.pushNamed(context, AppRoutes.contactUs),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
            ),
            const Divider(),
            ListTile(
              title: Text(l10n.deleteAccount, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
              onTap: () => _confirmLogout(context, auth, l10n, theme),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${l10n.version} ${AppConfig.appVersion}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AuthProvider auth, AppLocalizations l10n, ThemeData theme) async {
    final confirm = await showConfirmationDialog(
      context,
      l10n.deleteAccount,
      l10n.deleteAccountConfirmation,
    );
    if (confirm != true) return;
    await auth.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }
}