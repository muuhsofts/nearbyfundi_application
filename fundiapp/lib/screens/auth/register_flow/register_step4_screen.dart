// lib/screens/auth/register_flow/register_step4_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/service_provider.dart';
import '../../../config/app_routes.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_overlay.dart';

class RegisterStep4Screen extends StatefulWidget {
  final int technicianId;
  const RegisterStep4Screen({super.key, required this.technicianId});

  @override
  State<RegisterStep4Screen> createState() => _RegisterStep4ScreenState();
}

class _RegisterStep4ScreenState extends State<RegisterStep4Screen> {
  final Map<int, Map<String, TextEditingController>> _priceControllers = {};
  final Set<int> _selectedServiceIds = {};

  @override
  void initState() {
    super.initState();
    // ✅ Fetch services as soon as the screen loads (matching the old RegisterScreen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    for (var controllers in _priceControllers.values) {
      controllers['min']?.dispose();
      controllers['max']?.dispose();
    }
    super.dispose();
  }

  void _toggleService(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedServiceIds.add(id);
        _priceControllers[id] = {
          'min': TextEditingController(),
          'max': TextEditingController(),
        };
      } else {
        _selectedServiceIds.remove(id);
        _priceControllers[id]?.forEach((key, c) => c.dispose());
        _priceControllers.remove(id);
      }
    });
  }

  Future<void> _nextStep() async {
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    // Validate prices
    for (var id in _selectedServiceIds) {
      final min = double.tryParse(_priceControllers[id]!['min']!.text.trim());
      final max = double.tryParse(_priceControllers[id]!['max']!.text.trim());
      if (min == null || max == null || min < 0 || max < 0 || max < min) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid price range for a selected service'), backgroundColor: AppTheme.error),
        );
        return;
      }
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final List<Map<String, dynamic>> services = [];
    for (var id in _selectedServiceIds) {
      services.add({
        'service_id': id,
        'min_price': double.parse(_priceControllers[id]!['min']!.text.trim()),
        'max_price': double.parse(_priceControllers[id]!['max']!.text.trim()),
      });
    }

    final res = await auth.api.registerTechnicianStep4(
      technicianId: widget.technicianId,
      services: services,
    );

    if (!mounted) return;

    if (res.success) {
      final Map<String, dynamic> reviewData = {
        'technicianId': widget.technicianId,
        'services': services,
      };
      Navigator.pushNamed(context, AppRoutes.registerReview, arguments: reviewData);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final serviceProvider = context.watch<ServiceProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Step 4: Services & Pricing'), centerTitle: true, elevation: 0),
      body: LoadingOverlay(
        isLoading: auth.isLoading || serviceProvider.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Select services and set your price ranges:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              if (serviceProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (serviceProvider.services.isEmpty)
                const Center(child: Text('No services available. Please try again later.'))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: serviceProvider.services.map((service) {
                    final isSelected = _selectedServiceIds.contains(service.id);
                    return ChoiceChip(
                      label: Text(service.name),
                      selected: isSelected,
                      onSelected: (selected) => _toggleService(service.id, selected),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    );
                  }).toList(),
                ),

              // Show price inputs for selected services
              if (_selectedServiceIds.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Set price ranges for selected services:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ..._selectedServiceIds.map((id) {
                  final service = serviceProvider.services.firstWhere((s) => s.id == id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceControllers[id]!['min'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Min Price (TZS)',
                                  prefixText: 'TZS ',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _priceControllers[id]!['max'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Max Price (TZS)',
                                  prefixText: 'TZS ',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              const SizedBox(height: 32),

              CustomButton(
                text: 'Review & Submit',
                onPressed: _nextStep,
                isLoading: auth.isLoading || serviceProvider.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}