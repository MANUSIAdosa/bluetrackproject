import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';

/// Wider side margins than the app's 16dp base: this page has a single narrow
/// column, so extra breathing room at the edges keeps the form from filling
/// the width on a large phone.
const double _sidePadding = 24;

/// Clearance under the app bar. One 8dp step: the bar's back button already
/// gives the heading air, so a larger inset only pushed the form down.
const double _topPadding = 16;

const double _bottomPadding = 24;

/// Regular spacing follows an 8dp rhythm; compact spacing protects the form
/// when the keyboard or a short viewport reduces available height.
const double _regularSectionGap = 24;

/// Both stages (identifier and OTP) use the same gap under their subtitle, so
/// the two steps feel like one page.
const double _headingToFieldGap = 32;
const double _compactSectionGap = 16;

/// Spacing for the single-identifier form, in dp: 8 heading→subtitle,
/// 32 subtitle→input, 12 input→consent, 24 consent→Continue. The consent text
/// keeps its own 12dp top padding so the sentence sits beside the checkbox.
const double _headingToSubtitleGap = 8;
const double _fieldToConsentGap = 12;
const double _consentToButtonGap = 24;

/// Inputs stay 56–60dp tall: 20sp of text plus 18dp padding above and below.
const EdgeInsets _fieldPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 18,
);
const double _verifyToResendGap = 24;
const double _resendPromptGap = 8;

/// Indonesian mobile prefix. Kept in one place so the input box and the
/// identifier sent to the mock sign-in can never drift apart.
const String _countryCode = '+62';

/// Compact country list for the identifier prefix. `+62` stays first because
/// it is the default; the list is intentionally short instead of a full
/// worldwide picker, which would need extra data or a dependency.
const List<({String code, String label})> _dialCodes = [
  (code: '+62', label: 'ID'),
  (code: '+60', label: 'MY'),
  (code: '+65', label: 'SG'),
  (code: '+61', label: 'AU'),
  (code: '+63', label: 'PH'),
];

/// P02 — Login and account verification.
///
/// Email and phone live on one page, separated by a thin "OR" rule: the user
/// fills whichever channel they prefer and taps Continue. The mock 6-digit
/// code (123456) is then entered on the OTP step, which replaces the form in
/// place. On success the page returns to the origin via `redirect`.
///
/// The page stays top-aligned and scrollable. A centred form is what the
/// mobile keyboard covers, so the heading starts near the app bar and the
/// page only scrolls when the form outgrows the space
/// left above the keyboard.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.redirect});

  /// Original location to return to after sign-in (P02 behavior).
  final String? redirect;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// The page has two stages: the combined identifier form and the OTP step.
enum _AuthStage { identifier, otp }

class _LoginPageState extends State<LoginPage> {
  final _identifierController = TextEditingController();
  final _identifierFocus = FocusNode();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  _AuthStage _stage = _AuthStage.identifier;
  bool _loading = false;
  bool _consentAccepted = false;

  /// Validation error for the single email/phone field.
  String? _identifierErrorKey;

  /// Dial code chosen from the compact list; `+62` unless the reporter picks
  /// another country after starting with a digit.
  String _dialCode = _countryCode;

  /// True while the field is focused, so the example hint can step aside.
  bool _identifierFocused = false;

  String? _otpErrorKey;
  String? _consentErrorKey;

  /// Email or `+62` phone that the OTP was sent to. Resolved when the user
  /// continues, then reused for the subtitle and the mock sign-in token.
  String? _identifier;

