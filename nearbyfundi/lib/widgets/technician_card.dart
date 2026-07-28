import 'package:flutter/material.dart';
import '../models/technician.dart';
import '../screens/home/technician_location_map_screen.dart';
import '../utils/image_utils.dart';

class TechnicianCard extends StatelessWidget {
  final Technician technician;
  final VoidCallback onTap;

  const TechnicianCard({
    super.key,
    required this.technician,
    required this.onTap,
  });

  /// Opens the in-app OpenStreetMap view for this technician, showing
  /// their pin (and, if the user came from a place search, the route
  /// from that search point). Directions to Google Maps are offered
  /// from within that screen.
  void _openLocationMap(BuildContext context) {
    if (technician.latitude == null || technician.longitude == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TechnicianLocationMapScreen(technician: technician),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shadowColor: isDark ? Colors.black26 : Colors.grey.shade200,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: theme.primaryColor.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----- Avatar -----
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
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
                    ? Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: Colors.grey.shade500,
                )
                    : null,
              ),
              const SizedBox(width: 14),

              // ----- Middle (Info) -----
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Verified badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            technician.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (technician.verified)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              padding: const EdgeInsets.all(3),
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
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Area
                    if (technician.area != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              technician.area!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),

                    // Rating + Distance
                    Row(
                      children: [
                        if (technician.rating > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            technician.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 14,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (technician.distanceKm > 0) ...[
                          Icon(
                            Icons.place_rounded,
                            size: 15,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${technician.distanceKm.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Service Tags (max 3)
                    if (technician.services.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: technician.services.take(3).map((service) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
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

              // ----- Right Actions (Map + Arrow) -----
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (technician.latitude != null && technician.longitude != null)
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.map_rounded,
                              size: 18,
                              color: Colors.green.shade700,
                            ),
                            onPressed: () => _openLocationMap(context),
                            tooltip: 'View on map',
                          ),
                        ),
                      const SizedBox(width: 4),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: theme.primaryColor,
                          ),
                          onPressed: onTap,
                          tooltip: 'View profile',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}