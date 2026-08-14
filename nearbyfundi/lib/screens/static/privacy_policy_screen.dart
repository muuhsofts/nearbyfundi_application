// screens/profile/privacy_policy_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/static_page_provider.dart';
import '../../providers/settings_provider.dart';
import '../../l10n/app_localizations.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final settings = context.read<SettingsProvider>();
    final locale = settings.locale; // e.g., 'en' or 'sw'
    await context.read<StaticPageProvider>().loadPrivacyPolicy(locale: locale);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaticPageProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.privacyPolicy ?? 'Privacy Policy',
          style: TextStyle(color: theme.colorScheme.onPrimary),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
            tooltip: l10n.refresh ?? 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: theme.primaryColor,
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: theme.hintColor,
              ),
              const SizedBox(height: 16),
              Text(
                provider.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retry ?? 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Text(
            provider.privacyPolicy?.content ?? l10n.noContent,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
          ),
        ),
      ),
    );
  }
}