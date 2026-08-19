import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../l10n/app_localizations.dart';
import '../../models/country.dart';
import '../../config/country_codes.dart';
import '../../widgets/country_picker.dart';

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

  // ─── Normal Login ─────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_termsAccepted) {
      _showErrorSnackBar('Please accept the Terms & Conditions to continue');
      return;
    }

    String identifier;
    if (_isEmailLogin) {
      identifier = _emailController.text.trim();
    } else {
      final digits = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      identifier = '${_selectedCountry.dialCode}$digits';
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.login(identifier, _passwordController.text.trim());

    if (!mounted) return;

    if (success) {
      _navigateToHome();
    } else if (auth.errorMessage != null) {
      _showErrorSnackBar(auth.errorMessage!);
    }
  }

  // ─── Google Sign‑In ──────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '217153819583-i53f9rsb46uiid53ikuiv6r68o93qe4s.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to obtain ID token');
      }

      final bool success = await auth.loginWithGoogle(idToken);

      if (success && mounted) {
        _navigateToHome();
      } else if (auth.errorMessage != null && mounted) {
        _showErrorSnackBar(auth.errorMessage!);
      }
    } catch (e) {
      debugPrint('Google sign‑in error: $e');
      if (mounted) {
        _showErrorSnackBar('Google sign‑in failed: $e');
      }
    }
  }

  void _navigateToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Soft modern grey background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) => LoadingOverlay(
                isLoading: auth.isLoading,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Modern Brand Icon ---
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.handyman_rounded,
                              size: 36,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // --- Headings ---
                        Center(
                          child: Text(
                            'NearbyFundi',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            l10n.welcomeBack,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // --- Toggle Email / Phone ---
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'email', label: Text('Email')),
                            ButtonSegment(value: 'phone', label: Text('Phone')),
                          ],
                          selected: {_isEmailLogin ? 'email' : 'phone'},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _isEmailLogin = newSelection.first == 'email';
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F4F8),
                            selectedBackgroundColor: theme.primaryColor.withOpacity(0.15),
                            selectedForegroundColor: theme.primaryColor,
                            foregroundColor: theme.hintColor,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- Email or Phone field ---
                        if (_isEmailLogin)
                          _buildField(
                            context,
                            label: l10n.emailAddress,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(
                                context,
                                hintText: 'you@example.com',
                                prefixIcon: Icons.email_outlined,
                              ),
                              validator: (v) => v != null && v.contains('@')
                                  ? null
                                  : 'Enter a valid email address',
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Phone Number'),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  CountryPicker(
                                    selectedCountry: _selectedCountry,
                                    onChanged: (country) {
                                      setState(() => _selectedCountry = country);
                                    },
                                    countries: _countries,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: _inputDecoration(
                                        context,
                                        hintText: '712345678',
                                        prefixIcon: Icons.phone_outlined,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Enter your phone number';
                                        }
                                        final digits = v.trim().replaceAll(RegExp(r'[^0-9]'), '');
                                        if (digits.length < 7 || digits.length > 15) {
                                          return 'Phone number must be 7–15 digits';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // --- Password ---
                        _buildFieldLabel(l10n.password),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            context,
                            hintText: 'Enter your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: theme.hintColor,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 6
                              ? null
                              : 'Password must be at least 6 characters',
                        ),
                        const SizedBox(height: 12),

                        // --- Remember me & Forgot ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() => _rememberMe = value ?? false);
                                    },
                                    activeColor: theme.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remember me',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.forgot),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                l10n.forgotPassword,
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- Terms ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _termsAccepted,
                                onChanged: (value) {
                                  setState(() => _termsAccepted = value ?? false);
                                },
                                activeColor: theme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms & Conditions',
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                        decorationColor: theme.primaryColor.withOpacity(0.4),
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          Navigator.pushNamed(context, AppRoutes.terms);
                                        },
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                        decorationColor: theme.primaryColor.withOpacity(0.4),
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Privacy Policy page coming soon'),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                              ),
                                            ),
                                          );
                                        },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // --- Sign In Button ---
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: CustomButton(
                            text: l10n.signIn,
                            onPressed: _handleLogin,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- OR Divider ---
                        Row(
                          children: [
                            Expanded(child: Divider(color: theme.hintColor.withOpacity(0.25))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: theme.hintColor.withOpacity(0.25))),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- Google Sign-In Button ---
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _handleGoogleSignIn,
                            icon: Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            label: Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // --- Sign Up Link ---
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
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                l10n.signUp,
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildField(BuildContext context, {required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ─── Redesigned Input Decoration ──────────────────────────────────────
InputDecoration _inputDecoration(
    BuildContext context, {
      required String hintText,
      required IconData prefixIcon,
      Widget? suffixIcon,
    }) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: Colors.grey[500],
      fontWeight: FontWeight.w400,
    ),
    prefixIcon: Icon(prefixIcon, color: theme.hintColor, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF2F4F8), // Premium soft grey fill
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none, // No border by default
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
  );
}