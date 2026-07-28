import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/request.dart';
import '../../providers/request_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';

class FundiRequestsScreen extends StatefulWidget {
  const FundiRequestsScreen({super.key});

  @override
  State<FundiRequestsScreen> createState() => _FundiRequestsScreenState();
}

class _FundiRequestsScreenState extends State<FundiRequestsScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestProvider>().loadMyRequests();
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  List<ServiceRequest> get _filteredRequests {
    final requests = context.read<RequestProvider>().requests;
    var filtered = requests;

    if (_selectedStatusFilter != null) {
      filtered = filtered.where((r) => r.status == _selectedStatusFilter).toList();
    }

    if (_filterQuery.isNotEmpty) {
      final query = _filterQuery.toLowerCase();
      filtered = filtered.where((r) =>
      r.customerName.toLowerCase().contains(query) ||
          r.serviceName.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query)).toList();
    }

    return filtered;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
      case 'in_progress':
        return AppTheme.primary;
      case 'completed':
        return AppTheme.success;
      case 'rejected':
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Color _statusBgColor(String status) => _statusColor(status).withOpacity(0.12);

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
      case 'in_progress':
        return Icons.check_circle_outline_rounded;
      case 'completed':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'cancelled':
        return Icons.do_not_disturb_on_outlined;
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
        return 'Accepted';
      default:
        return status.toUpperCase();
    }
  }

  Future<void> _startChat(BuildContext context, ServiceRequest request) async {
    try {
      final chatProvider = context.read<ChatProvider>();
      final authProvider = context.read<AuthProvider>();

      final conversation = await chatProvider.getOrCreateConversation(
        customerId: request.customerId,
        fundiId: authProvider.user!.id,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Failed to start chat: $e', isError: true);
      }
    }
  }

  Future<void> _markCompleted(BuildContext context, int requestId) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.completeRequest, style: theme.textTheme.titleMedium),
        content: Text(l10n.completeConfirmation, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.completeRequest),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<RequestProvider>();
      final success = await provider.completeRequest(requestId);
      if (context.mounted) {
        _showSnack(
          context,
          success ? l10n.completedSuccess : l10n.failedToComplete,
          isError: !success,
        );
      }
    }
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final filteredRequests = _filteredRequests;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.requests,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => provider.refresh(),
            tooltip: 'Refresh',
          ),
        ],
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            _buildSearchAndFilter(context, provider, theme),
            _buildStatsBar(provider, theme),
            Expanded(
              child: _buildRequestList(
                context,
                provider,
                filteredRequests,
                l10n,
                theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SEARCH & FILTER ────────────────────────────────────────────────────
  Widget _buildSearchAndFilter(
      BuildContext context, RequestProvider provider, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: TextField(
              controller: _filterController,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: l10n.filterByCustomerService,
                hintStyle: theme.textTheme.bodySmall,
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
                suffixIcon: _filterQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  onPressed: () {
                    _filterController.clear();
                    setState(() => _filterQuery = '');
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
              onChanged: (value) => setState(() => _filterQuery = value),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', null, theme),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending', theme),
                const SizedBox(width: 8),
                _buildFilterChip('Accepted', 'accepted', theme),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed', theme),
                const SizedBox(width: 8),
                _buildFilterChip('Rejected', 'rejected', theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, ThemeData theme) {
    final isSelected = _selectedStatusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = isSelected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.primary : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── STATS BAR ──────────────────────────────────────────────────────────
  Widget _buildStatsBar(RequestProvider provider, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildStatChip('Total', provider.totalCount,
              theme.colorScheme.onSurface, theme, Colors.grey.shade200),
          const SizedBox(width: 8),
          _buildStatChip('Pending', provider.pendingCount,
              AppTheme.warning, theme, AppTheme.warning.withOpacity(0.12)),
          const SizedBox(width: 8),
          _buildStatChip('Accepted', provider.acceptedCount,
              AppTheme.primary, theme, AppTheme.primary.withOpacity(0.12)),
          const SizedBox(width: 8),
          _buildStatChip('Done', provider.completedCount,
              AppTheme.success, theme, AppTheme.success.withOpacity(0.12)),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color textColor,
      ThemeData theme, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── REQUEST LIST ──────────────────────────────────────────────────────
  Widget _buildRequestList(BuildContext context, RequestProvider provider,
      List<ServiceRequest> requests, AppLocalizations l10n, ThemeData theme) {
    if (provider.requests.isEmpty) {
      return _buildEmptyState(
          icon: Icons.inbox_outlined, text: l10n.noRequests, theme: theme);
    }

    if (requests.isEmpty) {
      return _buildEmptyState(
          icon: Icons.search_off_rounded,
          text: l10n.noMatchingRequests,
          theme: theme);
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: requests.length,
        itemBuilder: (ctx, i) => _buildRequestCard(context, requests[i], l10n, theme),
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String text, required ThemeData theme}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor),
            ),
            child: Icon(icon, size: 44,
                color: theme.colorScheme.onSurface.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  // ─── REQUEST CARD ──────────────────────────────────────────────────────
  Widget _buildRequestCard(BuildContext context, ServiceRequest request,
      AppLocalizations l10n, ThemeData theme) {
    final isPending = request.isPending;
    final isActioned = request.isAccepted || request.isInProgress;
    final isCompleted = request.isCompleted;
    final isRejectedOrCancelled = request.isRejected || request.isCancelled;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? AppTheme.success.withOpacity(0.3) : theme.dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.serviceName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusBgColor(request.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(request.status),
                          size: 13, color: _statusColor(request.status)),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusLabel(request.status).toUpperCase(),
                        style: TextStyle(
                          color: _statusColor(request.status),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.customerName,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              request.description,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            if (isPending) _buildPendingActions(context, request, l10n, theme),
            if (isActioned) _buildActionedActions(context, request, l10n, theme),
            if (isCompleted) _buildCompletedActions(request, l10n, theme),
            if (isRejectedOrCancelled) _buildRejectedActions(request, theme),
          ],
        ),
      ),
    );
  }

  // ─── ACTION BUTTONS ────────────────────────────────────────────────────
  Widget _buildPendingActions(BuildContext context, ServiceRequest request,
      AppLocalizations l10n, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _PrimaryButton(
            label: l10n.accept,
            color: AppTheme.primary,
            onPressed: () async {
              final provider = context.read<RequestProvider>();
              final success = await provider.acceptRequest(request.id);
              if (context.mounted) {
                _showSnack(context,
                    success ? l10n.requestAccepted : 'Failed to accept',
                    isError: !success);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PrimaryButton(
            label: l10n.reject,
            color: AppTheme.error,
            outlined: true,
            onPressed: () async {
              final provider = context.read<RequestProvider>();
              final success = await provider.rejectRequest(request.id);
              if (context.mounted) {
                _showSnack(context,
                    success ? l10n.requestRejected : 'Failed to reject',
                    isError: !success);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionedActions(BuildContext context, ServiceRequest request,
      AppLocalizations l10n, ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _PrimaryButton(
            label: l10n.chatWithCustomer,
            color: AppTheme.primary,
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () => _startChat(context, request),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _PrimaryButton(
            label: l10n.markComplete,
            color: AppTheme.success,
            icon: Icons.verified_rounded,
            outlined: true,
            onPressed: () => _markCompleted(context, request.id),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedActions(
      ServiceRequest request, AppLocalizations l10n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppTheme.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.completed,
                  style: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (request.technicianRating != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        ...List.generate(
                          request.technicianRating!.round(),
                              (index) => const Icon(Icons.star_rounded,
                              size: 14, color: Colors.amber),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          request.technicianRating!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedActions(ServiceRequest request, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Center(
        child: Text(
          request.isRejected ? 'Request Rejected' : 'Request Cancelled',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}

// ─── PRIMARY BUTTON ──────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool outlined;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = icon == null
        ? Text(label)
        : Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final padding = const EdgeInsets.symmetric(vertical: 12);
    final textStyle = const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5);

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.4)),
          shape: shape,
          padding: padding,
          textStyle: textStyle,
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: shape,
        padding: padding,
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}