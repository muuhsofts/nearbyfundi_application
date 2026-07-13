import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/static_page_provider.dart';
import '../../l10n/app_localizations.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaticPageProvider>().loadTerms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaticPageProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.terms,
          style: TextStyle(color: theme.colorScheme.onPrimary),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Container(
        color: theme.colorScheme.surface,
        child: provider.isLoading
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : provider.error != null
            ? _buildErrorState(provider, l10n, theme)
            : SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.gavel_rounded,
                    size: 40,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.terms,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const Divider(height: 32, thickness: 1.5),
                  Text(
                    provider.terms?.content ?? l10n.noContent,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      height: 1.8,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(StaticPageProvider provider, AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 80, color: theme.hintColor),
            const SizedBox(height: 20),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => provider.loadTerms(),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}