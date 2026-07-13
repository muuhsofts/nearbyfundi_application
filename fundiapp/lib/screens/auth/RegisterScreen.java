import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';
import '../../config/app_routes.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_overlay.dart';

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
  final _areaController = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Fundi-specific fields
  int? _selectedServiceId;
  List<int> _selectedServiceIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one service'), backgroundColor: AppTheme.error),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    // For simplicity, we'll use dummy lat/lng – you can integrate geocoding here.
    final success = await auth.registerFundi({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'password_confirmation': _confirmController.text.trim(),
      'phone': _phoneController.text.trim(),
      'area': _areaController.text.trim(),
      'latitude': -6.8, // Replace with actual geocoded values
      'longitude': 39.2,
      'service_ids': _selectedServiceIds,
    });

    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(context, AppRoutes.otp, arguments: _emailController.text.trim());
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final services = context.watch<ServiceProvider>();

    return Scaffold(
      body: LoadingOverlay(
        isLoading: auth.isLoading,
        child: Column(
          children: [
            // Top panel (same as other auth screens)
            Expanded(
              flex: 42,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1A1150),
                          AppTheme.primaryColor,
                          AppTheme.secondaryColor,
                        ],
                      ),
                    ),
                  ),
                  Positioned(top: -30, right: -30, child: _buildDecorCircle(140, 0.07)),
                  Positioned(bottom: 30, left: -20, child: _buildDecorCircle(90, 0.05)),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Positioned.fill(
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.person_add_rounded, size: 38, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Become a Fundi',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Join as a service provider',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -1,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, 36),
                      painter: _WavePainter(),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom form
            Expanded(
              flex: 58,
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Fundi Registration',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1150)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fill in your details to start serving customers',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 32),

                        // Full Name
                        _FieldLabel(label: 'Full Name'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(hint: 'Enter your full name', icon: Icons.person_outline_rounded),
                          validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Name is required',
                        ),
                        const SizedBox(height: 20),

                        // Email
                        _FieldLabel(label: 'Email Address'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration(hint: 'you@example.com', icon: Icons.email_outlined),
                          validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                        ),
                        const SizedBox(height: 20),

                        // Phone
                        _FieldLabel(label: 'Phone Number'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(hint: 'Optional', icon: Icons.phone_outlined),
                        ),
                        const SizedBox(height: 20),

                        // Area (for geocoding)
                        _FieldLabel(label: 'Service Area'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _areaController,
                          decoration: _inputDecoration(hint: 'e.g. Ubungo, Dar es Salaam', icon: Icons.location_on_outlined),
                          validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Area is required',
                        ),
                        const SizedBox(height: 20),

                        // Services
                        _FieldLabel(label: 'Select Services'),
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
                                selectedColor: AppTheme.primary,
                                backgroundColor: Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 20),

                        // Password
                        _FieldLabel(label: 'Password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePass,
                          decoration: _inputDecoration(
                            hint: 'Minimum 8 characters',
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 8 ? null : 'Password must be at least 8 characters',
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password
                        _FieldLabel(label: 'Confirm Password'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: _inputDecoration(
                            hint: 'Repeat your password',
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) => v == _passwordController.text ? null : 'Passwords do not match',
                        ),
                        const SizedBox(height: 32),

                        CustomButton(
                          text: 'Register as Fundi',
                          onPressed: _handleRegister,
                        ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account? '),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(fontWeight: FontWeight.bold),
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
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryColor),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF6F5FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0DDF7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0DDF7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }

  Widget _buildDecorCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1A1150), letterSpacing: 0.6),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.75, size.height, size.width, size.height * 0.5);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}