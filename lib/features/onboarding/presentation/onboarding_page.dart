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
    _OceanFact(titleKey: 'onboarding.slide1.title', bodyKey: 'onboarding.slide1.body', icon: Icons.water_drop),
    _OceanFact(titleKey: 'onboarding.slide2.title', bodyKey: 'onboarding.slide2.body', icon: Icons.waves),
    _OceanFact(titleKey: 'onboarding.slide3.title', bodyKey: 'onboarding.slide3.body', icon: Icons.eco),
  ];

  static const _interestIcons = <String, IconData>{
    'penyu': Icons.egg_alt_outlined,
    'karang': Icons.waves,
    'mangrove': Icons.forest,
    'mamalia_laut': Icons.pets,
    'lamun': Icons.grass,
  };

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish(List<String> interests) async {
    await OnboardingState.markDone(interests);
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (_showInterests) return _buildInterests(context);
    return _buildSlides(context);
  }

  Widget _buildSlides(BuildContext context) {
    final isLast = _slide == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _finish(const []),
                child: Text(context.tr('onboarding.skip')),
              ),
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
                        Expanded(
                          flex: 55,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.ocean,
                                  AppColors.teal,
                                ],
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
                        Expanded(
                          flex: 45,
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
    );
  }

  Widget _buildInterests(BuildContext context) {
    final canStart = _selectedInterests.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    for (final id in AppConfig.interestIds)
                      _InterestCard(
                        label: context.tr('cat.$id'),
                        icon: _interestIcons[id] ?? Icons.spa,
                        selected: _selectedInterests.contains(id),
                        onTap: () => setState(() {
                          _selectedInterests.contains(id)
                              ? _selectedInterests.remove(id)
                              : _selectedInterests.add(id);
                        }),
                      ),
                  ],
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

class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.ocean : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: selected ? AppColors.ocean : AppColors.textSecondary,
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.ocean,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.ocean : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
