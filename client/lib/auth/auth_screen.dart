import 'package:flutter/material.dart';

import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.auth,
    required this.onSignedIn,
  });

  final AuthService auth;
  final void Function(Session) onSignedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { login, register, guest }

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.login;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  String _gender = 'male';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
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
        widget.onSignedIn(s);
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
        return _email.text.contains('@') &&
            _password.text.length >= 8;

      case _Mode.register:
        return _email.text.contains('@') &&
            _password.text.length >= 8 &&
            _name.text.trim().isNotEmpty;

      case _Mode.guest:
        return _name.text.trim().isNotEmpty;
    }
  }

  String get _title {
    switch (_mode) {
      case _Mode.login:
        return 'Welcome back';

      case _Mode.register:
        return 'Create your player';

      case _Mode.guest:
        return 'Play as a guest';
    }
  }

  String get _subtitle {
    switch (_mode) {
      case _Mode.login:
        return 'Jump back into your learning journey.';

      case _Mode.register:
        return 'Create your profile and start playing.';

      case _Mode.guest:
        return 'Start playing without creating an account.';
    }
  }

  String get _buttonText {
    switch (_mode) {
      case _Mode.login:
        return 'Enter the game';

      case _Mode.register:
        return 'Create player';

      case _Mode.guest:
        return 'Start playing';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.12),
              colorScheme.surface,
              colorScheme.secondary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth < 600 ? 20.0 : 32.0;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 480,
                    ),
                    child: Column(
                      children: [
                        _buildBrand(context),
                        const SizedBox(height: 28),
                        _buildAuthCard(context),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 38,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'LEARN & PLAY',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeSelector(context),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Column(
                key: ValueKey(_mode),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_mode != _Mode.guest) ...[
                    _buildTextField(
                      context,
                      controller: _email,
                      label: 'Email',
                      hint: 'you@example.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      context,
                      controller: _password,
                      label: 'Password',
                      hint: 'At least 8 characters',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_mode != _Mode.login) ...[
                    _buildTextField(
                      context,
                      controller: _name,
                      label: 'Display name',
                      hint: 'Choose your player name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildGenderSelector(context),
                    const SizedBox(height: 14),
                  ],
                  if (_error != null) ...[
                    _buildError(context),
                    const SizedBox(height: 14),
                  ],
                  _buildSubmitButton(context),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SegmentedButton<_Mode>(
        segments: const [
          ButtonSegment(
            value: _Mode.login,
            label: Text('Login'),
            icon: Icon(Icons.login_rounded),
          ),
          ButtonSegment(
            value: _Mode.register,
            label: Text('Register'),
            icon: Icon(Icons.person_add_alt_1_rounded),
          ),
          ButtonSegment(
            value: _Mode.guest,
            label: Text('Guest'),
            icon: Icon(Icons.play_arrow_rounded),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: _busy
            ? null
            : (selection) {
                setState(() {
                  _mode = selection.first;
                  _error = null;
                });
              },
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: !_busy,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<String>(
      initialValue: _gender,
      decoration: InputDecoration(
        labelText: 'Gender',
        helperText: 'Used for matchmaking',
        prefixIcon: const Icon(Icons.groups_rounded),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'male',
          child: Text('Male'),
        ),
        DropdownMenuItem(
          value: 'female',
          child: Text('Female'),
        ),
      ],
      onChanged: _busy
          ? null
          : (value) {
              setState(() {
                _gender = value ?? 'male';
              });
            },
    );
  }

  Widget _buildError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: FilledButton(
        onPressed: (_busy || !_canSubmit) ? null : _submit,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _busy
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey('button'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_buttonText),
                    const SizedBox(width: 8),
                    Icon(
                      _mode == _Mode.login
                          ? Icons.arrow_forward_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _mode == _Mode.guest
                ? 'No account required'
                : 'Your progress will be saved securely',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}