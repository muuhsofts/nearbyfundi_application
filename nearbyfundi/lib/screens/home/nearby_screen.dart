// ================================================================
// FILE: lib/screens/home/nearby_screen.dart
// Nearby Fundi - Refined UI/UX (cleaned + UAT fixes)
//
// Change log vs previous version (see UAT report for full detail):
//  - Debounced + sequence-guarded place suggestion search
//  - Safe numeric casts everywhere a map picker / API result is parsed
//  - User-facing error feedback on search / route failures
//  - Bounded-concurrency OSRM route fetching (was: 10 parallel requests)
//  - Recommended-technician set computed once per build, not per row
//  - Distance-sorted technician list sheet
//  - Expandable search radius + retry CTA on empty results
//  - Centralized magic numbers / colors / literal strings
//  - Tooltips added to all icon buttons
// ================================================================

import 'dart:async';
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

// ================================================================
// ROUTE DATA
// ================================================================

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

// ================================================================
// CONSTANTS
// Centralizing tunables that were previously scattered as magic
// numbers / literals throughout the widget.
// ================================================================

class _NearbyConstants {
  _NearbyConstants._();

  // Colors
  static const Color primaryGreen = Color(0xFF006B5E);
  static const Color lightGreen = Color(0xFF008C7A);
  static const Color selectedColor = Color(0xFF1565C0);
  static const Color locationRed = Color(0xFFD32F2F);
  static const Color technicianGreen = Color(0xFF00897B);
  static const Color distanceGreen = Color(0xFF2E7D32);
  static const Color verifiedBlue = Color(0xFF1976D2);
  static const LatLng defaultMapCenter = LatLng(-6.7924, 39.2083); // Dar es Salaam

  // Behaviour tuning
  static const int maxHistoryEntries = 10;
  static const int recommendedCount = 2;
  static const int maxRouteTargets = 10;
  static const int routeFetchBatchSize = 4; // bounded concurrency for OSRM
  static const int defaultRadiusKm = 20;
  static const int maxRadiusKm = 100;
  static const int radiusStepKm = 20;
  static const Duration suggestionDebounce = Duration(milliseconds: 400);
  static const Duration placeSearchTimeout = Duration(seconds: 6);
  static const Duration routeSearchTimeout = Duration(seconds: 8);

  static const String historyPrefsKey = 'location_search_history';
}

// TODO(i18n): these strings are UI copy that has no AppLocalizations key
// yet. Centralized here so migrating them into app_localizations.dart is
// a single, obvious pass instead of a scattered find-and-replace.
class _Strings {
  _Strings._();

  static const filterByService = 'Filter by service...';
  static const chooseOnMap = 'Choose location on map';
  static const recommendedNearYou = 'Recommended • Near you';
  static const recommendedReason = 'Recommended because this fundi is near you';
  static const recentSearches = 'Recent searches';
  static const clear = 'Clear';
  static const findingRoutes = 'Finding best routes...';
  static const searchForTechnicians = 'Search for technicians';
  static const noTechniciansNearby = 'No technicians found nearby';
  static const expandSearchRadius = 'Expand search radius';
  static const you = 'You';
  static const zoomIn = 'Zoom in';
  static const zoomOut = 'Zoom out';
  static const fitTechnicians = 'Fit technicians';
  static const showList = 'Show technician list';
  static const showFullMap = 'Show full-screen map';
  static const clearFilters = 'Clear filters';
  static const viewProfile = 'View Profile';
  static const directions = 'Get directions';
  static const couldNotOpenMaps = 'Could not open maps app.';
  static const searchFailed = 'Search failed. Please check your connection and try again.';
}

