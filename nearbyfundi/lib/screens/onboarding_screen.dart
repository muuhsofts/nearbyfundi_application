// onboarding_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_routes.dart';
import '../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF006B5E);
  static const Color darkGreen = Color(0xFF003D35);
  static const Color accentGreen = Color(0xFF00B894);

  static const String logoPath =
      'assets/images/nearbyfundi-logo.svg';

  final PageController _pageController = PageController();

  int _currentPage = 0;

  late AnimationController _backgroundController;
  late AnimationController _contentController;

  final List<OnboardingItem> _items = const [
    OnboardingItem(
      title: 'Find Fundis',
      description:
      'Discover trusted and verified technicians offering quality services near you.',
      icon: Icons.handyman_rounded,
      icon2: Icons.location_on_rounded,
    ),
    OnboardingItem(
      title: 'Connect Fast',
      description:
      'Browse technician profiles, check ratings and connect with the right professional.',
      icon: Icons.people_alt_rounded,
      icon2: Icons.chat_bubble_rounded,
    ),
    OnboardingItem(
      title: 'Get It Done',
      description:
      'Send your request, get accepted and follow your service from start to finish.',
      icon: Icons.task_alt_rounded,
      icon2: Icons.route_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _contentController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _backgroundController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _changePage(int index) {
    if (index == _currentPage) return;

    _contentController.reset();

    setState(() {
      _currentPage = index;
    });

    _contentController.forward();
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skip() {
    _pageController.animateToPage(
      _items.length - 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _getStarted() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: darkGreen,
      body: Stack(
        children: [
          // ==========================================================
          // BACKGROUND
          // ==========================================================

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF002F29),
                  Color(0xFF00574D),
                  Color(0xFF006B5E),
                  Color(0xFF00483F),
                ],
                stops: [
                  0.0,
                  0.35,
                  0.70,
                  1.0,
                ],
              ),
            ),
          ),

          // Animated glow
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              final value =
                  _backgroundController.value * math.pi * 2;

              return Stack(
                children: [
                  Positioned(
                    top: -120 + math.sin(value) * 25,
                    right: -100 + math.cos(value) * 20,
                    child: _buildGlow(
                      340,
                      0.09,
                    ),
                  ),
                  Positioned(
                    bottom: -150 + math.cos(value) * 30,
                    left: -100 + math.sin(value) * 25,
                    child: _buildGlow(
                      380,
                      0.07,
                    ),
                  ),
                  Positioned(
                    top: size.height * 0.45,
                    right: -130,
                    child: _buildGlow(
                      250,
                      0.045,
                    ),
                  ),
                ],
              );
            },
          ),

          // ==========================================================
          // CONTENT
          // ==========================================================

          SafeArea(
            child: Column(
              children: [
                // ====================================================
                // TOP BAR
                // ====================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    18,
                    24,
                    8,
                  ),
                  child: Row(
                    children: [
                      // Small logo
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          logoPath,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(width: 12),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NearbyFundi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'FIND • CONNECT • GET IT DONE',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Skip
                      if (_currentPage != _items.length - 1)
                        TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            l10n.skip,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ====================================================
                // PAGE VIEW
                // ====================================================

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: _changePage,
                    itemBuilder: (context, index) {
                      return _OnboardingPage(
                        item: _items[index],
                        animation: _contentController,
                        primaryGreen: primaryGreen,
                        accentGreen: accentGreen,
                        logoPath: logoPath,
                      );
                    },
                  ),
                ),

                // ====================================================
                // PAGE INDICATOR
                // ====================================================

                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                          (index) {
                        final active =
                            _currentPage == index;

                        return AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 350,
                          ),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          width: active ? 32 : 8,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withOpacity(0.25),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ====================================================
                // BOTTOM BUTTON
                // ====================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    24,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 300,
                    ),
                    child: _currentPage ==
                        _items.length - 1
                        ? _buildGetStartedButton(
                      l10n,
                    )
                        : _buildNextButton(
                      l10n,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // NEXT BUTTON
  // ================================================================

  Widget _buildNextButton(
      AppLocalizations l10n,
      ) {
    return SizedBox(
      key: const ValueKey('next'),
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryGreen,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_rounded,
              size: 23,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // GET STARTED
  // ================================================================

  Widget _buildGetStartedButton(
      AppLocalizations l10n,
      ) {
    return SizedBox(
      key: const ValueKey('started'),
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _getStarted,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryGreen,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.getStarted,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 23,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // GLOW
  // ================================================================

  Widget _buildGlow(
      double size,
      double opacity,
      ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// ONBOARDING PAGE
// ==================================================================

class _OnboardingPage extends StatelessWidget {
  final OnboardingItem item;
  final Animation<double> animation;
  final Color primaryGreen;
  final Color accentGreen;
  final String logoPath;

  const _OnboardingPage({
    required this.item,
    required this.animation,
    required this.primaryGreen,
    required this.accentGreen,
    required this.logoPath,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ).value;

        final slide =
            (1 - animation.value) * 35;

        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, slide),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          12,
          24,
          8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ========================================================
            // VISUAL AREA
            // ========================================================

            _buildVisual(),

            const SizedBox(height: 34),

            // ========================================================
            // TITLE
            // ========================================================

            Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),

            const SizedBox(height: 14),

            // Green accent
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: accentGreen,
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 18),

            // ========================================================
            // DESCRIPTION
            // ========================================================

            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 360,
              ),
              child: Text(
                item.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 16,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ========================================================
            // BENEFITS
            // ========================================================

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Benefit(
                  icon: Icons.verified_rounded,
                  text: 'Verified',
                ),
                const SizedBox(width: 10),
                _Benefit(
                  icon: Icons.star_rounded,
                  text: 'Trusted',
                ),
                const SizedBox(width: 10),
                _Benefit(
                  icon: Icons.bolt_rounded,
                  text: 'Fast',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisual() {
    return SizedBox(
      width: 290,
      height: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentGreen.withOpacity(0.14),
                  blurRadius: 70,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Outer ring
          Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.045),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
                width: 1,
              ),
            ),
          ),

          // Middle ring
          Container(
            width: 225,
            height: 225,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
                width: 1,
              ),
            ),
          ),

          // Logo background
          Container(
            width: 175,
            height: 175,
            padding: const EdgeInsets.all(27),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 35,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: SvgPicture.asset(
              logoPath,
              fit: BoxFit.contain,
            ),
          ),

          // Feature icon
          Positioned(
            right: 20,
            top: 38,
            child: _FloatingIcon(
              icon: item.icon,
              primaryGreen: primaryGreen,
            ),
          ),

          // Secondary icon
          Positioned(
            left: 22,
            bottom: 40,
            child: _FloatingIcon(
              icon: item.icon2,
              primaryGreen: primaryGreen,
              small: true,
            ),
          ),

          // Location badge
          Positioned(
            right: 5,
            bottom: 38,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentGreen.withOpacity(0.35),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// FLOATING ICON
// ==================================================================

class _FloatingIcon extends StatelessWidget {
  final IconData icon;
  final Color primaryGreen;
  final bool small;

  const _FloatingIcon({
    required this.icon,
    required this.primaryGreen,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 55.0 : 64.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: primaryGreen,
        size: small ? 26 : 31,
      ),
    );
  }
}

// ==================================================================
// BENEFIT
// ==================================================================

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Benefit({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.09),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// MODEL
// ==================================================================

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final IconData icon2;

  const OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.icon2,
  });
}