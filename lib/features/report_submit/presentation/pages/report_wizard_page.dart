import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/login_prompt_card.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/report_draft_store.dart';
import '../../data/geocoding_service.dart';
import '../../data/report_location_service.dart';
import '../../data/report_photo_picker.dart';
import '../../data/report_submission_service.dart';
import '../../domain/report_draft.dart';
import '../../domain/report_rules.dart';
import '../widgets/report_location_step.dart';
import '../widgets/report_photo_grid.dart';
import '../widgets/report_photo_source_sheet.dart';
import '../widgets/report_review_step.dart';
import '../widgets/report_step_frame.dart';
import '../widgets/report_type_step.dart';

/// "Lapor Temuan" — one page, four internal steps.
///
/// Steps 1–4 are implemented; step 4 reviews the draft and sends it. The draft
/// lives in memory only ([InMemoryReportDraftStore]), so it survives moving
/// between steps and a detour to the login page, but not an app restart.
class ReportWizardPage extends StatefulWidget {
  const ReportWizardPage({
    super.key,
    this.store,
    this.photoPicker,
    this.locationService,
    this.geocodingService,
    this.locationTileProvider,
    this.submissionService,
    this.autoResume = false,
  });

  /// Injectable for tests; defaults to the session-only memory store.
  final ReportDraftStore? store;

  /// Injectable for tests; defaults to `image_picker`.
  final ReportPhotoPicker? photoPicker;

  /// Injectable for tests; defaults to Geolocator.
  final ReportLocationService? locationService;

  /// Injectable for tests; defaults to public Nominatim.
  final GeocodingService? geocodingService;

  /// Test seam for the two maps; defaults to the OSM network tiles.
  final TileProvider? locationTileProvider;

  /// Injectable for tests; defaults to the simulated submission.
  final ReportSubmissionService? submissionService;

  /// When true, restores a stored draft without the resume dialog. Used when
  /// the user returns from login and must land back on step 4.
  final bool autoResume;

  @override
  State<ReportWizardPage> createState() => _ReportWizardPageState();
}

