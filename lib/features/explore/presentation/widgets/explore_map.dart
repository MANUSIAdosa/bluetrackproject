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
    this.onConservationLayerChanged,
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

  /// Page-owned layer state: the floating switch reports changes here so the
  /// layer survives rebuilding the map (zoom, filter changes).
  final ValueChanged<bool>? onConservationLayerChanged;

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

  /// Markers closer than this on screen are merged into one cluster. 44px is
  /// the smallest gap at which two 40dp pins stay separately tappable.
  static const double _clusterRadius = 44;

  /// Tap target of a pin or cluster; the visual circle stays 40dp.
  static const double _tapSize = 48;

  final _controller = MapController();
  late double _zoom = widget.initialZoom;

  /// Camera of the last zoom level, used to measure marker distances in
  /// screen pixels. Panning does not change relative distances, so only a zoom
  /// change rebuilds the clusters.
  MapCamera? _camera;

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
            onMapReady: () => setState(() => _camera = _controller.camera),
            onPositionChanged: (camera, _) {
              if (_camera?.zoom != camera.zoom) {
                setState(() => _camera = camera);
              }
            },
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
                      color: area.status.color.withValues(alpha: 0.18),
                      borderColor: area.status.color,
                      borderStrokeWidth: 1.5,
                    ),
                ],
              ),
            MarkerLayer(markers: _markers()),
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
          left: 16,
          top: 16,
          child: _ConservationLayerCard(
            enabled: widget.showConservationLayer,
            onChanged: widget.onConservationLayerChanged,
          ),
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

  /// Projects whose pins land closer than [_clusterRadius] on screen become
  /// one numbered marker. Pin positions stay on their real coordinates.
  List<Marker> _markers() {
    final groups = _clusterGroups();
    return [
      for (final group in groups)
        if (group.length > 1)
          Marker(
            point: LatLngBounds.fromPoints([
              for (final project in group)
                LatLng(project.latitude, project.longitude),
            ]).center,
            width: _tapSize,
            height: _tapSize,
            child: _ClusterMarker(
              key: const ValueKey('explore.cluster'),
              count: group.length,
              onTap: () => _openCluster(group),
            ),
          )
        else
          Marker(
            point: LatLng(group.single.latitude, group.single.longitude),
            width: _tapSize,
            height: _tapSize,
            child: _ProjectMarker(
              key: ValueKey('explore.marker.${group.single.id}'),
              project: group.single,
              onTap: () => _openProjectSheet(group.single),
            ),
          ),
    ];
  }

  /// Greedy grouping in screen space: a project joins the first group whose
  /// first member is within [_clusterRadius] pixels of it.
  List<List<Project>> _clusterGroups() {
    final camera = _camera;
    if (camera == null) {
      return [
        for (final project in widget.projects) [project],
      ];
    }

    final groups = <List<Project>>[];
    final anchors = <Offset>[];
    for (final project in widget.projects) {
      final offset = camera.latLngToScreenOffset(
        LatLng(project.latitude, project.longitude),
      );
      final index = anchors.indexWhere(
        (anchor) => (anchor - offset).distance < _clusterRadius,
      );
      if (index == -1) {
        anchors.add(offset);
        groups.add([project]);
      } else {
        groups[index].add(project);
      }
    }
    return groups;
  }

  /// Zoom into the cluster's members' bounds. The higher max zoom is what
  /// actually separates the pins; a fit that stays at the current zoom would
  /// keep them clustered.
  void _openCluster(List<Project> projects) {
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          for (final project in projects)
            LatLng(project.latitude, project.longitude),
        ]),
        padding: const EdgeInsets.all(48),
        maxZoom: _maxZoom,
      ),
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
    return Semantics(
      button: true,
      label: project.title,
      child: Tooltip(
        message: project.title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: _ExploreMapState._tapSize,
            height: _ExploreMapState._tapSize,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
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
                  child: ExcludeSemantics(
                    child: CategoryIcon(
                      category: project.category,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Numbered pin for projects that would overlap at the current zoom. Tapping
/// it zooms into the group's bounds until the pins separate.
class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('p03_map_cluster', {'n': '$count'});
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: _ExploreMapState._tapSize,
            height: _ExploreMapState._tapSize,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.oceanDeep,
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
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
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
          onPressed: () async {
            try {
              await toggleSavedProject(project);
            } catch (_) {
              // Rolls back inside the entry point; the sheet stays open.
            }
          },
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

/// Floating card for the conservation-area layer.
///
/// A switch is the right control here: the layer is either drawn or not. The
/// legend appears only while it is on, because that is when the polygon colours
/// need explaining.
class _ConservationLayerCard extends StatelessWidget {
  const _ConservationLayerCard({required this.enabled, this.onChanged});

  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('p03_map_layer_conservation'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    key: const ValueKey('explore.conservationSwitch'),
                    value: enabled,
                    onChanged: onChanged,
                    // Both tracks clear 3:1 against the white card: ocean
                    // (4.1:1) when on, slate (4.8:1) when off, so the state
                    // reads without relying on colour alone.
                    activeTrackColor: AppColors.ocean,
                    inactiveTrackColor: AppColors.textSecondary,
                    activeThumbColor: Colors.white,
                    inactiveThumbColor: Colors.white,
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.oceanDeep
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (enabled) ...[
              const Divider(height: 12, color: AppColors.border),
              Text(
                context.tr('p03_map_legend'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              for (final condition in ProjectCondition.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        key: ValueKey('explore.legend.${condition.id}'),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: condition.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        condition.label(context),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
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
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
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
