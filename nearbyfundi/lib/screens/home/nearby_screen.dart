// screens/home/nearby_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/service.dart';
import '../../models/technician.dart';
import '../../providers/technician_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/image_utils.dart';
import 'nearby_map_screen.dart';
import 'map_location_picker_screen.dart';

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

  bool _isHeaderVisible = true;

  int? _selectedServiceId;
  int? _selectedCategoryId;
  bool _isSearching = false;
  String _serviceSearchQuery = '';
  String _currentLocale = 'en';
  String _searchedArea = '';

  final Map<int, TechnicianRouteData> _routesData = {};
  bool _isFetchingRoutes = false;

  List<String> _searchHistory = [];
  List<Map<String, dynamic>> _placeSuggestions = [];
  bool _showSuggestions = false;
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
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

  void _toggleHeaderVisibility() {
    setState(() {
      _isHeaderVisible = !_isHeaderVisible;
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _searchHistory = prefs.getStringList('location_search_history') ?? [];
      });
    }
  }

  Future<void> _saveToHistory(String place) async {
    if (place.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('location_search_history') ?? [];
    history.remove(place);
    history.insert(0, place);
    if (history.length > 10) history.removeLast();
    await prefs.setStringList('location_search_history', history);
    if (mounted) setState(() => _searchHistory = history);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('location_search_history');
    if (mounted) setState(() => _searchHistory = []);
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _placeSuggestions = [];
        _showSuggestions = _searchHistory.isNotEmpty;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
      _showSuggestions = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json&addressdetails=1&limit=8'
            '&countrycodes=tz',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'NearbyFundi/1.0'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _placeSuggestions = data.map((e) {
              final display = e['display_name'] as String? ?? '';
              final short = display.split(',').take(3).join(',').trim();
              return {
                'name': short,
                'full': display,
                'lat': double.tryParse(e['lat']?.toString() ?? '') ?? 0.0,
                'lng': double.tryParse(e['lon']?.toString() ?? '') ?? 0.0,
              };
            }).toList();
          });
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingSuggestions = false);
  }

  Future<void> _openMapPicker() async {
    final techProvider = context.read<TechnicianProvider>();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialCenter: techProvider.hasSearchOrigin
              ? LatLng(techProvider.searchLat!, techProvider.searchLng!)
              : null,
        ),
      ),
    );

    if (result != null && mounted) {
      final name = result['name'] as String;
      final lat = result['lat'] as double;
      final lng = result['lng'] as double;

      _locationController.text = name;
      await _saveToHistory(name);

      setState(() {
        _isSearching = true;
        _searchedArea = name;
        _routesData.clear();
        _showSuggestions = false;
      });
      techProvider.clearTechnicians();

      try {
        await techProvider.searchByCoordinates(
          lat: lat,
          lng: lng,
          serviceId: _selectedServiceId,
          categoryId: _selectedCategoryId,
          radius: 20,
          search: _serviceSearchQuery.isNotEmpty ? _serviceSearchQuery : null,
          locale: _currentLocale,
        );
      } catch (_) {
        await techProvider.searchByPlace(
          place: name,
          serviceId: _selectedServiceId,
          categoryId: _selectedCategoryId,
          radius: 20,
          search: _serviceSearchQuery.isNotEmpty ? _serviceSearchQuery : null,
          locale: _currentLocale,
        );
      }

      if (mounted) {
        setState(() => _isSearching = false);
        _fetchRoutesForTechnicians();
      }
    }
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

    setState(() => _showSuggestions = false);
    await _saveToHistory(place);

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
      _showSuggestions = false;
      _placeSuggestions = [];
    });
    context.read<TechnicianProvider>().clearTechnicians();
    _locationFocus.unfocus();
    _mapController.move(const LatLng(-6.7924, 39.2083), 11);
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
    return allServices
        .where((service) => service.matchesSearch(lowerQuery, _currentLocale))
        .toList();
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

  Widget _buildAvatar(
      Technician tech, {
        double size = 56,
        double iconSize = 28,
      }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
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
                child: _buildAvatar(tech, size: isSmall ? 52 : 62, iconSize: isSmall ? 26 : 32),
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
                              fontSize: isSmall ? 14.5 : 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tech.verified)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
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
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: isSmall ? 16 : 18,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                tech.area!,
                                style: TextStyle(
                                  fontSize: isSmall ? 12 : 13.5,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (tech.rating > 0) ...[
                          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                          Text(
                            tech.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          Container(width: 1, height: 12, color: Colors.grey.shade300),
                        ],
                        Icon(Icons.directions_car_rounded, size: 15, color: Colors.grey.shade500),
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: isSmall ? 12 : 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (durationMin != null) ...[
                          Text('•', style: TextStyle(color: Colors.grey.shade400)),
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade600),
                          Text(
                            '~${durationMin.toStringAsFixed(0)}m',
                            style: TextStyle(
                              fontSize: isSmall ? 12 : 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
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
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
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
                size: 15,
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
        title: Text(
            l10n.findFundi,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF006B5E),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isHeaderVisible
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            onPressed: _toggleHeaderVisibility,
            tooltip: _isHeaderVisible ? 'Hide search' : 'Show search',
          ),
          if (techProvider.technicians.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list_rounded),
              onPressed: () => _showTechniciansList(context, techProvider.technicians),
              tooltip: 'View list',
            ),
          if (techProvider.technicians.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.fullscreen_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NearbyMapScreen()),
              ),
              tooltip: l10n.viewOnMap,
            ),
          if (_locationController.text.isNotEmpty || _selectedServiceId != null)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              onPressed: _clearAllFilters,
              tooltip: l10n.clearFilters,
            ),
          IconButton(
            icon: techProvider.isLoading
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.refresh_rounded),
            onPressed: techProvider.isLoading ? null : _performSearch,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isHeaderVisible
                ? Container(
              key: const ValueKey('header-visible'),
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
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _locationController,
                                focusNode: _locationFocus,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.searchLocation,
                                  hintStyle: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 15,
                                    color: theme.hintColor.withOpacity(0.7),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: const Color(0xFF006B5E),
                                    size: 24,
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_locationController.text.isNotEmpty)
                                        IconButton(
                                          icon: Icon(Icons.clear_rounded, color: theme.hintColor),
                                          onPressed: () {
                                            _locationController.clear();
                                            setState(() {
                                              _placeSuggestions = [];
                                              _showSuggestions = _searchHistory.isNotEmpty;
                                            });
                                          },
                                        ),
                                      // ─── MAP ICON: MOUSE HOVER = TOAST, CLICK = NAVIGATE ───
                                      MouseRegion(
                                        onEnter: (_) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Choose location/place on map'),
                                              behavior: SnackBarBehavior.floating,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        child: Tooltip(
                                          message: 'Choose location/place on map',
                                          waitDuration: Duration.zero, // Instant hover
                                          showDuration: const Duration(seconds: 3),
                                          child: IconButton(
                                            icon: const Icon(Icons.map_rounded, color: Color(0xFF006B5E)),
                                            onPressed: _openMapPicker,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                  _fetchPlaceSuggestions(value);
                                },
                                onTap: () {
                                  setState(() {
                                    _showSuggestions = true;
                                    if (_locationController.text.trim().length < 2) {
                                      _placeSuggestions = [];
                                    }
                                  });
                                },
                                onSubmitted: (_) {
                                  setState(() => _showSuggestions = false);
                                  _performSearch();
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF006B5E),
                                    Color(0xFF008C7A),
                                  ],
                                ),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(24),
                                  bottomRight: Radius.circular(24),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isSearching
                                      ? null
                                      : () {
                                    setState(() => _showSuggestions = false);
                                    _performSearch();
                                  },
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(24),
                                    bottomRight: Radius.circular(24),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 12 : 16,
                                      vertical: isSmallScreen ? 10 : 12,
                                    ),
                                    child: _isSearching
                                        ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                        : Row(
                                      children: [
                                        const Icon(Icons.search_rounded,
                                            color: Colors.white, size: 20),
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
                        if (_showSuggestions)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 280),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(24),
                              ),
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              children: [
                                if (_searchHistory.isNotEmpty && _placeSuggestions.isEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Recent searches',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.hintColor,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: _clearHistory,
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Clear',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: const Color(0xFF006B5E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._searchHistory.map(
                                        (place) => ListTile(
                                      dense: true,
                                      leading: Icon(Icons.history,
                                          size: 20, color: theme.hintColor),
                                      title: Text(place,
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onTap: () {
                                        _locationController.text = place;
                                        setState(() => _showSuggestions = false);
                                        _performSearch();
                                      },
                                    ),
                                  ),
                                ],
                                if (_isLoadingSuggestions)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                ..._placeSuggestions.map(
                                      (s) => ListTile(
                                    dense: true,
                                    leading: Icon(Icons.place_outlined,
                                        size: 20, color: const Color(0xFF006B5E)),
                                    title: Text(s['name'],
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      s['full'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.hintColor,
                                      ),
                                    ),
                                    onTap: () async {
                                      _locationController.text = s['name'];
                                      setState(() => _showSuggestions = false);
                                      await _saveToHistory(s['name']);
                                      _performSearch();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (_searchedArea.isNotEmpty && techProvider.technicians.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006B5E).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF006B5E).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 16, color: const Color(0xFF006B5E)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Searching in: $_searchedArea',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF006B5E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006B5E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${techProvider.technicians.length} fundis',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  TextField(
                    controller: _serviceSearchController,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Filter by service...',
                      prefixIcon: const Icon(Icons.build_rounded, color: Color(0xFF006B5E)),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) {
                      setState(() => _serviceSearchQuery = v);
                    },
                  ),

                  if (filteredServices.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        controller: _serviceChipScrollController,
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildServiceChip(
                            label: 'All',
                            icon: Icons.apps_rounded,
                            isSelected: _selectedServiceId == null,
                            onTap: () {
                              setState(() {
                                _selectedServiceId = null;
                                _selectedCategoryId = null;
                              });
                            },
                            isSmallScreen: isSmallScreen,
                          ),
                          const SizedBox(width: 8),
                          ...filteredServices.map((s) {
                            final selected = _selectedServiceId == s.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildServiceChip(
                                label: s.name,
                                isSelected: selected,
                                onTap: () {
                                  setState(() {
                                    _selectedServiceId = selected ? null : s.id;
                                    _selectedCategoryId = null;
                                  });
                                },
                                isSmallScreen: isSmallScreen,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView(
                        controller: _categoryChipScrollController,
                        scrollDirection: Axis.horizontal,
                        children: categories.map((c) {
                          final selected = _selectedCategoryId == c.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildCategoryChip(
                              label: c.name,
                              isSelected: selected,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = selected ? null : c.id;
                                });
                              },
                              isSmallScreen: isSmallScreen,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            )
                : const SizedBox.shrink(key: ValueKey('header-hidden')),
          ),
          Expanded(
            child: Stack(
              children: [
                _buildMapView(theme, techProvider),

                Positioned(
                  right: 12,
                  bottom: 24,
                  child: Column(
                    children: [
                      _MapControlButton(
                        icon: Icons.add,
                        tooltip: 'Zoom in',
                        onPressed: () => _zoomBy(1),
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom out',
                        onPressed: () => _zoomBy(-1),
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.my_location,
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 400;

    final pinSize = isSmall ? 58.0 : 74.0;
    final avatarSize = isSmall ? 46.0 : 60.0;
    final avatarIconSize = isSmall ? 24.0 : 30.0;
    final badgeFontSize = isSmall ? 7.8 : 9.2;
    final markerHeight = isSmall ? 148.0 : 172.0;
    final markerWidth = isSmall ? 108.0 : 128.0;

    final polylines = <Polyline>[];
    for (final tech in techPoints) {
      final route = _routesData[tech.id];
      if (route != null && route.points.length > 1) {
        polylines.add(
          Polyline(
            points: route.points,
            strokeWidth: isSmall ? 9.0 : 11.0,
            color: Colors.black.withOpacity(0.22),
          ),
        );
        polylines.add(
          Polyline(
            points: route.points,
            strokeWidth: isSmall ? 6.0 : 7.5,
            color: const Color(0xFF006B5E),
            borderColor: Colors.white.withOpacity(0.4),
            borderStrokeWidth: 2.0,
          ),
        );
      }
    }

    final techMarkers = techPoints.map((tech) {
      final route = _routesData[tech.id];
      final distance = route?.distanceKm ?? tech.distanceKm;
      final durationMin = route?.durationMin;

      String label = tech.area ?? '';
      if (label.length > 15) label = '${label.substring(0, 15)}…';

      return Marker(
        point: LatLng(tech.latitude!, tech.longitude!),
        width: markerWidth,
        height: markerHeight,
        child: GestureDetector(
          onTap: () => _showTechnicianModal(context, tech, origin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.location_pin,
                    color: Colors.red.shade700,
                    size: pinSize,
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: pinSize * 0.32),
                    child: _buildAvatar(tech, size: avatarSize, iconSize: avatarIconSize),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (label.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 0.6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 9, color: Colors.white70),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmall ? 8 : 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (distance > 0)
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF006B5E), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.13),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
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
                            color: const Color(0xFF006B5E),
                          ),
                        ),
                        if (durationMin != null) ...[
                          const SizedBox(width: 1.5),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: badgeFontSize,
                              color: const Color(0xFF006B5E).withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(width: 1.5),
                          Icon(
                            Icons.access_time_rounded,
                            size: badgeFontSize + 0.8,
                            color: const Color(0xFF006B5E),
                          ),
                          const SizedBox(width: 1),
                          Text(
                            '~${durationMin.toStringAsFixed(0)}m',
                            style: TextStyle(
                              fontSize: badgeFontSize - 0.3,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF006B5E),
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
            size: isSmall ? 48 : 62,
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Text(
              'You',
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
            width: isSmall ? 86 : 100,
            height: isSmall ? 26 : 30,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF006B5E).withOpacity(0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
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
                        color: const Color(0xFF006B5E),
                      ),
                    ),
                    if (duration != null) ...[
                      const SizedBox(width: 1.5),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: badgeFontSize,
                          color: const Color(0xFF006B5E).withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 1.5),
                      Icon(
                        Icons.access_time_rounded,
                        size: badgeFontSize + 0.8,
                        color: const Color(0xFF006B5E),
                      ),
                      const SizedBox(width: 1),
                      Text(
                        '~${duration.toStringAsFixed(0)}m',
                        style: TextStyle(
                          fontSize: badgeFontSize - 0.3,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF006B5E),
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
        onTap: (_, __) {
          if (_showSuggestions) {
            setState(() => _showSuggestions = false);
            _locationFocus.unfocus();
          }
        },
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
                  _buildAvatar(tech, size: isSmall ? 52 : 60, iconSize: isSmall ? 26 : 30),
                  const SizedBox(width: 14),
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
                                  fontSize: isSmall ? 17 : 19,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tech.verified)
                              Container(
                                margin: const EdgeInsets.only(left: 5),
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    size: 13, color: Colors.white),
                              ),
                          ],
                        ),
                        if (tech.area != null)
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 15, color: theme.hintColor),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  tech.area!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: isSmall ? 13 : 14,
                                    color: theme.hintColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (tech.rating > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 17),
                        const SizedBox(width: 3),
                        Text(
                          tech.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_rounded,
                          size: 17, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF006B5E),
                        ),
                      ),
                    ],
                  ),
                  if (duration != null)
                    Text(
                      '• ~${duration.toStringAsFixed(0)}m',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
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
                          color: const Color(0xFF006B5E),
                        ),
                      ),
                      backgroundColor: const Color(0xFF006B5E).withOpacity(0.08),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                        Navigator.pushNamed(
                          context,
                          AppRoutes.technicianDetail,
                          arguments: tech.id,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006B5E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        l10n.viewProfile,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isSmall ? 14 : 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (tech.latitude != null && tech.longitude != null)
                    Container(
                      height: 56,
                      width: isSmall ? 50 : 60,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.green.withOpacity(0.15)
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.green.withOpacity(0.3)
                              : Colors.green.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.directions_rounded,
                          color: isDark
                              ? Colors.green.shade300
                              : Colors.green.shade700,
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
              ? const Color(0xFF006B5E)
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF006B5E)
                : theme.dividerColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: const Color(0xFF006B5E).withOpacity(0.25),
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
              Icon(icon,
                  size: isSmallScreen ? 12 : 14,
                  color: isSelected ? Colors.white : theme.hintColor),
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
              ? const Color(0xFF006B5E).withOpacity(0.12)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF006B5E)
                : theme.dividerColor.withOpacity(0.2),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  size: isSmallScreen ? 10 : 12, color: const Color(0xFF006B5E)),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF006B5E) : theme.colorScheme.onSurface,
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
      elevation: 4,
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF006B5E), size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}