// screens/tracking/tracking_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/request.dart';
import '../../providers/request_provider.dart';
import '../../services/api_service.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_localizations.dart';

class TrackingScreen extends StatefulWidget {
  final int requestId;

  const TrackingScreen({super.key, required this.requestId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  ServiceRequest? _request;
  bool _isLoading = true;
  String? _error;
  List<LatLng> _routePoints = [];
  double? _distance;
  String? _eta;
  double? _technicianLat;
  double? _technicianLng;
  double? _customerLat;
  double? _customerLng;

  @override
  void initState() {
    super.initState();
    _loadTrackingData();
  }

  Future<void> _loadTrackingData() async {
    setState(() => _isLoading = true);
    final api = ApiService();
    final response = await api.getTrackingData(widget.requestId);
    if (response.success && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final techLoc = data['technician_location'] as Map<String, dynamic>?;
      final custLoc = data['customer_location'] as Map<String, dynamic>?;
      _technicianLat = techLoc?['lat']?.toDouble();
      _technicianLng = techLoc?['lng']?.toDouble();
      _customerLat = custLoc?['lat']?.toDouble();
      _customerLng = custLoc?['lng']?.toDouble();
      _distance = data['distance_km']?.toDouble();
      _eta = data['eta'];

      // Fetch request details
      final reqProvider = context.read<RequestProvider>();
      await reqProvider.loadMyRequests();

      // Safely get the request – if not found, keep null
      try {
        _request = reqProvider.requests.firstWhere((r) => r.id == widget.requestId);
      } catch (_) {
        _request = null;
      }

      // Fetch route from OSRM if both locations exist
      if (_technicianLat != null && _technicianLng != null &&
          _customerLat != null && _customerLng != null) {
        final origin = LatLng(_technicianLat!, _technicianLng!);
        final dest = LatLng(_customerLat!, _customerLng!);
        await _fetchOsrmRoute(origin, dest);
      }
    } else {
      _error = response.message;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchOsrmRoute(LatLng origin, LatLng destination) async {
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
          setState(() => _routePoints = points);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Tracking', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
        children: [
          // Map
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _technicianLat != null && _technicianLng != null
                    ? LatLng(_technicianLat!, _technicianLng!)
                    : const LatLng(-6.7924, 39.2083),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.nearbyfundi',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_technicianLat != null && _technicianLng != null)
                      Marker(
                        point: LatLng(_technicianLat!, _technicianLng!),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    if (_customerLat != null && _customerLng != null)
                      Marker(
                        point: LatLng(_customerLat!, _customerLng!),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                      onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(Icons.route_rounded, '${_distance?.toStringAsFixed(1) ?? '--'} km', 'Distance', theme),
                _buildInfoItem(Icons.timer_rounded, _eta?.substring(11, 16) ?? '--:--', 'ETA', theme),
                _buildInfoItem(
                  Icons.circle_rounded,
                  _request?.status ?? '--',
                  'Status',
                  theme,
                  color: _request?.status == 'on_the_way'
                      ? Colors.green
                      : _request?.status == 'arrived'
                      ? Colors.teal
                      : Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label, ThemeData theme, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? theme.primaryColor, size: 28),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}