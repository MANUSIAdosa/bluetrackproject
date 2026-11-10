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

/// Clearance under the app bar, so the heading does not crowd it. Matches
/// the page's 24dp side margin instead of the tighter app-wide 16dp.
const double _topPadding = 24;

const double _bottomPadding = 24;

/// Regular spacing follows an 8dp rhythm; compact spacing protects the form
/// when the keyboard or a short viewport reduces available height.
const double _regularSectionGap = 24;

/// Both stages (identifier and OTP) use the same gap under their subtitle, so
/// the two steps feel like one page.
const double _headingToFieldGap = 32;
const double _compactSectionGap = 16;

/// Compact spacing around the email/phone separator keeps both options grouped.
const double _dividerGap = 8;

/// Primary and secondary actions stay grouped but visually distinct.
const double _consentToButtonGap = 16;
const double _verifyToResendGap = 24;
const double _resendPromptGap = 8;

/// Indonesian mobile prefix. Kept in one place so the input box and the
/// identifier sent to the mock sign-in can never drift apart.
const String _countryCode = '+62';

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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  _AuthStage _stage = _AuthStage.identifier;
  bool _loading = false;
  bool _consentAccepted = false;

  String? _emailErrorKey;
  String? _phoneErrorKey;

  /// Error for the "nothing filled yet" case, shown once below the phone row.
  String? _identifierErrorKey;

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
  static final _phonePattern = RegExp(r'^\d{8,12}$');

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
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

  // --- Combined email + phone form ----------------------------------------

  void _onEmailChanged(String _) {
    setState(() {
      _emailErrorKey = null;
      _identifierErrorKey = null;
    });
  }

  void _onPhoneChanged(String _) {
    setState(() {
      _phoneErrorKey = null;
      _identifierErrorKey = null;
    });
  }

  void _onConsentChanged(bool accepted) {
    setState(() {
      _consentAccepted = accepted;
      if (accepted) _consentErrorKey = null;
    });
  }

  /// Validates the selected identifier and consent before opening the OTP step.
  ///
  /// The user chooses one contact method. Clearing its field re-enables the
  /// other method so switching remains straightforward.
  void _continue() {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    final emailError = email.isEmpty || _emailPattern.hasMatch(email)
        ? null
        : 'auth.email.invalid';
    final phoneError = phone.isEmpty || _phonePattern.hasMatch(phone)
        ? null
        : 'auth.phone.invalid';
    final nothingFilled = email.isEmpty && phone.isEmpty;
    final bothFilled = email.isNotEmpty && phone.isNotEmpty;

    if (emailError != null || phoneError != null || nothingFilled) {
      setState(() {
        _emailErrorKey = emailError;
        _phoneErrorKey = phoneError;
        _identifierErrorKey = nothingFilled ? 'auth.identifier.missing' : null;
      });
      return;
    }

    if (bothFilled) {
      setState(() => _identifierErrorKey = 'auth.identifier.chooseOne');
      return;
    }

    if (!_consentAccepted) {
      setState(() => _consentErrorKey = 'auth.consent.required');
      return;
    }

    final identifier = email.isNotEmpty ? email : '$_countryCode$phone';
    setState(() {
      _identifier = identifier;
      _stage = _AuthStage.otp;
      _attemptsLeft = AppConfig.otpMaxAttempts;
      _otpErrorKey = null;
      _emailErrorKey = null;
      _phoneErrorKey = null;
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
    final hasEmail = _emailController.text.trim().isNotEmpty;
    final hasPhone = _phoneController.text.trim().isNotEmpty;
    final emailEnabled = !hasPhone;
    final phoneEnabled = !hasEmail;

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
        const SizedBox(height: 8),
        Text(
          context.tr('auth.subtitle'),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(
          height: _adaptiveSectionGap(context, regularGap: _headingToFieldGap),
        ),
        TextField(
          key: const Key('auth_email_field'),
          controller: _emailController,
          enabled: emailEnabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          decoration: InputDecoration(
            labelText: context.tr('auth.email.label'),
            hintText: context.tr('auth.email.hint'),
            errorText: _emailErrorKey == null
                ? null
                : context.tr(_emailErrorKey!),
          ),
          onChanged: _onEmailChanged,
          // Move to phone only when the user has not started an email.
          onSubmitted: (_) {
            if (hasEmail) {
              FocusScope.of(context).unfocus();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
        ),
        const SizedBox(height: _dividerGap),
        const _OrDivider(),
        const SizedBox(height: _dividerGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: phoneEnabled ? 1 : 0.5,
              child: Container(
                // Matches the field's 14dp content padding, so the prefix box
                // and the input line up while staying compact.
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _countryCode,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: phoneEnabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('auth_phone_field'),
                controller: _phoneController,
                enabled: phoneEnabled,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.tr('auth.phone.label'),
                  hintText: context.tr('auth.phone.hint'),
                  errorText: _phoneErrorKey == null
                      ? null
                      : context.tr(_phoneErrorKey!),
                ),
                onChanged: _onPhoneChanged,
                onSubmitted: (_) => _continue(),
              ),
            ),
          ],
        ),
        if (_identifierErrorKey != null) ...[
          const SizedBox(height: 10),
          _InlineError(
            key: const Key('auth_identifier_error'),
            message: context.tr(_identifierErrorKey!),
          ),
        ],
        SizedBox(height: _adaptiveSectionGap(context)),
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
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            context.tr('auth.or'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ],
    );
  }
}

/// Title and supporting line used by the OTP step.
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

/// Small inline error used when neither identifier was filled.
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

  /// Smallest size we accept when squeezing the consent sentence onto one
  /// line; below it the text is allowed to wrap so it stays readable.
  static const double _minConsentFontSize = 10;

  /// Largest font size that keeps the consent sentence on one line, or null
  /// when even [_minConsentFontSize] would overflow the available width.
  double? _fittedFontSize(
    BuildContext context, {
    required TextStyle base,
    required double maxWidth,
  }) {
    if (maxWidth <= 0 || !maxWidth.isFinite) return null;
    final scaler = MediaQuery.textScalerOf(context);

    for (var size = base.fontSize!; size >= _minConsentFontSize; size -= 0.5) {
      final painter = TextPainter(
        text: TextSpan(
          style: base.copyWith(fontSize: size),
          children: _consentSpans(context, size),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout(maxWidth: maxWidth);
      if (!painter.didExceedMaxLines) return size;
    }
    return null;
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fitted = _fittedFontSize(
                      context,
                      base: base,
                      maxWidth: constraints.maxWidth,
                    );
                    final singleLine = fitted != null;
                    final fontSize = fitted ?? base.fontSize!;

                    return Text.rich(
                      TextSpan(
                        style: base.copyWith(fontSize: fontSize),
                        children: _consentSpans(context, fontSize),
                      ),
                      textAlign: TextAlign.start,
                      maxLines: singleLine ? 1 : null,
                      softWrap: !singleLine,
                    );
                  },
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