// ================================================================
// SCREEN
// ================================================================

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen>
    with SingleTickerProviderStateMixin {
  // --------------------------------------------------------------
  // Controllers
  // --------------------------------------------------------------

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _serviceSearchController =
  TextEditingController();

  final FocusNode _locationFocus = FocusNode();

  final ScrollController _serviceChipScrollController = ScrollController();
  final ScrollController _categoryChipScrollController = ScrollController();

  final MapController _mapController = MapController();

  // --------------------------------------------------------------
  // Animation
  // --------------------------------------------------------------

  late AnimationController _pulseController;

  // --------------------------------------------------------------
  // State
  // --------------------------------------------------------------

  bool _isHeaderVisible = true;
  bool _isSearching = false;
  bool _isFetchingRoutes = false;

  int? _selectedServiceId;
  int? _selectedCategoryId;
  int? _selectedTechnicianId;

  String _serviceSearchQuery = '';
  String _currentLocale = 'en';
  String _searchedArea = '';

  int _searchRadiusKm = _NearbyConstants.defaultRadiusKm;

  // --------------------------------------------------------------
  // Data
  // --------------------------------------------------------------

  final Map<int, TechnicianRouteData> _routesData = {};

  List<String> _searchHistory = [];
  List<Map<String, dynamic>> _placeSuggestions = [];

  bool _showSuggestions = false;
  bool _isLoadingSuggestions = false;

  // Debounce + race-condition guard for place suggestions.
  Timer? _suggestionDebounce;
  int _suggestionRequestId = 0;

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _loadSearchHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final settings = context.read<SettingsProvider>();
      _currentLocale = settings.locale;

      context.read<ServiceProvider>().fetchServices(locale: _currentLocale);
    });
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _pulseController.dispose();
    _suggestionDebounce?.cancel();

    _locationController.dispose();
    _serviceSearchController.dispose();
    _locationFocus.dispose();

    _serviceChipScrollController.dispose();
    _categoryChipScrollController.dispose();

    super.dispose();
  }

  // ==============================================================
  // SEARCH HISTORY
  // ==============================================================

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _searchHistory =
          prefs.getStringList(_NearbyConstants.historyPrefsKey) ?? [];
    });
  }

  Future<void> _saveToHistory(String place) async {
    if (place.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history =
        prefs.getStringList(_NearbyConstants.historyPrefsKey) ?? [];

    history.remove(place);
    history.insert(0, place);

    if (history.length > _NearbyConstants.maxHistoryEntries) {
      history.removeLast();
    }

    await prefs.setStringList(_NearbyConstants.historyPrefsKey, history);

    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_NearbyConstants.historyPrefsKey);

    if (!mounted) return;
    setState(() {
      _searchHistory = [];
    });
  }

  // ==============================================================
  // PLACE SUGGESTIONS (debounced + race-safe)
  // ==============================================================

  /// Called directly from the TextField's onChanged. Debounces network
  /// calls so we don't fire a request per keystroke.
  void _onLocationQueryChanged(String value) {
    setState(() {}); // keeps clear/search button visibility in sync

    _suggestionDebounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _placeSuggestions = [];
        _showSuggestions = _searchHistory.isNotEmpty;
        _isLoadingSuggestions = false;
      });
      return;
    }

    _suggestionDebounce = Timer(
      _NearbyConstants.suggestionDebounce,
          () => _fetchPlaceSuggestions(value),
    );
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    final requestId = ++_suggestionRequestId;

    if (!mounted) return;

    setState(() {
      _isLoadingSuggestions = true;
      _showSuggestions = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json'
            '&addressdetails=1'
            '&limit=8'
            '&countrycodes=tz',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'NearbyFundi/1.0'},
      ).timeout(_NearbyConstants.placeSearchTimeout);

      // A newer request has since been issued — discard this stale result.
      if (requestId != _suggestionRequestId) return;

      if (response.statusCode == 200) {
        final List<dynamic> data =
        jsonDecode(response.body) as List<dynamic>;

        if (!mounted) return;

        setState(() {
          _placeSuggestions = data.map((dynamic item) {
            final value = item as Map<String, dynamic>;
            final display = value['display_name']?.toString() ?? '';
            final short = display.split(',').take(3).join(',').trim();

            return {
              'name': short,
              'full': display,
              'lat': double.tryParse(value['lat']?.toString() ?? '') ?? 0.0,
              'lng': double.tryParse(value['lon']?.toString() ?? '') ?? 0.0,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Place suggestion error: $e');
    }

    if (requestId != _suggestionRequestId) return;
    if (!mounted) return;

    setState(() {
      _isLoadingSuggestions = false;
    });
  }

  // ==============================================================
  // MAP LOCATION PICKER
  // ==============================================================

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

    if (result == null || !mounted) return;

    final name = result['name']?.toString() ?? '';
    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      _showErrorSnackBar('Invalid location selected. Please try again.');
      return;
    }

    _locationController.text = name;
    await _saveToHistory(name);

    setState(() {
      _isSearching = true;
      _searchedArea = name;
      _routesData.clear();
      _selectedTechnicianId = null;
      _showSuggestions = false;
    });

    techProvider.clearTechnicians();

    var searchSucceeded = true;

    try {
      await techProvider.searchByCoordinates(
        lat: lat,
        lng: lng,
        serviceId: _selectedServiceId,
        categoryId: _selectedCategoryId,
        radius: _searchRadiusKm,
        search: _serviceSearchQuery.isNotEmpty ? _serviceSearchQuery : null,
        locale: _currentLocale,
      );
    } catch (e) {
      debugPrint('Coordinate search failed: $e');

      try {
        await techProvider.searchByPlace(
          place: name,
          serviceId: _selectedServiceId,
          categoryId: _selectedCategoryId,
          radius: _searchRadiusKm,
          search: _serviceSearchQuery.isNotEmpty ? _serviceSearchQuery : null,
          locale: _currentLocale,
        );
      } catch (e2) {
        debugPrint('Fallback place search failed: $e2');
        searchSucceeded = false;
      }
    }

    if (!mounted) return;

    setState(() {
      _isSearching = false;
    });

    if (!searchSucceeded) {
      _showErrorSnackBar(_Strings.searchFailed);
      return;
    }

    await _fetchRoutesForTechnicians();
  }

  // ==============================================================
  // SEARCH
  // ==============================================================

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

    setState(() {
      _showSuggestions = false;
      _isSearching = true;
      _routesData.clear();
      _selectedTechnicianId = null;
      _searchedArea = place;
    });

    await _saveToHistory(place);

    final techProvider = context.read<TechnicianProvider>();
    techProvider.clearTechnicians();

    var searchSucceeded = true;

    try {
      await techProvider.searchByPlace(
        place: place,
        serviceId: _selectedServiceId,
        categoryId: _selectedCategoryId,
        radius: _searchRadiusKm,
        search: _serviceSearchQuery.isNotEmpty ? _serviceSearchQuery : null,
        locale: _currentLocale,
      );
    } catch (e) {
      debugPrint('Search error: $e');
      searchSucceeded = false;
    }

    if (!mounted) return;

    setState(() {
      _isSearching = false;
    });

    _locationFocus.unfocus();

    if (!searchSucceeded) {
      _showErrorSnackBar(_Strings.searchFailed);
      return;
    }

    await _fetchRoutesForTechnicians();
  }

  /// Retries the last search with a larger radius. Used by the empty-state
  /// CTA so a "no results" search isn't a dead end for the user.
  Future<void> _retryWithLargerRadius() async {
    if (_searchRadiusKm >= _NearbyConstants.maxRadiusKm) return;

    setState(() {
      _searchRadiusKm =
          (_searchRadiusKm + _NearbyConstants.radiusStepKm)
              .clamp(0, _NearbyConstants.maxRadiusKm);
    });

    if (_locationController.text.trim().isNotEmpty) {
      await _performSearch();
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ==============================================================
  // ROUTES
  // ==============================================================

  Future<void> _fetchRoutesForTechnicians() async {
    final techProvider = context.read<TechnicianProvider>();

    if (!techProvider.hasSearchOrigin) return;

    final origin = LatLng(techProvider.searchLat!, techProvider.searchLng!);

    final technicians = techProvider.technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();

    if (technicians.isEmpty) return;

    if (!mounted) return;

    setState(() {
      _isFetchingRoutes = true;
    });

    final targets = technicians.take(_NearbyConstants.maxRouteTargets).toList();
    final Map<int, TechnicianRouteData> fetched = {};

    // Bounded concurrency: the public OSRM demo server rate-limits/blocks
    // callers that fire too many simultaneous requests. Batch instead of
    // firing all N requests at once.
    for (var i = 0; i < targets.length; i += _NearbyConstants.routeFetchBatchSize) {
      final batch = targets.skip(i).take(_NearbyConstants.routeFetchBatchSize);

      await Future.wait(
        batch.map((tech) async {
          final destination = LatLng(tech.latitude!, tech.longitude!);
          final route = await _getOsrmRouteData(
            origin,
            destination,
            tech.distanceKm,
          );

          if (route != null) {
            fetched[tech.id] = route;
          }
        }),
      );
    }

    if (!mounted) return;

    setState(() {
      _routesData.addAll(fetched);
      _isFetchingRoutes = false;
    });

    _updateMapBounds();
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

      final response =
      await http.get(url).timeout(_NearbyConstants.routeSearchTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'];

        if (routes is List && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coordinates = geometry['coordinates'] as List<dynamic>;

          final points = coordinates.map<LatLng>((coord) {
            final values = coord as List<dynamic>;
            return LatLng(
              (values[1] as num).toDouble(),
              (values[0] as num).toDouble(),
            );
          }).toList();

          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSeconds = (route['duration'] as num).toDouble();

          return TechnicianRouteData(
            points: points,
            distanceKm: distanceMeters / 1000,
            durationMin: durationSeconds / 60,
          );
        }
      }
    } catch (e) {
      debugPrint('OSRM error: $e');
    }

    // Fallback: straight-line distance with a conservative average speed
    // estimate. This is clearly an estimate, not a routed ETA — surfaced
    // to the user as "~" prefixed values in the UI.
    final straightKm = fallbackKm > 0
        ? fallbackKm
        : const Distance().as(LengthUnit.Kilometer, origin, destination);

    const assumedAverageSpeedKmh = 30.0;

    return TechnicianRouteData(
      points: [origin, destination],
      distanceKm: straightKm,
      durationMin: (straightKm / assumedAverageSpeedKmh) * 60,
    );
  }

  // ==============================================================
  // CLEAR
  // ==============================================================

  void _clearAllFilters() {
    _locationController.clear();
    _serviceSearchController.clear();

    setState(() {
      _selectedServiceId = null;
      _selectedCategoryId = null;
      _selectedTechnicianId = null;
      _serviceSearchQuery = '';
      _routesData.clear();
      _searchedArea = '';
      _showSuggestions = false;
      _placeSuggestions = [];
      _searchRadiusKm = _NearbyConstants.defaultRadiusKm;
    });

    context.read<TechnicianProvider>().clearTechnicians();

    _locationFocus.unfocus();

    _mapController.move(_NearbyConstants.defaultMapCenter, 11);
  }

  // ==============================================================
  // MAP BOUNDS
  // ==============================================================

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
    final bounds = LatLngBounds.fromPoints(all);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(70),
      ),
    );
  }

  // ==============================================================
  // FILTER SERVICES
  // ==============================================================

  List<Service> _getFilteredServices(List<Service> services) {
    if (_serviceSearchQuery.trim().isEmpty) return services;

    final query = _serviceSearchQuery.toLowerCase().trim();

    return services
        .where((service) => service.matchesSearch(query, _currentLocale))
        .toList();
  }

  List<ServiceCategory> _getCategoriesForSelectedService(
      ServiceProvider provider,
      ) {
    if (_selectedServiceId == null) return [];
    return provider.getCategoriesForService(_selectedServiceId!);
  }

  // ==============================================================
  // RECOMMENDED TECHNICIANS
  //
  // Previously recomputed (with a fresh sort) on every single list row
  // and marker build via context.read() — O(n^2 log n) per frame. Now
  // computed once per build and the resulting id set is threaded through
  // to whichever widget needs it.
  // ==============================================================

  List<Technician> _getRecommendedTechnicians(List<Technician> technicians) {
    final valid = technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return valid.take(_NearbyConstants.recommendedCount).toList();
  }

  // ==============================================================
  // AVATAR
  // ==============================================================

  Widget _buildAvatar(
      Technician tech, {
        double size = 56,
        double iconSize = 28,
      }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
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
          errorBuilder: (_, __, ___) => Icon(
            Icons.build_rounded,
            size: iconSize,
            color: Colors.grey.shade600,
          ),
        )
            : Icon(
          Icons.build_rounded,
          size: iconSize,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  // ==============================================================
  // RECOMMENDED PULSE
  // ==============================================================

  Widget _buildRecommendationPulse(Technician tech, double size) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final value = _pulseController.value;
        final scale = 0.8 + (value * 0.45);
        final opacity = 0.40 * (1 - value);

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: size + 22,
                height: size + 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _NearbyConstants.primaryGreen
                        .withOpacity(opacity.clamp(0.0, 1.0)),
                    width: 3,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _NearbyConstants.primaryGreen,
                boxShadow: [
                  BoxShadow(
                    color: _NearbyConstants.primaryGreen.withOpacity(0.35),
                    blurRadius: 14,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: _buildAvatar(tech, size: size, iconSize: size * 0.48),
            ),
          ],
        );
      },
    );
  }

  // ==============================================================
  // TECHNICIAN LIST (bottom sheet)
  // ==============================================================

  void _showTechniciansList(
      BuildContext context,
      List<Technician> technicians,
      Set<int> recommendedIds,
      ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Sort by distance so the sheet order matches the "recommended = nearest"
    // logic used on the map, instead of whatever order the API returned.
    final sorted = [...technicians]
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${sorted.length} ${l10n.fundisFound}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: sorted.length,
                    itemBuilder: (_, index) {
                      final tech = sorted[index];
                      return _buildListTile(
                        context,
                        tech,
                        recommendedIds.contains(tech.id),
                      );
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

  // ==============================================================
  // LIST TILE
  // ==============================================================

  Widget _buildListTile(
      BuildContext context,
      Technician tech,
      bool recommended,
      ) {
    final theme = Theme.of(context);

    final route = _routesData[tech.id];
    final distance = route?.distanceKm ?? tech.distanceKm;
    final duration = route?.durationMin;
    final selected = _selectedTechnicianId == tech.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: selected ? 5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? _NearbyConstants.selectedColor
              : recommended
              ? _NearbyConstants.primaryGreen.withOpacity(0.35)
              : Colors.transparent,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _selectedTechnicianId = tech.id;
          });

          Navigator.pop(context);
          Navigator.pushNamed(
            context,
            AppRoutes.technicianDetail,
            arguments: tech.id,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(tech, size: 58, iconSize: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tech.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (tech.verified)
                          const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Icon(
                              Icons.verified_rounded,
                              color: _NearbyConstants.verifiedBlue,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    if (recommended)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          _Strings.recommendedNearYou,
                          style: TextStyle(
                            color: _NearbyConstants.primaryGreen,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (tech.area != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: _NearbyConstants.locationRed,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tech.area!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.hintColor,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        if (tech.rating > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                tech.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        _infoBadge(
                          Icons.directions_car_rounded,
                          '${distance.toStringAsFixed(1)} km',
                        ),
                        if (duration != null)
                          _infoBadge(
                            Icons.access_time_rounded,
                            '~${duration.toStringAsFixed(0)}m',
                          ),
                      ],
                    ),
                    if (tech.services.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: tech.services.take(3).map((service) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _NearbyConstants.primaryGreen
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                service,
                                style: const TextStyle(
                                  color: _NearbyConstants.primaryGreen,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: selected
                    ? _NearbyConstants.selectedColor
                    : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: _NearbyConstants.distanceGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _NearbyConstants.distanceGreen),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              color: _NearbyConstants.distanceGreen,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final techProvider = context.watch<TechnicianProvider>();
    final serviceProvider = context.watch<ServiceProvider>();
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final width = MediaQuery.of(context).size.width;
    final small = width < 400;

    if (_currentLocale != settings.locale) {
      _currentLocale = settings.locale;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ServiceProvider>().fetchServices(locale: _currentLocale);
      });
    }

    final services =
    _getFilteredServices(serviceProvider.localizedServices);
    final categories = _getCategoriesForSelectedService(serviceProvider);

    // Computed once per build instead of per row/marker.
    final validTechnicians = techProvider.technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();
    final recommendedIds = _getRecommendedTechnicians(validTechnicians)
        .map((t) => t.id)
        .toSet();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // ==========================================================
      // APP BAR
      // ==========================================================
      appBar: AppBar(
        backgroundColor: _NearbyConstants.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.findFundi,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: _isHeaderVisible ? 'Hide search panel' : 'Show search panel',
            icon: Icon(
              _isHeaderVisible
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isHeaderVisible = !_isHeaderVisible;
              });
            },
          ),
          if (techProvider.technicians.isNotEmpty)
            IconButton(
              tooltip: _Strings.showList,
              icon: const Icon(Icons.list_rounded, color: Colors.white),
              onPressed: () => _showTechniciansList(
                context,
                techProvider.technicians,
                recommendedIds,
              ),
            ),
          if (techProvider.technicians.isNotEmpty)
            IconButton(
              tooltip: _Strings.showFullMap,
              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NearbyMapScreen()),
                );
              },
            ),
          if (_locationController.text.isNotEmpty || _selectedServiceId != null)
            IconButton(
              tooltip: _Strings.clearFilters,
              icon: const Icon(Icons.clear_all_rounded, color: Colors.white),
              onPressed: _clearAllFilters,
            ),
          IconButton(
            tooltip: l10n.search,
            icon: techProvider.isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: techProvider.isLoading ? null : _performSearch,
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isHeaderVisible
                ? _buildSearchPanel(
              context,
              theme,
              l10n,
              services,
              categories,
              techProvider,
              small,
            )
                : const SizedBox(key: ValueKey('hidden-search')),
          ),
          Expanded(
            child: Stack(
              children: [
                _buildMapView(theme, techProvider, recommendedIds),
                Positioned(
                  right: 12,
                  bottom: 20,
                  child: Column(
                    children: [
                      _MapControlButton(
                        icon: Icons.add,
                        tooltip: _Strings.zoomIn,
                        onPressed: () => _zoomBy(1),
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.remove,
                        tooltip: _Strings.zoomOut,
                        onPressed: () => _zoomBy(-1),
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.my_location_rounded,
                        tooltip: _Strings.fitTechnicians,
                        onPressed: _updateMapBounds,
                      ),
                    ],
                  ),
                ),
                if (_isFetchingRoutes)
                  Positioned(top: 12, left: 12, child: _routeLoadingBadge()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // SEARCH PANEL
  // ==============================================================

  Widget _buildSearchPanel(
      BuildContext context,
      ThemeData theme,
      AppLocalizations l10n,
      List<Service> services,
      List<ServiceCategory> categories,
      TechnicianProvider techProvider,
      bool small,
      ) {
    return Container(
      key: const ValueKey('visible-search'),
      padding: EdgeInsets.fromLTRB(14, 8, 14, small ? 8 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // --------------------------------------------------------
          // LOCATION SEARCH
          // --------------------------------------------------------
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    focusNode: _locationFocus,
                    style: TextStyle(fontSize: small ? 14 : 15),
                    decoration: InputDecoration(
                      hintText: l10n.searchLocation,
                      hintStyle: TextStyle(color: theme.hintColor),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _NearbyConstants.primaryGreen,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_locationController.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _locationController.clear();
                                _suggestionDebounce?.cancel();

                                setState(() {
                                  _placeSuggestions = [];
                                  _showSuggestions =
                                      _searchHistory.isNotEmpty;
                                });
                              },
                            ),
                          Tooltip(
                            message: _Strings.chooseOnMap,
                            child: IconButton(
                              icon: const Icon(
                                Icons.map_rounded,
                                color: _NearbyConstants.primaryGreen,
                              ),
                              onPressed: _openMapPicker,
                            ),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onChanged: _onLocationQueryChanged,
                    onTap: () {
                      setState(() {
                        _showSuggestions = true;
                      });
                    },
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),

                // --------------------------------------------------
                // SEARCH BUTTON
                // --------------------------------------------------
                Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        _NearbyConstants.primaryGreen,
                        _NearbyConstants.lightGreen,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isSearching ? null : _performSearch,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: small ? 12 : 15,
                          vertical: small ? 11 : 12,
                        ),
                        child: _isSearching
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            if (!small) ...[
                              const SizedBox(width: 4),
                              Text(
                                l10n.search,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --------------------------------------------------------
          // SUGGESTIONS
          // --------------------------------------------------------
          if (_showSuggestions) _buildSuggestions(context, theme),

          // --------------------------------------------------------
          // SEARCH RESULT SUMMARY
          // --------------------------------------------------------
          if (_searchedArea.isNotEmpty && techProvider.technicians.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: _NearbyConstants.primaryGreen.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: _NearbyConstants.locationRed,
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _searchedArea,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _NearbyConstants.primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _NearbyConstants.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${techProvider.technicians.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 9),

          // --------------------------------------------------------
          // SERVICE SEARCH
          // --------------------------------------------------------
          TextField(
            controller: _serviceSearchController,
            decoration: InputDecoration(
              hintText: _Strings.filterByService,
              prefixIcon: const Icon(
                Icons.build_rounded,
                color: _NearbyConstants.primaryGreen,
              ),
              suffixIcon: _serviceSearchQuery.isNotEmpty
                  ? IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _serviceSearchController.clear();
                  setState(() {
                    _serviceSearchQuery = '';
                  });
                },
              )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
            onChanged: (value) {
              setState(() {
                _serviceSearchQuery = value;
              });
            },
          ),

          // --------------------------------------------------------
          // SERVICES
          // --------------------------------------------------------
          if (services.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: SizedBox(
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
                      isSmallScreen: small,
                    ),
                    const SizedBox(width: 7),
                    ...services.map((service) {
                      final selected = _selectedServiceId == service.id;

                      return Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: _buildServiceChip(
                          label: service.name,
                          isSelected: selected,
                          onTap: () {
                            setState(() {
                              _selectedServiceId =
                              selected ? null : service.id;
                              _selectedCategoryId = null;
                            });
                          },
                          isSmallScreen: small,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // --------------------------------------------------------
          // CATEGORIES
          // --------------------------------------------------------
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: SizedBox(
                height: 32,
                child: ListView(
                  controller: _categoryChipScrollController,
                  scrollDirection: Axis.horizontal,
                  children: categories.map((category) {
                    final selected = _selectedCategoryId == category.id;

                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: _buildCategoryChip(
                        label: category.name,
                        isSelected: selected,
                        onTap: () {
                          setState(() {
                            _selectedCategoryId =
                            selected ? null : category.id;
                          });
                        },
                        isSmallScreen: small,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==============================================================
  // SUGGESTIONS
  // ==============================================================

  Widget _buildSuggestions(BuildContext context, ThemeData theme) {
    final showHistoryHeader =
        _searchHistory.isNotEmpty && _placeSuggestions.isEmpty && !_isLoadingSuggestions;

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (showHistoryHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 8, 4),
              child: Row(
                children: [
                  Text(
                    _Strings.recentSearches,
                    style: TextStyle(
                      color: theme.hintColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearHistory,
                    child: const Text(
                      _Strings.clear,
                      style: TextStyle(
                        color: _NearbyConstants.primaryGreen,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showHistoryHeader)
            ..._searchHistory.map(
                  (place) => ListTile(
                dense: true,
                leading: Icon(Icons.history_rounded, color: theme.hintColor),
                title: Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  _locationController.text = place;

                  setState(() {
                    _showSuggestions = false;
                  });

                  _performSearch();
                },
              ),
            ),
          if (_isLoadingSuggestions)
            const Padding(
              padding: EdgeInsets.all(15),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ..._placeSuggestions.map((suggestion) {
            return ListTile(
              dense: true,
              leading: const Icon(
                Icons.location_on_rounded,
                color: _NearbyConstants.locationRed,
              ),
              title: Text(
                suggestion['name'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                suggestion['full'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                final name = suggestion['name'].toString();
                _locationController.text = name;

                setState(() {
                  _showSuggestions = false;
                });

                await _saveToHistory(name);
                _performSearch();
              },
            );
          }),
        ],
      ),
    );
  }

  // ==============================================================
  // MAP
  // ==============================================================

  Widget _buildMapView(
      ThemeData theme,
      TechnicianProvider techProvider,
      Set<int> recommendedIds,
      ) {
    if (!techProvider.hasSearchOrigin) {
      return _emptyMapState(
        theme,
        Icons.map_outlined,
        _Strings.searchForTechnicians,
      );
    }

    final origin = LatLng(techProvider.searchLat!, techProvider.searchLng!);

    final technicians = techProvider.technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();

    if (technicians.isEmpty) {
      return _emptyMapState(
        theme,
        Icons.person_search_rounded,
        _Strings.noTechniciansNearby,
        showExpandRadius: true,
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final small = screenWidth < 400;

    // ------------------------------------------------------------
    // ROAD POLYLINES
    // ------------------------------------------------------------
    final List<Polyline> polylines = [];

    for (final tech in technicians) {
      final route = _routesData[tech.id];
      if (route == null || route.points.length < 2) continue;

      final selected = _selectedTechnicianId == tech.id;

      polylines.add(
        Polyline(
          points: route.points,
          strokeWidth: selected ? 10 : 8,
          color: Colors.white.withOpacity(0.85),
        ),
      );

      polylines.add(
        Polyline(
          points: route.points,
          strokeWidth: selected ? 6.5 : 5.0,
          color: selected
              ? _NearbyConstants.selectedColor
              : _NearbyConstants.technicianGreen,
        ),
      );
    }

    // ------------------------------------------------------------
    // TECHNICIAN MARKERS
    // ------------------------------------------------------------
    final markers = technicians.map((tech) {
      final route = _routesData[tech.id];
      final distance = route?.distanceKm ?? tech.distanceKm;
      final duration = route?.durationMin;
      final selected = _selectedTechnicianId == tech.id;
      final isRecommended = recommendedIds.contains(tech.id);

      return Marker(
        point: LatLng(tech.latitude!, tech.longitude!),
        width: small ? 126 : 142,
        height: isRecommended
            ? (small ? 156 : 175)
            : (small ? 132 : 150),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _selectedTechnicianId = selected ? null : tech.id;
            });

            _showTechnicianModal(context, tech, origin, isRecommended);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRecommended)
                _buildRecommendationPulse(tech, small ? 46 : 55)
              else
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? _NearbyConstants.selectedColor
                          : Colors.white,
                      width: 3,
                    ),
                  ),
                  child: _buildAvatar(
                    tech,
                    size: small ? 46 : 55,
                    iconSize: small ? 23 : 28,
                  ),
                ),
              const SizedBox(height: 4),
              if (isRecommended)
                Container(
                  constraints: const BoxConstraints(maxWidth: 125),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _NearbyConstants.primaryGreen,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.near_me_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _Strings.recommendedNearYou,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isRecommended) const SizedBox(height: 3),
              if (tech.area != null && tech.area!.trim().isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxWidth: 125),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _NearbyConstants.locationRed,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: _NearbyConstants.locationRed,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          tech.area!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _NearbyConstants.locationRed,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 3),
              if (distance > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _NearbyConstants.distanceGreen,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: _NearbyConstants.distanceGreen,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (duration != null) ...[
                        const SizedBox(width: 4),
                        const Text(
                          '•',
                          style: TextStyle(color: _NearbyConstants.distanceGreen),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.access_time_rounded,
                          color: _NearbyConstants.distanceGreen,
                          size: 11,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '~${duration.toStringAsFixed(0)}m',
                          style: const TextStyle(
                            color: _NearbyConstants.distanceGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();

    // ------------------------------------------------------------
    // USER MARKER
    // ------------------------------------------------------------
    final originMarker = Marker(
      point: origin,
      width: small ? 86 : 100,
      height: small ? 88 : 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _NearbyConstants.locationRed.withOpacity(0.35),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: _NearbyConstants.locationRed,
              size: small ? 45 : 55,
            ),
          ),
          const SizedBox(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _NearbyConstants.locationRed,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              _Strings.you,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    // ------------------------------------------------------------
    // MAP
    // ------------------------------------------------------------
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: origin,
        initialZoom: 13,
        minZoom: 4,
        maxZoom: 18,
        onTap: (_, __) {
          if (_selectedTechnicianId != null) {
            setState(() {
              _selectedTechnicianId = null;
            });
          }

          if (_showSuggestions) {
            setState(() {
              _showSuggestions = false;
            });
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
        MarkerLayer(markers: [originMarker, ...markers]),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () {
                launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // ==============================================================
  // EMPTY MAP
  // ==============================================================

  Widget _emptyMapState(
      ThemeData theme,
      IconData icon,
      String message, {
        bool showExpandRadius = false,
      }) {
    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _NearbyConstants.primaryGreen.withOpacity(0.08),
            ),
            child: Icon(icon, size: 38, color: _NearbyConstants.primaryGreen),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Searching within $_searchRadiusKm km',
            style: TextStyle(color: theme.hintColor, fontSize: 12.5),
          ),
          if (showExpandRadius &&
              _searchRadiusKm < _NearbyConstants.maxRadiusKm) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _retryWithLargerRadius,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text(
                '${_Strings.expandSearchRadius} (+${_NearbyConstants.radiusStepKm} km)',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _NearbyConstants.primaryGreen,
                side: const BorderSide(color: _NearbyConstants.primaryGreen),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==============================================================
  // ROUTE LOADING
  // ==============================================================

  Widget _routeLoadingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 7),
          Text(
            _Strings.findingRoutes,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // ZOOM
  // ==============================================================

  void _zoomBy(double amount) {
    final camera = _mapController.camera;
    final zoom = (camera.zoom + amount).clamp(4.0, 18.0);
    _mapController.move(camera.center, zoom);
  }

  // ==============================================================
  // TECHNICIAN MODAL
  // ==============================================================

  void _showTechnicianModal(
      BuildContext context,
      Technician tech,
      LatLng origin,
      bool recommended,
      ) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final small = width < 400;

    final route = _routesData[tech.id];
    final distance = route?.distanceKm ?? tech.distanceKm;
    final duration = route?.durationMin;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(small ? 16 : 20, 12, small ? 16 : 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ------------------------------------------------
                // HEADER
                // ------------------------------------------------
                Row(
                  children: [
                    _buildAvatar(
                      tech,
                      size: small ? 56 : 64,
                      iconSize: small ? 28 : 32,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tech.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (tech.verified)
                                const Icon(
                                  Icons.verified_rounded,
                                  color: _NearbyConstants.verifiedBlue,
                                  size: 19,
                                ),
                            ],
                          ),
                          if (recommended)
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Text(
                                _Strings.recommendedReason,
                                style: TextStyle(
                                  color: _NearbyConstants.primaryGreen,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (tech.area != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: _NearbyConstants.locationRed,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      tech.area!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.hintColor,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip:
                      MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // ------------------------------------------------
                // DISTANCE CARD
                // ------------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _NearbyConstants.distanceGreen.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _NearbyConstants.distanceGreen.withOpacity(0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      _modalInfo(
                        Icons.directions_car_rounded,
                        '${distance.toStringAsFixed(1)} km',
                      ),
                      const SizedBox(width: 18),
                      if (duration != null)
                        _modalInfo(
                          Icons.access_time_rounded,
                          '~${duration.toStringAsFixed(0)} min',
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (tech.rating > 0)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        tech.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),

                const SizedBox(height: 13),

                if (tech.services.isNotEmpty)
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: tech.services.map((service) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _NearbyConstants.primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          service,
                          style: const TextStyle(
                            color: _NearbyConstants.primaryGreen,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // BUTTONS
                // ------------------------------------------------
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
                          backgroundColor: _NearbyConstants.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          _Strings.viewProfile,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (tech.latitude != null && tech.longitude != null) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        width: 54,
                        child: OutlinedButton(
                          onPressed: () {
                            _openDirectionsInGoogleMaps(
                              context,
                              origin: origin,
                              destination: LatLng(tech.latitude!, tech.longitude!),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _NearbyConstants.selectedColor,
                            side: const BorderSide(
                              color: _NearbyConstants.selectedColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Tooltip(
                            message: _Strings.directions,
                            child: Icon(Icons.directions_rounded),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modalInfo(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _NearbyConstants.distanceGreen, size: 18),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color: _NearbyConstants.distanceGreen,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // GOOGLE MAPS
  // ==============================================================

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
      final launched =
      await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(_Strings.couldNotOpenMaps)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_Strings.couldNotOpenMaps)),
      );
    }
  }

  // ==============================================================
  // SERVICE CHIP
  // ==============================================================

  Widget _buildServiceChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : 13,
            vertical: isSmallScreen ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? _NearbyConstants.primaryGreen
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? _NearbyConstants.primaryGreen
                  : theme.dividerColor.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: isSmallScreen ? 12 : 14,
                  color: isSelected ? Colors.white : theme.hintColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: isSmallScreen ? 10 : 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // CATEGORY CHIP
  // ==============================================================

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 9 : 12,
            vertical: isSmallScreen ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? _NearbyConstants.primaryGreen.withOpacity(0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? _NearbyConstants.primaryGreen
                  : theme.dividerColor.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  color: _NearbyConstants.primaryGreen,
                  size: 12,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? _NearbyConstants.primaryGreen
                      : theme.colorScheme.onSurface,
                  fontSize: isSmallScreen ? 10 : 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// MAP CONTROL
// ================================================================

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: _NearbyConstants.primaryGreen, size: 21),
      ),
    );
  }
}