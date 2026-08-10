// screens/profile/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/service_provider.dart';
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
    final serviceProvider = context.watch<ServiceProvider>();
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
            // ─── Push Notifications ──────────────────────────────────────
            SwitchListTile(
              title: Text(l10n.pushNotifications, style: theme.textTheme.titleMedium),
              subtitle: Text(l10n.receiveAlerts, style: theme.textTheme.bodySmall),
              value: settings.notificationsEnabled,
              onChanged: (val) => settings.updateNotificationStatus(val),
              activeColor: theme.primaryColor,
            ),
            const Divider(),

            // ─── Language Toggle ────────────────────────────────────────
            _LanguageToggle(
              currentLocale: settings.locale,
              onChanged: (val) async {
                if (val != null) {
                  await settings.updateLocale(val);
                  await auth.updateLocale(val);
                  // Refresh services with new locale
                  await serviceProvider.fetchServices(locale: val);
                }
              },
            ),
            const Divider(),

            // ─── Theme Toggle ───────────────────────────────────────────
            _ThemeToggle(
              currentThemeMode: themeProvider.themeMode,
              onChanged: (mode) {
                if (mode != null) {
                  themeProvider.setThemeMode(mode);
                }
              },
            ),
            const Divider(),

            // ─── About ──────────────────────────────────────────────────
            ListTile(
              title: Text(l10n.aboutUs, style: theme.textTheme.titleMedium),
              onTap: () => Navigator.pushNamed(context, AppRoutes.about),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
            ),

            // ─── FAQ ─────────────────────────────────────────────────────
            ListTile(
              title: Text(l10n.faq, style: theme.textTheme.titleMedium),
              onTap: () => Navigator.pushNamed(context, AppRoutes.faq),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
            ),

            // ─── Terms ──────────────────────────────────────────────────
            ListTile(
              title: Text(l10n.terms, style: theme.textTheme.titleMedium),
              onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
            ),

            // ─── Contact Us ─────────────────────────────────────────────
            ListTile(
              title: Text(l10n.contactUs, style: theme.textTheme.titleMedium),
              onTap: () => Navigator.pushNamed(context, AppRoutes.contactUs),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
            ),
            const Divider(),

            // ─── Delete Account ─────────────────────────────────────────
            ListTile(
              title: Text(
                l10n.deleteAccount,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              onTap: () => _confirmLogout(context, auth, l10n, theme),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),

            // ─── Version ────────────────────────────────────────────────
            Center(
              child: Text(
                '${l10n.version} ${AppConfig.appVersion}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(
      BuildContext context,
      AuthProvider auth,
      AppLocalizations l10n,
      ThemeData theme,
      ) async {
    final confirm = await showConfirmationDialog(
      context,
      l10n.deleteAccount,
      l10n.deleteAccountConfirmation,
    );
    if (confirm != true) return;
    await auth.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
          (_) => false,
    );
  }
}

// ─── LANGUAGE TOGGLE WIDGET ──────────────────────────────────────
class _LanguageToggle extends StatelessWidget {
  final String currentLocale;
  final ValueChanged<String?> onChanged;

  const _LanguageToggle({
    required this.currentLocale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnglish = currentLocale == 'en';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Language',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _LanguageOption(
                  label: 'English 🇬🇧',
                  isSelected: isEnglish,
                  onTap: () => onChanged('en'),
                ),
              ),
              Expanded(
                child: _LanguageOption(
                  label: 'Kiswahili 🇹🇿',
                  isSelected: !isEnglish,
                  onTap: () => onChanged('sw'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── LANGUAGE OPTION ─────────────────────────────────────────────
class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.primaryColor,
                size: 16,
              ),
            if (isSelected) const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? theme.primaryColor
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── THEME TOGGLE WIDGET ─────────────────────────────────────────
class _ThemeToggle extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode?> onChanged;

  const _ThemeToggle({
    required this.currentThemeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Theme',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  label: 'Light ☀️',
                  isSelected: currentThemeMode == ThemeMode.light,
                  onTap: () => onChanged(ThemeMode.light),
                ),
              ),
              Expanded(
                child: _ThemeOption(
                  label: 'Dark 🌙',
                  isSelected: currentThemeMode == ThemeMode.dark,
                  onTap: () => onChanged(ThemeMode.dark),
                ),
              ),
              Expanded(
                child: _ThemeOption(
                  label: 'System ⚙️',
                  isSelected: currentThemeMode == ThemeMode.system,
                  onTap: () => onChanged(ThemeMode.system),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── THEME OPTION ────────────────────────────────────────────────
class _ThemeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.primaryColor,
                size: 16,
              ),
            if (isSelected) const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? theme.primaryColor
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}