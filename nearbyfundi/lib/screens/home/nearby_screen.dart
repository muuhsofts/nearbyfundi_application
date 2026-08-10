// screens/home/nearby_screen.dart (Add language support)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/service.dart';
import '../../providers/technician_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/settings_provider.dart';
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
  final ScrollController _serviceChipScrollController = ScrollController();
  final ScrollController _categoryChipScrollController = ScrollController();

  int? _selectedServiceId;
  int? _selectedCategoryId;
  bool _isSearching = false;
  String _serviceSearchQuery = '';
  String _currentLocale = 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _currentLocale = settings.locale;
      context.read<ServiceProvider>().fetchServices(locale: _currentLocale);
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _serviceSearchController.dispose();
    _locationFocus.dispose();
    _serviceChipScrollController.dispose();
    _categoryChipScrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final place = _locationController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    if (place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterLocation),
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
      categoryId: _selectedCategoryId,
      radius: 20,
      search: _serviceSearchQuery.isNotEmpty ? _serviceSearchQuery : null,
      locale: _currentLocale,
    );

    if (mounted) setState(() => _isSearching = false);
    _locationFocus.unfocus();
  }

  void _clearAllFilters() {
    _locationController.clear();
    _serviceSearchController.clear();
    setState(() {
      _selectedServiceId = null;
      _selectedCategoryId = null;
      _serviceSearchQuery = '';
    });
    context.read<TechnicianProvider>().clearTechnicians();
    _locationFocus.unfocus();
  }

  List<Service> _getFilteredServices(List<Service> allServices) {
    if (_serviceSearchQuery.isEmpty) return allServices;
    final lowerQuery = _serviceSearchQuery.toLowerCase().trim();
    return allServices.where((service) =>
        service.matchesSearch(lowerQuery, _currentLocale)
    ).toList();
  }

  List<ServiceCategory> _getCategoriesForSelectedService(ServiceProvider provider) {
    if (_selectedServiceId == null) return [];
    return provider.getCategoriesForService(_selectedServiceId!);
  }

  @override
  Widget build(BuildContext context) {
    final techProvider = context.watch<TechnicianProvider>();
    final serviceProvider = context.watch<ServiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Update locale if changed
    if (_currentLocale != settings.locale) {
      _currentLocale = settings.locale;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ServiceProvider>().fetchServices(locale: _currentLocale);
      });
    }

    final filteredServices = _getFilteredServices(serviceProvider.localizedServices);
    final categories = _getCategoriesForSelectedService(serviceProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.findFundi, style: theme.appBarTheme.titleTextStyle),
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
              tooltip: l10n.viewOnMap,
            ),
          if (_locationController.text.isNotEmpty || _selectedServiceId != null)
            IconButton(
              icon: Icon(Icons.clear_all_rounded, color: theme.colorScheme.onSurface),
              onPressed: _clearAllFilters,
              tooltip: l10n.clearFilters,
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
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _locationController,
                          focusNode: _locationFocus,
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: l10n.searchLocation,
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: theme.hintColor.withOpacity(0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: theme.primaryColor,
                              size: 24,
                            ),
                            suffixIcon: _locationController.text.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: theme.hintColor),
                              onPressed: () {
                                _locationController.clear();
                                setState(() {});
                              },
                            )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.primaryColor, theme.primaryColorDark ?? theme.primaryColor],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isSearching ? null : _performSearch,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: _isSearching
                                  ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                                  : Row(
                                children: [
                                  Icon(Icons.search_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.search,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
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

                const SizedBox(height: 12),

                if (serviceProvider.services.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _serviceSearchController,
                          onChanged: (value) => setState(() => _serviceSearchQuery = value),
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: l10n.filterByService,
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: theme.hintColor.withOpacity(0.7),
                            ),
                            prefixIcon: Icon(
                              Icons.construction_rounded,
                              color: theme.hintColor,
                              size: 20,
                            ),
                            suffixIcon: _serviceSearchQuery.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 18, color: theme.hintColor),
                              onPressed: () {
                                _serviceSearchController.clear();
                                setState(() {
                                  _serviceSearchQuery = '';
                                  _selectedServiceId = null;
                                  _selectedCategoryId = null;
                                });
                              },
                            )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (filteredServices.isNotEmpty)
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            controller: _serviceChipScrollController,
                            children: [
                              _buildServiceChip(
                                label: l10n.all,
                                icon: Icons.apps_rounded,
                                isSelected: _selectedServiceId == null,
                                onTap: () => setState(() {
                                  _selectedServiceId = null;
                                  _selectedCategoryId = null;
                                  _serviceSearchQuery = '';
                                  _serviceSearchController.clear();
                                }),
                              ),
                              const SizedBox(width: 6),
                              ...filteredServices.map((service) {
                                final isSelected = _selectedServiceId == service.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _buildServiceChip(
                                    label: service.name,
                                    isSelected: isSelected,
                                    onTap: () => setState(() {
                                      _selectedServiceId = isSelected ? null : service.id;
                                      _selectedCategoryId = null;
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
                            l10n.noServicesFound,
                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          if (_selectedServiceId != null && categories.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.05),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.category_rounded, size: 14, color: theme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          l10n.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        controller: _categoryChipScrollController,
                        children: [
                          _buildCategoryChip(
                            label: l10n.all,
                            isSelected: _selectedCategoryId == null,
                            onTap: () => setState(() => _selectedCategoryId = null),
                          ),
                          const SizedBox(width: 6),
                          ...categories.map((category) {
                            final isSelected = _selectedCategoryId == category.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildCategoryChip(
                                label: category.getDisplayName(_currentLocale),
                                isSelected: isSelected,
                                onTap: () => setState(() {
                                  _selectedCategoryId = isSelected ? null : category.id;
                                }),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _buildContent(theme, l10n, techProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? theme.primaryColor
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : theme.dividerColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : theme.hintColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? theme.primaryColor.withOpacity(0.12)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? theme.primaryColor
                : theme.dividerColor.withOpacity(0.2),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 12, color: theme.primaryColor),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, AppLocalizations l10n, TechnicianProvider techProvider) {
    if (techProvider.isLoading && techProvider.technicians.isEmpty) {
      return _buildLoadingState(theme, l10n);
    }
    if (techProvider.error != null && techProvider.technicians.isEmpty) {
      return _buildErrorState(theme, l10n, techProvider);
    }
    if (techProvider.technicians.isEmpty) {
      return _buildEmptyState(theme, l10n, techProvider);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.people_rounded, size: 18, color: theme.hintColor),
                  const SizedBox(width: 6),
                  Text(
                    '${techProvider.technicians.length} ${l10n.fundisFound}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (_selectedServiceId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.filtered,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: techProvider.technicians.length,
            itemBuilder: (ctx, i) {
              final tech = techProvider.technicians[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TechnicianCard(
                  technician: tech,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.technicianDetail, arguments: tech.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.searchingForFundis,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
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
                color: theme.colorScheme.error.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.oopsSomethingWentWrong,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              techProvider.error ?? l10n.pleaseTryAgain,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n, TechnicianProvider techProvider) {
    final hasServiceFilter = _selectedServiceId != null;
    final hasCategoryFilter = _selectedCategoryId != null;
    final meta = techProvider.meta;
    final filters = techProvider.filters;

    String message = l10n.noFundisFound;
    String subtitle = l10n.tryAdjustingSearch;

    if (filters != null) {
      final serviceName = filters['service_name'];
      final categoryName = filters['category_name'];

      if (serviceName != null && categoryName != null) {
        message = l10n.noFundisForService(serviceName);
        subtitle = l10n.tryDifferentCategoryOrService;
      } else if (serviceName != null) {
        message = l10n.noFundisForService(serviceName);
        subtitle = l10n.tryDifferentService;
      }
    }

    final suggestions = meta != null && meta['suggestions'] != null
        ? (meta!['suggestions'] as List?)?.cast<String>()
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_rounded,
                size: 64,
                color: theme.primaryColor.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (suggestions != null && suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: suggestions.map((suggestion) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_locationController.text.isNotEmpty || _selectedServiceId != null)
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: Text(l10n.clearAllFilters),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}