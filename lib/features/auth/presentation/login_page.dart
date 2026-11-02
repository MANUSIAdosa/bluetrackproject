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

/// Clearance under the app bar, so the heading does not crowd it.
const double _topPadding = 32;

const double _bottomPadding = 24;

/// Gap between the heading block and the first field.
const double _headingToFieldGap = 32;

/// Gap above and below the "OR" rule, so it reads as a separator rather than
/// as part of either field.
const double _dividerGap = 20;

/// Gap between the form and its button. Wider than the usual 20 so the form
/// does not read as one solid block.
const double _fieldToButtonGap = 28;

/// Distance from the button down to the legal notice — near enough to belong
/// to the form, far enough not to look glued to the button.
const double _noticeGap = 32;

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
/// page only scrolls when the form (or the legal notice) outgrows the space
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

  String? _emailErrorKey;
  String? _phoneErrorKey;

  /// Error for the "nothing filled yet" case, shown once below the phone row.
  String? _identifierErrorKey;

  String? _otpErrorKey;

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

  // --- Combined email + phone form ----------------------------------------

  void _onEmailChanged(String _) {
    if (_emailErrorKey == null && _identifierErrorKey == null) return;
    setState(() {
      _emailErrorKey = null;
      _identifierErrorKey = null;
    });
  }

  void _onPhoneChanged(String _) {
    if (_phoneErrorKey == null && _identifierErrorKey == null) return;
    setState(() {
      _phoneErrorKey = null;
      _identifierErrorKey = null;
    });
  }

  /// Validates both fields, then opens the OTP step for the filled channel.
  ///
  /// At least one field must be valid. Empty fields are optional; a field with
  /// content must be valid, so a half-typed number cannot be sent by mistake.
  /// When both are valid, email wins because it is the first field on screen.
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

    if (emailError != null || phoneError != null || nothingFilled) {
      setState(() {
        _emailErrorKey = emailError;
        _phoneErrorKey = phoneError;
        _identifierErrorKey = nothingFilled ? 'auth.identifier.missing' : null;
      });
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
    if (_otpLocked || _loading) return;
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
    if (_otpCode.length == 6 && !_otpLocked) {
      _verify();
    }
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
          // bring the Continue button and the legal notice into view.
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
              const SizedBox(height: _noticeGap),
              const _LegalNotice(),
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
        const SizedBox(height: 8),
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
          key: const Key('auth_email_field'),
          controller: _emailController,
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
          // Leaves the choice open: the user can keep typing an email or move
          // down to the phone field instead.
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: _dividerGap),
        const _OrDivider(),
        const SizedBox(height: _dividerGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              // Matches the field's 14dp content padding, so the prefix box
              // and the input line up while staying compact.
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                _countryCode,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('auth_phone_field'),
                controller: _phoneController,
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
        const SizedBox(height: _fieldToButtonGap),
        PrimaryButton(
          label: context.tr('common.continue'),
          onPressed: _continue,
          color: AppColors.ocean,
        ),
      ],
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
        const SizedBox(height: _headingToFieldGap),
        LayoutBuilder(
          builder: (context, constraints) {
            // Six boxes shrink to 38dp on very narrow phones and stay 46dp
            // everywhere else, so the row never overflows.
            const gap = 8.0;
            final width = ((constraints.maxWidth - gap * 5) / 6)
                .clamp(38.0, 46.0)
                .toDouble();

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 6; i++)
                  SizedBox(
                    width: width,
                    child: TextField(
                      key: ValueKey('auth_otp_$i'),
                      controller: _otpControllers[i],
                      focusNode: _otpFocusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      enabled: !_otpLocked && !_loading,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
        const SizedBox(height: _fieldToButtonGap),
        PrimaryButton(
          label: context.tr('auth.verify'),
          loading: _loading,
          onPressed: (_otpCode.length == 6 && !_otpLocked) ? _verify : null,
          color: AppColors.ocean,
        ),
        const SizedBox(height: 8),
        // Left-aligned like the rest of the column; centred here read as a
        // separate block floating under the button.
        _resendSeconds > 0
            ? Text(
                context.tr('auth.otp.resendIn', {'s': '$_resendSeconds'}),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _resendCode,
                  child: Text(context.tr('auth.otp.resend')),
                ),
              ),
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

/// One sentence of legal copy with both documents as inline links.
///
/// This used to be three tappable targets stacked together — two legal
/// buttons plus "continue without signing in" — which invited misclicks. The
/// skip action is gone (the app-bar back arrow leaves the page), so the notice
/// is the only thing left and reads as the sentence it always was.
class _LegalNotice extends StatefulWidget {
  const _LegalNotice();

  @override
  State<_LegalNotice> createState() => _LegalNoticeState();
}

class _LegalNoticeState extends State<_LegalNotice> {
  // Held as fields so they outlive a single build and are disposed with the
  // state; recognizers created inline in `build` would leak on every rebuild.
  final TapGestureRecognizer _policyTap = TapGestureRecognizer();
  final TapGestureRecognizer _termsTap = TapGestureRecognizer();

  @override
  void dispose() {
    _policyTap.dispose();
    _termsTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _policyTap.onTap = () => context.push('/legal/privacy');
    _termsTap.onTap = () => context.push('/legal/terms');

    const base = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    const link = TextStyle(
      fontSize: 12,
      color: AppColors.ocean,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.ocean,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '${context.tr('auth.privacy.lead')} '),
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
          // Sentence punctuation is identical in both locales, so it stays
          // out of the localization maps.
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