class _ReportWizardPageState extends State<ReportWizardPage>
    with WidgetsBindingObserver {
  static const _saveDebounce = Duration(milliseconds: 500);

  late final ReportDraftStore _store =
      widget.store ?? InMemoryReportDraftStore.instance;
  late final ReportPhotoPicker _photoPicker =
      widget.photoPicker ?? ImagePickerReportPhotoPicker();
  late final ReportLocationService _locationService =
      widget.locationService ?? const GeolocatorReportLocationService();
  late final ReportSubmissionService _submissionService =
      widget.submissionService ?? MockReportSubmissionService();

  ReportWizardDraft _draft = const ReportWizardDraft();

  /// False until the stored draft has been resolved, so disposing the page
  /// while the first load is in flight cannot wipe an existing draft.
  bool _draftReady = false;
  bool _loading = true;
  bool _picking = false;
  bool _showTitleValidation = false;
  bool _showDescriptionValidation = false;
  bool _showTypeValidation = false;
  bool _submitting = false;
  bool _submitError = false;
  Timer? _saveTimer;

  int get _step => _draft.currentStep;

  int get _remaining => ReportRules.maxPhotos - _draft.photoCount;

  bool get _canContinue {
    if (_step == ReportWizardDraft.firstStep) {
      return _draft.photoCount >= ReportRules.minPhotos &&
          _draft.hasTitle &&
          _draft.hasDescription;
    }
    if (_step == ReportWizardDraft.locationStep) return _draft.hasLocation;
    if (_step == ReportWizardDraft.typeStep) return _draft.hasType;
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreDraft();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    if (_draftReady) unawaited(_persist());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_draftReady) unawaited(_persist());
    }
  }

  Future<void> _restoreDraft() async {
    final stored = await _store.load();
    if (!mounted) return;

    if (stored == null || !stored.hasContent) {
      setState(() {
        _loading = false;
        _draftReady = true;
      });
      return;
    }

    // Returning from login must land on the step the user left, without an
    // extra confirmation dialog.
    if (widget.autoResume) {
      setState(() {
        _draft = stored;
        _loading = false;
        _draftReady = true;
      });
      return;
    }

    // Render the empty step behind the modal. Keeping the spinner here would
    // animate forever while the dialog waits for an answer, which also makes
    // widget tests hang in pumpAndSettle.
    setState(() => _loading = false);

    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('report_resume_title')),
        content: Text(dialogContext.tr('report_resume_body')),
        actions: [
          TextButton(
            // Starting over discards the stored draft, so it reads as the
            // destructive choice instead of a neutral secondary action.
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('report_resume_new')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: AppDimens.dialogActionMinSize,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('report_resume_continue')),
          ),
        ],
      ),
    );
    if (!mounted) return;

    // A dismissed dialog (system back) keeps the draft instead of deleting it.
    if (resume == false) {
      // Show the loading state so a new photo cannot be added while the old
      // draft is being cleared.
      setState(() => _loading = true);
      await _store.clear();
      if (!mounted) return;
      setState(() {
        _draft = const ReportWizardDraft();
        _loading = false;
        _draftReady = true;
      });
      return;
    }

    setState(() {
      _draft = stored;
      _loading = false;
      _draftReady = true;
    });
  }

  void _update(ReportWizardDraft next) {
    setState(() {
      if (next.currentStep != _draft.currentStep) {
        _showTitleValidation = false;
        _showDescriptionValidation = false;
        _showTypeValidation = false;
        _submitError = false;
      }
      if (next.hasTitle) _showTitleValidation = false;
      if (next.hasDescription) _showDescriptionValidation = false;
      _draft = next.copyWith(updatedAt: DateTime.now().toUtc());
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () => unawaited(_persist()));
  }

  Future<void> _persist() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final draft = _draft;
    if (!draft.hasContent) {
      await _store.clear();
      return;
    }
    await _store.save(draft);
  }

  Future<void> _handleBack() async {
    if (_step > ReportWizardDraft.firstStep) {
      _update(_draft.copyWith(currentStep: _step - 1));
      return;
    }

    if (!_draft.hasContent) {
      Navigator.of(context).pop();
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('report_exit_title')),
        content: Text(dialogContext.tr('report_exit_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: AppDimens.dialogActionMinSize,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('report_exit_confirm')),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;

    await _persist();
    if (mounted) Navigator.of(context).pop();
  }

  void _goNext() {
    if (_step >= ReportWizardDraft.lastStep) return;
    if (_step == ReportWizardDraft.firstStep &&
        _draft.photoCount >= ReportRules.minPhotos) {
      if (!_draft.hasTitle) {
        _revealTitleValidation();
        return;
      }
      if (!_draft.hasDescription) {
        _revealDescriptionValidation();
        return;
      }
    }
    if (_step == ReportWizardDraft.typeStep && !_draft.hasType) {
      _revealTypeValidation();
      return;
    }
    if (!_canContinue) return;
    _update(_draft.copyWith(currentStep: _step + 1));
  }

  void _revealTitleValidation() {
    if (_draft.hasTitle || _showTitleValidation) return;
    setState(() => _showTitleValidation = true);
  }

  void _revealDescriptionValidation() {
    if (_draft.hasDescription || _showDescriptionValidation) return;
    setState(() => _showDescriptionValidation = true);
  }

  void _revealTypeValidation() {
    if (_draft.hasType || _showTypeValidation) return;
    setState(() => _showTypeValidation = true);
  }

  /// First step with a missing requirement, or null when the draft is ready
  /// to send. Sending jumps to this step so the user can complete it.
  int? _firstIncompleteStep() {
    if (_draft.photoCount < ReportRules.minPhotos ||
        !_draft.hasTitle ||
        !_draft.hasDescription) {
      return ReportWizardDraft.firstStep;
    }
    if (!_draft.hasLocation) return ReportWizardDraft.locationStep;
    if (!_draft.hasType) return ReportWizardDraft.typeStep;
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final missingStep = _firstIncompleteStep();
    if (missingStep != null) {
      _showSnack(
        context.tr(switch (missingStep) {
          ReportWizardDraft.firstStep =>
            _draft.photoCount < ReportRules.minPhotos
                ? 'report_submit_missing_photos'
                : !_draft.hasTitle
                ? 'report_submit_missing_title'
                : 'report_submit_missing_description',
          ReportWizardDraft.locationStep => 'report_submit_missing_location',
          _ => 'report_submit_missing_type',
        }),
      );
      _update(_draft.copyWith(currentStep: missingStep));
      return;
    }

    // Never drop the draft on the way to login: it stays in the memory store
    // and `/report?resume=1` reopens it on step 4.
    if (!AuthController.instance.signedIn) {
      await _openLogin();
      return;
    }

    if (OfflineController.instance.offline) {
      _showSnack(context.tr('report_submit_offline_body'));
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = false;
    });

    try {
      final report = await _submissionService.submit(
        _draft,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;

      // Cancel a pending autosave before clearing, otherwise the debounce can
      // write the submitted draft back into the store.
      _saveTimer?.cancel();
      _saveTimer = null;
      await _store.clear();
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _draft = const ReportWizardDraft();
      });
      context.pushReplacement(Routes.reportSuccessUrl(report.id));
    } catch (_) {
      // Keep every field so the user can retry without redoing the form.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = true;
      });
    }
  }

  Future<void> _openLogin() async {
    final redirect = Uri.encodeComponent('${Routes.report}?resume=1');
    await context.push<void>('${Routes.auth}?redirect=$redirect');
  }

  void _editFromReview(int step) {
    _update(_draft.copyWith(currentStep: step));
  }

  Future<void> _addPhoto() async {
    if (_remaining <= 0) {
      _showSnack(
        context.tr('report_max_photos', {'max': '${ReportRules.maxPhotos}'}),
      );
      return;
    }

    final source = await ReportPhotoSourceSheet.show(context);
    if (source == null || !mounted) return;

    setState(() => _picking = true);
    final result = await _photoPicker.pick(
      source: source,
      remaining: _remaining,
    );
    if (!mounted) return;
    setState(() => _picking = false);

    final failure = result.failure;
    if (failure != null) {
      await _showPickFailure(failure);
      return;
    }
    if (result.paths.isEmpty) return;

    final nextPaths = [
      ..._draft.photoPaths,
      ...result.paths,
    ].take(ReportRules.maxPhotos).toList();
    _update(_draft.copyWith(photoPaths: nextPaths));

    if (result.truncated) {
      _showSnack(
        context.tr('report_photos_truncated', {
          'n': '${result.paths.length}',
          'max': '${ReportRules.maxPhotos}',
        }),
      );
    }
  }

  void _removePhoto(int index) {
    final nextPaths = [..._draft.photoPaths]..removeAt(index);
    _update(_draft.copyWith(photoPaths: nextPaths));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPickFailure(ReportPhotoFailure failure) async {
    final permissionDenied =
        failure == ReportPhotoFailure.cameraPermissionDenied ||
        failure == ReportPhotoFailure.galleryPermissionDenied;

    final message = switch (failure) {
      ReportPhotoFailure.cameraPermissionDenied => context.tr(
        'report_permission_camera',
      ),
      ReportPhotoFailure.galleryPermissionDenied => context.tr(
        'report_permission_gallery',
      ),
      ReportPhotoFailure.unavailable => context.tr('report_photo_unavailable'),
      ReportPhotoFailure.unknown => context.tr('report_photo_failed'),
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.tr(
            permissionDenied
                ? 'report_permission_title'
                : 'report_photo_error_title',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (permissionDenied) ...[
              const SizedBox(height: 12),
              Text(
                dialogContext.tr('report_permission_settings_hint'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('report_permission_dismiss')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == ReportWizardDraft.firstStep && !_draft.hasContent,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleBack());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('report_title')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => unawaited(_handleBack()),
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ReportStepFrame(
                      step: _step,
                      showDraftBanner: _draft.hasContent,
                      child: _step == ReportWizardDraft.firstStep
                          ? _buildPhotoStep(context)
                          : _step == ReportWizardDraft.locationStep
                          ? _buildLocationStep(context)
                          : _step == ReportWizardDraft.typeStep
                          ? _buildTypeStep(context)
                          : _buildReviewStep(context),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _loading ? null : _buildActions(context),
      ),
    );
  }

  Widget _buildPhotoStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('report_photos_title'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('report_photos_body'),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        ReportPhotoGrid(
          photoPaths: _draft.photoPaths,
          maxPhotos: ReportRules.maxPhotos,
          onAdd: _picking ? null : _addPhoto,
          onRemove: _removePhoto,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('report_photo_counter', {
            'n': '${_draft.photoCount}',
            'max': '${ReportRules.maxPhotos}',
          }),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: const ValueKey('report_title_field'),
          initialValue: _draft.title,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: context.tr('report_title_field'),
            hintText: context.tr('report_title_hint'),
            errorText: _showTitleValidation && !_draft.hasTitle
                ? context.tr('report_title_error')
                : null,
          ),
          onChanged: (title) => _update(_draft.copyWith(title: title)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('report_description_field'),
          initialValue: _draft.description,
          minLines: 3,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: context.tr('report_description_title'),
            hintText: context.tr('report_description_hint'),
            alignLabelWithHint: true,
            errorText: _showDescriptionValidation && !_draft.hasDescription
                ? context.tr('report_description_error')
                : null,
          ),
          onChanged: (description) =>
              _update(_draft.copyWith(description: description)),
        ),
      ],
    );
  }

  Widget _buildLocationStep(BuildContext context) {
    return ReportLocationStep(
      latitude: _draft.latitude,
      longitude: _draft.longitude,
      locationDetail: _draft.locationDetail,
      areaName: _draft.areaName,
      geocodingService: widget.geocodingService,
      locationService: _locationService,
      tileProvider: widget.locationTileProvider,
      onLocationChanged: (latitude, longitude) {
        _update(_draft.copyWith(latitude: latitude, longitude: longitude));
      },
      onLocationDetailChanged: (locationDetail) {
        _update(_draft.copyWith(locationDetail: locationDetail));
      },
      onAreaChanged: (areaName) {
        if (areaName == _draft.areaName) return;
        _update(_draft.copyWith(areaName: areaName));
      },
    );
  }

  Widget _buildTypeStep(BuildContext context) {
    return ReportTypeStep(
      category: _draft.category,
      severity: _draft.severity,
      showValidation: _showTypeValidation,
      onCategoryChanged: (category) {
        _update(_draft.copyWith(category: category));
      },
      onSeverityChanged: (severity) {
        _update(_draft.copyWith(severity: severity));
      },
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        final signedIn = AuthController.instance.signedIn;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportReviewStep(
              photoPaths: _draft.photoPaths,
              title: _draft.title,
              description: _draft.description,
              areaName: _draft.areaName,
              locationDetail: _draft.locationDetail,
              latitude: _draft.latitude,
              longitude: _draft.longitude,
              category: _draft.category,
              severity: _draft.severity,
              reportedAt: _draft.updatedAt?.toLocal() ?? DateTime.now(),
              onEditReport: () => _editFromReview(ReportWizardDraft.firstStep),
              onEditLocation: () =>
                  _editFromReview(ReportWizardDraft.locationStep),
              onEditClassification: () =>
                  _editFromReview(ReportWizardDraft.typeStep),
              showSubmitError: _submitError,
              onRetry: _submitting ? null : () => unawaited(_submit()),
              tileProvider: widget.locationTileProvider,
            ),
            if (!signedIn) ...[
              const SizedBox(height: 16),
              LoginPromptCard(
                // Encoded because LoginPage reads `redirect` as one query
                // value and the wizard needs `resume=1` to skip the dialog.
                returnLocation: Uri.encodeComponent(
                  '${Routes.report}?resume=1',
                ),
                title: context.tr('report_review_login_title'),
                body: context.tr('report_review_login_body'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    final button = PrimaryButton(
      label: context.tr('common.continue'),
      onPressed: _canContinue ? _goNext : null,
    );

    // A disabled CTA still reveals inline feedback for a missing required
    // description or for incomplete type/severity choices.
    if (_canContinue) return button;
    if (_step == ReportWizardDraft.firstStep &&
        _draft.photoCount >= ReportRules.minPhotos) {
      if (!_draft.hasTitle) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _revealTitleValidation,
          child: button,
        );
      }
      if (!_draft.hasDescription) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _revealDescriptionValidation,
          child: button,
        );
      }
    }
    if (_step != ReportWizardDraft.typeStep) return button;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _revealTypeValidation,
      child: button,
    );
  }

  Widget _buildActions(BuildContext context) {
    final isFirst = _step == ReportWizardDraft.firstStep;
    final isLast = _step == ReportWizardDraft.lastStep;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (!isFirst) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => unawaited(_handleBack()),
                  child: Text(context.tr('report_back')),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: isLast
                  ? PrimaryButton(
                      key: const ValueKey('report_submit_button'),
                      label: context.tr('report_submit'),
                      loading: _submitting,
                      onPressed: _submitting
                          ? null
                          : () => unawaited(_submit()),
                    )
                  : _buildContinueButton(context),
            ),
          ],
        ),
      ),
    );
  }
}
