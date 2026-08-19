import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../l10n/app_localizations.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.resetPassword(
      widget.email,
      _otpController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.resetPasswordButton),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) => LoadingOverlay(
                isLoading: auth.isLoading,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Modern Brand Icon ---
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_reset_rounded,
                              size: 36,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // --- Headings ---
                        Center(
                          child: Text(
                            'NearbyFundi',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            l10n.resetPassword,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.otpSentTo} ${widget.email}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // --- OTP Code Field ---
                        _buildFieldLabel(l10n.otpCode),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 8),
                          decoration: _inputDecoration(
                            context,
                            hintText: '------',
                            prefixIcon: Icons.pin_rounded,
                          ),
                          validator: (v) => v != null && v.length == 6 ? null : 'Enter 6-digit OTP',
                        ),
                        const SizedBox(height: 24),

                        // --- New Password Field ---
                        _buildFieldLabel(l10n.newPassword),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePass,
                          decoration: _inputDecoration(
                            context,
                            hintText: 'Minimum 8 characters',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: theme.hintColor,
                              ),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 8 ? null : 'Password must be at least 8 characters',
                        ),
                        const SizedBox(height: 24),

                        // --- Confirm Password Field ---
                        _buildFieldLabel(l10n.confirmPassword),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: _inputDecoration(
                            context,
                            hintText: 'Repeat your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: theme.hintColor,
                              ),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) => v == _passwordController.text ? null : 'Passwords do not match',
                        ),
                        const SizedBox(height: 36),

                        // --- Reset Button ---
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: CustomButton(
                            text: l10n.resetPasswordButton,
                            onPressed: _handleReset,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Back Link ---
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              l10n.backToSignIn,
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        letterSpacing: 0.8,
      ),
    );
  }
}

// --- Reusable Input Decoration Helper ---
InputDecoration _inputDecoration(
    BuildContext context, {
      required String hintText,
      required IconData prefixIcon,
      Widget? suffixIcon,
    }) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: Colors.grey[500],
      fontWeight: FontWeight.w400,
    ),
    prefixIcon: Icon(prefixIcon, color: theme.hintColor, size: 20),
    suffixIcon: suffixIcon,
    counterText: '',
    filled: true,
    fillColor: const Color(0xFFF2F4F8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
  );
}