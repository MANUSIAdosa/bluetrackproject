import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';

/// P01 — Onboarding: 3 ocean-fact slides + interest selection.
///
/// Completing it sets `onboarding_done = true` and persists selected
/// interests (used later to sort Explore).
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

  static const _slides = [
    _OceanFact(
      titleKey: 'onboarding.slide1.title',
      bodyKey: 'onboarding.slide1.body',
      icon: Icons.water_drop,
    ),
    _OceanFact(
      titleKey: 'onboarding.slide2.title',
      bodyKey: 'onboarding.slide2.body',
      icon: Icons.waves,
    ),
    _OceanFact(
      titleKey: 'onboarding.slide3.title',
      bodyKey: 'onboarding.slide3.body',
      icon: Icons.eco,
    ),
  ];

  /// Material has no turtle, coral, or marine-mammal glyph, so those three use
  /// an emoji; mangrove and seagrass have close Material matches.
  static const _interestVisuals = <String, _InterestVisual>{
    'penyu': _InterestVisual(emoji: '🐢'),
    'karang': _InterestVisual(emoji: '🪸'),
    'mangrove': _InterestVisual(icon: Icons.forest),
    'mamalia_laut': _InterestVisual(emoji: '🐬'),
    'lamun': _InterestVisual(icon: Icons.grass),
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
    if (!mounted) return;
    // `go` replaces the stack, so /onboarding is gone: back from /explore
    // cannot land here again.
    context.go('/explore');
  }

  void _nextSlide() {
    if (_slide < _slides.length - 1) {
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
    setState(() => _showInterests = false);
    // The interest screen replaces the PageView in the tree, so the controller
    // is detached at this moment and only re-attaches after the next build.
    // Jumping eagerly would throw; waiting a frame lands on the last slide.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_slides.length - 1);
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
    return _buildSlides(context);
  }

  Widget _buildSlides(BuildContext context) {
    final isLast = _slide == _slides.length - 1;
    // Nothing behind slide 1, so there the route keeps its normal pop behavior.
    final isFirst = _slide == 0;
    return PopScope<Object?>(
      canPop: isFirst,
      onPopInvokedWithResult: (didPop, _) =>
          _handleSystemBack(didPop, onInterests: false),
      child: Scaffold(
        body: SafeArea(
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
                    child: Text(context.tr('onboarding.skip')),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _slide = i),
                  itemBuilder: (context, i) {
                    final slide = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Illustration area ≈ 55% of screen height.
                          Flexible(
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
                              child: Icon(
                                slide.icon,
                                size: 120,
                                color: Colors.white.withValues(alpha: 0.9),
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
                                    context.tr(slide.titleKey),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr(slide.bodyKey),
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
                  for (var i = 0; i < _slides.length; i++)
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
                          ? context.tr('onboarding.chooseInterests')
                          : context.tr('onboarding.next'),
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
                  context.tr('onboarding.interests.title'),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('onboarding.interests.subtitle'),
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
                        context.tr('onboarding.minOne'),
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
                    child: Text(context.tr('onboarding.start')),
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

class _OceanFact {
  const _OceanFact({
    required this.titleKey,
    required this.bodyKey,
    required this.icon,
  });

  final String titleKey;
  final String bodyKey;
  final IconData icon;
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
