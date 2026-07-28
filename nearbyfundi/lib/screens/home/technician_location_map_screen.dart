import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/technician_provider.dart';
import '../../models/technician.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../utils/image_utils.dart';
import '../../l10n/app_localizations.dart';

class TechnicianLocationMapScreen extends StatefulWidget {
  final Technician technician;

  const TechnicianLocationMapScreen({super.key, required this.technician});

  @override
  State<TechnicianLocationMapScreen> createState() => _TechnicianLocationMapScreenState();
}

class _TechnicianLocationMapScreenState extends State<TechnicianLocationMapScreen> {
  final MapController _mapController = MapController();
  static const double _minZoom = 4;
  static const double _maxZoom = 18;

  // OSRM State Variables
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  double? _osrmDistanceKm;
  double? _osrmDurationMin;

  Technician get technician => widget.technician;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOsrmRoute();
    });
  }

  /// Fetches actual driving route coordinates and metrics from OSRM
  Future<void> _fetchOsrmRoute() async {
    final techProvider = context.read<TechnicianProvider>();
    final lat = technician.latitude;
    final lng = technician.longitude;

    if (lat == null || lng == null || !techProvider.hasSearchOrigin) return;

    final origin = LatLng(techProvider.searchLat!, techProvider.searchLng!);
    final destination = LatLng(lat, lng);

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '${origin.longitude},${origin.latitude};'
            '${destination.longitude},${destination.latitude}'
            '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

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

          setState(() {
            _routePoints = points;
            _osrmDistanceKm = distanceMeters / 1000.0;
            _osrmDurationMin = durationSeconds / 60.0;
            _isLoadingRoute = false;
          });

          // Adjust map bounds to display the entire route cleanly
          _fitRouteBounds(origin, destination);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching OSRM route: $e');
    }

    // Fallback straight line if OSRM request fails or times out
    setState(() {
      _routePoints = [origin, destination];
      _isLoadingRoute = false;
    });
  }

  void _fitRouteBounds(LatLng origin, LatLng destination) {
    final bounds = LatLngBounds.fromPoints([origin, destination]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  // ─── Map controls ──────────────────────────────────────────────────
  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom + delta).clamp(_minZoom, _maxZoom);
    _mapController.move(camera.center, newZoom);
  }

  void _recenter(LatLng point, double zoom) {
    _mapController.move(point, zoom);
  }

  // ─── External Google Maps launcher ──────────────────────────────────
  Future<void> _openInGoogleMaps(
      BuildContext context, {
        required LatLng? origin,
        required LatLng destination,
      }) async {
    final Uri url;
    if (origin != null) {
      url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
            '&origin=${origin.latitude},${origin.longitude}'
            '&destination=${destination.latitude},${destination.longitude}'
            '&travelmode=driving',
      );
    } else {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1'
            '&query=${destination.latitude},${destination.longitude}',
      );
    }

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final techProvider = context.watch<TechnicianProvider>();

    final lat = technician.latitude;
    final lng = technician.longitude;

    if (lat == null || lng == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(technician.name),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Location not available for this technician.')),
      );
    }

    final destination = LatLng(lat, lng);
    final origin = techProvider.hasSearchOrigin
        ? LatLng(techProvider.searchLat!, techProvider.searchLng!)
        : null;
    final hasOrigin = origin != null;

    final fallbackKm = hasOrigin ? const Distance().as(LengthUnit.Kilometer, origin, destination) : 0.0;
    final displayKm = _osrmDistanceKm ?? (technician.distanceKm > 0 ? technician.distanceKm : fallbackKm);

    const initialZoom = 14.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          technician.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destination,
              initialZoom: initialZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.nearbyfundi',
                errorTileCallback: (tile, error, stackTrace) {
                  debugPrint('TILE ERROR: $error');
                },
              ),

              // OSRM Driving Polyline
              if (hasOrigin && _routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.5,
                      color: AppTheme.primary,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  if (hasOrigin) _buildOriginMarker(origin),
                  if (hasOrigin) _buildDistanceLabel(origin, destination, displayKm, theme),
                  _buildTechnicianMarker(context, destination, isDark),
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

          if (_isLoadingRoute)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Calculating driving route...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ─── Zoom & Recenter controls ────────────────────────────────
          Positioned(
            right: 16,
            bottom: hasOrigin ? 220 : 190,
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
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recenter',
                  onPressed: () => _recenter(destination, initialZoom),
                ),
              ],
            ),
          ),

          // ─── Floating Card ─────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: () => _showTechnicianDetailSheet(context, origin, destination, l10n, displayKm),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withOpacity(0.08),
                            image: technician.profilePhoto != null
                                ? DecorationImage(
                              image: NetworkImage(
                                ImageUtils.getFullImageUrl(technician.profilePhoto!),
                              ),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: technician.profilePhoto == null
                              ? Text(
                            technician.name[0].toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
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
                                  Flexible(
                                    child: Text(
                                      technician.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (technician.verified)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                        child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                              if (technician.area != null)
                                Text(
                                  technician.area!,
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (displayKm > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${displayKm.toStringAsFixed(1)} km',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_osrmDurationMin != null)
                                  Text(
                                    '~${_osrmDurationMin!.toStringAsFixed(0)} mins drive',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Icon(Icons.expand_less_rounded, color: theme.hintColor, size: 20),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.technicianDetail,
                              arguments: technician.id,
                            ),
                            icon: const Icon(Icons.person_rounded, size: 18),
                            label: Text(l10n.viewProfile),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openInGoogleMaps(
                              context,
                              origin: origin,
                              destination: destination,
                            ),
                            icon: Icon(hasOrigin ? Icons.directions_rounded : Icons.map_rounded, size: 18),
                            label: Text(
                              hasOrigin ? l10n.directions : 'Open in Maps',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        ],
      ),
    );
  }

  // ─── Markers ──────────────────────────────────────────────────────────
  Marker _buildOriginMarker(LatLng point) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.location_on, color: Colors.white, size: 22),
      ),
    );
  }

  Marker _buildTechnicianMarker(BuildContext context, LatLng point, bool isDark) {
    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () {
          final techProvider = context.read<TechnicianProvider>();
          final origin = techProvider.hasSearchOrigin
              ? LatLng(techProvider.searchLat!, techProvider.searchLng!)
              : null;
          final l10n = AppLocalizations.of(context)!;
          final fallbackKm = origin != null ? const Distance().as(LengthUnit.Kilometer, origin, point) : 0.0;
          final displayKm = _osrmDistanceKm ?? (technician.distanceKm > 0 ? technician.distanceKm : fallbackKm);

          _showTechnicianDetailSheet(context, origin, point, l10n, displayKm);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: technician.isOnline
                ? (isDark ? Colors.green.shade300 : Colors.green)
                : (isDark ? Colors.grey.shade600 : Colors.grey),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.build_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  /// Marker label positioned along the mid-point showing the calculated OSRM driving distance
  Marker _buildDistanceLabel(LatLng origin, LatLng destination, double km, ThemeData theme) {
    final midpoint = _routePoints.isNotEmpty
        ? _routePoints[_routePoints.length ~/ 2]
        : LatLng(
      (origin.latitude + destination.latitude) / 2,
      (origin.longitude + destination.longitude) / 2,
    );

    return Marker(
      point: midpoint,
      width: 100,
      height: 32,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '${km.toStringAsFixed(1)} km ${_osrmDurationMin != null ? '(${_osrmDurationMin!.toStringAsFixed(0)}m)' : ''}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  // ─── Detail modal ───────────────────────────────────────────────────
  void _showTechnicianDetailSheet(
      BuildContext context,
      LatLng? origin,
      LatLng destination,
      AppLocalizations l10n,
      double displayKm,
      ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasOrigin = origin != null;

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
                    image: technician.profilePhoto != null
                        ? DecorationImage(
                      image: NetworkImage(ImageUtils.getFullImageUrl(technician.profilePhoto!)),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: technician.profilePhoto == null
                      ? Text(
                    technician.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
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
                              technician.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (technician.verified)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                            ),
                        ],
                      ),
                      if (technician.area != null)
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: theme.hintColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                technician.area!,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, color: theme.hintColor),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (technician.isOnline ? Colors.green : Colors.grey).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    technician.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: technician.isOnline
                          ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                          : theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (technician.rating > 0) ...[
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    technician.rating.toStringAsFixed(1),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                ],
                if (displayKm > 0) ...[
                  Icon(Icons.directions_car_rounded, size: 17, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    '${displayKm.toStringAsFixed(1)} km driving',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                ],
              ],
            ),
            if (technician.services.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: technician.services
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
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(context, AppRoutes.technicianDetail, arguments: technician.id);
                    },
                    icon: const Icon(Icons.person_rounded, size: 18),
                    label: Text(l10n.viewProfile),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openInGoogleMaps(context, origin: origin, destination: destination),
                    icon: Icon(hasOrigin ? Icons.directions_rounded : Icons.map_rounded, size: 18),
                    label: Text(
                      hasOrigin ? l10n.directions : 'Open in Maps',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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