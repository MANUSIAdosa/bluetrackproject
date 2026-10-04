import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../features/organization/domain/organization.dart';
import '../../features/repositories.dart';
import 'error_state.dart';
import 'skeleton.dart';

/// Bottom sheet explaining an organization's verification status.
///
/// Renders the organization's existing checklist from the mock data — no
/// verification rules are defined here.
Future<void> showVerificationSheet(
  BuildContext context, {
  required String orgId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _VerificationSheet(orgId: orgId),
  );
}

class _VerificationSheet extends StatefulWidget {
  const _VerificationSheet({required this.orgId});

  final String orgId;

  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  Organization? _org;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final org = await Repositories.organizations.getById(widget.orgId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (org == null) {
          _error = true;
        } else {
          _org = org;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: _loading
              ? const _SheetSkeleton()
              : _error || _org == null
                  ? ErrorState(onRetry: _load)
                  : _content(context, _org!),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Organization org) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _hex(org.color).withValues(alpha: 0.15),
              child: Icon(Icons.business, size: 20, color: _hex(org.color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    org.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('org.checklist.title'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('org.verified.explanation'),
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),
        for (final item in org.checklist)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.done
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: item.done
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('org.checklist.${item.key}'),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SheetSkeleton extends StatelessWidget {
  const _SheetSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Skeleton(width: 40, height: 40, radius: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 16),
                  SizedBox(height: 8),
                  Skeleton(width: 140, height: 12),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Skeleton(height: 14),
        SizedBox(height: 8),
        Skeleton(width: 260, height: 14),
        SizedBox(height: 16),
        Skeleton(height: 14),
        SizedBox(height: 12),
        Skeleton(height: 14),
        SizedBox(height: 12),
        Skeleton(height: 14),
      ],
    );
  }
}

Color _hex(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));