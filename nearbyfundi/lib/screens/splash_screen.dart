import 'package:flutter/material.dart';
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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    final auth = context.read<AuthProvider>();
    await Future.delayed(const Duration(seconds: 2));
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.primaryColor, theme.primaryColorDark ?? theme.primaryColor],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.colorScheme.secondary, theme.primaryColor]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 10))],
                ),
                child: const Icon(Icons.handyman_rounded, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.appTitle,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeFundi,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}