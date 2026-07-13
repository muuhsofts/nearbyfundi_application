import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController.text = user?.name ?? '';
    _phoneController.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.updateProfile({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
    });
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.profileUpdated)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? l10n.updateFailed),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final cardWidth = isTablet ? 480.0 : double.infinity;
    final horizontalPadding = isTablet ? 40.0 : 24.0;
    final verticalPadding = isTablet ? 40.0 : 24.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.editProfile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardWidth),
            child: Form(
              key: _formKey,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with gradient circle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.primaryColor,
                              theme.primaryColor.withOpacity(0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.updateInfo,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update your personal information',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                          fontSize: 14,
                        ),
                      ),
                      const Divider(height: 32, thickness: 1.5),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.name,
                          labelStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                          prefixIcon: Icon(Icons.person_outline_rounded, color: theme.primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        style: theme.textTheme.bodyMedium,
                        validator: (v) =>
                        (v != null && v.isNotEmpty) ? null : 'Name is required',
                      ),
                      const SizedBox(height: 18),

                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: l10n.phone,
                          labelStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                          prefixIcon: Icon(Icons.phone_outlined, color: theme.primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      CustomButton(
                        text: l10n.saveChanges,
                        onPressed: isLoading ? null : _save,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}