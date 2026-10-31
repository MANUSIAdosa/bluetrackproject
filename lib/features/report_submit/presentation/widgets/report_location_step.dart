import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_location_service.dart';
import '../../domain/report_location.dart';

/// Step 2 of "Lapor Temuan": place a pin on the finding.
///
/// The map stays usable no matter what GPS does. A failure only shows a dialog;
/// the pin can always be set by tapping the map or dragging it. Offline hides
/// the OpenStreetMap tile layer (the page banner explains why), while taps,
/// drags and the draft keep working.
class ReportLocationStep extends StatefulWidget {
  const ReportLocationStep({
    super.key,
    required this.locationService,
    required this.onLocationChanged,
    this.latitude,
    this.longitude,
    this.tileProvider,
  });

  /// Injected so tests (and a future platform implementation) do not depend on
  /// Geolocator.
  final ReportLocationService locationService;

  /// Called whenever the pin moves, including while it is being dragged.
  final void Function(double latitude, double longitude) onLocationChanged;

  /// Pin restored from the draft.
  final double? latitude;
  final double? longitude;

  /// Test seam: replaces the network tile provider.
  final TileProvider? tileProvider;

  @override
  State<ReportLocationStep> createState() => _ReportLocationStepState();
}

class _ReportLocationStepState extends State<ReportLocationStep> {
  static const double _initialZoom = 13;
  static const double _gpsZoom = 15;

  final MapController _mapController = MapController();
  final GlobalKey _mapBoxKey = GlobalKey();

  LatLng? _location;
  bool _mapReady = false;
  bool _locating = false;
  bool _draggingPin = false;
  int? _dragPointer;

