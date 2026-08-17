import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'l10n/app_localizations.dart';

// Where the backend lives during local web dev.
// (Native builds later can point at a device-reachable host.)
const String kApiBaseUrl = 'http://127.0.0.1:8000';

void main() => runApp(const IslamicGameApp());

class IslamicGameApp extends StatefulWidget {
  const IslamicGameApp({super.key});

  @override
  State<IslamicGameApp> createState() => _IslamicGameAppState();
}

class _IslamicGameAppState extends State<IslamicGameApp> {
  // null = follow the device locale; otherwise force the chosen one.
  Locale? _locale;

  void _setLocale(Locale? locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Flutter applies RTL automatically for Arabic via Directionality,
      // driven by the active locale — no manual flipping needed.
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1F7A5A),
        useMaterial3: true,
      ),
      home: HealthScreen(onLocaleChange: _setLocale),
    );
  }
}

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key, required this.onLocaleChange});

  final void Function(Locale?) onLocaleChange;

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool _loading = true;
  bool _ok = false;
  bool _db = false;
  bool _redis = false;
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
        _db = body['db'] == true;
        _redis = body['redis'] == true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _db = false;
        _redis = false;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          PopupMenuButton<Locale?>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLocaleChange,
            itemBuilder: (context) => const [
              PopupMenuItem(value: Locale('en'), child: Text('English')),
              PopupMenuItem(value: Locale('ur'), child: Text('اردو')),
              PopupMenuItem(value: Locale('ar'), child: Text('العربية')),
            ],
          ),
        ],
      ),
      body: Center(
        child: _loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(t.checkingBackend),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(height: 16),
                  _statusRow(t.database, _db),
                  _statusRow(t.cache, _redis),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.refresh),
                    label: Text(t.retry),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _statusRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check : Icons.close,
              color: ok ? Colors.green : Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}