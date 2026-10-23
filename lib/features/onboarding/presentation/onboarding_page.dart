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
/// - "Skip" is a secondary text button that jumps to the interest screen; it
///   does not finish onboarding. Only "Start" completes it, and only with at
///   least one interest selected.
/// - The interest screen has a back arrow returning to the last slide, and the
///   system back button behaves the same.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  final Set<String> _selectedInterests = {};

  int _slide = 0;
  bool _showInterests = false;

  /// Set when returning from the interest screen: the slide deck is then
  /// re-attached one frame later (after the facts future surfaces), so the
  /// restore to the last slide is deferred until the PageView has clients.
  bool _returningToSlides = false;

  /// Slide copy for the device language; the future is created once the
  /// dependencies (i.e. the locale) are available and reused across rebuilds.
  Future<List<OnboardingSlide>>? _factsFuture;

  /// Material has no coral or marine-mammal glyph, so those use an emoji.
  // TODO(P01-part-4): icon proposals to confirm with Trevan — `recycling`
  // for marine waste, `set_meal` for sustainable fisheries.
  static const _interestVisuals = <String, _InterestVisual>{
    'sampah_laut': _InterestVisual(icon: Icons.recycling),
    'terumbu_karang': _InterestVisual(emoji: '🪸'),
    'mangrove': _InterestVisual(icon: Icons.forest),
    'perikanan': _InterestVisual(icon: Icons.set_meal),
    'satwa_laut': _InterestVisual(emoji: '🐬'),
  };

  static const double _cardHeight = 68;
  static const double _cardSpacing = 10;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish(List<String> interests) async {
    await OnboardingState.markDone(interests);
    // Keep the in-memory flag in sync, otherwise the router redirect bounces
    // /explore straight back to /onboarding.
    OnboardingController.instance.markDone();
    if (!mounted) return;
    // `go` replaces the stack, so /onboarding is gone: back from /explore
    // cannot land here again.
    context.go(Routes.explore);
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

  /// Both "Skip" and the last slide's primary button land here. Skipping must
  /// not complete onboarding — the interest screen still applies its own
  /// one-minimum rule.
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
    if (_showInterests) return _buildInterests(context);
    return _buildSlidesContainer(context);
  }

  /// Loads the slide copy once per page lifetime, mirroring the locale at
  /// first build. Retry clears the future so the next build re-runs.
  Widget _buildSlidesContainer(BuildContext context) {
    _factsFuture ??=
        OceanFactsRepository.load(Localizations.localeOf(context).languageCode);

    return FutureBuilder<List<OnboardingSlide>>(
      future: _factsFuture,
      builder: (context, snapshot) {
        final slides = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildScaffold(
            context,
            body: _buildLoadingBody(context),
          );
        }
        if (snapshot.hasError || slides == null || slides.isEmpty) {
          return _buildScaffold(
            context,
            body: Center(
              child: ErrorState(onRetry: _retryFacts),
            ),
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
          Skeleton(
            height: 28,
            radius: AppDimens.cardRadius,
          ),
          const SizedBox(height: 12),
          Skeleton(
            height: 18,
            radius: AppDimens.cardRadius,
          ),
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
    String id, {
    required double width,
  }) {
    final visual =
        _interestVisuals[id] ?? const _InterestVisual(icon: Icons.spa);

    return SizedBox(
      width: width,
      height: _cardHeight,
      child: _InterestCard(
        label: context.tr('cat.$id'),
        icon: visual.icon,
        emoji: visual.emoji,
        selected: _selectedInterests.contains(id),
        onTap: () => setState(() {
          _selectedInterests.contains(id)
              ? _selectedInterests.remove(id)
              : _selectedInterests.add(id);
        }),
      ),
    );
  }

  Widget _buildInterests(BuildContext context) {
    final canStart = _selectedInterests.isNotEmpty;
    return PopScope<Object?>(
      // On this screen back means "one step back in the flow", so the route
      // itself must not pop.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) =>
          _handleSystemBack(didPop, onInterests: true),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Secondary control, not a second primary button.
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.ocean,
                    onPressed: _backToSlides,
                  ),
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
                  context.tr('p01.interests.subtitle'),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  // Two columns, with a trailing odd card stretched across the
                  // full row so the five options stay balanced and visible
                  // without scrolling on a standard phone.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = SizedBox(width: _cardSpacing);
                      final cardWidth =
                          (constraints.maxWidth - _cardSpacing) / 2;

                      final rows = <Widget>[];
                      for (
                        var i = 0;
                        i < AppConfig.interestIds.length;
                        i += 2
                      ) {
                        final first = AppConfig.interestIds[i];
                        final second = i + 1 < AppConfig.interestIds.length
                            ? AppConfig.interestIds[i + 1]
                            : null;

                        rows.add(
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: second == null ? 0 : _cardSpacing,
                            ),
                            child: second == null
                                // Last odd card spans the whole row.
                                ? _buildInterestCard(
                                    context,
                                    first,
                                    width: constraints.maxWidth,
                                  )
                                : Row(
                                    children: [
                                      _buildInterestCard(
                                        context,
                                        first,
                                        width: cardWidth,
                                      ),
                                      gap,
                                      _buildInterestCard(
                                        context,
                                        second,
                                        width: cardWidth,
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rows,
                        ),
                      );
                    },
                  ),
                ),
                if (!canStart) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        context.tr('p01.minOne'),
                        style: const TextStyle(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canStart
                        ? () => _finish(_selectedInterests.toList())
                        : null,
                    child: Text(context.tr('p01.start')),
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

/// Visual for one interest: a Material icon where a close match exists,
/// otherwise an emoji glyph rendered as text.
class _InterestVisual {
  const _InterestVisual({this.icon, this.emoji});

  final IconData? icon;
  final String? emoji;
}

/// Compact interest option: icon or emoji on the left, the label on the
/// right, and an unmistakable check on the right edge when selected.
///
/// Selected cards keep the onboarding palette — an ocean-to-teal gradient with
/// white glyphs — while unselected ones stay a plain white surface with a
/// light border, so the two states are easy to tell apart at a glance.
class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.emoji,
  });

  final String label;
  final IconData? icon;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppDimens.cardRadius));

    return Material(
      color: selected ? AppColors.ocean : AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.oceanDeep : AppColors.border,
              width: selected ? 2 : 1,
            ),
            // Teal only joins selected cards, so the gradient doubles as the
            // selected-state signal rather than decoration.
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.ocean, AppColors.teal],
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Center(
                    child: emoji != null
                        ? Text(emoji!, style: const TextStyle(fontSize: 22))
                        : Icon(
                            icon,
                            size: 24,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // A filled check on selected, a hollow ring on unselected, so
                // every card shows where its state will appear.
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: selected ? 22 : 18,
                  color: selected ? Colors.white : AppColors.inactiveTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
