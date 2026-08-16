// lib/screens/auth/register_flow/register_step2_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../config/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../config/app_routes.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_overlay.dart';

class RegisterStep2Screen extends StatefulWidget {
  final int technicianId;
  const RegisterStep2Screen({super.key, required this.technicianId});

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nidaController = TextEditingController();
  String _idType = 'nida'; // 'nida', 'drivers_license', 'voter_id'
  File? _idImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nidaController.dispose();
    super.dispose();
  }

  Future<void> _pickIdImage() async {
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
                  imageQuality: 80,
                );
                if (picked != null) {
                  setState(() => _idImage = File(picked.path));
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
                  imageQuality: 80,
                );
                if (picked != null) {
                  setState(() => _idImage = File(picked.path));
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
    if (_idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your ID document'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final res = await auth.api.registerTechnicianStep2(
      technicianId: widget.technicianId,
      nida: _nidaController.text.trim(),
      idDocumentType: _idType,
      idDocumentImage: _idImage!,
    );

    if (!mounted) return;

    if (res.success) {
      Navigator.pushNamed(context, AppRoutes.registerStep3, arguments: widget.technicianId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Step 2: Identification'), centerTitle: true, elevation: 0),
      body: LoadingOverlay(
        isLoading: auth.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ID Document Image with Camera/Gallery options
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 160,
                        height: 100,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: _idImage != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_idImage!, fit: BoxFit.cover),
                        )
                            : const Center(child: Text('Tap to upload ID')),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _pickIdImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // NIDA with character counter
                TextFormField(
                  controller: _nidaController,
                  maxLength: 20, // ✅ Shows counter (e.g., 5/20)
                  decoration: InputDecoration(
                    hintText: 'NIDA Number (20 digits)',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => v != null && v.length == 20 ? null : 'NIDA must be 20 digits',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // ID Type Dropdown
                DropdownButtonFormField<String>(
                  value: _idType,
                  items: const [
                    DropdownMenuItem(value: 'nida', child: Text('NIDA')),
                    DropdownMenuItem(value: 'drivers_license', child: Text('Driver\'s License')),
                    DropdownMenuItem(value: 'voter_id', child: Text('Voter\'s ID (KURA)')),
                  ],
                  onChanged: (val) => setState(() => _idType = val!),
                  decoration: const InputDecoration(
                    hintText: 'Select ID Type',
                    prefixIcon: Icon(Icons.assignment_ind_outlined),
                  ),
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Next →',
                  onPressed: _nextStep,
                  isLoading: auth.isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}