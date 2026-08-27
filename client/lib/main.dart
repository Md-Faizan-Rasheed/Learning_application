import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api/game_api.dart' show kApiBaseUrl;
import 'auth/auth_screen.dart';
import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/multiplayer_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quests_screen.dart';
import 'widgets/app_header.dart';
import 'widgets/category_card.dart';
import 'widgets/category_picker_dialog.dart';
import 'widgets/language_picker.dart';

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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _ok = false;
  String? _error;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _check();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController!);

    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController!.dispose();
    super.dispose();
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
      appBar: AppHeader(
        title: t.appTitle,
        centerTitle: false,
        actions: [
          LanguagePicker(
            currentLanguage: widget.currentLang,
            onLocaleChange: widget.onLocaleChange,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDesktop = width >= 900;
          final isTablet = width >= 600 && width < 900;
          final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 32.0 : 18.0);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
              child: FadeTransition(
                opacity: _fadeAnimation!,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (name.isNotEmpty) ...[
                        _buildWelcomeBanner(context, name, isDesktop),
                        const SizedBox(height: 20),
                      ],
                      _buildConnectionStatus(t),
                      const SizedBox(height: 28),
                      Text(
                        'Play',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActions(context, twoColumns: isDesktop),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, String name, bool isDesktop) {
    final bannerHeight = isDesktop ? 160.0 : 130.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: bannerHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.primary),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 18, vertical: 16),
              child: Row(
                children: [
                  _BannerAvatar(name: name, size: isDesktop ? 52 : 44),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome back',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(AppLocalizations t) {
    if (_loading) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Checking connection…',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      );
    }

    if (_ok) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Text(
            t.backendHealthy,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.backendUnreachable,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          TextButton(onPressed: _check, child: Text(t.retry)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, {required bool twoColumns}) {
    final practice = CategoryCard(
      title: 'Practice',
      icon: Icons.play_arrow,
      onTap: () async {
        final category = await _pickCategory(context);
        if (category == null || !context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PracticeScreen(
              lang: widget.currentLang,
              category: category,
            ),
          ),
        );
      },
    );

    final multiplayer = CategoryCard(
      title: 'Multiplayer',
      icon: Icons.groups,
      onTap: () async {
        final category = await _pickCategory(context);
        if (category == null || !context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MultiplayerScreen(
              lang: widget.currentLang,
              name: widget.auth.current?.displayName ?? 'You',
              token: widget.auth.current?.token,
              category: category,
            ),
          ),
        );
      },
    );

    final profile = CategoryCard(
      title: 'My Profile',
      icon: Icons.person,
      onTap: () {
        if (widget.auth.current != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                name: widget.auth.current!.displayName ?? 'Player',
                token: widget.auth.current!.token,
              ),
            ),
          );
        }
      },
    );

    final quests = CategoryCard(
      title: 'Daily Quests',
      icon: Icons.checklist,
      onTap: () {
        if (widget.auth.current != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuestsScreen(
                token: widget.auth.current!.token,
              ),
            ),
          );
        }
      },
    );

    final cards = [practice, multiplayer, profile, quests];

    if (!twoColumns) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 16),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  Future<String?> _pickCategory(BuildContext context) => showCategoryPicker(context);
}

class _BannerAvatar extends StatelessWidget {
  const _BannerAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'P';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.40,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}