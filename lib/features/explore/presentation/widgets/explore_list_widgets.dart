import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/project_card.dart';
import '../../domain/project.dart';

/// Local spacing scale (4/8/12/16/24). The theme is outside this change's
/// scope, so the Explore list keeps its own tokens here.
abstract final class ExploreSpacing {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x24 = 24;
}

/// Section heading used by the Jelajahi list. Horizontal page padding is the
/// caller's job, so both headings share the inset of the content below them.
Widget exploreSectionHeader(BuildContext context, String text) => Text(
  text,
  style: Theme.of(context).textTheme.titleLarge
      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
);

/// Horizontally snapping recommended projects with a small position indicator.
class ForYouList extends StatefulWidget {
  const ForYouList({
    super.key,
    required this.projects,
    required this.onSavedChanged,
  });

  final List<Project> projects;
  final VoidCallback onSavedChanged;

  @override
  State<ForYouList> createState() => _ForYouListState();
}

class _ForYouListState extends State<ForYouList> {
  static const double _maxCardWidth = 320;
  static const double _minCardWidth = 240;
  static const double _peekWidth = ExploreSpacing.x24 * 2;
  static const double _dotGap = 6;

  final _controller = ScrollController();
  double _itemExtent = 0;
  int _activeIndex = 0;
  int _dragStartIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ForYouList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projects.length != widget.projects.length) {
      final lastIndex = math.max(0, widget.projects.length - 1);
      _activeIndex = _activeIndex.clamp(0, lastIndex);
      _dragStartIndex = _activeIndex;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients ||
        _itemExtent <= 0 ||
        widget.projects.isEmpty) {
      return;
    }
    final index = (_controller.position.pixels / _itemExtent).round().clamp(
      0,
      widget.projects.length - 1,
    );
    if (index != _activeIndex) setState(() => _activeIndex = index);
  }

  bool _onScrollStart(ScrollStartNotification notification) {
    _dragStartIndex = _activeIndex;
    return false;
  }

  void _scrollToIndex(int index) {
    if (!_controller.hasClients || _itemExtent <= 0) return;
    final position = _controller.position;
    final target = (index * _itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave 16dp for the page inset, 12dp for the card gap, and 48dp for
        // the next-card peek; narrower viewports keep a 240dp minimum card.
        final availableWidth =
            constraints.maxWidth -
            ExploreSpacing.x16 -
            ExploreSpacing.x12 -
            _peekWidth;
        final cardWidth = math.max(
          _minCardWidth,
          math.min(_maxCardWidth, availableWidth),
        );
        final itemExtent = cardWidth + ExploreSpacing.x12;
        _itemExtent = itemExtent;
        final trailingInset = math.max(
          0.0,
          constraints.maxWidth - ExploreSpacing.x16 - cardWidth,
        );
        final height = ProjectCard.heightFor(context, cardWidth);
        final multipleProjects = widget.projects.length > 1;

        Widget slider = ListView.separated(
          key: const ValueKey('explore.forYouList'),
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: _ForYouSnapPhysics(
            itemExtent: itemExtent,
            itemCount: widget.projects.length,
            dragStartIndex: () => _dragStartIndex,
          ),
          padding: EdgeInsets.only(
            left: ExploreSpacing.x16,
            right: trailingInset,
          ),
          itemCount: widget.projects.length,
          separatorBuilder: (_, _) => const SizedBox(width: ExploreSpacing.x12),
          itemBuilder: (context, index) => SizedBox(
            width: cardWidth,
            child: ProjectCard(
              project: widget.projects[index],
              rail: true,
              onSavedChanged: widget.onSavedChanged,
            ),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: NotificationListener<ScrollStartNotification>(
                onNotification: _onScrollStart,
                child: slider,
              ),
            ),
            if (multipleProjects) ...[
              const SizedBox(height: ExploreSpacing.x12),
              _buildDots(context),
              const SizedBox(height: ExploreSpacing.x4),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDots(BuildContext context) {
    final projectCount = widget.projects.length;
    final dotWidths = [
      for (var i = 0; i < projectCount; i++) i == _activeIndex ? 18.0 : 6.0,
    ];
    final dotCenters = <double>[];
    var cursor = 0.0;
    for (final width in dotWidths) {
      dotCenters.add(cursor + width / 2);
      cursor += width + _dotGap;
    }
    final visualWidth = cursor - _dotGap;
    const hitTargetSize = 24.0;
    const visualInset = hitTargetSize / 2;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);

    return Semantics(
      container: true,
      label: context.tr('explore.forYouPosition', {
        'n': '${_activeIndex + 1}',
        'total': '$projectCount',
      }),
      child: ExcludeSemantics(
        child: Center(
          child: SizedBox(
            width: visualWidth + hitTargetSize,
            height: hitTargetSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: visualInset,
                  top: 0,
                  width: visualWidth,
                  height: hitTargetSize,
                  child: Align(
                    child: Row(
                      key: const ValueKey('explore.forYouDots'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < projectCount; i++) ...[
                          AnimatedContainer(
                            duration: animationDuration,
                            curve: Curves.easeOut,
                            width: dotWidths[i],
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _activeIndex
                                  ? AppColors.ocean
                                  : AppColors.inactiveTab,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          if (i < projectCount - 1)
                            const SizedBox(width: _dotGap),
                        ],
                      ],
                    ),
                  ),
                ),
                for (var i = 0; i < projectCount; i++)
                  Positioned(
                    left: visualInset + dotCenters[i] - hitTargetSize / 2,
                    top: 0,
                    width: hitTargetSize,
                    height: hitTargetSize,
                    child: GestureDetector(
                      key: ValueKey('explore.forYouDot.$i'),
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTapUp: (details) {
                        final tapX =
                            visualInset +
                            dotCenters[i] +
                            details.localPosition.dx -
                            hitTargetSize / 2;
                        var nearestIndex = 0;
                        var nearestDistance = double.infinity;
                        for (var dot = 0; dot < dotCenters.length; dot++) {
                          final distance =
                              (tapX - visualInset - dotCenters[dot]).abs();
                          if (distance < nearestDistance) {
                            nearestDistance = distance;
                            nearestIndex = dot;
                          }
                        }
                        _scrollToIndex(nearestIndex);
                      },
                      child: const SizedBox.expand(),
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

/// Snaps to a single adjacent card per fling and preserves the first/last
/// card's normal overscroll behavior.
class _ForYouSnapPhysics extends ScrollPhysics {
  const _ForYouSnapPhysics({
    required this.itemExtent,
    required this.itemCount,
    required this.dragStartIndex,
    super.parent,
  });

  final double itemExtent;
  final int itemCount;
  final int Function() dragStartIndex;

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 100,
    ratio: 1.1,
  );

  @override
  _ForYouSnapPhysics applyTo(ScrollPhysics? ancestor) => _ForYouSnapPhysics(
    itemExtent: itemExtent,
    itemCount: itemCount,
    dragStartIndex: dragStartIndex,
    parent: buildParent(ancestor),
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange || itemCount <= 1 || itemExtent <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final lastIndex = itemCount - 1;
    final anchor = dragStartIndex().clamp(0, lastIndex);
    final targetIndex = velocity.abs() > tolerance.velocity
        ? (anchor + (velocity > 0 ? 1 : -1)).clamp(0, lastIndex)
        : (position.pixels / itemExtent).round().clamp(0, lastIndex);

    if (velocity.abs() > tolerance.velocity && targetIndex == anchor) {
      // At either endpoint, let the platform's regular physics handle a fling
      // farther out instead of creating a competing snap simulation.
      return super.createBallisticSimulation(position, velocity);
    }

    final target = (targetIndex * itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - target).abs() < 0.5 &&
        velocity.abs() < tolerance.velocity) {
      return super.createBallisticSimulation(position, velocity);
    }

    return ScrollSpringSimulation(
      _spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
