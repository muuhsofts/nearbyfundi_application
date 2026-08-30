// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _cardController;

  final List<OnboardingItem> _items = [
    const OnboardingItem(
      title: 'Expert Technicians',
      subtitle: 'At Your Fingertips',
      description:
      'Discover verified professionals in your area. From AC repair to plumbing, find the right expert for every job.',
      icon: Icons.engineering_rounded,
      color: AppTheme.primary,
      gradientColors: [Color(0xFF075E54), Color(0xFF0A8A6D)],
    ),
    OnboardingItem(
      title: 'Instant Connection',
      subtitle: 'No More Waiting',
      description:
      'Connect with available fundis in seconds. Share details, get quotes, and start your service immediately.',
      icon: Icons.flash_on_rounded,
      color: AppTheme.success,
      gradientColors: [const Color(0xFF00A896), const Color(0xFF21AE8C)],
    ),
    OnboardingItem(
      title: 'Track & Trust',
      subtitle: 'Complete Transparency',
      description:
      'Monitor progress in real-time. Secure payments, quality assurance, and verified reviews build trust.',
      icon: Icons.shield_rounded,
      color: AppTheme.secondary,
      gradientColors: [const Color(0xFFF5A623), const Color(0xFFF7B731)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage == _items.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
      _cardController.reset();
      _cardController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryColor; // Using static getter

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
              const Color(0xFF0A0E1A),
              const Color(0xFF151B2E),
              const Color(0xFF0D1520),
            ]
                : [
              const Color(0xFFE8EDF9),
              const Color(0xFFD5DEEF),
              const Color(0xFFF0F4FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.15),
                            AppTheme.success.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.15),
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/nearbyfundi-logo.png',
                        width: 28,
                        height: 28,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.build, size: 28, color: primaryColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby Fundi',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1A1F35),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'TECHNICIAN NETWORK',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_currentPage < 2)
                      TextButton(
                        onPressed: () => _pageController.jumpToPage(2),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _cardController.reset();
                    _cardController.forward();
                  },
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return _OnboardingCard(
                      item: _items[index],
                      isActive: index == _currentPage,
                      animation: _cardController,
                      isDark: isDark,
                    );
                  },
                ),
              ),

              // Bottom controls
              Container(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                child: Column(
                  children: [
                    // Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _items.length,
                            (index) {
                          final isActive = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 40 : 8,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? LinearGradient(
                                colors: [
                                  _items[index].gradientColors[0],
                                  _items[index].gradientColors[1],
                                ],
                              )
                                  : null,
                              color: isActive
                                  ? null
                                  : (isDark
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _currentPage > 0
                                  ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOutCubic,
                                );
                              }
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? Colors.white.withOpacity(0.6)
                                    : Colors.black.withOpacity(0.4),
                                side: BorderSide(
                                  color: (isDark
                                      ? Colors.white
                                      : Colors.black).withOpacity(0.15),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: isDark
                                    ? Colors.white.withOpacity(0.6)
                                    : Colors.black.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _onNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor, // Using primaryColor
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == _items.length - 1
                                        ? 'Get Started'
                                        : 'Continue',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_currentPage != _items.length - 1) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final OnboardingItem item;
  final bool isActive;
  final AnimationController animation;
  final bool isDark;

  const _OnboardingCard({
    required this.item,
    required this.isActive,
    required this.animation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = AppTheme.primaryColor;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ]
                    : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.4)
                      : primaryColor.withOpacity(0.08), // Using primaryColor
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              item.color.withOpacity(isDark ? 0.2 : 0.15),
                              item.color.withOpacity(isDark ? 0.05 : 0.03),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.5, 1],
                          ),
                        ),
                      ),
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.color.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                      ),
                      _buildRotatingRing(item.color),
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              item.gradientColors[0]
                                  .withOpacity(isDark ? 0.3 : 0.2),
                              item.gradientColors[1]
                                  .withOpacity(isDark ? 0.15 : 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: item.color.withOpacity(0.2),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          item.icon,
                          size: 50,
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Text content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontSize: 26,
                          color: isDark ? Colors.white : const Color(0xFF1A1F35),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              item.gradientColors[0].withOpacity(0.15),
                              item.gradientColors[1].withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: item.color,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        item.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black.withOpacity(0.6),
                          height: 1.6,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Feature chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildFeatureChip('✓ Verified', item.gradientColors[0]),
                    _buildFeatureChip('★ Rated', item.gradientColors[1]),
                    _buildFeatureChip('⚡ Fast', item.gradientColors[0]),
                    _buildFeatureChip('🔒 Secure', item.gradientColors[1]),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotatingRing(Color color) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 20),
      builder: (context, value, _) {
        return Transform.rotate(
          angle: value * 2 * 3.14159,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.08),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(isDark ? 0.15 : 0.1),
            color.withOpacity(isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;

  const OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradientColors,
  });
}