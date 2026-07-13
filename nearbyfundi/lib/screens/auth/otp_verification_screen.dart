import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../l10n/app_localizations.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String get _otp => _otpControllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.enterOtp),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.verifyOtp(widget.email, _otp);
    if (!mounted) return;
    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      auth.clearError();
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
                            AppTheme.dark,
                            AppTheme.primary,
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
                              child: Icon(Icons.verified_rounded, size: 38, color: theme.colorScheme.onPrimary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.verificationCode,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${l10n.enterCodeSent}\n${widget.email}',
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
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.enterOtp,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.otpSent,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            6,
                                (i) => SizedBox(
                              width: 48,
                              child: TextFormField(
                                controller: _otpControllers[i],
                                focusNode: _focusNodes[i],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  fillColor: theme.colorScheme.surface,
                                ),
                                onChanged: (val) {
                                  if (val.isNotEmpty && i < 5) {
                                    _focusNodes[i + 1].requestFocus();
                                  } else if (val.isEmpty && i > 0) {
                                    _focusNodes[i - 1].requestFocus();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        CustomButton(
                          text: l10n.verifyOtp,
                          onPressed: _handleVerify,
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