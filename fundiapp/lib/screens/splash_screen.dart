import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../config/app_routes.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final AnimationController _orbitController;

  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _slideUp;
  late final Animation<double> _pulse;
  late final Animation<double> _orbit;

  @override
  void initState() {
    super.initState();

    // Main entrance animation
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Soft continuous pulse for the logo glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slow orbit for the decorative rings
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _orbit = Tween<double>(begin: 0, end: 1).animate(_orbitController);

    _mainController.forward();
    _navigate();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    final auth = context.read<AuthProvider>();

    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    if (isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Brand colors – adjust these to match your AppTheme if needed
    final primary = theme.primaryColor;
    final secondary = theme.colorScheme.secondary;
    final bgStart = isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF8FAFC);
    final bgEnd = isDark ? const Color(0xFF111827) : const Color(0xFFEEF2FF);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgStart, bgEnd],
          ),
        ),
        child: Stack(
          children: [
            // Soft ambient glow circles
            Positioned(
              top: -80,
              right: -60,
              child: _AmbientBlob(
                size: 220,
                color: primary.withOpacity(isDark ? 0.12 : 0.08),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: _AmbientBlob(
                size: 280,
                color: secondary.withOpacity(isDark ? 0.10 : 0.07),
              ),
            ),

            // Subtle tech grid pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _TechGridPainter(
                  color: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.03),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: AnimatedBuilder(
                    animation: _slideUp,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideUp.value),
                        child: child,
                      );
                    },
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo + orbiting rings
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer orbit ring
                                AnimatedBuilder(
                                  animation: _orbit,
                                  builder: (context, _) {
                                    return Transform.rotate(
                                      angle: _orbit.value * 2 * 3.14159,
                                      child: Container(
                                        width: 150,
                                        height: 150,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: primary.withOpacity(0.18),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Align(
                                          alignment: const Alignment(0.9, -0.4),
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: primary.withOpacity(0.7),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: primary.withOpacity(0.5),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Middle ring
                                AnimatedBuilder(
                                  animation: _orbit,
                                  builder: (context, _) {
                                    return Transform.rotate(
                                      angle: -_orbit.value * 2 * 3.14159 * 0.6,
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: secondary.withOpacity(0.15),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Align(
                                          alignment: const Alignment(-0.85, 0.5),
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: secondary.withOpacity(0.65),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Soft pulse glow behind logo
                                AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (context, _) {
                                    return Container(
                                      width: 100 * _pulse.value,
                                      height: 100 * _pulse.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primary.withOpacity(0.25),
                                            blurRadius: 30 * _pulse.value,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                // Logo container
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withOpacity(0.15),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: primary.withOpacity(0.12),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/icons/nearbyfundi-logo.svg',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),

                          // App name
                          Text(
                            'Nearby Fundi',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tagline
                          Text(
                            'Find skilled help nearby',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.55),
                              letterSpacing: 0.2,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Modern progress indicator
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.8,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(primary),
                              backgroundColor: primary.withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom branding strip
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: primary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Local • Trusted • Fast',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.45),
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Soft ambient background blob
class _AmbientBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

// Very subtle tech grid
class _TechGridPainter extends CustomPainter {
  final Color color;

  _TechGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const step = 28.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}