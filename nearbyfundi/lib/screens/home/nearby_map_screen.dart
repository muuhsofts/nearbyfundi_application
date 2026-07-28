import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../providers/technician_provider.dart';
import '../../models/technician.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../utils/image_utils.dart';
import '../../l10n/app_localizations.dart';

/// Helper model to store calculated OSRM route data
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

class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  final MapController _mapController = MapController();
  static const double _minZoom = 4;
  static const double _maxZoom = 18;

  // Cache OSRM route details per technician ID
  final Map<int, TechnicianRouteData> _routesData = {};
  bool _isFetchingRoutes = false;
  int? _selectedTechId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoutesForTechnicians();
    });
  }

  /// Fetches actual driving route coordinates & distances from OSRM for all visible technicians
  Future<void> _fetchRoutesForTechnicians() async {
    final techProvider = context.read<TechnicianProvider>();
    if (!techProvider.hasSearchOrigin) return;

    final origin = LatLng(techProvider.searchLat!, techProvider.searchLng!);
    final techPoints = techProvider.technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();

    if (techPoints.isEmpty) return;

    setState(() {
      _isFetchingRoutes = true;
    });

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

    // Straight line fallback
    final straightKm = fallbackKm > 0
        ? fallbackKm
        : const Distance().as(LengthUnit.Kilometer, origin, destination);

    return TechnicianRouteData(
      points: [origin, destination],
      distanceKm: straightKm,
      durationMin: straightKm * 2,
    );
  }

  // ─── Controls ───────────────────────────────────────────────────────
  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom + delta).clamp(_minZoom, _maxZoom);
    _mapController.move(camera.center, newZoom);
  }

  void _fitAllMarkers(LatLng? searchPoint, List<Technician> techPoints) {
    final List<LatLng> allPoints = [];
    if (searchPoint != null) allPoints.add(searchPoint);
    allPoints.addAll(techPoints.map((t) => LatLng(t.latitude!, t.longitude!)));

    if (allPoints.isEmpty) return;

    if (allPoints.length == 1) {
      _mapController.move(allPoints.first, 14);
      return;
    }

    final bounds = LatLngBounds.fromPoints(allPoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  // ─── Google Maps Launchers ──────────────────────────────────────────
  Future<void> _openLocationInGoogleMaps(
      BuildContext context,
      double lat,
      double lng,
      ) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await _launch(context, url);
  }

  Future<void> _openDirectionsInGoogleMaps(
      BuildContext context, {
        required LatLng? origin,
        required LatLng destination,
      }) async {
    if (origin == null) {
      await _openLocationInGoogleMaps(context, destination.latitude, destination.longitude);
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&travelmode=driving',
    );
    await _launch(context, url);
  }

  Future<void> _launch(BuildContext context, Uri url) async {
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) _showLaunchError(context);
    } catch (_) {
      if (context.mounted) _showLaunchError(context);
    }
  }

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open maps app.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techProvider = context.watch<TechnicianProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final searchPoint = techProvider.hasSearchOrigin
        ? LatLng(techProvider.searchLat!, techProvider.searchLng!)
        : null;

    final techPoints = techProvider.technicians
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();

    final LatLng center;
    double zoom = 13;

    if (searchPoint != null) {
      center = searchPoint;
    } else if (techPoints.isNotEmpty) {
      center = LatLng(techPoints.first.latitude!, techPoints.first.longitude!);
      if (techPoints.length > 1) zoom = 12;
    } else {
      center = const LatLng(-6.7924, 39.2083);
      zoom = 11;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          techProvider.searchPlace != null
              ? '${l10n.near} "${techProvider.searchPlace}"'
              : l10n.nearbyMap,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              _routesData.clear();
              techProvider.refreshLastSearch();
              _fetchRoutesForTechnicians();
            },
            tooltip: 'Refresh search',
          ),
        ],
      ),
      body: techProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : techPoints.isEmpty
          ? _buildEmptyState(context, theme, techProvider, horizontalPadding)
          : _buildMap(context, theme, isDark, techProvider, techPoints, searchPoint, center, zoom),
    );
  }

  Widget _buildEmptyState(
      BuildContext context,
      ThemeData theme,
      TechnicianProvider techProvider,
      double horizontalPadding,
      ) {
    final hasTechnicians = techProvider.technicians.isNotEmpty;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 56, color: theme.hintColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              hasTechnicians ? 'No technicians with location data' : 'No technicians found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasTechnicians
                  ? 'Some technicians are missing location information'
                  : 'Try adjusting your search or location',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            if (!hasTechnicians)
              ElevatedButton.icon(
                onPressed: () => techProvider.refreshLastSearch(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(
      BuildContext context,
      ThemeData theme,
      bool isDark,
      TechnicianProvider techProvider,
      List<Technician> techPoints,
      LatLng? searchPoint,
      LatLng center,
      double zoom,
      ) {
    return Column(
      children: [
        // Map top status banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.primary.withOpacity(0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                '${techPoints.length} technician${techPoints.length > 1 ? 's' : ''} on map',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primary,
                ),
              ),
              if (_isFetchingRoutes) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
              if (searchPoint != null && !_isFetchingRoutes) ...[
                const SizedBox(width: 6),
                Text(
                  '· tap pin to view route & distance',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.primary.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: zoom,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  onTap: (_, __) {
                    setState(() {
                      _selectedTechId = null;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.nearbyfundi',
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint('TILE ERROR: $error');
                    },
                  ),

                  // Polyline routes
                  if (searchPoint != null)
                    PolylineLayer(
                      polylines: techPoints.map((tech) {
                        final isSelected = _selectedTechId == tech.id;
                        final route = _routesData[tech.id];
                        final points = route?.points ??
                            [searchPoint, LatLng(tech.latitude!, tech.longitude!)];

                        return Polyline(
                          points: points,
                          strokeWidth: isSelected ? 5.5 : 3.0,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.primary.withOpacity(0.45),
                        );
                      }).toList(),
                    ),

                  // Markers layer: RED Origin Pin + Tech Pins + Distance Badges
                  MarkerLayer(
                    markers: [
                      if (searchPoint != null) _buildRedOriginMarker(searchPoint),
                      ...techPoints.map(
                            (tech) => _buildTechnicianMarker(context, tech, isDark, searchPoint),
                      ),
                      if (searchPoint != null)
                        ...techPoints
                            .where((tech) => _routesData.containsKey(tech.id))
                            .map((tech) => _buildRouteDistanceBadge(tech, searchPoint, theme)),
                    ],
                  ),

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
              ),

              // Controls
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
                      onPressed: () => _fitAllMarkers(searchPoint, techPoints),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ONLY ORIGIN POINT IS RED
  Marker _buildRedOriginMarker(LatLng point) {
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.shade600,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  /// TECHNICIAN PINS (Using original AppTheme.primary color)
  Marker _buildTechnicianMarker(
      BuildContext context,
      Technician tech,
      bool isDark,
      LatLng? searchPoint,
      ) {
    final isSelected = _selectedTechId == tech.id;

    return Marker(
      point: LatLng(tech.latitude!, tech.longitude!),
      width: isSelected ? 52 : 44,
      height: isSelected ? 52 : 44,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTechId = tech.id;
          });

          if (searchPoint != null) {
            final bounds = LatLngBounds.fromPoints([
              searchPoint,
              LatLng(tech.latitude!, tech.longitude!),
            ]);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(70),
              ),
            );
          }

          _showTechnicianSheet(context, tech, searchPoint);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary,
            border: Border.all(
              color: isSelected ? Colors.amber : Colors.white,
              width: isSelected ? 3.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: isSelected ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.build_rounded,
            color: Colors.white,
            size: isSelected ? 26 : 22,
          ),
        ),
      ),
    );
  }

  Marker _buildRouteDistanceBadge(Technician tech, LatLng origin, ThemeData theme) {
    final routeData = _routesData[tech.id];
    if (routeData == null || routeData.points.isEmpty) {
      return Marker(point: origin, child: const SizedBox());
    }

    final midIndex = routeData.points.length ~/ 2;
    final midPoint = routeData.points[midIndex];
    final isSelected = _selectedTechId == tech.id;

    return Marker(
      point: midPoint,
      width: 90,
      height: 28,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTechId = tech.id;
          });
          _showTechnicianSheet(context, tech, origin);
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white : AppTheme.primary.withOpacity(0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '${routeData.distanceKm.toStringAsFixed(1)} km',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _showTechnicianSheet(BuildContext context, Technician tech, LatLng? searchPoint) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final hasOrigin = searchPoint != null;

    final routeData = _routesData[tech.id];
    final displayDistanceKm = routeData?.distanceKm ?? tech.distanceKm;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: theme.colorScheme.surface,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.08),
                    image: tech.profilePhoto != null
                        ? DecorationImage(
                      image: NetworkImage(ImageUtils.getFullImageUrl(tech.profilePhoto!)),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: tech.profilePhoto == null
                      ? Text(
                    tech.name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  )
                      : null,
                ),
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
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
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
                              child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                            ),
                        ],
                      ),
                      if (tech.area != null)
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: theme.hintColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tech.area!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  color: theme.hintColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (tech.rating > 0) ...[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    tech.rating.toStringAsFixed(1),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.directions_car_rounded, size: 16, color: theme.hintColor),
                const SizedBox(width: 4),
                Text(
                  '${displayDistanceKm.toStringAsFixed(1)} km driving',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                if (routeData?.durationMin != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(~${routeData!.durationMin.toStringAsFixed(0)} mins)',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (tech.services.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tech.services
                    .map(
                      (s) => Chip(
                    label: Text(
                      s,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primary,
                      ),
                    ),
                    backgroundColor: AppTheme.primary.withOpacity(0.08),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      l10n.viewProfile,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (tech.latitude != null && tech.longitude != null)
                  Container(
                    height: 50,
                    width: 56,
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
                        hasOrigin ? Icons.directions_rounded : Icons.map_rounded,
                        color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                        size: 26,
                      ),
                      onPressed: () => _openDirectionsInGoogleMaps(
                        context,
                        origin: searchPoint,
                        destination: LatLng(tech.latitude!, tech.longitude!),
                      ),
                      tooltip: hasOrigin ? l10n.directions : 'View on map',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
        icon: Icon(icon, color: AppTheme.primary, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}