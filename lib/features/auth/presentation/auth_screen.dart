import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../location/presentation/location_scope.dart';
import '../data/auth_service.dart';
import 'auth_scope.dart';

enum AuthMode { login, signup, otp, forgotPassword, resetPassword }

extension on AuthMode {
  String get heading => switch (this) {
    AuthMode.login => 'Welcome back',
    AuthMode.signup => 'Your voice matters',
    AuthMode.otp => 'Verify your email',
    AuthMode.forgotPassword => 'Forgot your password?',
    AuthMode.resetPassword => 'Choose a new password',
  };

  String get introduction => switch (this) {
    AuthMode.signup => 'Join a community of responsible citizen reporters.',
    AuthMode.otp => 'Enter the 6-digit code sent to your email.',
    AuthMode.forgotPassword =>
      'We will send a secure recovery link to your email.',
    AuthMode.resetPassword =>
      'Use at least 6 characters with a letter and a number.',
    _ => 'Stay connected to your community.',
  };

  String get submitLabel => switch (this) {
    AuthMode.login => 'Log in',
    AuthMode.signup => 'Create account',
    AuthMode.otp => 'Verify email',
    AuthMode.forgotPassword => 'Send recovery email',
    AuthMode.resetPassword => 'Save new password',
  };

  IconData get icon => switch (this) {
    AuthMode.login => Icons.login_rounded,
    AuthMode.signup => Icons.person_add_alt_1_rounded,
    AuthMode.otp => Icons.mark_email_read_outlined,
    AuthMode.forgotPassword => Icons.lock_reset_rounded,
    AuthMode.resetPassword => Icons.password_rounded,
  };

