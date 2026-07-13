import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_routes.dart';
import '../../../models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/technician_provider.dart';
import '../../../widgets/confirmation_dialog.dart';
import '../../../utils/image_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../config/app_theme.dart';

class FundiProfileScreen extends StatefulWidget {
  const FundiProfileScreen({super.key});

  @override
  State<FundiProfileScreen> createState() => _FundiProfileScreenState();
}

class _FundiProfileScreenState extends State<FundiProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TechnicianProvider>().fetchMyProfile();
      context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tech = context.watch<TechnicianProvider>();
    final user = auth.user;
    final technician = tech.technician;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isOnline = technician?.isOnline ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.profile),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
      ),
      body: tech.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ---- Header Card with Gradient ----
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                          ),
                          child: ClipOval(
                            child: technician?.profilePhoto != null
                                ? Image.network(
                              ImageUtils.getFullImageUrl(technician!.profilePhoto!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _defaultAvatar(user, theme),
                            )
                                : _defaultAvatar(user, theme),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                    ),
                    if (user?.phone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📱 ${user!.phone}',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOnline ? AppTheme.success : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? '● ONLINE' : '● OFFLINE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- Edit Profile ----
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.editProfile),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- Services ----
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.build_circle_outlined, color: theme.colorScheme.primary),
                    ),
                    title: Text(l10n.servicesIOffer, style: theme.textTheme.titleMedium),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    onTap: () => _showServicesDialog(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: technician?.services.isNotEmpty == true
                          ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: technician!.services.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.primary),
                          ),
                        )).toList(),
                      )
                          : Text(l10n.noServicesSelected, style: theme.textTheme.bodySmall),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- Details ----
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.profileDetails, style: theme.textTheme.titleMedium),
                    const Divider(height: 24),
                    if (technician?.bio != null && technician!.bio!.isNotEmpty) ...[
                      _detailTile(l10n.bio, technician!.bio!, theme),
                      const Divider(height: 16),
                    ],
                    if (technician?.experience != null) ...[
                      _detailTile(l10n.experience, '${technician!.experience} ${l10n.years}', theme),
                      const Divider(height: 16),
                    ],
                    if (technician?.hourlyRate != null) ...[
                      _detailTile(l10n.hourlyRate, '${l10n.tzs} ${technician!.hourlyRate!.toStringAsFixed(0)}', theme),
                      const Divider(height: 16),
                    ],
                    if (technician?.area != null && technician!.area!.isNotEmpty) ...[
                      _detailTile(l10n.area, technician!.area!, theme),
                      const Divider(height: 16),
                    ],
                    _detailTile(l10n.accountStatus, l10n.active, theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ---- Settings & Logout ----
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(l10n.settings),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.dividerColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showConfirmationDialog(context, l10n.logout, l10n.logoutConfirmation);
                  if (confirm == true) {
                    await auth.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(l10n.logout),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Delete Account ----
            TextButton.icon(
              onPressed: () async {
                final confirm = await showConfirmationDialog(
                  context,
                  l10n.deleteAccount,
                  l10n.deleteAccountConfirmation,
                );
                if (confirm == true) {
                  await auth.deleteAccount();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                }
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.deleteAccount, style: TextStyle(color: AppTheme.error)),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(User? user, ThemeData theme) {
    return Container(
      color: Colors.white.withOpacity(0.2),
      child: Center(
        child: Text(
          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'F',
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  void _showServicesDialog(BuildContext context) {
    final provider = context.read<TechnicianProvider>();
    final serviceProvider = context.read<ServiceProvider>();
    final technician = provider.technician;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final currentServiceIds = technician?.serviceObjects.map((s) => s.id).toList() ?? [];
    List<int> selectedIds = List.from(currentServiceIds);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.build_circle_outlined, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(l10n.selectServicesDialogTitle, style: theme.textTheme.titleLarge),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: serviceProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              shrinkWrap: true,
              itemCount: serviceProvider.services.length,
              itemBuilder: (ctx, i) {
                final service = serviceProvider.services[i];
                final isSelected = selectedIds.contains(service.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    title: Text(service.name, style: theme.textTheme.bodyMedium),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedIds.add(service.id);
                        } else {
                          selectedIds.remove(service.id);
                        }
                      });
                    },
                    activeColor: theme.colorScheme.primary,
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
                if (selectedIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.selectAtLeastOneService),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                  return;
                }
                if (selectedIds.toSet().difference(currentServiceIds.toSet()).isNotEmpty ||
                    currentServiceIds.toSet().difference(selectedIds.toSet()).isNotEmpty) {
                  await provider.updateServices(selectedIds);
                } else {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No changes made'),
                      backgroundColor: Colors.grey,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.servicesUpdated),
                    backgroundColor: theme.colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(l10n.saveChanges),
            ),
          ],
        ),
      ),
    );
  }
}