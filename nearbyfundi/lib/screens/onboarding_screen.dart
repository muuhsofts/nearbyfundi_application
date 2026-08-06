import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Custom green color
  static const Color primaryGreen = Color(0xFF006B5E);

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Find Trusted Fundis',
      description: 'Connect with verified technicians near you. Get quality services for AC repair, plumbing, and more.',
      icon: Icons.handyman_rounded,
      color: primaryGreen,
    ),
    OnboardingItem(
      title: 'Search & Connect',
      description: 'Browse through skilled professionals, view their experience, and connect with the right expert.',
      icon: Icons.search_rounded,
      color: primaryGreen,
    ),
    OnboardingItem(
      title: 'Find via Map',
      description: 'Discover fundis and services in your area using the map feature. Find the nearest professionals with ease.',
      icon: Icons.map_rounded,
      color: primaryGreen,
      isMapsPage: true,
    ),
    OnboardingItem(
      title: 'Request & Track',
      description: 'Post a service request, get accepted by a fundi, and track the progress in real-time.',
      icon: Icons.track_changes_rounded,
      color: primaryGreen,
    ),
  ];

  // Exit app confirmation
  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.exit_to_app_rounded,
              color: primaryGreen,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Exit App?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit the app?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Exit',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryGreen,
                primaryGreen.withOpacity(0.85),
                const Color(0xFF004D44),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // NearbyFundi Text at the top
                Padding(
                  padding: const EdgeInsets.only(top: 30.0),
                  child: Text(
                    'NearbyFundi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: _items.map((item) => _OnboardingPage(
                      item: item,
                      theme: theme,
                      primaryGreen: primaryGreen,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _currentPage == _items.length - 1
                      ? Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: primaryGreen,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.getStarted,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryGreen,
                            size: 22,
                          ),
                        ],
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
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(
                          _items.length,
                              (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: _currentPage == index ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: _currentPage == index
                                  ? LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.8),
                                ],
                              )
                                  : null,
                              color: _currentPage == index
                                  ? null
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: _currentPage == index
                                  ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                                  : [],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: TextButton(
                          onPressed: () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
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
  final bool isMapsPage;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isMapsPage = false,
  });
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingItem item;
  final ThemeData theme;
  final Color primaryGreen;

  const _OnboardingPage({
    required this.item,
    required this.theme,
    required this.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    final isMapsPage = item.isMapsPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Netsaf Logo or Map Icon in circular white card (no shadow)
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isMapsPage
                    ? primaryGreen.withOpacity(0.5)
                    : Colors.white.withOpacity(0.3),
                width: isMapsPage ? 3 : 2,
              ),
            ),
            child: Center(
              child: isMapsPage
                  ? Icon(
                Icons.map_rounded,
                color: primaryGreen,
                size: 80,
              )
                  : Image.asset(
                'assets/icons/netsaf.png',
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      item.icon,
                      color: Colors.white,
                      size: 60,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Title with gradient effect
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              item.title,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              height: 1.6,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (isMapsPage) ...[
            const SizedBox(height: 20),
            // Map feature explanation card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // How to use map feature
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'How the map feature works',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '1',
                    'View fundis on the map',
                    'See all available technicians in your area on an interactive map',
                  ),
                  _buildStep(
                    '2',
                    'Find nearby services',
                    'Discover technicians offering AC repair, plumbing, and more services near you',
                  ),
                  _buildStep(
                    '3',
                    'Connect instantly',
                    'Tap on any fundi to view their profile and connect with them directly',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),
          // Feature indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: isMapsPage
                ? [
              _buildFeatureIndicator(Icons.location_on_rounded, 'Locate'),
              const SizedBox(width: 16),
              _buildFeatureIndicator(Icons.search_rounded, 'Find'),
              const SizedBox(width: 16),
              _buildFeatureIndicator(Icons.connect_without_contact_rounded, 'Connect'),
            ]
                : [
              _buildFeatureIndicator(Icons.verified_rounded, 'Verified'),
              const SizedBox(width: 16),
              _buildFeatureIndicator(Icons.star_rounded, 'Trusted'),
              const SizedBox(width: 16),
              _buildFeatureIndicator(Icons.support_agent_rounded, 'Support'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIndicator(IconData icon, String label) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.4),
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}