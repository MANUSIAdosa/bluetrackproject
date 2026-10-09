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

/// P02 — Login and account verification.
///
/// Steps: email → phone (+62) → 6-digit OTP (mock: 123456).
/// On success returns to the origin page via the `redirect` query parameter.
///
/// The three steps are self-explanatory, so the page carries no step
/// indicator. The app-bar back arrow is the single way out — it steps back
/// through the flow, and leaves the page when already on the first step.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.redirect});

  /// Original location to return to after sign-in (P02 behavior).
  final String? redirect;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _step = 0;
  bool _loading = false;
  String? _errorKey;

  // OTP state.
  int _attemptsLeft = AppConfig.otpMaxAttempts;
  int _resendSeconds = 0;
  Timer? _timer;

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

  String get _fullPhone => '+62${_phoneController.text}';

  // --- Step 1: email -------------------------------------------------------

  void _submitEmail() {
    final email = _emailController.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) {
      setState(() => _errorKey = 'auth.email.invalid');
      return;
    }
    setState(() {
      _errorKey = null;
      _step = 1;
    });
  }

  // --- Step 2: phone -------------------------------------------------------

  void _sendCode() {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^\d{8,12}$').hasMatch(phone)) {
      setState(() => _errorKey = 'auth.phone.invalid');
      return;
    }
    setState(() {
      _errorKey = null;
      _step = 2;
      _attemptsLeft = AppConfig.otpMaxAttempts;
    });
    _startResendCountdown();
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

  // --- Step 3: OTP ---------------------------------------------------------

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otpLocked || _loading) return;
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    // Mock verification — no network involved.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    if (_otpCode == AppConfig.mockOtp) {
      await AuthController.instance.signIn(_emailController.text.trim());
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
      if (_otpLocked) {
        _errorKey = 'auth.otp.locked';
      } else {
        _errorKey = 'auth.otp.mismatch';
      }
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

  /// Steps back through the flow, or leaves the page from the first step.
  ///
  /// A deep link straight into `/auth` has nothing to pop, so fall back to the
  /// origin page the user asked for, or to the app entry point.
  void _goBack() {
    if (_step > 0) {
      setState(() {
        _step--;
        _errorKey = null;
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
        title: Text(context.tr('auth.title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == 0) _buildEmailStep(),
              if (_step == 1) _buildPhoneStep(),
              if (_step == 2) _buildOtpStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            hintText: context.tr('auth.email.hint'),
            errorText: _errorKey == null ? null : context.tr(_errorKey!),
          ),
          onSubmitted: (_) => _submitEmail(),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: context.tr('common.continue'),
          loading: _loading,
          onPressed: _submitEmail,
          color: AppColors.ocean,
        ),
        const SizedBox(height: 24),
        const _LegalNotice(),
      ],
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '+62',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: context.tr('auth.phone.hint'),
                  errorText: _errorKey == null ? null : context.tr(_errorKey!),
                ),
                onSubmitted: (_) => _sendCode(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: context.tr('auth.sendCode'),
          loading: _loading,
          onPressed: _sendCode,
          color: AppColors.ocean,
        ),
        const SizedBox(height: 24),
        const _LegalNotice(),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('auth.otp.title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('auth.otp.subtitle', {'phone': _fullPhone}),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 6; i++)
              SizedBox(
                width: 46,
                child: TextField(
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
        ),
        if (_errorKey != null) ...[
          const SizedBox(height: 12),
          Text(
            context.tr(_errorKey!),
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!_otpLocked && _errorKey == 'auth.otp.mismatch') ...[
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
        const SizedBox(height: 24),
        PrimaryButton(
          label: context.tr('auth.verify'),
          loading: _loading,
          onPressed: (_otpCode.length == 6 && !_otpLocked) ? _verify : null,
          color: AppColors.ocean,
        ),
        const SizedBox(height: 12),
        Center(
          child: _resendSeconds > 0
              ? Text(
                  context.tr('auth.otp.resendIn', {'s': '$_resendSeconds'}),
                  style: const TextStyle(color: AppColors.textSecondary),
                )
              : TextButton(
                  onPressed: () {
                    if (_otpLocked) {
                      setState(() {
                        _attemptsLeft = AppConfig.otpMaxAttempts;
                        _errorKey = null;
                      });
                    }
                    _sendCode();
                  },
                  child: Text(context.tr('auth.otp.resend')),
                ),
        ),
        const SizedBox(height: 24),
        const _LegalNotice(),
      ],
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
