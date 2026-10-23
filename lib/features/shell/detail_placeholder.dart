import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/router/routes.dart';

/// Shared shell for the non-tab placeholder pages (Periode 2 part 3).
///
/// Every detail placeholder shows the same anatomy: page title, Pxx code, the
/// dynamic parameters it received (verification only — no business data), and
/// a "coming soon" note. The back button is safe: it pops when there is
/// something to pop to, otherwise it falls back to Explore, so a cold deep
/// link can never throw.
class DetailPlaceholder extends StatelessWidget {
  const DetailPlaceholder({
    super.key,
    required this.titleKey,
    required this.pageCode,
    this.parameters = const [],
  });

  /// Localization key of the page title.
  final String titleKey;

  /// Spec page code, e.g. `P15` — shown as a tag for traceability.
  final String pageCode;

  /// Verification-only dynamic parameters, e.g. `('id', actionId)`.
  final List<(String, String)> parameters;

  void _back(BuildContext context) {
    if (context.canPop()) {
      Navigator.of(context).maybePop();
    } else {
      context.go(Routes.explore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: Text(context.tr(titleKey)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                pageCode,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (name, value) in parameters)
                    Text(
                      context.tr('placeholder.paramValue', {
                        'name': name,
                        'value': value,
                      }),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (parameters.isNotEmpty) const SizedBox(height: 16),
                  Text(
                    context.tr('common.comingSoon'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
