import 'package:flutter/material.dart';
import 'package:nearbyfundi/models/service.dart';
import 'package:provider/provider.dart';
import '../../providers/technician_provider.dart';
import '../../providers/service_provider.dart';
import '../../widgets/technician_card.dart';
import '../../config/app_routes.dart';
import '../../l10n/app_localizations.dart';
import 'nearby_map_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _serviceSearchController = TextEditingController();
  final FocusNode _locationFocus = FocusNode();
  final ScrollController _chipScrollController = ScrollController();
  int? _selectedServiceId;
  bool _isSearching = false;
  String _serviceFilterQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _serviceSearchController.dispose();
    _locationFocus.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final place = _locationController.text.trim();
    if (place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a location'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    final techProvider = context.read<TechnicianProvider>();
    setState(() => _isSearching = true);
    techProvider.clearTechnicians();
    await techProvider.searchByPlace(
      place: place,
      serviceId: _selectedServiceId,
      radius: 20,
    );
    if (mounted) setState(() => _isSearching = false);
    _locationFocus.unfocus();
  }

  void _clearAllFilters() {
    _locationController.clear();
    _serviceSearchController.clear();
    setState(() {
      _selectedServiceId = null;
      _serviceFilterQuery = '';
    });
    context.read<TechnicianProvider>().clearTechnicians();
    _locationFocus.unfocus();
  }

  List<Service> _getFilteredServices(List<Service> allServices) {
    if (_serviceFilterQuery.isEmpty) return allServices;
    return allServices.where((s) =>
        s.name.toLowerCase().contains(_serviceFilterQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final techProvider = context.watch<TechnicianProvider>();
    final serviceProvider = context.watch<ServiceProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final filteredServices = _getFilteredServices(serviceProvider.services);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Find Fundi', style: theme.appBarTheme.titleTextStyle),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: true,
        actions: [
          if (techProvider.technicians.isNotEmpty)
            IconButton(
              icon: Icon(Icons.map_rounded, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NearbyMapScreen()),
              ),
              tooltip: 'View on map',
            ),
          if (_locationController.text.isNotEmpty || _selectedServiceId != null)
            IconButton(
              icon: Icon(Icons.clear_all_rounded, color: theme.colorScheme.onSurface),
              onPressed: _clearAllFilters,
              tooltip: 'Clear filters',
            ),
          IconButton(
            icon: techProvider.isLoading
                ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
            )
                : Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
            onPressed: techProvider.isLoading ? null : _performSearch,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Location Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    focusNode: _locationFocus,
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      prefixIcon: Icon(Icons.location_on_rounded, color: theme.primaryColor),
                      suffixIcon: _locationController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: theme.hintColor),
                        onPressed: () {
                          _locationController.clear();
                          setState(() {});
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [theme.primaryColor, theme.primaryColorDark ?? theme.primaryColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _isSearching ? null : _performSearch,
                    icon: _isSearching
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                        : Icon(Icons.search_rounded, color: Colors.white, size: 26),
                    tooltip: 'Search',
                  ),
                ),
              ],
            ),
          ),

          // Service Filter
          if (serviceProvider.services.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: TextField(
                      controller: _serviceSearchController,
                      onChanged: (value) => setState(() => _serviceFilterQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Filter services...',
                        hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: theme.hintColor),
                        suffixIcon: _serviceFilterQuery.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 18, color: theme.hintColor),
                          onPressed: () {
                            _serviceSearchController.clear();
                            setState(() => _serviceFilterQuery = '');
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filteredServices.isNotEmpty)
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        controller: _chipScrollController,
                        children: [
                          _buildChip(
                            label: 'All',
                            isSelected: _selectedServiceId == null,
                            onTap: () => setState(() {
                              _selectedServiceId = null;
                              _serviceSearchController.clear();
                              _serviceFilterQuery = '';
                            }),
                          ),
                          const SizedBox(width: 8),
                          ...filteredServices.map((service) {
                            final isSelected = _selectedServiceId == service.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildChip(
                                label: service.name,
                                isSelected: isSelected,
                                onTap: () => setState(() {
                                  _selectedServiceId = isSelected ? null : service.id;
                                }),
                              ),
                            );
                          }),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'No services match your filter',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                    ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: _buildContent(theme, l10n, techProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? theme.primaryColor : theme.colorScheme.surfaceContainerHighest,
          border: isSelected ? null : Border.all(color: theme.dividerColor),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.primaryColor.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, AppLocalizations l10n, TechnicianProvider techProvider) {
    if (techProvider.isLoading && techProvider.technicians.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (techProvider.error != null) {
      return _buildErrorState(theme, l10n, techProvider);
    }
    if (techProvider.technicians.isEmpty) {
      return _buildEmptyState(theme, l10n);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: techProvider.technicians.length,
      itemBuilder: (ctx, i) {
        final tech = techProvider.technicians[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TechnicianCard(
            technician: tech,
            onTap: () => Navigator.pushNamed(context, AppRoutes.technicianDetail, arguments: tech.id),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, AppLocalizations l10n, TechnicianProvider techProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              techProvider.error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _performSearch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_search_rounded, size: 56, color: theme.primaryColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              'No Fundis Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or location',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (_locationController.text.isNotEmpty || _selectedServiceId != null)
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Clear All Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}