import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api/game_api.dart' show kApiBaseUrl;
import 'auth/auth_screen.dart';
import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/multiplayer_screen.dart';
import 'screens/practice_screen.dart';

void main() => runApp(const IslamicGameApp());

class IslamicGameApp extends StatefulWidget {
  const IslamicGameApp({super.key});

  @override
  State<IslamicGameApp> createState() => _IslamicGameAppState();
}

class _IslamicGameAppState extends State<IslamicGameApp> {
  Locale _locale = const Locale('en');
  final AuthService _auth = AuthService();
  bool _booting = true;

  void _setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  void initState() {
    super.initState();
    _auth.restore().then((_) => setState(() => _booting = false));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F7A5A),
        useMaterial3: true,
      ),
      home: _booting
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _auth.isSignedIn
              ? HomeScreen(
                  auth: _auth,
                  currentLang: _locale.languageCode,
                  onLocaleChange: _setLocale,
                  onSignOut: () async {
                    await _auth.signOut();
                    setState(() {});
                  },
                )
              : AuthScreen(
                  auth: _auth,
                  onSignedIn: (_) => setState(() {}),
                ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.currentLang,
    required this.onLocaleChange,
    required this.onSignOut,
  });

  final AuthService auth;
  final String currentLang;
  final void Function(Locale) onLocaleChange;
  final Future<void> Function() onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _ok = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/health'))
          .timeout(const Duration(seconds: 5));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _ok = body['status'] == 'ok';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final name = widget.auth.current?.displayName ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLocaleChange,
            itemBuilder: (context) => const [
              PopupMenuItem(value: Locale('en'), child: Text('English')),
              PopupMenuItem(value: Locale('ur'), child: Text('اردو')),
              PopupMenuItem(value: Locale('ar'), child: Text('العربية')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Signed in as $name',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                  Icon(
                    _ok ? Icons.check_circle : Icons.error,
                    color: _ok ? Colors.green : Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _ok ? t.backendHealthy : t.backendUnreachable,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _ok
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PracticeScreen(lang: widget.currentLang),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(t.practice),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _ok
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MultiplayerScreen(
                                  lang: widget.currentLang,
                                  name: widget.auth.current?.displayName ?? 'You',
                                  token: widget.auth.current?.token,
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.groups),
                    label: const Text('Multiplayer'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.refresh),
                    label: Text(t.retry),
                  ),
                ],
              ),
      ),
    );
  }
}