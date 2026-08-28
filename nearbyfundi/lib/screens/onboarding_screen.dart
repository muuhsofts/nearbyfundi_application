// onboarding_screen.dart
// Fully Responsive Onboarding Screen - Supports all screen sizes with scrolling

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

  static const String logoPath = 'assets/images/nearbyfundi-logo.svg';

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

  // ================================================================
  // RESPONSIVE HELPERS
  // ================================================================

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 480;
  }

  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 480 && width < 1024;
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  double _getVisualSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final baseSize = width < height ? width : height;

    if (_isDesktop(context)) {
      return baseSize * 0.45;
    } else if (_isTablet(context)) {
      return baseSize * 0.40;
    } else {
      return baseSize * 0.55;
    }
  }

  EdgeInsets _getPadding(BuildContext context) {
    if (_isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 80, vertical: 20);
    } else if (_isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 40, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 8);
  }

  // Helper to get spacing values
  double _getVerticalSpacing(BuildContext context) {
    if (_isDesktop(context)) {
      return 30.0;
    } else if (_isTablet(context)) {
      return 24.0;
    }
    return 16.0;
  }

  double _getBottomSpacing(BuildContext context) {
    if (_isDesktop(context)) {
      return 20.0;
    } else if (_isTablet(context)) {
      return 16.0;
    }
    return 10.0;
  }

  // Helper to get floating icon sizes
  double _getFloatingIconSize(BuildContext context) {
    if (_isDesktop(context)) {
      return 72.0;
    } else if (_isTablet(context)) {
      return 64.0;
    }
    return 55.0;
  }

  double _getFloatingIconSizeSmall(BuildContext context) {
    if (_isDesktop(context)) {
      return 62.0;
    } else if (_isTablet(context)) {
      return 56.0;
    }
    return 48.0;
  }

  double _getIconSize(BuildContext context) {
    if (_isDesktop(context)) {
      return 36.0;
    } else if (_isTablet(context)) {
      return 32.0;
    }
    return 26.0;
  }

  double _getBadgeSize(BuildContext context) {
    if (_isDesktop(context)) {
      return 56.0;
    } else if (_isTablet(context)) {
      return 50.0;
    }
    return 44.0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isDesktop = _isDesktop(context);
    final isTablet = _isTablet(context);
    final visualSize = _getVisualSize(context);
    final padding = _getPadding(context);

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
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),

          // Animated glow
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              final value = _backgroundController.value * math.pi * 2;

              return Stack(
                children: [
                  Positioned(
                    top: -120 + math.sin(value) * 25,
                    right: -100 + math.cos(value) * 20,
                    child: _buildGlow(340.0, 0.09),
                  ),
                  Positioned(
                    bottom: -150 + math.cos(value) * 30,
                    left: -100 + math.sin(value) * 25,
                    child: _buildGlow(380.0, 0.07),
                  ),
                  Positioned(
                    top: size.height * 0.45,
                    right: -130,
                    child: _buildGlow(250.0, 0.045),
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
                  padding: EdgeInsets.fromLTRB(
                    padding.left,
                    isDesktop ? 24.0 : 18.0,
                    padding.right,
                    8.0,
                  ),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        width: isDesktop ? 56.0 : 48.0,
                        height: isDesktop ? 56.0 : 48.0,
                        padding: EdgeInsets.all(isDesktop ? 11.0 : 9.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isDesktop ? 18.0 : 15.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20.0,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          logoPath,
                          fit: BoxFit.contain,
                        ),
                      ),

                      SizedBox(width: isDesktop ? 16.0 : 12.0),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NearbyFundi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isDesktop ? 24.0 : (isTablet ? 21.0 : 19.0),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'FIND • CONNECT • GET IT DONE',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: isDesktop ? 11.0 : (isTablet ? 9.0 : 8.0),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Skip button
                      if (_currentPage != _items.length - 1)
                        TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 20.0 : 12.0,
                              vertical: isDesktop ? 12.0 : 8.0,
                            ),
                          ),
                          child: Text(
                            l10n.skip,
                            style: TextStyle(
                              fontSize: isDesktop ? 16.0 : (isTablet ? 14.0 : 13.0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ====================================================
                // PAGE VIEW (Scrollable)
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
                        visualSize: visualSize,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        padding: padding,
                        verticalSpacing: _getVerticalSpacing(context),
                        bottomSpacing: _getBottomSpacing(context),
                        floatingIconSize: _getFloatingIconSize(context),
                        floatingIconSizeSmall: _getFloatingIconSizeSmall(context),
                        iconSize: _getIconSize(context),
                        badgeSize: _getBadgeSize(context),
                      );
                    },
                  ),
                ),

                // ====================================================
                // PAGE INDICATOR
                // ====================================================

                Padding(
                  padding: EdgeInsets.only(
                    bottom: isDesktop ? 24.0 : 20.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                          (index) {
                        final active = _currentPage == index;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          width: active ? (isDesktop ? 40.0 : 32.0) : (isDesktop ? 10.0 : 8.0),
                          height: isDesktop ? 9.0 : 7.0,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20.0),
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
                  padding: EdgeInsets.fromLTRB(
                    padding.left,
                    0.0,
                    padding.right,
                    isDesktop ? 32.0 : 24.0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentPage == _items.length - 1
                        ? _buildGetStartedButton(l10n, isDesktop)
                        : _buildNextButton(l10n, isDesktop),
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
  // NEXT BUTTON (Responsive)
  // ================================================================

  Widget _buildNextButton(AppLocalizations l10n, bool isDesktop) {
    return SizedBox(
      key: const ValueKey('next'),
      width: double.infinity,
      height: isDesktop ? 68.0 : 58.0,
      child: ElevatedButton(
        onPressed: _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryGreen,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 22.0 : 18.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: TextStyle(
                fontSize: isDesktop ? 20.0 : 17.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
            SizedBox(width: isDesktop ? 14.0 : 10.0),
            Icon(
              Icons.arrow_forward_rounded,
              size: isDesktop ? 28.0 : 23.0,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // GET STARTED (Responsive)
  // ================================================================

  Widget _buildGetStartedButton(AppLocalizations l10n, bool isDesktop) {
    return SizedBox(
      key: const ValueKey('started'),
      width: double.infinity,
      height: isDesktop ? 68.0 : 58.0,
      child: ElevatedButton(
        onPressed: _getStarted,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryGreen,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 22.0 : 18.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.getStarted,
              style: TextStyle(
                fontSize: isDesktop ? 20.0 : 17.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
            SizedBox(width: isDesktop ? 14.0 : 10.0),
            Icon(
              Icons.arrow_forward_rounded,
              size: isDesktop ? 28.0 : 23.0,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // GLOW
  // ================================================================

  Widget _buildGlow(double size, double opacity) {
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
// ONBOARDING PAGE (Fully Responsive + Scrollable)
// ==================================================================

class _OnboardingPage extends StatelessWidget {
  final OnboardingItem item;
  final Animation<double> animation;
  final Color primaryGreen;
  final Color accentGreen;
  final String logoPath;
  final double visualSize;
  final bool isDesktop;
  final bool isTablet;
  final EdgeInsets padding;
  final double verticalSpacing;
  final double bottomSpacing;
  final double floatingIconSize;
  final double floatingIconSizeSmall;
  final double iconSize;
  final double badgeSize;

  const _OnboardingPage({
    required this.item,
    required this.animation,
    required this.primaryGreen,
    required this.accentGreen,
    required this.logoPath,
    required this.visualSize,
    required this.isDesktop,
    required this.isTablet,
    required this.padding,
    required this.verticalSpacing,
    required this.bottomSpacing,
    required this.floatingIconSize,
    required this.floatingIconSizeSmall,
    required this.iconSize,
    required this.badgeSize,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = _getFontSize();
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ).value;

        final slide = (1 - animation.value) * 35;

        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, slide),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                verticalSpacing,
                padding.right,
                bottomSpacing,
              ),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight * 0.65,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ========================================================
                    // VISUAL AREA (Responsive size)
                    // ========================================================

                    _buildVisual(context),

                    SizedBox(height: isDesktop ? 40.0 : (isTablet ? 34.0 : 30.0)),

                    // ========================================================
                    // TITLE (Responsive)
                    // ========================================================

                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 44.0 : (isTablet ? 36.0 : 28.0),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),

                    SizedBox(height: isDesktop ? 20.0 : (isTablet ? 16.0 : 14.0)),

                    // Green accent
                    Container(
                      width: isDesktop ? 56.0 : 42.0,
                      height: isDesktop ? 5.0 : 4.0,
                      decoration: BoxDecoration(
                        color: accentGreen,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),

                    SizedBox(height: isDesktop ? 24.0 : (isTablet ? 20.0 : 18.0)),

                    // ========================================================
                    // DESCRIPTION (Responsive)
                    // ========================================================

                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 600.0 : (isTablet ? 500.0 : 360.0),
                      ),
                      child: Text(
                        item.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: fontSize,
                          height: 1.55,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    SizedBox(height: isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0)),

                    // ========================================================
                    // BENEFITS (Responsive layout)
                    // ========================================================

                    Wrap(
                      spacing: isDesktop ? 16.0 : 10.0,
                      runSpacing: 10.0,
                      alignment: WrapAlignment.center,
                      children: [
                        _Benefit(
                          icon: Icons.verified_rounded,
                          text: 'Verified',
                          isDesktop: isDesktop,
                        ),
                        _Benefit(
                          icon: Icons.star_rounded,
                          text: 'Trusted',
                          isDesktop: isDesktop,
                        ),
                        _Benefit(
                          icon: Icons.bolt_rounded,
                          text: 'Fast',
                          isDesktop: isDesktop,
                        ),
                        if (isDesktop) ...[
                          _Benefit(
                            icon: Icons.security_rounded,
                            text: 'Secure',
                            isDesktop: isDesktop,
                          ),
                          _Benefit(
                            icon: Icons.support_rounded,
                            text: '24/7',
                            isDesktop: isDesktop,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _getFontSize() {
    if (isDesktop) {
      return 20.0;
    } else if (isTablet) {
      return 18.0;
    }
    return 16.0;
  }

  Widget _buildVisual(BuildContext context) {
    final size = visualSize;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentGreen.withOpacity(0.14),
                  blurRadius: size * 0.24,
                  spreadRadius: 5.0,
                ),
              ],
            ),
          ),

          // Outer ring
          Container(
            width: size * 0.93,
            height: size * 0.93,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.045),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
                width: 1.0,
              ),
            ),
          ),

          // Middle ring
          Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
                width: 1.0,
              ),
            ),
          ),

          // Logo background
          Container(
            width: size * 0.60,
            height: size * 0.60,
            padding: EdgeInsets.all(size * 0.09),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: size * 0.12,
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
            right: size * 0.08,
            top: size * 0.13,
            child: _FloatingIcon(
              icon: item.icon,
              primaryGreen: primaryGreen,
              size: floatingIconSize,
              iconSize: iconSize,
            ),
          ),

          // Secondary icon
          Positioned(
            left: size * 0.08,
            bottom: size * 0.14,
            child: _FloatingIcon(
              icon: item.icon2,
              primaryGreen: primaryGreen,
              size: floatingIconSizeSmall,
              iconSize: iconSize - 4.0,
              small: true,
            ),
          ),

          // Location badge
          Positioned(
            right: size * 0.02,
            bottom: size * 0.13,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: accentGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentGreen.withOpacity(0.35),
                    blurRadius: badgeSize * 0.35,
                  ),
                ],
              ),
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: badgeSize * 0.56,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// FLOATING ICON (Responsive)
// ==================================================================

class _FloatingIcon extends StatelessWidget {
  final IconData icon;
  final Color primaryGreen;
  final double size;
  final double iconSize;
  final bool small;

  const _FloatingIcon({
    required this.icon,
    required this.primaryGreen,
    required this.size,
    required this.iconSize,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: size * 0.35,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: primaryGreen,
        size: iconSize,
      ),
    );
  }
}

// ==================================================================
// BENEFIT (Responsive)
// ==================================================================

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDesktop;

  const _Benefit({
    required this.icon,
    required this.text,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16.0 : 11.0,
        vertical: isDesktop ? 10.0 : 7.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(isDesktop ? 24.0 : 20.0),
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
            size: isDesktop ? 18.0 : 14.0,
          ),
          SizedBox(width: isDesktop ? 8.0 : 5.0),
          Text(
            text,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isDesktop ? 14.0 : 11.0,
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