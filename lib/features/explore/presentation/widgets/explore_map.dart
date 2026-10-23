import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/category_icon.dart';
import '../../data/saved_project_store.dart';
import '../../domain/explore_map_data.dart';
import '../../domain/project.dart';
import 'condition_label.dart';

/// Map mode of Jelajahi: one marker per (already filtered) project, plus the
/// conservation-area layer from the mock map data.
///
/// The page owns the filtering; this widget draws what it is given and reports
/// a marker tap through [onOpenProject], so it stays free of routing concerns
/// and testable on its own.
class ExploreMap extends StatefulWidget {
  const ExploreMap({
    super.key,
    required this.projects,
    required this.mapData,
    required this.userLocationLabel,
    this.showConservationLayer = false,
    this.offline = false,
    this.tileProvider,
    this.initialZoom = 4,
    this.onOpenProject,
  });

  final List<Project> projects;
  final ExploreMapData mapData;

  /// Names the mock reference location behind the distance filter.
  final String userLocationLabel;

  final bool showConservationLayer;

  /// Offline skips the OpenStreetMap tile layer entirely — no network call —
  /// while markers and polygons still draw over the background colour.
  final bool offline;

  /// Test seam: replaces the network tile provider.
  final TileProvider? tileProvider;

  final double initialZoom;

  final ValueChanged<String>? onOpenProject;

  @override
  State<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends State<ExploreMap> {
  static const double _minZoom = 3;
  static const double _maxZoom = 12;

  final _controller = MapController();
  late double _zoom = widget.initialZoom;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            backgroundColor: AppColors.ocean.withValues(alpha: 0.08),
          ),
          children: [
            if (!widget.offline)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.bluetrack',
                tileProvider: widget.tileProvider,
              ),
            if (widget.showConservationLayer)
              PolygonLayer(
                key: const ValueKey('explore.conservationLayer'),
                polygons: [
                  for (final area in widget.mapData.conservationAreas)
                    Polygon(
                      points: area.points,
                      color: CategoryIcons.colorFor(
                        area.status.id,
                      ).withValues(alpha: 0.18),
                      borderColor: CategoryIcons.colorFor(area.status.id),
                      borderStrokeWidth: 1.5,
                    ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final project in widget.projects)
                  Marker(
                    point: LatLng(project.latitude, project.longitude),
                    width: 40,
                    height: 40,
                    child: _ProjectMarker(
                      key: ValueKey('explore.marker.${project.id}'),
                      project: project,
                      onTap: () => _openProjectSheet(project),
                    ),
                  ),
              ],
            ),
            // OpenStreetMap asks for attribution whenever its tiles are shown.
            if (!widget.offline) const _Attribution(),
          ],
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: _MapCountBadge(count: widget.projects.length),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              _ZoomButton(
                icon: Icons.add,
                tooltip: context.tr('p03_map_zoom_in'),
                onPressed: () => _zoomBy(1),
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.remove,
                tooltip: context.tr('p03_map_zoom_out'),
                onPressed: () => _zoomBy(-1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Midpoint of the filtered projects, so filtering cannot strand the user on
  /// the other side of the country.
  LatLng get _center {
    if (widget.projects.isEmpty) return widget.mapData.userLocation;
    var lat = 0.0;
    var lng = 0.0;
    for (final project in widget.projects) {
      lat += project.latitude;
      lng += project.longitude;
    }
    return LatLng(lat / widget.projects.length, lng / widget.projects.length);
  }

  void _zoomBy(double step) {
    final camera = _controller.camera;
    _zoom = (camera.zoom + step).clamp(_minZoom, _maxZoom);
    _controller.move(camera.center, _zoom);
  }

  void _openProjectSheet(Project project) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ProjectPreviewSheet(
        project: project,
        condition: widget.mapData.conditionOf(project.id),
        distance: distanceKm(
          widget.mapData.userLocation,
          LatLng(project.latitude, project.longitude),
        ),
        userLocationLabel: widget.userLocationLabel,
        onOpenProject: widget.onOpenProject,
      ),
    );
  }
}

/// Category-coloured pin: the glyph tells the five categories apart, so the map
/// reads without a legend.
class _ProjectMarker extends StatelessWidget {
  const _ProjectMarker({super.key, required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryIcons.colorFor(project.category);
    return Tooltip(
      message: project.title,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: CategoryIcon(
              category: project.category,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectPreviewSheet extends StatelessWidget {
  const _ProjectPreviewSheet({
    required this.project,
    required this.condition,
    required this.distance,
    required this.userLocationLabel,
    required this.onOpenProject,
  });

  final Project project;
  final ProjectCondition? condition;
  final double distance;
  final String userLocationLabel;
  final ValueChanged<String>? onOpenProject;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CategoryIcon(category: project.category, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                _SaveButton(project: project),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${project.orgName} • ${project.location}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (condition != null)
                  _SheetFact(
                    icon: Icons.health_and_safety_outlined,
                    text:
                        '${context.tr('p03_map_condition')}: '
                        '${condition!.label(context)}',
                  ),
                _SheetFact(
                  icon: Icons.straighten,
                  text: context.tr('p03_map_distance', {
                    'n': '${distance.round()}',
                    'place': userLocationLabel,
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenProject?.call(project.id);
                },
                child: Text(context.tr('p03_map_open_project')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bookmark for the project in the map sheet — same saved collection and
/// offline snapshot as the list card.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SavedProjectsController.instance,
      builder: (context, _) {
        final saved = SavedProjectsController.instance.isSaved(project.id);
        return IconButton(
          tooltip: context.tr(saved ? 'p03_saved' : 'p03_save'),
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
          color: saved ? AppColors.ocean : AppColors.textSecondary,
          onPressed: () => toggleSavedProject(project),
        );
      },
    );
  }
}

class _SheetFact extends StatelessWidget {
  const _SheetFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MapCountBadge extends StatelessWidget {
  const _MapCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          context.tr('p03_map_count', {'n': '$count'}),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return const RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      attributions: [TextSourceAttribution('OpenStreetMap contributors')],
    );
  }
}
