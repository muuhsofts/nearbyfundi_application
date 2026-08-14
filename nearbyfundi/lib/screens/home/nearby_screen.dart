// screens/home/nearby_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/service.dart';
import '../../models/technician.dart';
import '../../providers/technician_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/image_utils.dart';
import 'nearby_map_screen.dart';

class TechnicianRouteData {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;

  TechnicianRouteData({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
  });
}

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

  final MapController _mapController = MapController();
  final GlobalKey _mapKey = GlobalKey();

  int? _selectedServiceId;
  int? _selectedCategoryId;
  bool _isSearching = false;
  String _serviceSearchQuery = '';
  String _currentLocale = 'en';
  String _searchedArea = '';

  final Map<int, TechnicianRouteData> _routesData = {};
  bool _isFetchingRoutes = false;

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
    _mapController.dispose();
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
    setState(() {
      _isSearching = true;
      _routesData.clear();
      _searchedArea = place;
    });
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

    _fetchRoutesForTechnicians();
  }

  Future<void> _fetchRoutesForTechnicians() async {
    final techProvider = context.read<TechnicianProvider>();
    if (!techProvider.hasSearchOrigin) return;

    final origin = LatLng(techProvider.searchLat!, techProvider.searchLng!);
    final techPoints = techProvider.technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();

    if (techPoints.isEmpty) return;

    setState(() => _isFetchingRoutes = true);

    final Map<int, TechnicianRouteData> fetched = {};
    final targets = techPoints.take(10);

    await Future.wait(targets.map((tech) async {
      final dest = LatLng(tech.latitude!, tech.longitude!);
      final routeData = await _getOsrmRouteData(origin, dest, tech.distanceKm);
      if (routeData != null) {
        fetched[tech.id] = routeData;
      }
    }));

    if (mounted) {
      setState(() {
        _routesData.addAll(fetched);
        _isFetchingRoutes = false;
        _updateMapBounds();
      });
    }
  }

  Future<TechnicianRouteData?> _getOsrmRouteData(
      LatLng origin,
      LatLng destination,
      double fallbackKm,
      ) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '${origin.longitude},${origin.latitude};'
            '${destination.longitude},${destination.latitude}'
            '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;

          final points = geometry
              .map<LatLng>((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSeconds = (route['duration'] as num).toDouble();

          return TechnicianRouteData(
            points: points,
            distanceKm: distanceMeters / 1000.0,
            durationMin: durationSeconds / 60.0,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching OSRM route: $e');
    }

    final straightKm = fallbackKm > 0
        ? fallbackKm
        : const Distance().as(LengthUnit.Kilometer, origin, destination);

    return TechnicianRouteData(
      points: [origin, destination],
      distanceKm: straightKm,
      durationMin: straightKm * 2,
    );
  }

  void _clearAllFilters() {
    _locationController.clear();
    _serviceSearchController.clear();
    setState(() {
      _selectedServiceId = null;
      _selectedCategoryId = null;
      _serviceSearchQuery = '';
      _routesData.clear();
      _searchedArea = '';
    });
    context.read<TechnicianProvider>().clearTechnicians();
    _locationFocus.unfocus();
    _mapController.move(LatLng(-6.7924, 39.2083), 11);
  }

  void _updateMapBounds() {
    final techProvider = context.read<TechnicianProvider>();
    if (!techProvider.hasSearchOrigin) return;

    final origin = LatLng(techProvider.searchLat!, techProvider.searchLng!);
    final techPoints = techProvider.technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .map((t) => LatLng(t.latitude!, t.longitude!))
        .toList();

    if (techPoints.isEmpty) {
      _mapController.move(origin, 13);
      return;
    }

    final all = <LatLng>[origin, ...techPoints];
    if (all.length == 1) {
      _mapController.move(origin, 13);
      return;
    }

    final bounds = LatLngBounds.fromPoints(all);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
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

  void _showTechniciansList(BuildContext context, List<Technician> technicians) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: theme.colorScheme.surface,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 20),
                    Text(
                      '${technicians.length} ${l10n.fundisFound}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: technicians.length,
                    itemBuilder: (ctx, index) {
                      final tech = technicians[index];
                      return _buildListTile(context, tech);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Circular avatar with a white "backing card" behind the photo.
  Widget _buildAvatar(
      Technician tech, {
        double size = 48,
        double iconSize = 26,
      }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: tech.profilePhoto != null
            ? Image.network(
          ImageUtils.getFullImageUrl(tech.profilePhoto!),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => Icon(
            Icons.build_rounded,
            color: Colors.grey.shade600,
            size: iconSize,
          ),
        )
            : Icon(
          Icons.build_rounded,
          color: Colors.grey.shade600,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, Technician tech) {
    final theme = Theme.of(context);
    final routeData = _routesData[tech.id];
    final distance = routeData?.distanceKm ?? tech.distanceKm;
    final durationMin = routeData?.durationMin;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 400;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, AppRoutes.technicianDetail, arguments: tech.id);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 12, top: 2),
                child: _buildAvatar(tech, size: isSmall ? 50 : 60, iconSize: isSmall ? 24 : 30),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tech.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: isSmall ? 14 : 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tech.verified)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                          ),
                      ],
                    ),
                    if (tech.area != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: isSmall ? 20 : 24,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tech.area!,
                                style: TextStyle(fontSize: isSmall ? 12 : 13, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Info row - FLATTENED Wrap (no nested Rows) to fix overflow
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (tech.rating > 0) ...[
                          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                          Text(
                            tech.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Container(width: 1, height: 14, color: Colors.grey.shade300),
                          const SizedBox(width: 4),
                        ],
                        Icon(Icons.place_rounded, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: isSmall ? 12 : 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (durationMin != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '•',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.access_time_rounded, size: isSmall ? 12 : 14, color: Colors.grey.shade600),
                          const SizedBox(width: 2),
                          Text(
                            '~${durationMin.toStringAsFixed(0)} min',
                            style: TextStyle(
                              fontSize: isSmall ? 12 : 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (tech.services.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: tech.services.take(3).map((service) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: theme.primaryColor.withOpacity(0.1),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              service,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techProvider = context.watch<TechnicianProvider>();
    final serviceProvider = context.watch<ServiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

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
              icon: Icon(Icons.list_rounded, color: theme.colorScheme.onSurface),
              onPressed: () => _showTechniciansList(context, techProvider.technicians),
              tooltip: 'View list',
            ),
          if (techProvider.technicians.isNotEmpty)
            IconButton(
              icon: Icon(Icons.fullscreen_rounded, color: theme.colorScheme.onSurface),
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
            padding: EdgeInsets.fromLTRB(16, 8, 16, isSmallScreen ? 8 : 12),
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
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: isSmallScreen ? 14 : 16),
                          decoration: InputDecoration(
                            hintText: l10n.searchLocation,
                            hintStyle: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
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
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
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
                                      fontSize: isSmallScreen ? 12 : 14,
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
                // Searched area chip
                if (_searchedArea.isNotEmpty && techProvider.technicians.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Searching in: $_searchedArea',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              color: theme.primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${techProvider.technicians.length} fundis',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: isSmallScreen ? 13 : 14),
                          decoration: InputDecoration(
                            hintText: l10n.filterByService,
                            hintStyle: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
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
                          height: isSmallScreen ? 32 : 36,
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
                                isSmallScreen: isSmallScreen,
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
                                    isSmallScreen: isSmallScreen,
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
                      height: isSmallScreen ? 28 : 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        controller: _categoryChipScrollController,
                        children: [
                          _buildCategoryChip(
                            label: l10n.all,
                            isSelected: _selectedCategoryId == null,
                            onTap: () => setState(() => _selectedCategoryId = null),
                            isSmallScreen: isSmallScreen,
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
                                isSmallScreen: isSmallScreen,
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
            child: Stack(
              children: [
                _buildMapView(theme, techProvider),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: Column(
                    children: [
                      _MapControlButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom in',
                        onPressed: () => _zoomBy(1),
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom out',
                        onPressed: () => _zoomBy(-1),
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.center_focus_strong_rounded,
                        tooltip: 'Fit all markers',
                        onPressed: () => _updateMapBounds(),
                      ),
                    ],
                  ),
                ),
                if (_isFetchingRoutes)
                  Positioned(
                    top: 8,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Loading routes...',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom + delta).clamp(4.0, 18.0);
    _mapController.move(camera.center, newZoom);
  }

  Widget _buildMapView(ThemeData theme, TechnicianProvider techProvider) {
    if (!techProvider.hasSearchOrigin) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'Search for technicians',
              style: TextStyle(color: theme.hintColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final origin = LatLng(techProvider.searchLat!, techProvider.searchLng!);
    final techPoints = techProvider.technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();

    if (techPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'No technicians on map',
              style: TextStyle(color: theme.hintColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Responsive sizes based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 400;
    final pinSize = isSmall ? 56.0 : 72.0;
    final avatarSize = isSmall ? 44.0 : 58.0;
    final avatarIconSize = isSmall ? 22.0 : 28.0;
    final badgeFontSize = isSmall ? 9.0 : 11.0;
    final markerHeight = isSmall ? 150.0 : 180.0;
    final markerWidth = isSmall ? 110.0 : 130.0;

    // --- Polylines (routes) ---
    final polylines = <Polyline>[];
    for (final tech in techPoints) {
      final route = _routesData[tech.id];
      if (route != null && route.points.length > 1) {
        // Shadow
        polylines.add(
          Polyline(
            points: route.points,
            strokeWidth: isSmall ? 6.0 : 8.0,
            color: Colors.black.withOpacity(0.15),
          ),
        );
        // Main route
        polylines.add(
          Polyline(
            points: route.points,
            strokeWidth: isSmall ? 4.0 : 6.0,
            color: theme.primaryColor,
            borderColor: Colors.white.withOpacity(0.4),
            borderStrokeWidth: 2.0,
          ),
        );
      }
    }

    // --- Technician Markers (responsive) ---
    final techMarkers = techPoints.map((tech) {
      final route = _routesData[tech.id];
      final distance = route?.distanceKm ?? tech.distanceKm;
      final durationMin = route?.durationMin;

      String label = tech.area ?? '';
      if (label.length > 20) label = '${label.substring(0, 20)}…';

      return Marker(
        point: LatLng(tech.latitude!, tech.longitude!),
        width: markerWidth,
        height: markerHeight,
        child: GestureDetector(
          onTap: () => _showTechnicianModal(context, tech, origin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pin with avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.location_pin,
                    color: Colors.red.shade700,
                    size: pinSize,
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: pinSize * 0.35),
                    child: _buildAvatar(tech, size: avatarSize, iconSize: avatarIconSize),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (label.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 0.5),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmall ? 9 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(Icons.location_on_rounded, size: isSmall ? 11 : 13, color: Colors.red.shade700),
              ],
              // Distance + ETA badge
              if (distance > 0)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 8, vertical: isSmall ? 2 : 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.primaryColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: badgeFontSize,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        if (durationMin != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: badgeFontSize,
                              color: theme.primaryColor.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.access_time_rounded,
                            size: badgeFontSize,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '~${durationMin.toStringAsFixed(0)} min',
                            style: TextStyle(
                              fontSize: badgeFontSize - 1,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();

    // --- Origin Marker with bold label (responsive) ---
    final originMarker = Marker(
      point: origin,
      width: isSmall ? 80 : 100,
      height: isSmall ? 80 : 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_pin,
            color: Colors.red.shade800,
            size: isSmall ? 48 : 64,
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              'You are here',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmall ? 10 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    // --- Distance/ETA markers along routes (responsive) ---
    final distanceMarkers = <Marker>[];
    for (final tech in techPoints) {
      final route = _routesData[tech.id];
      if (route != null && route.points.isNotEmpty) {
        final midIndex = route.points.length ~/ 2;
        final midPoint = route.points[midIndex];
        final distance = route.distanceKm;
        final duration = route.durationMin;
        distanceMarkers.add(
          Marker(
            point: midPoint,
            width: isSmall ? 130 : 160,
            height: isSmall ? 30 : 36,
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 6, vertical: isSmall ? 2 : 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.primaryColor.withOpacity(0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: isSmall ? 9 : 11,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    if (duration != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: isSmall ? 9 : 11,
                          color: theme.primaryColor.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.access_time_rounded,
                        size: isSmall ? 9 : 11,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '~${duration.toStringAsFixed(0)} min',
                        style: TextStyle(
                          fontSize: isSmall ? 8 : 10,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    final allMarkers = [
      originMarker,
      ...techMarkers,
      ...distanceMarkers,
    ];

    return FlutterMap(
      key: _mapKey,
      mapController: _mapController,
      options: MapOptions(
        initialCenter: origin,
        initialZoom: 13,
        minZoom: 4,
        maxZoom: 18,
        onTap: (_, __) {},
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.nearbyfundi',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: allMarkers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTechnicianModal(BuildContext context, Technician tech, LatLng origin) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 400;

    final route = _routesData[tech.id];
    final distance = route?.distanceKm ?? tech.distanceKm;
    final duration = route?.durationMin;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: theme.colorScheme.surface,
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isSmall ? 16 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetContext),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildAvatar(tech, size: isSmall ? 48 : 56, iconSize: isSmall ? 20 : 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tech.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmall ? 18 : 20,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tech.verified)
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                              ),
                          ],
                        ),
                        if (tech.area != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tech.area!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: isSmall ? 13 : 14,
                                  color: theme.hintColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Icon(Icons.location_on_rounded, size: 16, color: theme.hintColor),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (tech.rating > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          tech.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_rounded, size: 18, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.toStringAsFixed(1)} km away',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  if (duration != null)
                    Text(
                      '• ~${duration.toStringAsFixed(0)} min',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (tech.services.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tech.services
                      .map(
                        (s) => Chip(
                      label: Text(
                        s,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: isSmall ? 12 : 13,
                          fontWeight: FontWeight.w500,
                          color: theme.primaryColor,
                        ),
                      ),
                      backgroundColor: theme.primaryColor.withOpacity(0.08),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.pushNamed(context, AppRoutes.technicianDetail, arguments: tech.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        l10n.viewProfile,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 14 : 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (tech.latitude != null && tech.longitude != null)
                    Container(
                      height: 56,
                      width: isSmall ? 50 : 60,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.green.withOpacity(0.3) : Colors.green.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.directions_rounded,
                          color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                          size: isSmall ? 24 : 30,
                        ),
                        onPressed: () => _openDirectionsInGoogleMaps(
                          context,
                          origin: origin,
                          destination: LatLng(tech.latitude!, tech.longitude!),
                        ),
                        tooltip: l10n.directions,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirectionsInGoogleMaps(
      BuildContext context, {
        required LatLng origin,
        required LatLng destination,
      }) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&travelmode=driving',
    );
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app.')),
        );
      }
    }
  }

  Widget _buildServiceChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10 : 14,
          vertical: isSmallScreen ? 4 : 6,
        ),
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
              Icon(icon, size: isSmallScreen ? 12 : 14, color: isSelected ? Colors.white : theme.hintColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
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
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12,
          vertical: isSmallScreen ? 3 : 4,
        ),
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
              Icon(Icons.check_circle_rounded, size: isSmallScreen ? 10 : 12, color: theme.primaryColor),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MapControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        icon: Icon(icon, color: theme.primaryColor, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
