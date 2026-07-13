import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../l10n/app_localizations.dart';
import '../../models/country.dart';
import '../../config/country_codes.dart';  // <-- import the config
import '../../widgets/country_picker.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _termsAccepted = false;

  // Country picker – use the config list directly
  late List<Country> _countries;
  Country? _selectedCountry;

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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // ... (unchanged)
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('NearbyFundi'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) => LoadingOverlay(
          isLoading: auth.isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Optional small icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.createAccount,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.joinCommunity,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Full Name
                  _buildFieldLabel(l10n.fullName),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration(
                      context,
                      hintText: 'Enter your full name',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    validator: (v) => v != null && v.trim().isNotEmpty
                        ? null
                        : 'Full name is required',
                  ),
                  const SizedBox(height: 18),

                  // Email
                  _buildFieldLabel(l10n.emailAddress),
                  const SizedBox(height: 6),
                  TextFormField(
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
                  const SizedBox(height: 18),

                  // Phone Number with country picker (now no loading)
                  _buildFieldLabel(l10n.phoneNumber),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CountryPicker(
                        selectedCountry: _selectedCountry!,
                        onChanged: (country) {
                          setState(() => _selectedCountry = country);
                        },
                        countries: _countries,
                      ),
                      const SizedBox(width: 8),
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
                              return 'Phone number is required';
                            }
                            final digits = v.trim().replaceAll(RegExp(r'[^0-9]'), '');
                            if (digits.length < 7 || digits.length > 15) {
                              return 'Phone must be 7–15 digits';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Password
                  _buildFieldLabel(l10n.password),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePass,
                    decoration: _inputDecoration(
                      context,
                      hintText: 'Minimum 8 characters',
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: theme.hintColor,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    validator: (v) => v != null && v.length >= 8
                        ? null
                        : 'Password must be at least 8 characters',
                  ),
                  const SizedBox(height: 18),

                  // Confirm Password
                  _buildFieldLabel(l10n.confirmPassword),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    decoration: _inputDecoration(
                      context,
                      hintText: 'Repeat your password',
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: theme.hintColor,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) => v == _passwordController.text
                        ? null
                        : 'Passwords do not match',
                  ),
                  const SizedBox(height: 20),

                  // Terms (unchanged)
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
                  const SizedBox(height: 28),

                  // Sign Up
                  CustomButton(
                    text: l10n.signUp,
                    onPressed: _handleRegister,
                  ),
                  const SizedBox(height: 20),

                  // Sign In Link
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
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.signIn,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        letterSpacing: 0.8,
      ),
    );
  }
}

// ---- Reuse the input decoration ----
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
      color: theme.hintColor.withOpacity(0.7),
      fontWeight: FontWeight.w400,
    ),
    prefixIcon: Icon(prefixIcon, color: theme.primaryColor.withOpacity(0.7), size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: theme.colorScheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.primaryColor, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red, width: 1.8),
    ),
  );
}