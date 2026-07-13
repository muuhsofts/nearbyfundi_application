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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) => LoadingOverlay(
          isLoading: auth.isLoading,
          child: Column(
            children: [
              Expanded(
                flex: 42,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                            theme.colorScheme.tertiary ?? theme.colorScheme.primary,
                          ]
                              : [
                            const Color(0xFF1A1150),
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                    Positioned(top: -30, right: -30, child: _buildDecorCircle(140, 0.07, theme)),
                    Positioned(bottom: 30, left: -20, child: _buildDecorCircle(90, 0.05, theme)),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 12,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned.fill(
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onPrimary.withOpacity(0.15),
                                border: Border.all(color: theme.colorScheme.onPrimary.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.lock_reset_rounded, size: 38, color: theme.colorScheme.onPrimary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.resetPassword,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.setNewPassword,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onPrimary.withOpacity(0.75),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        size: const Size(double.infinity, 36),
                        painter: _WavePainter(color: theme.colorScheme.surface),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 58,
                child: Container(
                  color: theme.colorScheme.surface,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.setNewPassword,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.otpSentTo} ${widget.email}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                          ),
                          const SizedBox(height: 32),
                          _FieldLabel(label: l10n.otpCode),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 8),
                            decoration: InputDecoration(
                              hintText: '------',
                              hintStyle: const TextStyle(letterSpacing: 8, fontSize: 20),
                              counterText: '',
                              prefixIcon: Icon(Icons.pin_rounded, size: 20, color: theme.primaryColor),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.hintColor.withOpacity(0.3), width: 0.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.hintColor.withOpacity(0.3), width: 0.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                              ),
                            ),
                            validator: (v) => v != null && v.length == 6 ? null : 'Enter 6-digit OTP',
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel(label: l10n.newPassword),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              hintText: 'Minimum 8 characters',
                              prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: theme.primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass ? Icons.visibility_off : Icons.visibility,
                                  color: theme.hintColor,
                                ),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.hintColor.withOpacity(0.3), width: 0.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.hintColor.withOpacity(0.3), width: 0.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                            ),
                            validator: (v) => v != null && v.length >= 8 ? null : 'Password must be at least 8 characters',
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel(label: l10n.confirmPassword),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              hintText: 'Repeat your password',
                              prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: theme.primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                  color: theme.hintColor,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.hintColor.withOpacity(0.3), width: 0.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.hintColor.withOpacity(0.3), width: 0.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              labelStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                            ),
                            validator: (v) => v == _passwordController.text ? null : 'Passwords do not match',
                          ),
                          const SizedBox(height: 32),
                          CustomButton(
                            text: l10n.resetPasswordButton,
                            onPressed: _handleReset,
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              l10n.backToSignIn,
                              style: TextStyle(color: theme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecorCircle(double size, double opacity, ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.onPrimary.withOpacity(opacity),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  const _WavePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.75, size.height, size.width, size.height * 0.5);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}