  // OTP state.
  int _attemptsLeft = AppConfig.otpMaxAttempts;
  int _resendSeconds = 0;
  Timer? _timer;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _identifierFocus.addListener(_onIdentifierFocusChanged);
  }

  void _onIdentifierFocusChanged() {
    setState(() => _identifierFocused = _identifierFocus.hasFocus);
  }

  @override
  void dispose() {
    _identifierFocus.removeListener(_onIdentifierFocusChanged);
    _timer?.cancel();
    _identifierController.dispose();
    _identifierFocus.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _otpLocked => _attemptsLeft <= 0;

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  bool _isCompactLayout(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.viewInsets.bottom > 0 || media.size.height < 600;
  }

  double _adaptiveSectionGap(BuildContext context, {double? regularGap}) {
    return _isCompactLayout(context)
        ? _compactSectionGap
        : (regularGap ?? _regularSectionGap);
  }

  // --- Single identifier field ---------------------------------------------

  void _onIdentifierChanged(String _) {
    setState(() => _identifierErrorKey = null);
  }

  /// The dial-code prefix only makes sense once the input starts with a digit;
  /// an email address never does.
  bool get _showsDialCode {
    final text = _identifierController.text.trimLeft();
    return text.isNotEmpty && RegExp(r'^[0-9]').hasMatch(text);
  }

  /// `+62` form of [value] when it can be a phone number, otherwise null.
  ///
  /// Accepts `0812…`, `812…`, `62812…` and `+62 812…`; the stored identifier
  /// is always `+62` followed by 8–12 digits, as before.
  String? _phoneAsE164(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    final dial = _dialCode.substring(1);
    var local = digits;
    if (local.startsWith(dial)) {
      local = local.substring(dial.length);
    } else if (local.startsWith('0')) {
      local = local.substring(1);
    }
    if (local.length < 7 || local.length > 12) return null;
    return '$_dialCode$local';
  }

  /// One field, two formats: anything with `@` is an email, the rest must be a
  /// phone number. The message names the expected format so the fix is obvious.
  String? _validateIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'auth.identifier.missing';
    if (trimmed.contains('@')) {
      return _emailPattern.hasMatch(trimmed) ? null : 'auth.email.invalid';
    }
    return _phoneAsE164(trimmed) == null ? 'auth.phone.invalid' : null;
  }

  void _onConsentChanged(bool accepted) {
    setState(() {
      _consentAccepted = accepted;
      if (accepted) _consentErrorKey = null;
    });
  }

  /// Validates the identifier and the consent before opening the OTP step.
  void _continue() {
    final value = _identifierController.text.trim();
    final error = _validateIdentifier(value);
    if (error != null) {
      setState(() => _identifierErrorKey = error);
      return;
    }

    if (!_consentAccepted) {
      setState(() => _consentErrorKey = 'auth.consent.required');
      return;
    }

    final identifier = value.contains('@') ? value : _phoneAsE164(value)!;

    setState(() {
      _identifier = identifier;
      _stage = _AuthStage.otp;
      _attemptsLeft = AppConfig.otpMaxAttempts;
      _otpErrorKey = null;
      _identifierErrorKey = null;
      _consentErrorKey = null;
      for (final c in _otpControllers) {
        c.clear();
      }
    });
    _startResendCountdown();
    _showCodeSentSnackBar();
  }

  // --- OTP -----------------------------------------------------------------

  void _showCodeSentSnackBar() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr('auth.otp.sent'))));
  }

  void _startResendCountdown() {
    _timer?.cancel();
    setState(() => _resendSeconds = AppConfig.otpResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _resendCode() {
    setState(() {
      _attemptsLeft = AppConfig.otpMaxAttempts;
      _otpErrorKey = null;
    });
    _startResendCountdown();
    _showCodeSentSnackBar();
  }

  Future<void> _verify() async {
    if (_otpLocked || _loading || _otpCode.length != 6) return;
    final identifier = _identifier;
    if (identifier == null || identifier.isEmpty) return;

    setState(() {
      _loading = true;
      _otpErrorKey = null;
    });

    // Mock verification — no network involved.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    if (_otpCode == AppConfig.mockOtp) {
      await AuthController.instance.signIn(identifier);
      if (!mounted) return;
      final redirect = widget.redirect;
      if (redirect != null && redirect.isNotEmpty) {
        context.go(redirect);
      } else {
        context.go('/explore');
      }
      return;
    }

    setState(() {
      _loading = false;
      _attemptsLeft--;
      _otpErrorKey = _otpLocked ? 'auth.otp.locked' : 'auth.otp.mismatch';
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes.first.requestFocus();
    });
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }

    // Rebuild the Verify CTA as the number of entered digits changes.
    setState(() {});
  }

  // --- Shared --------------------------------------------------------------

  /// Returns to the form from OTP, or leaves the page from the form.
  ///
  /// A deep link straight into `/auth` has nothing to pop, so fall back to the
  /// origin page the user asked for, or to the app entry point.
  void _goBack() {
    if (_stage == _AuthStage.otp) {
      _timer?.cancel();
      setState(() {
        _stage = _AuthStage.identifier;
        _resendSeconds = 0;
        _loading = false;
        _otpErrorKey = null;
        for (final c in _otpControllers) {
          c.clear();
        }
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    final redirect = widget.redirect;
    context.go(redirect != null && redirect.isNotEmpty ? redirect : '/explore');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Dragging the form away also closes the keyboard, so the user can
          // bring the primary action and related controls into view.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(
            left: _sidePadding,
            right: _sidePadding,
            top: _topPadding,
            bottom: _bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_stage == _AuthStage.identifier)
                _buildIdentifierStep()
              else
                _buildOtpStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentifierStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('auth.title'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: _headingToSubtitleGap),
        Text(
          context.tr('auth.subtitle'),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: _headingToFieldGap),
        TextField(
          key: const Key('auth_identifier_field'),
          controller: _identifierController,
          focusNode: _identifierFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.username],
          autocorrect: false,
          decoration: InputDecoration(
            contentPadding: _fieldPadding,
            labelText: context.tr('auth.identifier.label'),
            // The example steps aside while the reporter types; the floating
            // label keeps the field's purpose visible.
            hintText: _identifierFocused
                ? null
                : context.tr('auth.identifier.hint'),
            prefix: _DialCodePrefix(
              visible: _showsDialCode,
              code: _dialCode,
              onChanged: (code) => setState(() {
                _dialCode = code;
                _identifierErrorKey = null;
              }),
            ),
            errorText: _identifierErrorKey == null
                ? null
                : context.tr(_identifierErrorKey!),
          ),
          onChanged: _onIdentifierChanged,
          onSubmitted: (_) => _continue(),
        ),
        const SizedBox(height: _fieldToConsentGap),
        _buildConsentNotice(context),
        const SizedBox(height: _consentToButtonGap),
        PrimaryButton(
          label: context.tr('common.continue'),
          onPressed: _continue,
          color: AppColors.ocean,
        ),
      ],
    );
  }

  Widget _buildConsentNotice(BuildContext context) {
    final errorKey = _consentErrorKey;
    return _ConsentNotice(
      value: _consentAccepted,
      errorMessage: errorKey == null ? null : context.tr(errorKey),
      onChanged: _onConsentChanged,
    );
  }

  Widget _buildResendControl(BuildContext context) {
    if (_resendSeconds > 0) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('auth.otp.resendIn', {'s': '$_resendSeconds'}),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('auth_resend_button'),
        onPressed: _resendCode,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text(context.tr('auth.otp.resend')),
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(
          title: context.tr('auth.otp.title'),
          subtitle: context.tr('auth.otp.subtitle', {
            'target': _identifier ?? '',
          }),
        ),
        SizedBox(
          height: _adaptiveSectionGap(context, regularGap: _headingToFieldGap),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Keep a fixed gap and let each box share the available row width.
            // Integer widths stop the first and last box from rounding to a
            // different size than the rest.
            const gap = 8.0;
            const boxCount = 6;
            final available = constraints.maxWidth.clamp(0.0, 360.0);
            final boxWidth = ((available - gap * (boxCount - 1)) / boxCount)
                .floorToDouble();
            final rowWidth = boxWidth * boxCount + gap * (boxCount - 1);

            return Center(
              child: SizedBox(
                key: const Key('auth_otp_row'),
                width: rowWidth,
                child: Row(
                  children: [
                    for (var i = 0; i < boxCount; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: boxWidth,
                        child: TextField(
                          key: ValueKey('auth_otp_$i'),
                          controller: _otpControllers[i],
                          focusNode: _otpFocusNodes[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          enabled: !_otpLocked && !_loading,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            errorText: null,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (value) => _onOtpChanged(i, value),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (_otpErrorKey != null) ...[
          const SizedBox(height: 12),
          Text(
            context.tr(_otpErrorKey!),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!_otpLocked && _otpErrorKey == 'auth.otp.mismatch') ...[
            const SizedBox(height: 4),
            Text(
              context.tr('auth.otp.attemptsLeft', {'n': '$_attemptsLeft'}),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
        SizedBox(
          height: _otpErrorKey == null
              ? _adaptiveSectionGap(context)
              : _compactSectionGap,
        ),
        PrimaryButton(
          label: context.tr('auth.verify'),
          loading: _loading,
          onPressed: (_otpCode.length == 6 && !_otpLocked) ? _verify : null,
          color: AppColors.ocean,
        ),
        const SizedBox(height: _verifyToResendGap),
        Text(
          context.tr('auth.otp.resendPrompt'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: _resendPromptGap),
        _buildResendControl(context),
      ],
    );
  }
}

/// Thin rule with the localized "OR" between the email and phone choices.
/// Dial-code selector that slides in once the input starts with a digit.
///
/// The list is short on purpose: a full country picker would add data or a
/// dependency. The caret may shift as the prefix appears, so the reveal is
/// animated to read as one movement instead of a flicker.
class _DialCodePrefix extends StatelessWidget {
  const _DialCodePrefix({
    required this.visible,
    required this.code,
    required this.onChanged,
  });

  final bool visible;
  final String code;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.centerLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: visible ? 1 : 0,
        child: visible
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  key: const Key('auth_dial_code'),
                  tooltip: context.tr('auth.identifier.countryCode'),
                  initialValue: code,
                  onSelected: onChanged,
                  itemBuilder: (context) => [
                    for (final entry in _dialCodes)
                      PopupMenuItem<String>(
                        value: entry.code,
                        child: Text('${entry.label}  ${entry.code}'),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox(width: 0, height: 0),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consent remains a distinct control from the Continue/Verify buttons, with
/// each legal document still available as an inline link.
class _ConsentNotice extends StatefulWidget {
  const _ConsentNotice({
    required this.value,
    required this.onChanged,
    this.errorMessage,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorMessage;

  @override
  State<_ConsentNotice> createState() => _ConsentNoticeState();
}

class _ConsentNoticeState extends State<_ConsentNotice> {
  // Keep recognizers alive across rebuilds and dispose them with this widget.
  final TapGestureRecognizer _policyTap = TapGestureRecognizer();
  final TapGestureRecognizer _termsTap = TapGestureRecognizer();

  @override
  void dispose() {
    _policyTap.dispose();
    _termsTap.dispose();
    super.dispose();
  }

  /// The consent sentence with tappable policy links at [fontSize].
  List<InlineSpan> _consentSpans(BuildContext context, double fontSize) {
    final link = TextStyle(
      fontSize: fontSize,
      height: 1.4,
      color: AppColors.ocean,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.ocean,
    );
    return [
      TextSpan(text: '${context.tr('auth.consent.lead')} '),
      TextSpan(
        text: context.tr('auth.privacyPolicy'),
        style: link,
        recognizer: _policyTap,
      ),
      TextSpan(text: ' ${context.tr('auth.privacy.and')} '),
      TextSpan(
        text: context.tr('auth.terms'),
        style: link,
        recognizer: _termsTap,
      ),
      const TextSpan(text: '.'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _policyTap.onTap = () => context.push('/legal/privacy');
    _termsTap.onTap = () => context.push('/legal/terms');

    const base = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: AppColors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          // The checkbox glyph is centred in its 48dp tap target, so the text
          // block is centred with it instead of carrying its own top padding.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              label: context.tr('auth.consent.semantic'),
              checked: widget.value,
              onTap: () => widget.onChanged(!widget.value),
              child: ExcludeSemantics(
                child: Checkbox(
                  key: const Key('auth_consent_checkbox'),
                  value: widget.value,
                  onChanged: (value) => widget.onChanged(value ?? false),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              // Pulled 8dp towards the checkbox: its 48dp tap target already
              // leaves ~15dp of empty space around the glyph, so the default
              // gap read much wider than it was.
              child: Transform.translate(
                offset: const Offset(-8, 0),
                child: SizedBox(
                  height: 20,
                  // One line that always fits: the sentence is scaled down to
                  // the width instead of being measured and then clipped.
                  child: FittedBox(
                    key: const Key('auth_consent_sentence'),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: base,
                        children: _consentSpans(context, base.fontSize!),
                      ),
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.start,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: 4),
          _InlineError(
            key: const Key('auth_consent_error'),
            message: widget.errorMessage!,
          ),
        ],
      ],
    );
  }
}
