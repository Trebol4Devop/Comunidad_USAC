import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/url_utils.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  String _selectedCampus = 'Todas';

  List<Map<String, dynamic>> get _locations {
    final seenCoordinates = <String>{};
    return USACConstants.campusBuildings.where((location) {
      final latitude = location['latitude'];
      final longitude = location['longitude'];
      if (latitude is! num || longitude is! num) return false;
      if (_selectedCampus != 'Todas' &&
          location['sede_id'] != _campusIdFor(_selectedCampus)) {
        return false;
      }
      final coordinates = '$latitude,$longitude';
      return seenCoordinates.add(coordinates);
    }).toList();
  }

  String? _campusIdFor(String campus) => switch (campus) {
    'Campus Central' => 'central',
    'CUM' => 'cum',
    _ => null,
  };

  Future<void> _openDirections(Map<String, dynamic> location) async {
    final latitude = location['latitude'] as num;
    final longitude = location['longitude'] as num;
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'walking',
    });
    await UrlUtils.openUrl(context, url.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locations = _locations;

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 20 : 32,
            vertical: 24,
          ),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mapa', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Puntos de encuentro y edificios de la USAC',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final campus in const [
                        'Todas',
                        'Campus Central',
                        'CUM',
                      ])
                        ChoiceChip(
                          label: Text(campus),
                          selected: _selectedCampus == campus,
                          onSelected: (_) =>
                              setState(() => _selectedCampus = campus),
                          showCheckmark: false,
                          backgroundColor: theme.colorScheme.surface,
                          selectedColor: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.07),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${locations.length} ubicaciones',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final location in locations)
                    _LocationRow(
                      location: location,
                      onDirections: () => _openDirections(location),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final Map<String, dynamic> location;
  final VoidCallback onDirections;

  const _LocationRow({required this.location, required this.onDirections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 21,
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location['building_code'] as String? ?? 'Ubicación USAC',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location['description'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cómo llegar',
            onPressed: onDirections,
            icon: const Icon(Icons.directions_outlined),
          ),
        ],
      ),
    );
  }
}
