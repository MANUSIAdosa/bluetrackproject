import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/step_indicator.dart';
import '../../explore/domain/project.dart';
import '../../repositories.dart';

/// P06 — Donation, amount step.
///
/// Flow: Amount → Purpose → Confirmation → Result. Only the amount step is
/// assigned to Subproject 01 (Week 03, Task Group 2); later steps show a
/// pending notice rather than being invented here.
class DonateAmountPage extends StatefulWidget {
  const DonateAmountPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<DonateAmountPage> createState() => _DonateAmountPageState();
}

class _DonateAmountPageState extends State<DonateAmountPage> {
  final _amountController = TextEditingController();

  Project? _project;
  int? _selectedPreset;
  bool _monthly = false;
  bool _showAmountError = false;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    final project = await Repositories.projects.getProjectById(widget.projectId);
    if (mounted) setState(() => _project = project);
  }

  int get _amount {
    final custom = int.tryParse(_amountController.text.replaceAll('.', ''));
    if (custom != null && custom > 0) return custom;
    return _selectedPreset ?? 0;
  }

  void _continue() {
    if (_amount <= 0) {
      setState(() => _showAmountError = true);
      return;
    }
    setState(() => _showAmountError = false);
    // TODO(donation-flow): steps 2–4 (purpose/confirmation/result) are
    // assigned to a later week — do not invent them here.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('donate.stepPending'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('donate.title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StepIndicator(
                labels: [
                  context.tr('donate.step1'),
                  context.tr('donate.step2'),
                  context.tr('donate.step3'),
                  context.tr('donate.step4'),
                ],
                current: 0,
              ),
              const SizedBox(height: 20),
              if (_project != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: AppColors.coral),
                    title: Text(
                      _project!.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_project!.orgName),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                context.tr('donate.quickAmount'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in AppConfig.donationPresets)
                    ChoiceChip(
                      label: Text(Formatters.currency(preset, lang)),
                      selected: _selectedPreset == preset,
                      showCheckmark: true,
                      onSelected: (selected) {
                        setState(() {
                          _selectedPreset = selected ? preset : null;
                          if (selected) _amountController.clear();
                          _showAmountError = false;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('donate.customAmount'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '0',
                  errorText: _showAmountError
                      ? context.tr('donate.amountInvalid')
                      : null,
                ),
                onChanged: (_) {
                  if (_showAmountError) setState(() => _showAmountError = false);
                  if (_amountController.text.isNotEmpty) {
                    setState(() => _selectedPreset = null);
                  }
                },
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('donate.frequency'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(context.tr('donate.once')),
                    icon: const Icon(Icons.bolt_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(context.tr('donate.monthly')),
                    icon: const Icon(Icons.calendar_month),
                  ),
                ],
                selected: {_monthly},
                onSelectionChanged: (set) => setState(() => _monthly = set.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: context.tr('common.continue'),
                onPressed: _continue,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
