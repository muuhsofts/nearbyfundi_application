import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../l10n/app_localizations.dart';
import '../../models/country.dart';
import '../../config/country_codes.dart';
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
  final _phoneController = TextEditingController(); // digits only
  final _nidaController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _areaController = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  List<int> _selectedServiceIds = [];
  File? _profilePhoto;
  final ImagePicker _picker = ImagePicker();

  // Country picker – using static config
  late final List<Country> _countries;
  late Country _selectedCountry;

  @override
  void initState() {
    super.initState();
    _countries = CountryCodes.all; // no cast needed
    _selectedCountry = _countries.firstWhere(
          (c) => c.dialCode == '+255',
      orElse: () => _countries.first,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nidaController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _profilePhoto = File(picked.path));
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (_profilePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a profile photo'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    // ✅ Build full phone number without '+'
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final dialCode = _selectedCountry.dialCode.replaceAll('+', '');
    final fullPhone = '$dialCode$digits';

    final Map<String, dynamic> formData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'password_confirmation': _confirmController.text.trim(),
      'phone': fullPhone,
      'nida': _nidaController.text.trim(),
      'area': _areaController.text.trim(),
      'service_ids': _selectedServiceIds,
      'profile_photo': _profilePhoto!.path,
    };

    final success = await auth.registerFundi(formData);

    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(context, AppRoutes.otp,
          arguments: _emailController.text.trim());
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final services = context.watch<ServiceProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('NearbyFundi'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: LoadingOverlay(
        isLoading: auth.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // Profile Photo
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: theme.colorScheme.surface,
                        child: _profilePhoto != null
                            ? ClipOval(
                          child: Image.file(
                            _profilePhoto!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                            : Icon(
                          Icons.person_add_alt_rounded,
                          size: 60,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
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
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _profilePhoto == null
                        ? 'Tap camera to add photo'
                        : 'Profile photo selected',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                _buildField(
                  controller: _nameController,
                  hint: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Name required',
                ),
                const SizedBox(height: 16),

                // Email
                _buildField(
                  controller: _emailController,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                  v != null && v.contains('@') ? null : 'Enter valid email',
                ),
                const SizedBox(height: 16),

                // Phone with Country Picker (static)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CountryPicker(
                          selectedCountry: _selectedCountry,
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
                            style: theme.textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'Phone number',
                              hintStyle: theme.textTheme.bodySmall,
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
                  ],
                ),
                const SizedBox(height: 16),

                // NIDA
                _buildField(
                  controller: _nidaController,
                  hint: 'NIDA Number (20 digits)',
                  icon: Icons.badge_outlined,
                  validator: (v) =>
                  v != null && v.length == 20 ? null : 'NIDA must be 20 digits',
                ),
                const SizedBox(height: 16),

                // Service Area
                _buildField(
                  controller: _areaController,
                  hint: 'Service Area (e.g. Ubungo, Dar)',
                  icon: Icons.location_on_outlined,
                  validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Area required',
                ),
                const SizedBox(height: 16),

                // Services Selection
                Text(
                  'Select Services',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (services.isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services.services.map((service) {
                      final isSelected = _selectedServiceIds.contains(service.id);
                      return ChoiceChip(
                        label: Text(service.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedServiceIds.add(service.id);
                            } else {
                              _selectedServiceIds.remove(service.id);
                            }
                          });
                        },
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surface,
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),

                // Password
                _buildField(
                  controller: _passwordController,
                  hint: 'Password (min 8 chars)',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) =>
                  v != null && v.length >= 8 ? null : 'Password must be ≥8 chars',
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _confirmController,
                  hint: 'Confirm Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) =>
                  v == _passwordController.text ? null : 'Passwords do not match',
                ),
                const SizedBox(height: 32),

                // Register Button
                CustomButton(
                  text: l10n.registerAsFundi,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
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