  String get eyebrow => switch (this) {
    AuthMode.login => 'SIGN IN',
    AuthMode.signup => 'JOIN CITIZENNEWS',
    AuthMode.otp => 'EMAIL VERIFICATION',
    AuthMode.forgotPassword => 'ACCOUNT RECOVERY',
    AuthMode.resetPassword => 'SECURE YOUR ACCOUNT',
  };
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.mode,
    this.initialEmail = '',
    this.returnTo,
    super.key,
  });

  final AuthMode mode;
  final String initialEmail;
  final String? returnTo;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();
  final _phone = PhoneController(initialValue: PhoneNumber.parse('+92'));

  Timer? _usernameTimer;
  Timer? _resendTimer;
  bool _busy = false;
  bool _sent = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _terms = false;
  bool _guidelines = false;
  int _resendWait = 0;
  String? _error;
  String _usernameStatus = '';

  @override
  void initState() {
    super.initState();
    _email.text = AuthService.normalizeEmail(widget.initialEmail);
    _password.addListener(_refreshPasswordRules);
    if (widget.mode == AuthMode.otp) _startResendCooldown();
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _resendTimer?.cancel();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password
      ..removeListener(_refreshPasswordRules)
      ..dispose();
    _confirm.dispose();
    _otp.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _refreshPasswordRules() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 18 : 28,
          vertical: mobile ? 24 : 48,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: Material(
              color: AppColors.paper,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: mobile
                  ? Column(
                      children: [
                        _MobileAuthBrand(mode: widget.mode),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 30,
                          ),
                          child: _buildForm(context),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: _AuthStory()),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 52,
                              vertical: 40,
                            ),
                            child: _buildForm(context),
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

  Widget _buildForm(BuildContext context) {
    final session = AuthScope.watch(context);
    final location = LocationScope.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.backOr('/'),
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('Back to news'),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'CITIZENNEWS ACCOUNT',
          style: TextStyle(
            color: AppColors.red,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.mode.heading,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          widget.mode.introduction,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (widget.mode == AuthMode.signup) ...[
          const SizedBox(height: 18),
          const _SignupGuide(),
        ],
        if (!session.configured) ...[
          const SizedBox(height: 18),
          _ConfigurationNotice(startupError: session.startupError),
        ],
        const SizedBox(height: 24),
        if (_sent)
          const _SentNotice()
        else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.mode == AuthMode.signup) ...[
                  _LabeledField(
                    label: 'Full name',
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Enter your full name.',
                    ),
                  ),
                  _LabeledField(
                    label: 'Username',
                    helper: _usernameStatus,
                    helperSuccess: _usernameStatus == 'Username is available.',
                    child: TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                        LengthLimitingTextInputFormatter(30),
                      ],
                      onChanged: _checkUsername,
                      validator: (value) =>
                          RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(value ?? '')
                          ? null
                          : 'Use 3–30 lowercase letters, numbers or underscores.',
                    ),
                  ),
                ],
                if (widget.mode != AuthMode.resetPassword)
                  _LabeledField(
                    label: 'Email address',
                    child: TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                    ),
                  ),
                if ({
                  AuthMode.login,
                  AuthMode.signup,
                  AuthMode.resetPassword,
                }.contains(widget.mode)) ...[
                  _LabeledField(
                    label: 'Password',
                    child: TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: [
                        widget.mode == AuthMode.login
                            ? AutofillHints.password
                            : AutofillHints.newPassword,
                      ],
                      textInputAction: widget.mode == AuthMode.login
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onFieldSubmitted: widget.mode == AuthMode.login
                          ? (_) => _submit()
                          : null,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => _validatePassword(
                        value,
                        strict: widget.mode != AuthMode.login,
                      ),
                    ),
                  ),
                  if (widget.mode != AuthMode.login)
                    _PasswordRules(password: _password.text),
                ],
                if ({
                  AuthMode.signup,
                  AuthMode.resetPassword,
                }.contains(widget.mode))
                  _LabeledField(
                    label: 'Confirm password',
                    child: TextFormField(
                      controller: _confirm,
                      obscureText: !_showConfirm,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showConfirm
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () =>
                              setState(() => _showConfirm = !_showConfirm),
                          icon: Icon(
                            _showConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == _password.text
                          ? null
                          : 'Passwords do not match.',
                    ),
                  ),
                if (widget.mode == AuthMode.signup) ...[
                  _LabeledField(
                    label: 'Phone number',
                    helper:
                        'Private account contact. It is never shown on your public profile.',
                    child: PhoneFormField(
                      controller: _phone,
                      countrySelectorNavigator:
                          const CountrySelectorNavigator.modalBottomSheet(),
                      countryButtonStyle: const CountryButtonStyle(
                        showDialCode: true,
                        showIsoCode: true,
                        showFlag: true,
                        flagSize: 16,
                      ),
                      autofillHints: const [AutofillHints.telephoneNumber],
                      validator: PhoneValidator.compose([
                        PhoneValidator.required(
                          context,
                          errorText: 'Enter your phone number.',
                        ),
                        PhoneValidator.valid(
                          context,
                          errorText: 'Enter a valid phone number.',
                        ),
                      ]),
                    ),
                  ),
                  _LabeledField(
                    label: 'Country',
                    helper: 'Choose the country for your account profile.',
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('signup-country-${location.countryId}'),
                      initialValue: location.countryId.isEmpty
                          ? null
                          : location.countryId,
                      isExpanded: true,
                      items: [
                        for (final country in location.countries)
                          DropdownMenuItem(
                            value: country.id,
                            child: Text(country.name),
                          ),
                      ],
                      onChanged: location.loading
                          ? null
                          : (value) => location.selectCountry(value ?? ''),
                      validator: (_) => location.countryId.isEmpty
                          ? 'Choose your country.'
                          : null,
                    ),
                  ),
                  if (location.countryId.isNotEmpty) ...[
                    if (location.regions.isNotEmpty)
                      _LabeledField(
                        label: 'Region (optional)',
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('signup-region-${location.regionId}'),
                          initialValue: location.regionId,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All regions'),
                            ),
                            for (final region in location.regions)
                              DropdownMenuItem(
                                value: region.id,
                                child: Text(region.name),
                              ),
                          ],
                          onChanged: location.loading
                              ? null
                              : (value) => location.selectRegion(value ?? ''),
                        ),
                      ),
                    _LabeledField(
                      label: 'Search city',
                      child: TextFormField(
                        decoration: const InputDecoration(
                          hintText: 'Type your city name',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: location.searchCities,
                      ),
                    ),
                    _LabeledField(
                      label: 'City',
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('signup-city-${location.cityId}'),
                        initialValue: location.cityId.isEmpty
                            ? null
                            : location.cityId,
                        isExpanded: true,
                        items: [
                          for (final city in location.cities)
                            DropdownMenuItem(
                              value: city.id,
                              child: Text(city.name),
                            ),
                        ],
                        onChanged: location.loading
                            ? null
                            : (value) => location.selectCity(value ?? ''),
                        validator: (_) => location.cityId.isEmpty
                            ? 'Choose your city.'
                            : null,
                      ),
                    ),
                  ],
                  if (location.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        location.error!,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  _AgreementTile(
                    value: _terms,
                    onChanged: (value) => setState(() => _terms = value),
                    text: 'I accept the Terms and Privacy Policy.',
                  ),
                  _AgreementTile(
                    value: _guidelines,
                    onChanged: (value) => setState(() => _guidelines = value),
                    text: 'I agree to follow the Community Guidelines.',
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/terms'),
                        child: const Text('Terms'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/privacy'),
                        child: const Text('Privacy'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/community-guidelines'),
                        child: const Text('Community guidelines'),
                      ),
                    ],
                  ),
                ],
                if (widget.mode == AuthMode.otp) ...[
                  _LabeledField(
                    label: '6-digit verification code',
                    child: TextFormField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value ?? '')
                          ? null
                          : 'Enter the 6-digit code.',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _busy || _resendWait > 0 ? null : _resend,
                      child: Text(
                        _resendWait > 0
                            ? 'Resend code in ${_resendWait}s'
                            : 'Resend code',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (widget.mode == AuthMode.login)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/forgot-password'),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _ErrorNotice(message: _error!),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.mode.submitLabel),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        if (widget.mode != AuthMode.resetPassword &&
            widget.mode != AuthMode.otp)
          _AuthSwitch(mode: widget.mode),
        const SizedBox(height: 12),
        const Text(
          'Your account is protected by Supabase Auth and database row-level security.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  String? _validateEmail(String? value) {
    final email = AuthService.normalizeEmail(value ?? '');
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Enter a valid email address.';
  }

  String? _validatePassword(String? value, {required bool strict}) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password.';
    if (!strict) return null;
    if (password.length < 6 ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Use at least 6 characters with a letter and a number.';
    }
    return null;
  }

  void _checkUsername(String value) {
    _usernameTimer?.cancel();
    final username = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(username)) {
      setState(() => _usernameStatus = '');
      return;
    }
    setState(() => _usernameStatus = 'Checking username…');
    _usernameTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final available = await AuthScope.read(
          context,
        ).service.usernameAvailable(username);
        if (!mounted || _username.text.trim() != username) return;
        setState(
          () => _usernameStatus = available
              ? 'Username is available.'
              : 'Username is already taken.',
        );
      } catch (_) {
        if (mounted) setState(() => _usernameStatus = '');
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (widget.mode == AuthMode.signup && (!_terms || !_guidelines)) {
      setState(
        () => _error =
            'Accept the Terms, Privacy Policy and Community Guidelines to continue.',
      );
      return;
    }
    if (!valid) return;

    final session = AuthScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (widget.mode) {
        case AuthMode.signup:
          final location = LocationScope.read(context);
          if (location.cityId.isEmpty) {
            throw Exception('Choose your country and city.');
          }
          final username = _username.text.trim().toLowerCase();
          if (!await session.service.usernameAvailable(username)) {
            throw Exception('That username is already taken.');
          }
          final phone = _phone.value;
          if (!phone.isValid()) throw Exception('Enter a valid phone number.');
          final e164 = phone.international.replaceAll(RegExp(r'[^+\d]'), '');
          final response = await session.service.signUp(
            fullName: _name.text,
            username: username,
            email: _email.text,
            password: _password.text,
            phoneE164: e164,
            phoneCountry: phone.isoCode.name,
            cityId: location.cityId,
          );
          if (AuthService.isExistingSignupUser(response.user)) {
            throw Exception('An account already exists for this email.');
          }
          await session.syncFromClient();
          if (!mounted) return;
          if (response.session != null) {
            context.go('/verification');
          } else {
            context.go(
              '/otp?email=${Uri.encodeQueryComponent(AuthService.normalizeEmail(_email.text))}',
            );
          }
        case AuthMode.login:
          await session.service.signIn(
            email: _email.text,
            password: _password.text,
          );
          await session.syncFromClient();
          if (!mounted) return;
          final target = widget.returnTo;
          context.go(
            target != null && target.startsWith('/') && !target.startsWith('//')
                ? target
                : '/',
          );
        case AuthMode.otp:
          await session.service.verifyEmailOtp(
            email: _email.text,
            token: _otp.text,
          );
          await session.syncFromClient();
          if (mounted) context.go('/verification');
        case AuthMode.forgotPassword:
          await session.service.requestPasswordReset(_email.text);
          if (mounted) setState(() => _sent = true);
        case AuthMode.resetPassword:
          if (!session.isSignedIn) {
            throw Exception('Open the recovery link from your email first.');
          }
          await session.service.updatePassword(_password.text);
          session.finishPasswordRecovery();
          if (mounted) context.go('/account');
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _resendWait > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthScope.read(context).service.resendSignupOtp(_email.text);
      _otp.clear();
      _startResendCooldown();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendWait = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendWait--);
      if (_resendWait <= 0) timer.cancel();
    });
  }
}

