import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/geocoding_service.dart';
import '../../domain/geocoding.dart';

/// Bottom panel for the address search.
///
/// Public Nominatim allows one request per second and no search-as-you-type, so
/// the query only runs when the reporter taps "Cari" (or submits the field).
/// The panel returns the chosen [GeocodingPlace], or null when dismissed.
Future<GeocodingPlace?> showReportAddressSearchSheet(
  BuildContext context, {
  required GeocodingService service,
}) {
  return showModalBottomSheet<GeocodingPlace>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.cardRadius),
      ),
    ),
    builder: (_) => _AddressSearchSheet(service: service),
  );
}

class _AddressSearchSheet extends StatefulWidget {
  const _AddressSearchSheet({required this.service});

  final GeocodingService service;

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  final TextEditingController _controller = TextEditingController();

  List<GeocodingPlace> _results = const [];
  bool _loading = false;
  GeocodingFailure? _failure;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _failure = null;
      _results = const [];
    });
    final result = await widget.service.search(
      query,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failure = result.failure;
      _results = result.places;
    });
  }

  @override
  Widget build(BuildContext context) {
    final offline = OfflineController.instance.offline;
    final enabled = !offline && !_loading;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('report_address_title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('report_address_sheet_close'),
                tooltip: context.tr('common.close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            key: const ValueKey('report_address_field'),
            controller: _controller,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if (enabled) _search();
            },
            decoration: InputDecoration(
              hintText: context.tr('report_address_hint'),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            key: const ValueKey('report_address_sheet_search'),
            label: context.tr('report_address_action'),
            loading: _loading,
            onPressed: enabled ? _search : null,
          ),
          if (offline) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('report_geocoding_offline'),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (_failure != null) ...[
            const SizedBox(height: 10),
            Text(
              _message(context, _failure!),
              key: const ValueKey('report_address_error'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.danger,
              ),
            ),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            Flexible(
              child: _ResultsPanel(
                results: _results,
                onSelected: (place) => Navigator.of(context).pop(place),
              ),
            ),
            const SizedBox(height: 8),
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

  String _message(BuildContext context, GeocodingFailure failure) =>
      context.tr(switch (failure) {
        GeocodingFailure.empty => 'report_address_empty',
        GeocodingFailure.rateLimited => 'report_geocoding_rate_limited',
        GeocodingFailure.timeout => 'report_address_error',
        GeocodingFailure.unavailable => 'report_address_error',
      });
}

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({required this.results, required this.onSelected});

  final List<GeocodingPlace> results;
  final ValueChanged<GeocodingPlace> onSelected;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: AppColors.border),
          itemBuilder: (context, index) {
            final place = results[index];
            return InkWell(
              key: ValueKey('report_address_result_$index'),
              onTap: () => onSelected(place),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: AppColors.ocean,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
