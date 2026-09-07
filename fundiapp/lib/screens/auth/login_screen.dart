// screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../l10n/app_localizations.dart';
import '../../models/country.dart';
import '../../config/country_codes.dart';
import '../../widgets/country_picker.dart';
import '../../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _termsAccepted = false;
  bool _rememberMe = false;
  bool _isEmailLogin = true;

  late final List<Country> _countries;
  late Country _selectedCountry;

  @override
  void initState() {
    super.initState();
    _countries = CountryCodes.all;
    _selectedCountry = _countries.firstWhere(
          (c) => c.dialCode == '+255',
      orElse: () => _countries.first,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept the Terms & Conditions to continue'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    String identifier;
    if (_isEmailLogin) {
      identifier = _emailController.text.trim();
    } else {
      final digits = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final dialCode = _selectedCountry.dialCode.replaceAll('+', '');
      identifier = '$dialCode$digits';
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.login(identifier, _passwordController.text.trim());

    if (!mounted) return;

    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 380;

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
              const Color(0xFF0F1C1A),
              const Color(0xFF122421),
              const Color(0xFF0D1A17),
            ]
                : [
              const Color(0xFFF0F7F5),
              const Color(0xFFE6F2EF),
              const Color(0xFFF5FAF8),
            ],
          ),
        ),
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) => LoadingOverlay(
            isLoading: auth.isLoading,
            child: SafeArea(
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    top: -80,
                    right: -60,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primaryColor.withOpacity(isDark ? 0.08 : 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    left: -80,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primaryColor.withOpacity(isDark ? 0.06 : 0.05),
                      ),
                    ),
                  ),

                  // Main content
                  Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 16 : 22,
                        vertical: 16,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          children: [
                            // Top-right Language + Theme buttons
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ElegantIconButton(
                                    icon: Icons.language_rounded,
                                    tooltip: l10n.language,
                                    onTap: () => _showLanguageSheet(context, settings, l10n),
                                  ),
                                  const SizedBox(width: 8),
                                  _ElegantIconButton(
                                    icon: themeProvider.isDarkMode
                                        ? Icons.dark_mode_rounded
                                        : Icons.light_mode_rounded,
                                    tooltip: 'Theme',
                                    onTap: () => _showThemeSheet(context, themeProvider),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Floating Card
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                isSmall ? 20 : 26,
                                26,
                                isSmall ? 20 : 26,
                                26,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A2A27) : Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                                    blurRadius: 40,
                                    offset: const Offset(0, 16),
                                    spreadRadius: -4,
                                  ),
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Logo
                                    Center(
                                      child: Image.asset(
                                        'assets/images/nearbyfundi-logo.png',
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.contain,
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    Text(
                                      l10n.welcomeBack,
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.6,
                                        fontSize: isSmall ? 24 : 26,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.signInManage,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.hintColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),

                                    const SizedBox(height: 28),

                                    // Email / Phone Toggle
                                    Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => setState(() => _isEmailLogin = true),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 220),
                                                margin: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: _isEmailLogin
                                                      ? theme.primaryColor
                                                      : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(11),
                                                  boxShadow: _isEmailLogin
                                                      ? [
                                                    BoxShadow(
                                                      color: theme.primaryColor.withOpacity(0.28),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    )
                                                  ]
                                                      : null,
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Email',
                                                  style: TextStyle(
                                                    color: _isEmailLogin
                                                        ? Colors.white
                                                        : theme.hintColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => setState(() => _isEmailLogin = false),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 220),
                                                margin: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: !_isEmailLogin
                                                      ? theme.primaryColor
                                                      : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(11),
                                                  boxShadow: !_isEmailLogin
                                                      ? [
                                                    BoxShadow(
                                                      color: theme.primaryColor.withOpacity(0.28),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    )
                                                  ]
                                                      : null,
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Phone',
                                                  style: TextStyle(
                                                    color: !_isEmailLogin
                                                        ? Colors.white
                                                        : theme.hintColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    // Email or Phone field
                                    if (_isEmailLogin)
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: _decoration(
                                          context,
                                          hint: 'you@example.com',
                                          icon: Icons.email_outlined,
                                        ),
                                        validator: (v) =>
                                        v != null && v.contains('@')
                                            ? null
                                            : 'Enter a valid email',
                                      )
                                    else
                                      Row(
                                        children: [
                                          CountryPicker(
                                            selectedCountry: _selectedCountry,
                                            onChanged: (c) =>
                                                setState(() => _selectedCountry = c),
                                            countries: _countries,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _phoneController,
                                              keyboardType: TextInputType.phone,
                                              decoration: _decoration(
                                                context,
                                                hint: '712345678',
                                                icon: Icons.phone_outlined,
                                              ),
                                              validator: (v) {
                                                if (v == null || v.trim().isEmpty) {
                                                  return 'Enter phone number';
                                                }
                                                final digits = v
                                                    .trim()
                                                    .replaceAll(RegExp(r'[^0-9]'), '');
                                                if (digits.length < 7 ||
                                                    digits.length > 15) {
                                                  return '7–15 digits required';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),

                                    const SizedBox(height: 16),

                                    // Password
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: _decoration(
                                        context,
                                        hint: l10n.password,
                                        icon: Icons.lock_outline_rounded,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 22,
                                            color: theme.hintColor,
                                          ),
                                          onPressed: () => setState(
                                                  () => _obscurePassword = !_obscurePassword),
                                        ),
                                      ),
                                      validator: (v) => v != null && v.length >= 6
                                          ? null
                                          : 'Min 6 characters',
                                    ),

                                    const SizedBox(height: 10),

                                    // Remember + Forgot
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (v) =>
                                              setState(() => _rememberMe = v ?? false),
                                          activeColor: theme.primaryColor,
                                          materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        Text(
                                          'Remember me',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () => Navigator.pushNamed(
                                              context, AppRoutes.forgot),
                                          child: Text(
                                            l10n.forgotPassword,
                                            style: TextStyle(
                                              color: theme.primaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    // Terms
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Checkbox(
                                          value: _termsAccepted,
                                          onChanged: (v) => setState(
                                                  () => _termsAccepted = v ?? false),
                                          activeColor: theme.primaryColor,
                                          materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 12),
                                            child: RichText(
                                              text: TextSpan(
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme.colorScheme.onSurface
                                                      .withOpacity(0.75),
                                                ),
                                                children: [
                                                  const TextSpan(text: 'I agree to the '),
                                                  TextSpan(
                                                    text: 'Terms & Conditions',
                                                    style: TextStyle(
                                                      color: theme.primaryColor,
                                                      fontWeight: FontWeight.w700,
                                                      decoration:
                                                      TextDecoration.underline,
                                                    ),
                                                    recognizer: TapGestureRecognizer()
                                                      ..onTap = () =>
                                                          Navigator.pushNamed(
                                                              context, AppRoutes.terms),
                                                  ),
                                                  const TextSpan(text: ' and '),
                                                  TextSpan(
                                                    text: 'Privacy Policy',
                                                    style: TextStyle(
                                                      color: theme.primaryColor,
                                                      fontWeight: FontWeight.w700,
                                                      decoration:
                                                      TextDecoration.underline,
                                                    ),
                                                    recognizer: TapGestureRecognizer()
                                                      ..onTap = () =>
                                                          Navigator.pushNamed(
                                                              context, AppRoutes.privacy),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 26),

                                    CustomButton(
                                      text: l10n.signIn,
                                      onPressed: _handleLogin,
                                      isLoading: auth.isLoading,
                                    ),

                                    const SizedBox(height: 26),

                                    // Sign up
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          l10n.dontHaveAccount,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.hintColor,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            final storedId =
                                            await StorageService.getTechnicianId();
                                            if (storedId != null) {
                                              final auth = context.read<AuthProvider>();
                                              final step = await auth
                                                  .getRegistrationStep(storedId);
                                              if (step != null) {
                                                switch (step) {
                                                  case 1:
                                                    Navigator.pushNamed(
                                                        context, AppRoutes.registerStep1);
                                                    break;
                                                  case 2:
                                                    Navigator.pushNamed(
                                                      context,
                                                      AppRoutes.registerStep2,
                                                      arguments: storedId,
                                                    );
                                                    break;
                                                  case 3:
                                                    Navigator.pushNamed(
                                                      context,
                                                      AppRoutes.registerStep3,
                                                      arguments: storedId,
                                                    );
                                                    break;
                                                  case 4:
                                                    Navigator.pushNamed(
                                                      context,
                                                      AppRoutes.registerStep4,
                                                      arguments: storedId,
                                                    );
                                                    break;
                                                  default:
                                                    Navigator.pushNamed(context,
                                                        AppRoutes.registerStep1);
                                                }
                                                return;
                                              } else {
                                                await StorageService.clearTechnicianData();
                                              }
                                            }
                                            Navigator.pushNamed(
                                                context, AppRoutes.registerStep1);
                                          },
                                          child: Text(
                                            l10n.signUp,
                                            style: TextStyle(
                                              color: theme.primaryColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────── Language Bottom Sheet ─────────────────
  void _showLanguageSheet(
      BuildContext context,
      SettingsProvider settings,
      AppLocalizations l10n,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.language,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                _SheetTile(
                  title: 'English 🇬🇧',
                  selected: settings.locale == 'en',
                  onTap: () async {
                    await settings.updateLocale('en');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 10),
                _SheetTile(
                  title: 'Kiswahili 🇹🇿',
                  selected: settings.locale == 'sw',
                  onTap: () async {
                    await settings.updateLocale('sw');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────── Theme Bottom Sheet ─────────────────
  void _showThemeSheet(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Theme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                _SheetTile(
                  title: 'Light ☀️',
                  selected: !themeProvider.isDarkMode,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.light);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 10),
                _SheetTile(
                  title: 'Dark 🌙',
                  selected: themeProvider.isDarkMode,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.dark);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _decoration(
      BuildContext context, {
        required String hint,
        required IconData icon,
        Widget? suffix,
      }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: theme.primaryColor.withOpacity(0.8)),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : theme.colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}

// ───────────────── Elegant Icon Button ─────────────────
class _ElegantIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ElegantIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.06),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: Theme.of(context).primaryColor),
          ),
        ),
      ),
    );
  }
}

// ───────────────── Sheet Tile ─────────────────
class _SheetTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SheetTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.primaryColor
                  : theme.dividerColor.withOpacity(0.35),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selected) ...[
                Icon(Icons.check_circle_rounded, color: theme.primaryColor, size: 20),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? theme.primaryColor : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}