import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/technician_provider.dart';
import '../../models/technician.dart';
import '../../config/app_routes.dart';
import '../../utils/image_utils.dart';
import '../../l10n/app_localizations.dart';

/// Shows the geocoded search location as a pin, plus every technician
/// found by the last place search, connected back to the search point
/// with a straight line — so "nearby" is visible, not just a list.
class NearbyMapScreen extends StatelessWidget {
  const NearbyMapScreen({super.key});

  void _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Silently fail
    }
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

    // Fallback center if no search point yet (Dar es Salaam)
    final center = searchPoint ??
        (techPoints.isNotEmpty
            ? LatLng(techPoints.first.latitude!, techPoints.first.longitude!)
            : const LatLng(-6.7924, 39.2083));

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          techProvider.searchPlace != null
              ? '${l10n.near} "${techProvider.searchPlace}"'
              : l10n.nearbyMap,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: Container(
        color: theme.colorScheme.surface,
        child: searchPoint == null && techPoints.isEmpty
            ? Center(
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.map_outlined,
                    size: 56,
                    color: theme.primaryColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.searchPlaceFirst,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.searchPlaceHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        )
            : FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nearbyfundi.app',
            ),

            // Lines from the searched place to every technician found
            if (searchPoint != null)
              PolylineLayer(
                polylines: techPoints.map((tech) {
                  return Polyline(
                    points: [
                      searchPoint,
                      LatLng(tech.latitude!, tech.longitude!),
                    ],
                    strokeWidth: 2.5,
                    color: theme.primaryColor.withOpacity(0.6),
                  );
                }).toList(),
              ),

            MarkerLayer(
              markers: [
                // The searched place — bigger pin, distinct color
                if (searchPoint != null)
                  Marker(
                    point: searchPoint,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 44,
                    ),
                  ),

                // Each technician found near that place
                ...techPoints.map((tech) {
                  return Marker(
                    point: LatLng(tech.latitude!, tech.longitude!),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showTechnicianSheet(context, tech),
                      child: Icon(
                        Icons.build_circle_rounded,
                        color: tech.isOnline
                            ? (isDark ? Colors.green.shade300 : Colors.green)
                            : (isDark ? Colors.grey.shade600 : Colors.grey),
                        size: 34,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTechnicianSheet(BuildContext context, Technician tech) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: theme.colorScheme.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with profile photo
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primaryColor.withOpacity(0.08),
                    image: tech.profilePhoto != null
                        ? DecorationImage(
                      image: NetworkImage(
                        ImageUtils.getFullImageUrl(tech.profilePhoto!),
                      ),
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
                      color: theme.primaryColor,
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
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      if (tech.area != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: theme.hintColor,
                            ),
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

            // Rating & Distance
            Row(
              children: [
                if (tech.rating > 0) ...[
                  Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    tech.rating.toStringAsFixed(1),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.place_rounded, size: 16, color: theme.hintColor),
                const SizedBox(width: 2),
                Text(
                  '${tech.distanceKm.toStringAsFixed(1)} ${l10n.kmAway}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Service chips
            if (tech.services.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tech.services.map((s) => Chip(
                  label: Text(
                    s,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.primaryColor,
                    ),
                  ),
                  backgroundColor: theme.primaryColor.withOpacity(0.08),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons Row
            Row(
              children: [
                // View Profile Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        AppRoutes.technicianDetail,
                        arguments: tech.id,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      l10n.viewProfile,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Directions Button
                if (tech.latitude != null && tech.longitude != null)
                  Container(
                    height: 50,
                    width: 56,
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
                        color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                        size: 26,
                      ),
                      onPressed: () => _openGoogleMaps(
                        tech.latitude!,
                        tech.longitude!,
                      ),
                      tooltip: l10n.directions,
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