  LatLng? get _draftLocation {
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  /// Uses the saved pin when there is one. GPS is fetched only when the user
  /// asks for it, so opening this step never triggers a permission prompt.
  LatLng get _initialCenter =>
      _location ??
      const LatLng(
        AppConfig.reportDefaultLatitude,
        AppConfig.reportDefaultLongitude,
      );

  @override
  void initState() {
    super.initState();
    _location = _draftLocation;
  }

  @override
  void didUpdateWidget(covariant ReportLocationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _draftLocation;
    if (next != null) _location = next;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _setLocation(LatLng point, {bool recenter = false}) {
    setState(() => _location = point);
    widget.onLocationChanged(point.latitude, point.longitude);

    if (recenter && _mapReady) {
      final zoom = _mapController.camera.zoom;
      _mapController.move(point, zoom < _gpsZoom ? _gpsZoom : zoom);
    }
  }

  void _handlePinDown(PointerDownEvent event) {
    _dragPointer = event.pointer;
    // Stop the map from panning under the finger while the pin is dragged.
    if (!_draggingPin) setState(() => _draggingPin = true);
  }

  void _handlePinMove(PointerMoveEvent event) {
    if (_dragPointer != event.pointer) return;
    final box = _mapBoxKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(event.position);
    _setLocation(_mapController.camera.screenOffsetToLatLng(local));
  }

  void _endPinDrag() {
    _dragPointer = null;
    if (_draggingPin && mounted) setState(() => _draggingPin = false);
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;

    setState(() => _locating = true);
    ReportLocationResult result;
    try {
      result = await widget.locationService.currentLocation();
    } catch (_) {
      result = const ReportLocationResult.failed(
        ReportLocationFailure.unavailable,
      );
    }
    if (!mounted) return;
    setState(() => _locating = false);

    if (!result.hasLocation) {
      await _showFailure(result.failure ?? ReportLocationFailure.unavailable);
      return;
    }

    _setLocation(LatLng(result.latitude!, result.longitude!), recenter: true);
  }

  Future<void> _showFailure(ReportLocationFailure failure) async {
    final canOpenSettings =
        failure == ReportLocationFailure.permissionDeniedForever ||
        failure == ReportLocationFailure.serviceDisabled;
    final opensAppSettings =
        failure == ReportLocationFailure.permissionDeniedForever;

    final messageKey = switch (failure) {
      ReportLocationFailure.permissionDenied =>
        'report_location_permission_denied',
      ReportLocationFailure.permissionDeniedForever =>
        'report_location_permission_denied_forever',
      ReportLocationFailure.serviceDisabled =>
        'report_location_service_disabled',
      ReportLocationFailure.timeout => 'report_location_timeout',
      ReportLocationFailure.unavailable => 'report_location_unavailable',
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('report_location_error_title')),
        content: Text(dialogContext.tr(messageKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('report_location_manual')),
          ),
          if (canOpenSettings)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                var opened = false;
                try {
                  opened = opensAppSettings
                      ? await widget.locationService.openAppSettings()
                      : await widget.locationService.openLocationSettings();
                } catch (_) {
                  opened = false;
                }
                if (!mounted || opened) return;
                _showSnack(context.tr('report_location_settings_failed'));
              },
              child: Text(
                dialogContext.tr(
                  opensAppSettings
                      ? 'report_location_open_settings'
                      : 'report_location_open_location_settings',
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OfflineController.instance,
      builder: (context, _) {
        final offline = OfflineController.instance.offline;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('report_location_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('report_location_body'),
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              key: _mapBoxKey,
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FlutterMap(
                      key: const ValueKey('report_location_map'),
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _initialCenter,
                        initialZoom: _initialZoom,
                        minZoom: 3,
                        maxZoom: 18,
                        backgroundColor: AppColors.ocean.withValues(
                          alpha: 0.08,
                        ),
                        interactionOptions: InteractionOptions(
                          flags: _draggingPin
                              ? InteractiveFlag.none
                              : InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                        onMapReady: () {
                          if (!mounted) return;
                          setState(() => _mapReady = true);
                        },
                        onTap: (_, point) => _setLocation(point),
                      ),
                      children: [
                        if (!offline)
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'app.bluetrack',
                            tileProvider: widget.tileProvider,
                          ),
                        const RichAttributionWidget(
                          key: ValueKey('report_location_attribution'),
                          alignment: AttributionAlignment.bottomRight,
                          attributions: [
                            TextSourceAttribution('OpenStreetMap contributors'),
                          ],
                        ),
                      ],
                    ),
                    // The pin is an overlay instead of a MarkerLayer child so
                    // its drag gesture always wins over the map's pan. It is
                    // repositioned from the camera on every map event.
                    if (_location case final point? when _mapReady)
                      StreamBuilder<MapEvent>(
                        stream: _mapController.mapEventStream,
                        builder: (context, snapshot) {
                          final offset = _mapController.camera
                              .latLngToScreenOffset(point);
                          return Positioned(
                            left: offset.dx - 24,
                            top: offset.dy - 48,
                            width: 48,
                            height: 48,
                            child: Listener(
                              key: const ValueKey('report_location_pin_drag'),
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: _handlePinDown,
                              onPointerMove: _handlePinMove,
                              onPointerUp: (_) => _endPinDrag(),
                              onPointerCancel: (_) => _endPinDrag(),
                              child: const Icon(
                                Icons.location_on,
                                size: 48,
                                color: AppColors.coral,
                              ),
                            ),
                          );
                        },
                      ),
                    if (_location == null)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: IgnorePointer(
                          child: Align(
                            child: _MapHint(
                              text: context.tr('report_location_hint'),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('report_location_gps'),
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  context.tr(
                    _locating
                        ? 'report_location_gps_loading'
                        : 'report_location_gps',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _CoordinateCard(
              latitude: _location?.latitude,
              longitude: _location?.longitude,
            ),
          ],
        );
      },
    );
  }
}

class _MapHint extends StatelessWidget {
  const _MapHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('report_location_hint'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.touch_app_outlined,
            size: 16,
            color: AppColors.ocean,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinateCard extends StatelessWidget {
  const _CoordinateCard({required this.latitude, required this.longitude});

  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    // TODO(lapor): reverse geocoding is not available yet. Show the raw
    // coordinates (six decimals ≈ 0.11 m) instead of inventing an address.
    return Container(
      key: const ValueKey('report_location_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('report_location_card_title'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (latitude == null || longitude == null)
            Text(
              context.tr('report_location_empty_hint'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _CoordinateValue(
                    label: context.tr('report_location_latitude'),
                    value: latitude!.toStringAsFixed(6),
                    valueKey: const ValueKey('report_location_latitude_value'),
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                const SizedBox(width: 16),
                Expanded(
                  child: _CoordinateValue(
                    label: context.tr('report_location_longitude'),
                    value: longitude!.toStringAsFixed(6),
                    valueKey: const ValueKey('report_location_longitude_value'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CoordinateValue extends StatelessWidget {
  const _CoordinateValue({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
