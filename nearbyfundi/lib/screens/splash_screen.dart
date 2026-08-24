// splash_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_routes.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF006B5E);
  static const Color darkGreen = Color(0xFF003D35);
  static const Color accentGreen = Color(0xFF00B894);
  static const Color lightGreen = Color(0xFFE8F5E9);

  static const String logoPath = 'assets/images/nearbyfundi-logo.svg';

  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _particleController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _waveHeight;
  late Animation<double> _particleRotation;

  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Initialize particles
    for (int i = 0; i < 30; i++) {
      _particles.add(Particle());
    }

    // Main entrance animation
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoScale = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.0,
          0.6,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    _logoFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.0,
          0.4,
          curve: Curves.easeOut,
        ),
      ),
    );

    _contentFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.3,
          0.8,
          curve: Curves.easeOut,
        ),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.3,
          0.85,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    // Wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _waveHeight = Tween<double>(
      begin: 0.0,
      end: 30.0,
    ).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Particle rotation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particleRotation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: Curves.linear,
      ),
    );

    // Small pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _mainController.forward();

    _navigate();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();

    final isFirstLaunch =
        prefs.getBool('is_first_launch') ?? true;

    final auth = context.read<AuthProvider>();

    await Future.delayed(
      const Duration(milliseconds: 3200),
    );

    if (!mounted) return;

    if (isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.onboarding,
      );
    } else if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.home,
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.login,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // ============================================================
          // GRADIENT BACKGROUND
          // ============================================================
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A2E36),
                  Color(0xFF0F4B4A),
                  Color(0xFF1A6B5A),
                  Color(0xFF0D3D3A),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // ============================================================
          // FLOATING PARTICLES
          // ============================================================
          AnimatedBuilder(
            animation: _particleRotation,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  rotation: _particleRotation.value,
                  size: size,
                ),
                size: size,
              );
            },
          ),

          // ============================================================
          // WAVES AT BOTTOM
          // ============================================================
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _waveHeight,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WavePainter(
                    waveHeight: _waveHeight.value,
                  ),
                  size: Size(size.width, 120),
                );
              },
            ),
          ),

          // ============================================================
          // GLOW ORB
          // ============================================================
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentGreen.withOpacity(0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.shade400.withOpacity(0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // ============================================================
          // MAIN CONTENT
          // ============================================================
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ====================================================
                    // LOGO WITH GLOW
                    // ====================================================
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulse =
                                1.0 + (_pulseController.value * 0.03);

                            return Transform.scale(
                              scale: pulse,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer glow ring
                                  Container(
                                    width: 320,
                                    height: 320,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          accentGreen.withOpacity(0.25),
                                          accentGreen.withOpacity(0.05),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),

                                  // Animated rotating ring
                                  Container(
                                    width: 290,
                                    height: 290,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(
                                          0.06,
                                        ),
                                        width: 2,
                                      ),
                                    ),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                      backgroundColor: Colors.transparent,
                                    ),
                                  ),

                                  // Glass effect circle
                                  Container(
                                    width: 250,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.15),
                                          Colors.white.withOpacity(0.04),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(
                                          0.12,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),

                                  // White logo plate with shadow
                                  Container(
                                    width: 210,
                                    height: 210,
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 60,
                                          offset: const Offset(0, 25),
                                          spreadRadius: 5,
                                        ),
                                        BoxShadow(
                                          color: accentGreen.withOpacity(
                                            0.15,
                                          ),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: SvgPicture.asset(
                                      logoPath,
                                      fit: BoxFit.contain,
                                      semanticsLabel: 'NearbyFundi logo',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ====================================================
                    // BRAND NAME
                    // ====================================================
                    FadeTransition(
                      opacity: _contentFade,
                      child: SlideTransition(
                        position: _contentSlide,
                        child: Column(
                          children: [
                            // Decorative line with gradient
                            Container(
                              width: 80,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    accentGreen,
                                    Color(0xFF00D4A0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Tagline
                            Text(
                              'Find trusted help,\nright where you need it.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                                letterSpacing: 0.3,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Sub tagline
                            Text(
                              'Professional services at your doorstep',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),

                    // ====================================================
                    // LOADING INDICATOR
                    // ====================================================
                    FadeTransition(
                      opacity: _contentFade,
                      child: Column(
                        children: [
                          // Dot loading animation
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLoadingDot(0),
                              const SizedBox(width: 12),
                              _buildLoadingDot(1),
                              const SizedBox(width: 12),
                              _buildLoadingDot(2),
                            ],
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ============================================================
          // BOTTOM BRANDING
          // ============================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Text(
                    'NEARBYFUNDI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Find • Connect • Get It Done',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.15),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingDot(int index) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final delay = (index * 0.15);
        final progress = (_mainController.value - delay).clamp(0.0, 1.0);
        final scale = 0.4 + (progress * 1.6);
        final opacity = 0.3 + (progress * 0.7);

        return Transform.scale(
          scale: scale.clamp(0.4, 2.0),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity.clamp(0.3, 1.0)),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentGreen.withOpacity(0.2 * progress),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// PARTICLE CLASS
// ================================================================

class Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double driftX;
  double driftY;

  Particle()
      : x = math.Random().nextDouble() * 1.0,
        y = math.Random().nextDouble() * 1.0,
        size = 1.5 + math.Random().nextDouble() * 3,
        speed = 0.2 + math.Random().nextDouble() * 0.5,
        opacity = 0.1 + math.Random().nextDouble() * 0.3,
        driftX = (math.Random().nextDouble() - 0.5) * 0.002,
        driftY = (math.Random().nextDouble() - 0.5) * 0.002;
}

// ================================================================
// PARTICLE PAINTER
// ================================================================

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double rotation;
  final Size size;

  _ParticlePainter({
    required this.particles,
    required this.rotation,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      // Update positions
      particle.x += particle.driftX;
      particle.y += particle.driftY;

      // Wrap around
      if (particle.x < 0) particle.x = 1;
      if (particle.x > 1) particle.x = 0;
      if (particle.y < 0) particle.y = 1;
      if (particle.y > 1) particle.y = 0;

      final x = particle.x * this.size.width;
      final y = particle.y * this.size.height;

      paint.color = Colors.white.withOpacity(particle.opacity * 0.5);

      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }

    // Draw some connecting lines
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final dx = (particles[i].x - particles[j].x) * this.size.width;
        final dy = (particles[i].y - particles[j].y) * this.size.height;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < 120) {
          final opacity = (1 - distance / 120) * 0.06;
          paint.color = Colors.white.withOpacity(opacity);
          canvas.drawLine(
            Offset(
              particles[i].x * this.size.width,
              particles[i].y * this.size.height,
            ),
            Offset(
              particles[j].x * this.size.width,
              particles[j].y * this.size.height,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ================================================================
// WAVE PAINTER
// ================================================================

class _WavePainter extends CustomPainter {
  final double waveHeight;

  _WavePainter({required this.waveHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height -
          (waveHeight * math.sin(x / 80 + 1.5)) +
          (waveHeight * 0.5 * math.sin(x / 50 + 3.0));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Second wave
    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height -
          (waveHeight * 0.7 * math.sin(x / 60 + 0.5)) +
          (waveHeight * 0.3 * math.sin(x / 40 + 4.0));
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}