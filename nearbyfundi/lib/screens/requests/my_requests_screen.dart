import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../l10n/app_localizations.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestProvider>().loadMyRequests();
    });
  }

  // ---- Status helpers ----
  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case 'accepted':
        return theme.primaryColor;
      case 'completed':
        return Colors.green.shade700;
      case 'rejected':
      case 'cancelled':
        return theme.colorScheme.error;
      case 'in_progress':
        return Colors.purple.shade700;
      default: // pending
        return Colors.orange;
    }
  }

  Color _statusBackgroundColor(String status, ThemeData theme) {
    final color = _statusColor(status, theme);
    return color.withOpacity(0.12);
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'completed':
        return Icons.verified_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'cancelled':
        return Icons.do_not_disturb_on_outlined;
      case 'in_progress':
        return Icons.hourglass_top_rounded;
      default: // pending
        return Icons.hourglass_empty_rounded;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      case 'in_progress':
        return 'In Progress';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 32.0 : 16.0;
    final cardMargin = isTablet ? 12.0 : 8.0;

    final filteredRequests = provider.requests.where((r) {
      if (_selectedStatusFilter == null) return true;
      return r.status == _selectedStatusFilter;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.myRequests,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onPrimary),
            onPressed: provider.loadMyRequests,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Filter & Stats ----
          _buildFilterBar(context, theme, l10n, horizontalPadding),
          if (provider.requests.isNotEmpty) _buildStatsRow(context, provider, theme, horizontalPadding),
          // ---- List ----
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.loadMyRequests,
              child: _buildContent(provider, filteredRequests, theme, l10n, horizontalPadding, cardMargin),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Filter Bar ----
  Widget _buildFilterBar(BuildContext context, ThemeData theme, AppLocalizations l10n, double hPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 12.0),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded, size: 20, color: theme.primaryColor),
          const SizedBox(width: 8),
          Text(
            'Filter:',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _selectedStatusFilter,
              isDense: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                suffixIcon: Icon(Icons.arrow_drop_down, color: theme.hintColor),
              ),
              style: theme.textTheme.bodyMedium,
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('All')),
                DropdownMenuItem<String?>(value: 'pending', child: Text('Pending')),
                DropdownMenuItem<String?>(value: 'accepted', child: Text('Accepted')),
                DropdownMenuItem<String?>(value: 'in_progress', child: Text('In Progress')),
                DropdownMenuItem<String?>(value: 'completed', child: Text('Completed')),
                DropdownMenuItem<String?>(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem<String?>(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (newValue) => setState(() => _selectedStatusFilter = newValue),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Stats Row ----
  Widget _buildStatsRow(BuildContext context, RequestProvider provider, ThemeData theme, double hPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      child: Row(
        children: [
          _buildStatChip('📋 ${provider.requests.length}', theme.hintColor.withOpacity(0.1), theme.hintColor),
          const SizedBox(width: 8),
          _buildStatChip('⏳ ${provider.pendingCount}', Colors.orange.withOpacity(0.15), Colors.orange.shade700),
          const SizedBox(width: 8),
          _buildStatChip('✅ ${provider.acceptedCount}', Colors.green.withOpacity(0.15), Colors.green.shade700),
          const SizedBox(width: 8),
          _buildStatChip('✔️ ${provider.completedCount}', Colors.blue.withOpacity(0.15), Colors.blue.shade700),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  // ---- Content (list/empty/error) ----
  Widget _buildContent(
      RequestProvider provider,
      List<dynamic> filteredRequests,
      ThemeData theme,
      AppLocalizations l10n,
      double hPadding,
      double cardMargin,
      ) {
    if (provider.isLoading && provider.requests.isEmpty) {
      return Center(child: CircularProgressIndicator(color: theme.primaryColor));
    }

    if (provider.requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: theme.hintColor.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              l10n.noRequestsYet,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.requestsWillAppear,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      );
    }

    if (filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off, size: 60, color: theme.hintColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No requests match the selected filter',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
      itemCount: filteredRequests.length,
      itemBuilder: (ctx, i) {
        final r = filteredRequests[i];
        final isCompleted = r.isCompleted;
        final isPending = r.isPending;
        final statusColor = _statusColor(r.status, theme);
        final statusBg = _statusBackgroundColor(r.status, theme);

        return Card(
          margin: EdgeInsets.only(bottom: cardMargin + 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 2,
          shadowColor: theme.shadowColor.withOpacity(0.06),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Top row: service name + status ----
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.serviceName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(r.status), size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusLabel(r.status).toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ---- Description ----
                Text(
                  r.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // ---- Meta info (technician, time, area) ----
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: theme.hintColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        r.technicianName,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ),
                    Icon(Icons.schedule, size: 16, color: theme.hintColor),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(r.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
                if (r.technicianArea != null && r.technicianArea!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: theme.hintColor),
                        const SizedBox(width: 4),
                        Text(
                          r.technicianArea!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                // ---- Completed badge ----
                if (isCompleted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Completed ✓',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                        ),
                        if (r.technicianRating != null && r.technicianRating! > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade600),
                          Text(
                            r.technicianRating!.toStringAsFixed(1),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                // ---- Actions ----
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPending)
                      TextButton.icon(
                        onPressed: provider.isLoading
                            ? null
                            : () async {
                          final confirmed = await showConfirmationDialog(
                            context,
                            l10n.cancelRequest,
                            l10n.areYouSureCancel,
                          );
                          if (confirmed == true && context.mounted) {
                            await context.read<RequestProvider>().cancelRequest(r.id);
                          }
                        },
                        icon: Icon(Icons.cancel_outlined, size: 18, color: theme.colorScheme.error),
                        label: Text(
                          l10n.cancelRequest,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    if (r.isAccepted || r.isCompleted || r.isInProgress)
                      TextButton.icon(
                        onPressed: () {
                          // Navigate to request details (if implemented)
                        },
                        icon: Icon(Icons.visibility_outlined, size: 18, color: theme.primaryColor),
                        label: Text(
                          'View Details',
                          style: TextStyle(color: theme.primaryColor, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}