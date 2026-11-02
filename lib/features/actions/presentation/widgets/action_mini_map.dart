import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';

/// Non-interactive mini map for the action detail page.
///
/// The map is wrapped in [IgnorePointer] and uses [InteractiveFlag.none], so a
/// vertical drag scrolls the detail page instead of panning the map. Tiles are
/// skipped while the app is offline; the marker and background still render.
class ActionMiniMap extends StatelessWidget {
  const ActionMiniMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.tileProvider,
  });

  final double latitude;
  final double longitude;

  /// Test seam: replaces the network tile provider.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final point = LatLng(latitude, longitude);

    return ListenableBuilder(
      listenable: OfflineController.instance,
      builder: (context, _) {
        final offline = OfflineController.instance.offline;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(color: colors.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            child: SizedBox(
              key: const ValueKey('action.detail.map'),
              height: 170,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                          backgroundColor: colors.primary.withValues(
                            alpha: 0.08,
                          ),
                        ),
                        children: [
                          if (!offline)
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'app.bluetrack',
                              tileProvider: tileProvider,
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: point,
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.location_on,
                                  key: const ValueKey('action.detail.marker'),
                                  size: 44,
                                  color: colors.tertiary,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!offline)
                    Positioned(
                      right: 6,
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          child: Text(
                            '© OpenStreetMap',
                            style: TextStyle(
                              fontSize: 9,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
