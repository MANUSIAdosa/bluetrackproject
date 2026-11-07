import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../data/geocoding_service.dart';
import '../../data/report_location_service.dart';
import '../../domain/geocoding.dart';
import '../../domain/report_location.dart';
import 'report_address_search_sheet.dart';

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
    required this.onLocationDetailChanged,
    required this.onAreaChanged,
    this.geocodingService,
    this.locationDetail = '',
    this.areaName = '',
    this.latitude,
    this.longitude,
    this.tileProvider,
  });

  /// Injected so tests (and a future platform implementation) do not depend on
  /// Geolocator.
  final ReportLocationService locationService;

  /// Called whenever the pin moves, including while it is being dragged.
  final void Function(double latitude, double longitude) onLocationChanged;

  /// Optional nearby landmark or area entered by the reporter.
  final String locationDetail;

  /// Called whenever the optional location detail changes.
  final ValueChanged<String> onLocationDetailChanged;

  /// Resolved area name restored from the draft, if any.
  final String areaName;

  /// Called when a lookup or a chosen search result yields a new area name.
  final ValueChanged<String> onAreaChanged;

  /// Test seam: the place lookup provider. Defaults to public Nominatim.
  final GeocodingService? geocodingService;

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
  late final TextEditingController _detailController = TextEditingController(
    text: widget.locationDetail,
  );
  late final GeocodingService _geocoding =
      widget.geocodingService ?? NominatimGeocodingService();

  LatLng? _location;
  bool _mapReady = false;
  bool _locating = false;
  bool _draggingPin = false;
  int? _dragPointer;

  late String _areaName = widget.areaName;
  bool _areaLoading = false;
  GeocodingFailure? _areaFailure;

  /// Key (4 decimals) of the point whose name is currently shown, so moving
  /// the pin always refreshes it while an unchanged point reuses the answer.
  String? _areaKey;
  Timer? _areaTimer;

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
    if (_location != null) _scheduleAreaLookup(delay: Duration.zero);
  }

  @override
  void didUpdateWidget(covariant ReportLocationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _draftLocation;
    if (next != null) _location = next;
    // A resolved area name or a resumed draft can change the landmark text;
    // the controller follows unless the reporter is already typing that text.
    if (widget.areaName != oldWidget.areaName && widget.areaName != _areaName) {
      _areaName = widget.areaName;
    }
    if (widget.locationDetail != oldWidget.locationDetail &&
        widget.locationDetail != _detailController.text) {
      _detailController.value = TextEditingValue(
        text: widget.locationDetail,
        selection: TextSelection.collapsed(
          offset: widget.locationDetail.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _areaTimer?.cancel();
    _mapController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  String get _languageCode => Localizations.localeOf(context).languageCode;

  /// Names the area after the pin settles.
  ///
  /// Debounced because a drag emits many positions, and the service itself
  /// spaces requests at least 1.1 s apart, so public Nominatim is never
  /// flooded. Moving the pin to a new point always refreshes the name.
  void _scheduleAreaLookup({
    Duration delay = const Duration(milliseconds: 900),
  }) {
    _areaTimer?.cancel();
    if (_location == null) return;
    if (OfflineController.instance.offline) return;
    _areaTimer = Timer(delay, () => unawaited(_lookupArea()));
  }

  String _keyFor(LatLng point) =>
      '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';

  Future<void> _lookupArea() async {
    final point = _location;
    if (point == null || _areaLoading) return;
    final key = _keyFor(point);
    if (key == _areaKey && _areaName.trim().isNotEmpty) return;

    // The previous name describes a different point. Keeping it beside the new
    // pin would be ambiguous, so drop it before asking for the new one.
    if (key != _areaKey && _areaName.trim().isNotEmpty) {
      setState(() => _areaName = '');
      _areaKey = null;
      widget.onAreaChanged('');
    }

    setState(() {
      _areaLoading = true;
      _areaFailure = null;
    });
    final result = await _geocoding.reverse(
      latitude: point.latitude,
      longitude: point.longitude,
      languageCode: _languageCode,
    );
    if (!mounted) return;
    final place = result.place;
    setState(() {
      _areaLoading = false;
      _areaFailure = result.failure;
      if (place != null) {
        _areaName = place.displayName;
        _areaKey = key;
      }
    });
    // The area name is its own value: the landmark stays the reporter's words.
    if (place != null) widget.onAreaChanged(place.displayName);
  }

  Future<void> _openAddressSearch() async {
    if (OfflineController.instance.offline) return;
    final place = await showReportAddressSearchSheet(
      context,
      service: _geocoding,
    );
    if (place == null || !mounted) return;
    _selectPlace(place);
  }

  void _selectPlace(GeocodingPlace place) {
    FocusScope.of(context).unfocus();
    _setLocation(LatLng(place.latitude, place.longitude), recenter: true);
    setState(() {
      _areaName = place.displayName;
      _areaFailure = null;
      _areaKey = _keyFor(LatLng(place.latitude, place.longitude));
    });
    widget.onAreaChanged(place.displayName);
  }

  void _setLocation(LatLng point, {bool recenter = false}) {
    setState(() => _location = point);
    widget.onLocationChanged(point.latitude, point.longitude);
    _scheduleAreaLookup();

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
    if (mounted) _scheduleAreaLookup(delay: Duration.zero);
  }

  Future<void> _useCurrentLocation() async {
    if (_locating || OfflineController.instance.offline) return;

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
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: context.tr('report_location_gps'),
                    child: OutlinedButton.icon(
                      key: const ValueKey('report_location_gps'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _locating || offline
                          ? null
                          : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(
                        context.tr(
                          _locating
                              ? 'report_location_gps_loading_short'
                              : 'report_location_gps_short',
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('report_address_search'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: offline ? null : _openAddressSearch,
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(
                      context.tr('report_address_action'),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            if (offline) ...[
              const SizedBox(height: 6),
              Text(
                context.tr('report_geocoding_offline'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SelectedLocationCard(
              areaName: _areaName,
              areaLoading: _areaLoading,
              areaFailure: _areaFailure,
              hasPin: _location != null,
              canLookupArea: _location != null && !offline,
              onLookupArea: _lookupArea,
              latitude: _location?.latitude,
              longitude: _location?.longitude,
              detailController: _detailController,
              onDetailChanged: widget.onLocationDetailChanged,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// One card for everything the reporter needs to confirm the location.
///
/// Hierarchy follows what a person reads first: the area name is the answer,
/// the coordinates are the precise detail, and the landmark note is optional.
/// The tinted pin turns teal once a name is known, so state is visible without
/// a separate badge.
class _SelectedLocationCard extends StatelessWidget {
  const _SelectedLocationCard({
    required this.areaName,
    required this.areaLoading,
    required this.areaFailure,
    required this.hasPin,
    required this.canLookupArea,
    required this.onLookupArea,
    required this.latitude,
    required this.longitude,
    required this.detailController,
    required this.onDetailChanged,
  });

  final String areaName;
  final bool areaLoading;
  final GeocodingFailure? areaFailure;
  final bool hasPin;
  final bool canLookupArea;
  final VoidCallback onLookupArea;
  final double? latitude;
  final double? longitude;
  final TextEditingController detailController;
  final ValueChanged<String> onDetailChanged;

  @override
  Widget build(BuildContext context) {
    final resolved = areaName.trim().isEmpty ? null : areaName.trim();
    final latitude = this.latitude;
    final longitude = this.longitude;
    final offline = OfflineController.instance.offline;
    final failure = areaFailure;

    return Container(
      key: const ValueKey('report_location_card'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(
          color: resolved != null
              ? AppColors.teal.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // The hint sits on one short line, so it reads best centred on the
            // pin rather than hanging from the top edge of the icon.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                key: const ValueKey('report_area_icon'),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (resolved != null ? AppColors.teal : AppColors.ocean)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resolved != null ? Icons.place_rounded : Icons.place_outlined,
                  size: 20,
                  color: resolved != null ? AppColors.teal : AppColors.ocean,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (areaLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Skeleton(width: 200, height: 20),
                      )
                    else if (resolved != null)
                      Text(
                        resolved,
                        key: const ValueKey('report_area_value'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      )
                    else
                      Text(
                        context.tr(
                          !hasPin
                              ? 'report_area_empty_hint'
                              : offline
                              ? 'report_area_offline'
                              : 'report_area_hint',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (failure != null && !areaLoading) ...[
            const SizedBox(height: 8),
            Text(
              _areaMessage(context, failure),
              key: const ValueKey('report_area_error'),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.danger,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('report_area_retry'),
                onPressed: canLookupArea ? onLookupArea : null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 40),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.tr('common.retry')),
              ),
            ),
          ],
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 12),
            _CoordinateLine(latitude: latitude, longitude: longitude),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('report_location_detail_field'),
            controller: detailController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.tr('report_location_detail_title'),
              hintText: context.tr('report_location_detail_hint'),
              alignLabelWithHint: true,
            ),
            onChanged: onDetailChanged,
          ),
          if (resolved != null) ...[
            const SizedBox(height: 10),
            Text(
              context.tr('report_osm_attribution'),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _areaMessage(BuildContext context, GeocodingFailure failure) =>
      context.tr(switch (failure) {
        GeocodingFailure.rateLimited => 'report_geocoding_rate_limited',
        GeocodingFailure.empty => 'report_area_empty',
        GeocodingFailure.timeout => 'report_area_error',
        GeocodingFailure.unavailable => 'report_area_error',
      });
}

/// Precise coordinates as one quiet line: readable at a glance, still exact.
class _CoordinateLine extends StatelessWidget {
  const _CoordinateLine({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CoordinateValue(
          label: context.tr('report_location_latitude'),
          value: latitude.toStringAsFixed(6),
          valueKey: const ValueKey('report_location_latitude_value'),
        ),
        _CoordinateValue(
          label: context.tr('report_location_longitude'),
          value: longitude.toStringAsFixed(6),
          valueKey: const ValueKey('report_location_longitude_value'),
        ),
      ],
    );
  }
}
