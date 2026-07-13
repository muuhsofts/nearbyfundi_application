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
      title: 'Welcome to NearbyFundi',
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.primaryColor, theme.primaryColorDark ?? theme.primaryColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: _items.map((item) => _OnboardingPage(item: item, theme: theme)).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(24),
                child: _currentPage == _items.length - 1
                    ? ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.primaryColor,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    l10n.getStarted,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.primaryColor),
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => _pageController.jumpToPage(_items.length - 1),
                      child: Text(l10n.skip, style: TextStyle(color: Colors.white70)),
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
                            color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 80),
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

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  OnboardingItem({required this.title, required this.description, required this.icon, required this.color});
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingItem item;
  final ThemeData theme;
  const _OnboardingPage({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [item.color.withOpacity(0.3), item.color.withOpacity(0.1)]),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 72, color: item.color),
          ),
          const SizedBox(height: 40),
          Text(
            item.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}