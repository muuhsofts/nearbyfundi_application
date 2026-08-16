// lib/screens/auth/register_flow/register_step1_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../config/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../config/app_routes.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/country.dart';
import '../../../config/country_codes.dart';
import '../../../widgets/country_picker.dart';

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  File? _profilePhoto;
  final ImagePicker _picker = ImagePicker();

  late final List<Country> _countries;
  late Country _selectedCountry;

  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _countries = CountryCodes.all;
    _selectedCountry = _countries.firstWhere(
          (c) => c.dialCode == '+255',
      orElse: () => _countries.first,
    );
    _passwordController.addListener(_updatePasswordStrength);
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

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;
    if (password.length >= 8) strength = 1;
    if (password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      strength = 2;
    }
    if (strength == 2 &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      strength = 3;
    }
    setState(() => _passwordStrength = strength);
  }

  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (picked != null) {
                  setState(() => _profilePhoto = File(picked.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (picked != null) {
                  setState(() => _profilePhoto = File(picked.path));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _nextStep() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profilePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a profile photo'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final digits = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final dialCode = _selectedCountry.dialCode.replaceAll('+', '');
    final fullPhone = '$dialCode$digits';

    final Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'password_confirmation': _confirmController.text.trim(),
      'phone': fullPhone,
      'profile_photo': _profilePhoto!.path,
    };

    final res = await auth.api.registerTechnicianStep1(data);

    if (!mounted) return;

    if (res.success) {
      final technicianId = res.data['technician_id'] as int;
      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {
          'email': _emailController.text.trim(),
          'technicianId': technicianId,
          'redirectToStep2': true,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Step 1: Personal Info'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: LoadingOverlay(
        isLoading: auth.isLoading, // ✅ Full-screen loading indicator
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Photo
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: theme.colorScheme.surface,
                        child: _profilePhoto != null
                            ? ClipOval(child: Image.file(_profilePhoto!, width: 120, height: 120, fit: BoxFit.cover))
                            : Icon(Icons.person_add_alt_rounded, size: 60, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                _buildField(
                  controller: _nameController,
                  hint: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Name required',
                ),
                const SizedBox(height: 16),

                // Email
                _buildField(
                  controller: _emailController,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v != null && v.contains('@') ? null : 'Enter valid email',
                ),
                const SizedBox(height: 16),

                // Phone
                Row(
                  children: [
                    CountryPicker(
                      selectedCountry: _selectedCountry,
                      onChanged: (c) => setState(() => _selectedCountry = c),
                      countries: _countries,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Phone number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
                          if (cleaned.length >= 7 && cleaned.length <= 12) return null;
                          return 'Enter a valid phone number';
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Password with strength
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField(
                      controller: _passwordController,
                      hint: 'Password (min 8 chars)',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePass,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) => v != null && v.length >= 8 ? null : 'Password must be ≥8 chars',
                    ),
                    const SizedBox(height: 6),
                    if (_passwordController.text.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: _passwordStrength >= 1
                                    ? (_passwordStrength >= 2
                                    ? (_passwordStrength >= 3 ? Colors.green : Colors.orange)
                                    : Colors.red)
                                    : Colors.grey.shade300,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _passwordStrength == 0
                                ? 'Too short'
                                : _passwordStrength == 1
                                ? 'Weak'
                                : _passwordStrength == 2
                                ? 'Medium'
                                : 'Strong',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _passwordStrength == 0
                                  ? Colors.grey
                                  : _passwordStrength == 1
                                  ? Colors.red
                                  : _passwordStrength == 2
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),

                // Confirm Password
                _buildField(
                  controller: _confirmController,
                  hint: 'Confirm Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) => v == _passwordController.text ? null : 'Passwords do not match',
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Next →',
                  onPressed: _nextStep,
                  isLoading: auth.isLoading, // ✅ Button shows spinner inside it
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodySmall,
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.5)),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }
}