// screens/requests/my_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/request_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_routes.dart';

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
  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.primary;
      case 'completed':
        return AppTheme.success;
      case 'rejected':
      case 'cancelled':
        return AppTheme.error;
      case 'in_progress':
        return Colors.purple.shade700;
      default: // pending
        return AppTheme.warning;
    }
  }

  Color _statusBackgroundColor(String status) {
    final color = _statusColor(status);
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

  // ─── Show Request Details Modal ──────────────────────────────────────
  void _showRequestDetails(BuildContext context, dynamic request) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _RequestDetailModal(request: request),
    );
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: provider.loadMyRequests,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Filter Bar ----
          _buildFilterBar(context, theme, l10n, horizontalPadding),
          // ---- Stats Row ----
          if (provider.requests.isNotEmpty)
            _buildStatsRow(context, provider, theme, horizontalPadding),
          // ---- List ----
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.loadMyRequests,
              color: AppTheme.primary,
              child: _buildContent(
                provider,
                filteredRequests,
                theme,
                l10n,
                horizontalPadding,
                cardMargin,
              ),
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
          Icon(Icons.filter_list_rounded, size: 20, color: AppTheme.primary),
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
          _buildStatChip('⏳ ${provider.pendingCount}', AppTheme.warning.withOpacity(0.15), AppTheme.warning),
          const SizedBox(width: 8),
          _buildStatChip('✅ ${provider.acceptedCount}', AppTheme.primary.withOpacity(0.15), AppTheme.primary),
          const SizedBox(width: 8),
          _buildStatChip('✔️ ${provider.completedCount}', AppTheme.success.withOpacity(0.15), AppTheme.success),
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

  // ---- Content ----
  Widget _buildContent(
      RequestProvider provider,
      List<dynamic> filteredRequests,
      ThemeData theme,
      AppLocalizations l10n,
      double hPadding,
      double cardMargin,
      ) {
    if (provider.isLoading && provider.requests.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
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
        final statusColor = _statusColor(r.status);
        final statusBg = _statusBackgroundColor(r.status);

        return Card(
          margin: EdgeInsets.only(bottom: cardMargin + 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 2,
          shadowColor: theme.shadowColor.withOpacity(0.06),
          color: theme.cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Very Small Bolder Line ───────────────────────────────
              Container(
                height: 3,
                width: 40,
                margin: const EdgeInsets.only(top: 6, left: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- Top row: service name + category + status ----
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.serviceName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              if (r.categoryName != null && r.categoryName!.isNotEmpty)
                                Text(
                                  '📂 ${r.categoryName}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
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
                    // ---- Meta info ----
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
                          color: AppTheme.success.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 16, color: AppTheme.success),
                            const SizedBox(width: 6),
                            Text(
                              'Completed ✓',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success),
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
                            icon: Icon(Icons.cancel_outlined, size: 18, color: AppTheme.error),
                            label: Text(
                              l10n.cancelRequest,
                              style: TextStyle(color: AppTheme.error, fontSize: 13),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.error,
                            ),
                          ),
                        if (r.isAccepted || r.isCompleted || r.isInProgress)
                          TextButton.icon(
                            onPressed: () => _showRequestDetails(context, r),
                            icon: Icon(Icons.visibility_outlined, size: 18, color: AppTheme.primary),
                            label: Text(
                              'View Details',
                              style: TextStyle(color: AppTheme.primary, fontSize: 13),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── REQUEST DETAIL MODAL ──────────────────────────────────────────────
class _RequestDetailModal extends StatelessWidget {
  final dynamic request;

  const _RequestDetailModal({required this.request});

  String _formatDateFull(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(request.status);
    final statusBg = _statusBackgroundColor(request.status);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.cardColor,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.request_page_rounded, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Request Details',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 24, color: theme.hintColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1.2),

              // ─── Service Name ──────────────────────────────────────────
              _buildDetailRow(
                label: 'Service',
                value: request.serviceName,
                icon: Icons.construction_rounded,
                theme: theme,
              ),
              const SizedBox(height: 12),

              // ─── Category ──────────────────────────────────────────────
              if (request.categoryName != null && request.categoryName!.isNotEmpty)
                _buildDetailRow(
                  label: 'Category',
                  value: request.categoryName!,
                  icon: Icons.category_rounded,
                  theme: theme,
                ),
              if (request.categoryName != null) const SizedBox(height: 12),

              // ─── Status ─────────────────────────────────────────────────
              _buildStatusRow(statusColor, statusBg, theme),

              const SizedBox(height: 12),

              // ─── Description ────────────────────────────────────────────
              _buildDetailRow(
                label: 'Description',
                value: request.description,
                icon: Icons.description_outlined,
                theme: theme,
                multiline: true,
              ),
              const SizedBox(height: 12),

              // ─── Customer ──────────────────────────────────────────────
              _buildDetailRow(
                label: 'Customer',
                value: request.customerName ?? 'N/A',
                icon: Icons.person_outline,
                theme: theme,
              ),
              const SizedBox(height: 12),

              // ─── Technician ─────────────────────────────────────────────
              _buildDetailRow(
                label: 'Technician',
                value: request.technicianName,
                icon: Icons.handyman_rounded,
                theme: theme,
              ),
              const SizedBox(height: 12),

              // ─── Area ───────────────────────────────────────────────────
              if (request.technicianArea != null && request.technicianArea!.isNotEmpty)
                _buildDetailRow(
                  label: 'Area',
                  value: request.technicianArea!,
                  icon: Icons.location_on_outlined,
                  theme: theme,
                ),
              if (request.technicianArea != null) const SizedBox(height: 12),

              // ─── Created At ─────────────────────────────────────────────
              _buildDetailRow(
                label: 'Requested On',
                value: _formatDateFull(request.createdAt),
                icon: Icons.calendar_today_outlined,
                theme: theme,
              ),
              const SizedBox(height: 20),

              // ─── Close Button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    required ThemeData theme,
    bool multiline = false,
  }) {
    return Row(
      crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: multiline ? 1.4 : 1.2,
                ),
                maxLines: multiline ? 4 : 1,
                overflow: multiline ? TextOverflow.ellipsis : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(Color statusColor, Color statusBg, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_statusIcon(request.status), size: 18, color: statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusLabel(request.status).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Reuse status helpers ----
  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.primary;
      case 'completed':
        return AppTheme.success;
      case 'rejected':
      case 'cancelled':
        return AppTheme.error;
      case 'in_progress':
        return Colors.purple.shade700;
      default:
        return AppTheme.warning;
    }
  }

  Color _statusBackgroundColor(String status) {
    final color = _statusColor(status);
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
      default:
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
}