import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/ocean_facts_repository.dart';

/// P01 — Onboarding: 3 slides introducing the reporting / community-action
/// flow + interest selection.
///
/// Slide copy comes from `assets/mock/ocean_facts.json` —
/// TODO(P01-part-4): the wording is a DRAFT awaiting Trevan's approval; the
/// JSON is the only place it can change. Completing onboarding sets
/// `onboarding_done = true` and persists selected interests (used later to
/// sort Explore).
///
/// Flow rules:
/// - One primary button per screen. Slides 1–2 say "Next", slide 3 says
///   "Choose Interests", the interest screen says "Start". Each label means the
///   same thing wherever it appears, so it never changes meaning mid-flow.
/// - Slides can be skipped to interests; interests can be skipped to Explore.
/// - Profile reopens the same picker with saved interests, without the slides.
/// - The interest screen has a back arrow returning to the last slide, and the
///   system back button behaves the same.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.editInterests = false});

  final bool editInterests;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  final Set<String> _selectedInterests = {};

  int _slide = 0;
  bool _showInterests = false;
  bool _saving = false;
  bool _loadingPreferences = false;
  bool _preferencesError = false;

  /// Set when returning from the interest screen: the slide deck is then
  /// re-attached one frame later (after the facts future surfaces), so the
  /// restore to the last slide is deferred until the PageView has clients.
  bool _returningToSlides = false;

  /// Slide copy for the device language; the future is created once the
  /// dependencies (i.e. the locale) are available and reused across rebuilds.
  Future<List<OnboardingSlide>>? _factsFuture;

  static const double _gallerySpacing = 8;
  static const _interestImages = {
    'sampah_laut': 'assets/images/interests/marine_waste.jpg',
    'terumbu_karang': 'assets/images/interests/coral_reef.jpg',
    'mangrove': 'assets/images/interests/mangrove.jpg',
    'perikanan': 'assets/images/interests/sustainable_fishery.jpg',
    'satwa_laut': 'assets/images/interests/marine_wildlife.jpg',
  };

  @override
  void initState() {
    super.initState();
    if (widget.editInterests) {
      _showInterests = true;
      _loadPreferences();
    }
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loadingPreferences = true;
      _preferencesError = false;
    });
    try {
      final saved = await OnboardingState.readInterests();
      if (!mounted) return;
      setState(() {
        _selectedInterests.addAll(saved.where(AppConfig.interestIds.contains));
        _loadingPreferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPreferences = false;
        _preferencesError = true;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish(List<String> interests) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (widget.editInterests) {
        await OnboardingState.saveInterests(interests);
      } else {
        await OnboardingState.markDone(interests);
        OnboardingController.instance.markDone();
      }
      if (!mounted) return;
      if (widget.editInterests) {
        _leavePreferences();
      } else {
        context.go(Routes.explore);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('p01.interests.saveError'))),
      );
    }
  }

  void _leavePreferences() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.profile);
    }
  }

  /// Re-runs the facts load after an error; the build recreates the future.
  void _retryFacts() => setState(() => _factsFuture = null);

  void _nextSlide() {
    // The deck is fixed at 3 slides per the onboarding rules; the copy of all
    // three lives in ocean_facts.json.
    if (_slide < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      setState(() => _showInterests = true);
    }
  }

  /// Skipping slides opens interests, which has its own optional Skip action.
  void _showInterestScreen() => setState(() => _showInterests = true);

  /// Steps back one slide so an earlier fact can be re-read. A no-op on the
  /// first slide, which is where the back arrow is hidden.
  void _previousSlide() {
    if (_slide == 0 || !_pageController.hasClients) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Returns from the interest screen to the last slide, keeping any interests
  /// already selected.
  void _backToSlides() {
    if (_saving) return;
    if (widget.editInterests) {
      _leavePreferences();
      return;
    }
    setState(() {
      _showInterests = false;
      _returningToSlides = true;
    });
  }

  /// System back mirrors the on-screen arrows: on the interest screen it
  /// returns to the last slide, on a slide it steps back one slide. On the
  /// first slide it is a no-op (canPop stays true) so the platform's own
  /// behavior is untouched.
  void _handleSystemBack(bool didPop, {required bool onInterests}) {
    if (didPop) return;
    if (onInterests) {
      _backToSlides();
      return;
    }
    _previousSlide();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPreferences || _preferencesError) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('p01.interests.manage')),
          leading: BackButton(onPressed: _leavePreferences),
        ),
        body: _preferencesError
            ? ErrorState(onRetry: _loadPreferences)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    if (_showInterests) return _buildInterests(context);
    return _buildSlidesContainer(context);
  }

  /// Loads the slide copy once per page lifetime, mirroring the locale at
  /// first build. Retry clears the future so the next build re-runs.
  Widget _buildSlidesContainer(BuildContext context) {
    _factsFuture ??= OceanFactsRepository.load(
      Localizations.localeOf(context).languageCode,
    );

    return FutureBuilder<List<OnboardingSlide>>(
      future: _factsFuture,
      builder: (context, snapshot) {
        final slides = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildScaffold(context, body: _buildLoadingBody(context));
        }
        if (snapshot.hasError || slides == null || slides.isEmpty) {
          return _buildScaffold(
            context,
            body: Center(child: ErrorState(onRetry: _retryFacts)),
          );
        }
        return _buildSlides(context, slides);
      },
    );
  }

  /// Thin outer scaffold shared by every onboarding state so the Skip/arrow
  /// layout sub-header stays present while facts load.
  Widget _buildScaffold(
    BuildContext context, {
    required Widget body,
    Widget? header,
  }) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ?header,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Skeleton(height: 300, radius: 24),
          const SizedBox(height: 32),
          Skeleton(height: 28, radius: AppDimens.cardRadius),
          const SizedBox(height: 12),
          Skeleton(height: 18, radius: AppDimens.cardRadius),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSlides(BuildContext context, List<OnboardingSlide> slides) {
    if (_returningToSlides) {
      _returningToSlides = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          // Back always lands on the last slide; the deck is fixed at 3.
          _pageController.jumpToPage(2);
        }
      });
    }

    final isLast = _slide == slides.length - 1;
    // Nothing behind slide 1, so there the route keeps its normal pop behavior.
    final isFirst = _slide == 0;
    return _buildScaffold(
      context,
      body: PopScope<Object?>(
        canPop: isFirst,
        onPopInvokedWithResult: (didPop, _) =>
            _handleSystemBack(didPop, onInterests: false),
        child: SafeArea(
          child: Column(
            children: [
              // Back arrow and Skip are secondary controls, deliberately not the
              // screen's primary action. The arrow is absent on slide 1: there is
              // nothing before it.
              Row(
                children: [
                  if (_slide > 0)
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.ocean,
                      onPressed: _previousSlide,
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  TextButton(
                    onPressed: _showInterestScreen,
                    child: Text(context.tr('p01.skip')),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _slide = i),
                  itemBuilder: (context, i) {
                    final slide = slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Illustration area ≈ 55% of slide height; tight so
                          // the block cannot shrink below its share (a loose
                          // Flexible would collapse to the icon's 120px).
                          Expanded(
                            flex: 55,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.ocean, AppColors.teal],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.waves,
                                size: 120,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Flexible(
                            flex: 45,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slide.title,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    slide.body,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Dot indicator.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _slide == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _slide == i ? AppColors.ocean : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _nextSlide,
                    child: Text(
                      isLast
                          ? context.tr('p01.chooseInterests')
                          : context.tr('p01.next'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterestCard(
    BuildContext context,
    int index, {
    required double galleryHeight,
    required double labelHeight,
  }) {
    final id = AppConfig.interestIds[index];

    return Expanded(
      child: _InterestGalleryColumn(
        id: id,
        label: context.tr('cat.$id'),
        imagePath: _interestImages[id]!,
        galleryHeight: galleryHeight,
        labelHeight: labelHeight,
        blockHeight: galleryHeight * (index.isEven ? 1 : 0.88),
        selected: _selectedInterests.contains(id),
        onTap: _saving
            ? null
            : () => setState(() {
                _selectedInterests.contains(id)
                    ? _selectedInterests.remove(id)
                    : _selectedInterests.add(id);
              }),
      ),
    );
  }

  Widget _buildInterests(BuildContext context) {
    final canStart = widget.editInterests || _selectedInterests.isNotEmpty;
    return PopScope<Object?>(
      // On this screen back means "one step back in the flow", so the route
      // itself must not pop.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) =>
          _handleSystemBack(didPop, onInterests: true),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Secondary control, not a second primary button.
                Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.ocean,
                      onPressed: _saving ? null : _backToSlides,
                    ),
                    const Spacer(),
                    if (!widget.editInterests)
                      TextButton(
                        onPressed: _saving ? null : () => _finish([]),
                        child: Text(context.tr('p01.skip')),
                      ),
                  ],
                ),
                Text(
                  context.tr('p01.interests.title'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('p01.interests.later'),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewport) {
                      // Keep captions reachable on short/wide screens. Large
                      // text can still scroll instead of clipping the gallery.
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final columnWidth =
                                    (constraints.maxWidth -
                                        _gallerySpacing *
                                            (AppConfig.interestIds.length -
                                                1)) /
                                    AppConfig.interestIds.length;
                                // Measure translated captions at the current
                                // text scale; bottom-align them without ellipses.
                                var labelHeight = 0.0;
                                for (final id in AppConfig.interestIds) {
                                  final painter = TextPainter(
                                    text: TextSpan(
                                      text: context.tr('cat.$id'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    textDirection: Directionality.of(context),
                                    textScaler: MediaQuery.textScalerOf(
                                      context,
                                    ),
                                  )..layout(maxWidth: columnWidth);
                                  if (painter.height > labelHeight) {
                                    labelHeight = painter.height;
                                  }
                                  painter.dispose();
                                }
                                final maxBlockHeight =
                                    (viewport.maxHeight - labelHeight - 40)
                                        .clamp(100.0, 420.0);
                                final galleryHeight = (columnWidth * 4.2).clamp(
                                  100.0,
                                  maxBlockHeight,
                                );

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < AppConfig.interestIds.length;
                                      i++
                                    ) ...[
                                      if (i > 0)
                                        const SizedBox(width: _gallerySpacing),
                                      _buildInterestCard(
                                        context,
                                        i,
                                        galleryHeight: galleryHeight,
                                        labelHeight: labelHeight,
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (!canStart) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        context.tr('p01.interests.subtitle'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canStart && !_saving
                        ? () => _finish(_selectedInterests.toList())
                        : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.tr(
                              widget.editInterests
                                  ? 'p01.interests.save'
                                  : 'p01.start',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal-width gallery columns reserve the same image area, leaving space
/// below shorter blocks so every caption sits on the same horizontal line.
class _InterestGalleryColumn extends StatefulWidget {
  const _InterestGalleryColumn({
    required this.id,
    required this.label,
    required this.imagePath,
    required this.galleryHeight,
    required this.labelHeight,
    required this.blockHeight,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String label;
  final String imagePath;
  final double galleryHeight;
  final double labelHeight;
  final double blockHeight;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_InterestGalleryColumn> createState() => _InterestGalleryColumnState();
}

class _InterestGalleryColumnState extends State<_InterestGalleryColumn> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppDimens.cardRadius));
    final highlighted = widget.selected || _hovered || _focused;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      label: widget.label,
      button: true,
      selected: widget.selected,
      enabled: widget.onTap != null,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('interest.option.${widget.id}'),
            borderRadius: radius,
            onTap: widget.onTap,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: widget.galleryHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedContainer(
                      key: ValueKey('interest.block.${widget.id}'),
                      duration: duration,
                      curve: Curves.easeOut,
                      height: widget.blockHeight,
                      width: double.infinity,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: highlighted ? AppColors.teal : AppColors.border,
                        borderRadius: radius,
                        boxShadow: highlighted
                            ? [
                                BoxShadow(
                                  color:
                                      (widget.selected
                                              ? AppColors.teal
                                              : AppColors.ocean)
                                          .withValues(
                                            alpha: widget.selected ? 0.5 : 0.25,
                                          ),
                                  blurRadius: widget.selected ? 18 : 12,
                                  spreadRadius: widget.selected ? 2 : 0,
                                ),
                              ]
                            : const [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppDimens.cardRadius - 2,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedScale(
                              scale: _hovered || _focused ? 1.06 : 1,
                              duration: duration,
                              child: Image.asset(
                                widget.imagePath,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                                errorBuilder: (context, error, stack) =>
                                    const ColoredBox(
                                      color: AppColors.border,
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                      ),
                                    ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: widget.selected
                                        ? AppColors.ocean
                                        : Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Icon(
                                      widget.selected
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: widget.labelHeight,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      widget.label,
                      key: ValueKey('interest.caption.${widget.id}'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: widget.selected
                            ? AppColors.oceanDeep
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
