import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../../config/app_theme.dart';
import '../../config/app_routes.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_localizations.dart';

class MySubscriptionsScreen extends StatefulWidget {
  const MySubscriptionsScreen({super.key});

  @override
  State<MySubscriptionsScreen> createState() => _MySubscriptionsScreenState();
}

class _MySubscriptionsScreenState extends State<MySubscriptionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SubscriptionProvider>();
      provider.loadMySubscriptions();
      provider.loadMyInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final provider = context.watch<SubscriptionProvider>();
    final isDownloading = provider.downloadProgress != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mySubscriptions),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              provider.loadMySubscriptions();
              provider.loadMyInvoices();
            },
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await provider.loadMySubscriptions();
          await provider.loadMyInvoices();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(context, provider, l10n),
              const SizedBox(height: 24),

              if (provider.hasActiveSubscription)
                _buildActiveSubscription(context, provider, l10n),

              Text(
                l10n.subscriptionHistory,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (provider.subscriptions.isEmpty)
                _buildEmptyState(context, l10n)
              else
                ...provider.subscriptions.map((sub) => _buildSubscriptionItem(context, sub, l10n)),

              const SizedBox(height: 24),

              Text(
                'Invoices',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (provider.invoices.isEmpty)
                _buildEmptyInvoices(context, l10n)
              else
                ...provider.invoices.map((invoice) => _buildInvoiceItem(context, invoice, provider, l10n)),

              const SizedBox(height: 32),

              if (provider.isLocked || provider.isPending)
                CustomButton(
                  text: l10n.subscribeNow,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.rateCards),
                ),

              if (isDownloading)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            provider.downloadProgress ?? 'Downloading...',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================
  Widget _buildStatusCard(BuildContext context, SubscriptionProvider provider, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isActive = provider.hasActiveSubscription;
    final daysLeft = provider.daysRemaining;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isActive) {
      statusColor = Colors.green;
      statusText = l10n.subscriptionActive;
      statusIcon = Icons.check_circle_rounded;
    } else if (provider.isPending) {
      statusColor = Colors.orange;
      statusText = l10n.subscriptionPending;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (provider.isLocked) {
      statusColor = Colors.red;
      statusText = l10n.subscriptionExpired;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = Colors.grey;
      statusText = l10n.subscriptionInactive;
      statusIcon = Icons.remove_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(statusIcon, color: statusColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.subscriptionStatus, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                Text(statusText, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: statusColor)),
                if (isActive && daysLeft != null)
                  Text(l10n.daysRemaining(daysLeft), style: theme.textTheme.bodyMedium?.copyWith(
                    color: daysLeft < 7 ? Colors.orange : Colors.green,
                  )),
                if (provider.expiryDate != null && isActive)
                  Text(l10n.expiresOn(provider.expiryDate!), style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIVE SUBSCRIPTION
  // ============================================================
  Widget _buildActiveSubscription(BuildContext context, SubscriptionProvider provider, AppLocalizations l10n) {
    final theme = Theme.of(context);

    // ✅ FIXED: Use firstWhere with null check instead of empty()
    Subscription? activeSub;
    try {
      activeSub = provider.subscriptions.firstWhere((s) => s.isActive);
    } catch (e) {
      // No active subscription found
      return const SizedBox.shrink();
    }

    if (activeSub == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Colors.green),
              const SizedBox(width: 8),
              Text(l10n.activePlan, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Text(activeSub.rateCard?.name ?? 'Unknown Plan', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(activeSub.rateCard?.formattedPrice ?? '', style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColor)),
          if (activeSub.expiryDate != null)
            Text(l10n.validUntil(activeSub.expiryDate!), style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }

  // ============================================================
  // SUBSCRIPTION ITEM
  // ============================================================
  Widget _buildSubscriptionItem(BuildContext context, Subscription sub, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isActive = sub.isActive;
    final isExpired = sub.isExpired;

    Color statusColor;
    String statusText;

    if (isActive) {
      statusColor = Colors.green;
      statusText = l10n.subscriptionActive;
    } else if (sub.isPending) {
      statusColor = Colors.orange;
      statusText = l10n.subscriptionPending;
    } else if (isExpired) {
      statusColor = Colors.red;
      statusText = l10n.subscriptionExpired;
    } else if (sub.isCancelled) {
      statusColor = Colors.grey;
      statusText = l10n.cancelled;
    } else {
      statusColor = Colors.grey;
      statusText = sub.statusLabel;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(isActive ? Icons.check_circle : Icons.history, color: statusColor, size: 24),
        ),
        title: Text(sub.rateCard?.name ?? 'Subscription', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.amountPaid}: ${sub.amountPaid} ${sub.currency}'),
            if (sub.expiryDate != null)
              Text(l10n.expiresOn(sub.expiryDate!), style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Text(statusText, style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
        ),
        isThreeLine: true,
      ),
    );
  }

  // ============================================================
  // INVOICE ITEM
  // ============================================================
  Widget _buildInvoiceItem(BuildContext context, dynamic invoice, SubscriptionProvider provider, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final isPaid = invoice.isPaid;
    final hasPdf = invoice.pdfUrl != null && invoice.pdfUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isPaid ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(isPaid ? Icons.paid_rounded : Icons.pending_rounded, color: isPaid ? Colors.green : Colors.orange, size: 24),
        ),
        title: Text(l10n.invoiceNumber(invoice.invoiceNumber), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text('${l10n.amountPaid}: ${invoice.amount}', style: theme.textTheme.bodyMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isPaid ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(isPaid ? l10n.paid : l10n.pending, style: theme.textTheme.bodySmall?.copyWith(
                color: isPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.w600,
              )),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(hasPdf ? Icons.download_rounded : Icons.file_download_outlined,
                  color: hasPdf ? theme.primaryColor : Colors.grey),
              enabled: hasPdf,
              onSelected: (value) {
                switch (value) {
                  case 'download': _downloadInvoice(context, invoice, provider); break;
                  case 'share': _shareInvoice(context, invoice, provider); break;
                  case 'open': _openInvoice(context, invoice, provider); break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'download', child: Row(children: [Icon(Icons.download_rounded, color: Colors.blue), SizedBox(width: 12), Text('Download PDF')])),
                PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_rounded, color: Colors.green), SizedBox(width: 12), Text('Share PDF')])),
                PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.visibility_rounded, color: Colors.purple), SizedBox(width: 12), Text('Open PDF')])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INVOICE ACTIONS
  // ============================================================
  Future<void> _downloadInvoice(BuildContext context, dynamic invoice, SubscriptionProvider provider) async {
    try {
      final result = await provider.downloadInvoice(invoice.id);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('Invoice downloaded successfully!'))
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareInvoice(BuildContext context, dynamic invoice, SubscriptionProvider provider) async {
    try {
      await provider.shareInvoice(invoice.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openInvoice(BuildContext context, dynamic invoice, SubscriptionProvider provider) async {
    try {
      final pdfPath = await provider.downloadInvoice(invoice.id);
      if (pdfPath != null) {
        await OpenFile.open(pdfPath);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // EMPTY STATES
  // ============================================================
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.subscriptions_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 8),
            Text(l10n.noSubscriptions, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInvoices(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.noInvoices, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
      ),
    );
  }
}