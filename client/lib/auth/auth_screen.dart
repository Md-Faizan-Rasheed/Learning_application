import 'package:flutter/material.dart';

import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth, required this.onSignedIn});

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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Session s;
      switch (_mode) {
        case _Mode.login:
          s = await widget.auth
              .login(email: _email.text.trim(), password: _password.text);
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
          s = await widget.auth
              .guest(displayName: _name.text.trim(), gender: _gender);
          break;
      }
      if (mounted) widget.onSignedIn(s);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_Mode>(
                  segments: const [
                    ButtonSegment(value: _Mode.login, label: Text('Login')),
                    ButtonSegment(value: _Mode.register, label: Text('Register')),
                    ButtonSegment(value: _Mode.guest, label: Text('Guest')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() {
                    _mode = s.first;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 24),
                if (_mode != _Mode.guest) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (8+ characters)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_mode != _Mode.login) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender (for matchmaking)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? 'male'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null) ...[
                  Text(_error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: (_busy || !_canSubmit) ? null : _submit,
                  child: Text(_busy
                      ? '…'
                      : switch (_mode) {
                          _Mode.login => 'Log in',
                          _Mode.register => 'Create account',
                          _Mode.guest => 'Continue as guest',
                        }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}