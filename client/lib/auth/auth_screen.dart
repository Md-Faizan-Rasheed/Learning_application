import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/game_api.dart' show kApiBaseUrl;
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/language_picker.dart';
import 'auth_service.dart';
import 'portal_backdrop.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.auth,
    required this.onSignedIn,
    required this.currentLang,
    required this.onLocaleChange,
  });

  final AuthService auth;
  final void Function(Session) onSignedIn;
  final String currentLang;
  final void Function(Locale) onLocaleChange;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { login, register, guest }

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.login;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();

  String _gender = 'male';
  bool _asTeacher = false;
  bool _busy = false;
  String? _error;
  int _registerStep = 0;
  int _burstSignal = 0;

  @override
  void initState() {
    super.initState();
    for (final f in [_emailFocus, _passwordFocus, _nameFocus]) {
      f.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  double get _portalIntensity {
    if (_busy) return 1.0;
    if (_emailFocus.hasFocus ||
        _passwordFocus.hasFocus ||
        _nameFocus.hasFocus) {
      return 0.85;
    }
    return 0.4;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final Session s;

      switch (_mode) {
        case _Mode.login:
          s = await widget.auth.login(
            email: _email.text.trim(),
            password: _password.text,
          );
          break;

        case _Mode.register:
          s = await widget.auth.register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            gender: _gender,
            role: _asTeacher ? 'teacher' : 'player',
          );
          break;

        case _Mode.guest:
          s = await widget.auth.guest(
            displayName: _name.text.trim(),
            gender: _gender,
          );
          break;
      }

      if (mounted) {
        // Let the portal's light burst play before handing off to the app.
        setState(() => _burstSignal++);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) widget.onSignedIn(s);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool get _canSubmit {
    switch (_mode) {
      case _Mode.login:
        return _email.text.contains('@') && _password.text.length >= 8;

      case _Mode.register:
        return _email.text.contains('@') &&
            _password.text.length >= 8 &&
            _name.text.trim().isNotEmpty;

      case _Mode.guest:
        return _name.text.trim().isNotEmpty;
    }
  }

  bool get _currentStepValid {
    switch (_registerStep) {
      case 0:
        return _name.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _goToMode(_Mode m) {
    setState(() {
      _mode = m;
      _error = null;
      _registerStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.emerald,
          secondary: AppPalette.violet,
          surface: AppPalette.nightTop,
          error: AppPalette.gold,
        ),
        scaffoldBackgroundColor: AppPalette.nightTop,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const AnimatedNightBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;
                  return isDesktop
                      ? _buildDesktopLayout(context, t)
                      : _buildMobileLayout(context, t);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppLocalizations t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        children: [
          _buildTopBar(context),
          const SizedBox(height: 12),
          _buildHero(context, t),
          const SizedBox(height: 18),
          GlowingPortal(
              size: 176,
              intensity: _portalIntensity,
              spinFast: _busy,
              burstSignal: _burstSignal),
          const SizedBox(height: 18),
          _buildGlassPanel(context, t),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      child: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHero(context, t),
                      const SizedBox(height: 32),
                      GlowingPortal(
                          size: 260,
                          intensity: _portalIntensity,
                          spinFast: _busy,
                          burstSignal: _burstSignal),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: SingleChildScrollView(
                          child: _buildGlassPanel(context, t)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: LanguagePicker(
          currentLanguage: widget.currentLang,
          onLocaleChange: widget.onLocaleChange),
    );
  }

  Widget _buildHero(BuildContext context, AppLocalizations t) {
    final isReturning = _mode == _Mode.login;
    final title = isReturning ? t.authHeroWelcomeTitle : t.authHeroNewTitle;
    final subtitle =
        isReturning ? t.authHeroWelcomeSubtitle : t.authHeroNewSubtitle;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, (1 - value) * 14), child: child),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              shadows: [Shadow(color: AppPalette.emerald, blurRadius: 18)],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500),
          ),
          if (_busy) ...[
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: _busy ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: Text(
                t.authOpeningPortal,
                style: const TextStyle(
                    color: AppPalette.gold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassPanel(BuildContext context, AppLocalizations t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppPalette.glassFill,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppPalette.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModeSelector(context, t),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _mode == _Mode.register
                    ? _buildRegisterSteps(context, t)
                    : _buildSingleStepForm(context, t),
              ),
              if (_mode != _Mode.guest) ...[
                const SizedBox(height: 18),
                _buildChooseWayIn(context, t),
              ],
              const SizedBox(height: 16),
              _buildFooterLinks(context, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, AppLocalizations t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three full-word segments (icon + label each) don't fit a narrow
        // phone at normal size — the longest label ("Register") wraps to a
        // second line instead of truncating. Below this width, drop the
        // icons and shrink the text so all three stay on one line.
        final compact = constraints.maxWidth < 360;

        Widget label(String text) => Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            );

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.glassBorder),
          ),
          child: SegmentedButton<_Mode>(
            segments: [
              ButtonSegment(
                  value: _Mode.login,
                  label: label(t.authLogin),
                  icon: compact ? null : const Icon(Icons.login_rounded)),
              ButtonSegment(
                  value: _Mode.register,
                  label: label(t.authRegister),
                  icon: compact
                      ? null
                      : const Icon(Icons.person_add_alt_1_rounded)),
              ButtonSegment(
                  value: _Mode.guest,
                  label: label(t.authGuest),
                  icon: compact ? null : const Icon(Icons.explore_rounded)),
            ],
            selected: {_mode},
            onSelectionChanged:
                _busy ? null : (selection) => _goToMode(selection.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(
                TextStyle(
                    fontSize: compact ? 12.5 : 14,
                    fontWeight: FontWeight.w700),
              ),
              padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(
                    horizontal: compact ? 2 : 6, vertical: 12),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleStepForm(BuildContext context, AppLocalizations t) {
    return Column(
      key: const ValueKey('single'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mode == _Mode.login) ...[
          _buildTextField(
            controller: _email,
            focusNode: _emailFocus,
            label: t.authEmail,
            hint: t.authEmailHint,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _password,
            focusNode: _passwordFocus,
            label: t.authPassword,
            hint: t.authPasswordHint,
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _busy ? null : _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.textSecondary,
                textStyle: const TextStyle(fontSize: 12.5),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
              ),
              child: Text(t.authForgotPassword),
            ),
          ),
          const SizedBox(height: 2),
        ] else ...[
          Text(t.authExploreFirst,
              style: const TextStyle(
                  color: AppPalette.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _name,
            focusNode: _nameFocus,
            label: t.authDisplayName,
            hint: t.authDisplayNameHint,
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          _buildGenderSelector(context, t),
          const SizedBox(height: 8),
          Text(t.authGuestHelper,
              style: const TextStyle(
                  color: AppPalette.textSecondary, fontSize: 11.5)),
          const SizedBox(height: 14),
        ],
        if (_error != null) ...[
          _buildError(context, t),
          const SizedBox(height: 14)
        ],
        _buildSubmitButton(context, t),
      ],
    );
  }

  Widget _buildRegisterSteps(BuildContext context, AppLocalizations t) {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepIndicator(context, t),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildStepContent(context, t),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _buildError(context, t),
          const SizedBox(height: 14)
        ],
        Row(
          children: [
            if (_registerStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _busy ? null : () => setState(() => _registerStep--),
                  child: Text(t.authBack),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: _registerStep < 2
                  ? SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: (_busy || !_currentStepValid)
                            ? null
                            : () => setState(() => _registerStep++),
                        child: Text(t.authNext,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    )
                  : _buildSubmitButton(context, t),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepIndicator(BuildContext context, AppLocalizations t) {
    final titles = [t.authStep1Title, t.authStep2Title, t.authStep3Title];
    final bar = Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 4,
              decoration: BoxDecoration(
                color: i <= _registerStep
                    ? AppPalette.emerald
                    : AppPalette.glassBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i != 2) const SizedBox(width: 6),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        const SizedBox(height: 8),
        Text(
          titles[_registerStep],
          style: const TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildStepContent(BuildContext context, AppLocalizations t) {
    switch (_registerStep) {
      case 0:
        return Column(
          key: const ValueKey('step0'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _name,
              focusNode: _nameFocus,
              label: t.authDisplayName,
              hint: t.authDisplayNameHint,
              icon: Icons.person_outline_rounded,
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey('step1'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGenderSelector(context, t),
            const SizedBox(height: 12),
            _buildTeacherToggle(context, t),
          ],
        );
      default:
        return Column(
          key: const ValueKey('step2'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _email,
              focusNode: _emailFocus,
              label: t.authEmail,
              hint: t.authEmailHint,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _password,
              focusNode: _passwordFocus,
              label: t.authPassword,
              hint: t.authPasswordHint,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
          ],
        );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: !_busy,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppPalette.textSecondary),
        hintStyle:
            TextStyle(color: AppPalette.textSecondary.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: AppPalette.textSecondary),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.22),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.glassBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.emerald, width: 2)),
      ),
    );
  }

  Widget _buildGenderSelector(BuildContext context, AppLocalizations t) {
    return DropdownButtonFormField<String>(
      initialValue: _gender,
      dropdownColor: AppPalette.nightBottom,
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: InputDecoration(
        labelText: t.authGender,
        helperText: t.authGenderHelper,
        labelStyle: const TextStyle(color: AppPalette.textSecondary),
        helperStyle: const TextStyle(color: AppPalette.textSecondary),
        prefixIcon:
            const Icon(Icons.groups_rounded, color: AppPalette.textSecondary),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.22),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.glassBorder)),
      ),
      items: [
        DropdownMenuItem(value: 'male', child: Text(t.authMale)),
        DropdownMenuItem(value: 'female', child: Text(t.authFemale)),
      ],
      onChanged:
          _busy ? null : (value) => setState(() => _gender = value ?? 'male'),
    );
  }

  Widget _buildTeacherToggle(BuildContext context, AppLocalizations t) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _busy ? null : () => setState(() => _asTeacher = !_asTeacher),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _asTeacher
              ? AppPalette.emerald.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _asTeacher
                  ? AppPalette.emerald.withValues(alpha: 0.6)
                  : AppPalette.glassBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.school_rounded,
                size: 20,
                color:
                    _asTeacher ? AppPalette.emerald : AppPalette.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.authRegisterAsTeacher,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _asTeacher
                        ? AppPalette.emerald
                        : AppPalette.textPrimary),
              ),
            ),
            Switch(
              value: _asTeacher,
              activeThumbColor: AppPalette.emerald,
              onChanged: _busy ? null : (v) => setState(() => _asTeacher = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_fix_high_rounded, color: AppPalette.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.authErrorSoft,
                    style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_error!,
                    style: const TextStyle(
                        color: AppPalette.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, AppLocalizations t) {
    final label = switch (_mode) {
      _Mode.login => t.authEnterGame,
      _Mode.register => t.authCreatePlayerBtn,
      _Mode.guest => t.authStartPlaying,
    };

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
              colors: [AppPalette.emerald, AppPalette.teal, AppPalette.violet]),
          boxShadow: [
            BoxShadow(
                color: AppPalette.emerald.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: FilledButton(
          onPressed: (_busy || !_canSubmit) ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _busy
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    key: const ValueKey('button'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildChooseWayIn(BuildContext context, AppLocalizations t) {
    void comingSoon() {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.authComingSoon)));
    }

    return Column(
      children: [
        Text(t.authChooseWayIn,
            style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Divider(color: AppPalette.glassBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(t.authOrDivider,
                  style: const TextStyle(
                      color: AppPalette.textSecondary, fontSize: 12)),
            ),
            const Expanded(child: Divider(color: AppPalette.glassBorder)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _GlowIconButton(
                    icon: Icons.g_mobiledata_rounded, onTap: comingSoon)),
            const SizedBox(width: 10),
            Expanded(
                child: _GlowIconButton(
                    icon: Icons.apple_rounded, onTap: comingSoon)),
            const SizedBox(width: 10),
            Expanded(
                child: _GlowIconButton(
                    icon: Icons.phone_iphone_rounded, onTap: comingSoon)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: comingSoon,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              side: const BorderSide(color: AppPalette.glassBorder),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(t.authMagicLink),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks(BuildContext context, AppLocalizations t) {
    return Column(
      children: [
        if (_mode == _Mode.login)
          TextButton(
            onPressed: _busy ? null : () => _goToMode(_Mode.register),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                      text: '${t.authNewExplorerPrompt} ',
                      style: const TextStyle(color: AppPalette.textSecondary)),
                  TextSpan(
                      text: t.authRegister,
                      style: const TextStyle(
                          color: AppPalette.emerald,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined,
                size: 15, color: AppPalette.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _mode == _Mode.guest
                    ? t.authNoAccountRequired
                    : t.authProgressSaved,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppPalette.textSecondary, fontSize: 11.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _openLegal('/legal/privacy'),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.textSecondary,
                textStyle: const TextStyle(fontSize: 11.5),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(t.authPrivacyPolicy),
            ),
            const Text('·', style: TextStyle(color: AppPalette.textSecondary)),
            TextButton(
              onPressed: () => _openLegal('/legal/terms'),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.textSecondary,
                textStyle: const TextStyle(fontSize: 11.5),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(t.authTermsOfService),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openLegal(String path) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showForgotPasswordDialog() async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _email.text.trim());
    bool sending = false;
    bool sent = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> send() async {
            if (!controller.text.contains('@')) return;
            setDialogState(() {
              sending = true;
              error = null;
            });
            try {
              await widget.auth.forgotPassword(controller.text.trim());
              setDialogState(() {
                sending = false;
                sent = true;
              });
            } catch (e) {
              setDialogState(() {
                sending = false;
                error = e.toString();
              });
            }
          }

          return AlertDialog(
            backgroundColor: AppPalette.nightBottom,
            title: Text(t.authForgotPasswordTitle,
                style: const TextStyle(color: AppPalette.textPrimary)),
            content: sent
                ? Text(t.authForgotPasswordSent,
                    style: const TextStyle(color: AppPalette.textSecondary))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.authForgotPasswordPrompt,
                          style: const TextStyle(
                              color: AppPalette.textSecondary, fontSize: 13)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        enabled: !sending,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppPalette.textPrimary),
                        decoration: InputDecoration(
                          labelText: t.authEmail,
                          labelStyle:
                              const TextStyle(color: AppPalette.textSecondary),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.22),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!,
                            style: const TextStyle(
                                color: AppPalette.gold, fontSize: 12)),
                      ],
                    ],
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(sent ? t.authClose : t.authCancel),
              ),
              if (!sent)
                FilledButton(
                  onPressed: sending ? null : send,
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.authSend),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A compact glowing round button for the disabled social-login row.
class _GlowIconButton extends StatefulWidget {
  const _GlowIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GlowIconButton> createState() => _GlowIconButtonState();
}

class _GlowIconButtonState extends State<_GlowIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.glassBorder),
          ),
          child: Icon(widget.icon, color: AppPalette.textSecondary, size: 22),
        ),
      ),
    );
  }
}