class _MobileAuthBrand extends StatelessWidget {
  const _MobileAuthBrand({required this.mode});

  final AuthMode mode;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF172C3A), Color(0xFF29475A)],
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(mode.icon, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode.eyebrow,
                style: const TextStyle(
                  color: Color(0xFFFC8794),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Local voices. Trusted news.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AuthStory extends StatelessWidget {
  const _AuthStory();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF172C3A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(45, 54, 45, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CITIZENNEWS / JOIN THE NEWSROOM',
              style: TextStyle(
                color: Color(0xFFB5C2CD),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 55),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Every community\nhas a story.\n'),
                  TextSpan(
                    text: 'Tell yours.',
                    style: TextStyle(color: Color(0xFFFC8794)),
                  ),
                ],
              ),
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                height: 1.13,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'On-the-ground reporting. Verified voices. News that brings your community closer.',
              style: TextStyle(
                color: Color(0xFFBBC8D0),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 35),
            const _StoryValue(
              icon: Icons.verified_user_outlined,
              text: 'Real people, verified identities',
            ),
            const _StoryValue(
              icon: Icons.my_location_rounded,
              text: 'Stories captured at the scene',
            ),
            const _StoryValue(
              icon: Icons.fact_check_outlined,
              text: 'Human review, editorial accountability',
            ),
            const SizedBox(height: 50),
            const Text(
              'Local voices. Accountable journalism.',
              style: TextStyle(color: Color(0xFFBBC8D0), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryValue extends StatelessWidget {
  const _StoryValue({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFD1DCE4), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFD1DCE4), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _SignupGuide extends StatelessWidget {
  const _SignupGuide();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF2FAF5),
      border: Border.all(color: const Color(0xFFD8E9DF)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: Color(0xFF168557),
          child: Icon(Icons.check, size: 13, color: Colors.white),
        ),
        SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One account for reading and reporting',
                style: TextStyle(
                  color: Color(0xFF24543C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'After email confirmation, complete identity verification to become a reporter.',
                style: TextStyle(
                  color: Color(0xFF527060),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ConfigurationNotice extends StatelessWidget {
  const _ConfigurationNotice({this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7E6),
      border: Border.all(color: const Color(0xFFF0D6A0)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      startupError ??
          'Supabase configuration is missing. Copy config.example.json to config.json, add the public project URL/key, then run with --dart-define-from-file=config.json.',
      style: const TextStyle(
        color: Color(0xFF78530B),
        fontSize: 12,
        height: 1.45,
      ),
    ),
  );
}

class _SentNotice extends StatelessWidget {
  const _SentNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF2FAF5),
      border: Border.all(color: const Color(0xFFD8E9DF)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'If an account exists for this email, a recovery message has been sent. Open its link to choose a new password.',
      style: TextStyle(color: Color(0xFF24543C), height: 1.5),
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.helper,
    this.helperSuccess = false,
  });
  final String label;
  final Widget child;
  final String? helper;
  final bool helperSuccess;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        child,
        if (helper?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(
            helper!,
            style: TextStyle(
              color: helperSuccess ? AppColors.success : AppColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    ),
  );
}

class _PasswordRules extends StatelessWidget {
  const _PasswordRules({required this.password});
  final String password;
  @override
  Widget build(BuildContext context) {
    final rules = [
      ('6+ characters', password.length >= 6),
      ('A letter', RegExp(r'[A-Za-z]').hasMatch(password)),
      ('A number', RegExp(r'\d').hasMatch(password)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: rules
            .map(
              (rule) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rule.$2
                      ? const Color(0xFFE9F8EF)
                      : const Color(0xFFF0F3F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rule.$2 ? '✓' : '○'} ${rule.$1}',
                  style: TextStyle(
                    color: rule.$2 ? const Color(0xFF087649) : AppColors.muted,
                    fontSize: 10,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AgreementTile extends StatelessWidget {
  const _AgreementTile({
    required this.value,
    required this.onChanged,
    required this.text,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: value,
    onChanged: (next) => onChanged(next ?? false),
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(text, style: const TextStyle(fontSize: 12, height: 1.35)),
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F3),
      border: Border.all(color: const Color(0xFFF8D9DE)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFFA51E30), fontSize: 12),
    ),
  );
}

class _AuthSwitch extends StatelessWidget {
  const _AuthSwitch({required this.mode});
  final AuthMode mode;
  @override
  Widget build(BuildContext context) {
    final signup = mode == AuthMode.signup;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          signup ? 'Already have an account? ' : 'New to CitizenNews? ',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        TextButton(
          onPressed: () => context.go(signup ? '/login' : '/signup'),
          child: Text(signup ? 'Log in' : 'Create account'),
        ),
      ],
    );
  }
}
