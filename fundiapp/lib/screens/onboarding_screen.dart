import 'package:flutter/material.dart';
import '../config/app_routes.dart';
import '../config/app_theme.dart';
import '../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Welcome to NETSAF FUNDI APP',
      description: 'Find trusted technicians near you. Request services like AC repair, plumbing, and more.',
      icon: Icons.handyman_rounded,
      color: AppTheme.primary,
    ),
    OnboardingItem(
      title: 'Search & Connect',
      description: 'Search for skilled fundis in your area, view their profiles, and connect instantly.',
      icon: Icons.search_rounded,
      color: AppTheme.secondary,
    ),
    OnboardingItem(
      title: 'Request & Track',
      description: 'Post service requests, get accepted by a fundi, and track progress in real time.',
      icon: Icons.track_changes_rounded,
      color: AppTheme.accent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Gradient: primary → dark teal (original colors)
    final gradientColors = [
      theme.primaryColor,
      const Color(0xFF0D1F1F), // deep teal (consistent with dark theme)
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ✅ NETSAF Logo at top - ENLARGED
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icons/netsaf.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'NETSAF FUNDI APP',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Technician Network',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onPrimary.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Onboarding Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: _items.map((item) => _OnboardingPage(item: item, theme: theme)).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Navigation
              Padding(
                padding: const EdgeInsets.all(24),
                child: _currentPage == _items.length - 1
                    ? ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    l10n.getStarted,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => _pageController.jumpToPage(_items.length - 1),
                      child: Text(
                        l10n.skip,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        _items.length,
                            (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onPrimary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      icon: Icon(
                        Icons.arrow_forward_rounded,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingItem item;
  final ThemeData theme;

  const _OnboardingPage({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [item.color.withOpacity(0.25), item.color.withOpacity(0.06)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 72,
              color: item.color,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            item.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: theme.colorScheme.onPrimary.withOpacity(0.85),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}