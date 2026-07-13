import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.forgotPassword(_emailController.text.trim());
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.otpSent),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushNamed(context, AppRoutes.reset, arguments: _emailController.text.trim());
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
                              l10n.forgotPassword,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.noWorries,
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
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.resetPassword,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.enterEmailReset,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _FieldLabel(label: l10n.emailAddress),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.email_outlined, color: theme.primaryColor),
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
                            validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                          ),
                          const SizedBox(height: 32),
                          CustomButton(
                            text: l10n.sendResetCode,
                            onPressed: _handleSend,
                          ),
                          const SizedBox(height: 24),
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