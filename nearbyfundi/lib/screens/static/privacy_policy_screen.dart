import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/static_page_provider.dart';
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
    // Assuming StaticPageProvider has a method to load privacy policy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaticPageProvider>().loadPrivacyPolicy();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaticPageProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy', style: TextStyle(color: theme.colorScheme.onPrimary)),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
          ? Center(child: Text(provider.error!))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          provider.privacyPolicy?.content ?? l10n.noContent,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
        ),
      ),
    );
  }
}