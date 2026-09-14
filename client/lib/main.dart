import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'api/game_api.dart' show kApiBaseUrl;
import 'api/profile_api.dart';
import 'auth/auth_screen.dart';
import 'auth/auth_service.dart';
import 'l10n/app_localizations.dart';
import 'screens/achievements_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/multiplayer_choice_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quests_screen.dart';
import 'screens/student/assigned_quizzes_screen.dart';
import 'screens/teacher/teacher_home_screen.dart';
import 'screens/word_search_screen.dart';
import 'theme/app_theme.dart';
import 'utils/level.dart';
import 'widgets/achievement_data.dart';
import 'widgets/ambient_backdrop.dart';
import 'widgets/card_stock.dart';
import 'widgets/category_options.dart';
import 'widgets/continue_arrow_icon.dart';
import 'widgets/category_picker_dialog.dart';
import 'widgets/fade_scroll_edge.dart';
import 'widgets/language_picker.dart';
import 'widgets/reward_card.dart';
import 'widgets/word_search_difficulty_sheet.dart';

// Empty DSN makes the SDK a documented safe no-op — set at build time with
//   flutter build appbundle --dart-define=SENTRY_DSN=https://...
const String _kSentryDsn =
    String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  await SentryFlutter.init(
    (options) => options.dsn = _kSentryDsn,
    appRunner: () => runApp(const IslamicGameApp()),
  );
}

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
      theme: buildAppTheme(locale: _locale),
      home: _booting
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _auth.isSignedIn
              ? (_auth.current!.role == 'teacher'
                  ? TeacherHomeScreen(
                      token: _auth.current!.token,
                      onSignOut: () async {
                        await _auth.signOut();
                        setState(() {});
                      },
                    )
                  : (_auth.current!.role == 'admin' ||
                          _auth.current!.role == 'developer')
                      ? AdminHomeScreen(
                          token: _auth.current!.token,
                          onSignOut: () async {
                            await _auth.signOut();
                            setState(() {});
                          },
                        )
                      : HomeScreen(
                          auth: _auth,
                          currentLang: _locale.languageCode,
                          onLocaleChange: _setLocale,
                          onSignOut: () async {
                            await _auth.signOut();
                            setState(() {});
                          },
                        ))
              : AuthScreen(
                  auth: _auth,
                  onSignedIn: (_) => setState(() {}),
                  currentLang: _locale.languageCode,
                  onLocaleChange: _setLocale,
                ),
    );
  }
}

const _dailyPhrases = <(String, String)>[
  ('السلام عليكم', 'Peace be upon you'),
  ('بارك الله فيك', 'May Allah bless you'),
  ('إن شاء الله', 'God willing'),
  ('الحمد لله', 'Praise be to Allah'),
  ('جزاك الله خيرا', 'May Allah reward you with good'),
  ('صباح الخير', 'Good morning'),
  ('مع السلامة', 'Go with peace / goodbye'),
  ('شكرا جزيلا', 'Thank you very much'),
  ('أهلا وسهلا', 'Welcome'),
  ('كل عام وأنتم بخير', 'May every year find you well'),
  ('طالب العلم', 'Seeker of knowledge'),
  ('العلم نور', 'Knowledge is light'),
];

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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _healthLoading = true;
  bool _healthOk = false;
  String? _healthError;

  bool _profileLoading = true;
  Profile? _profile;
  List<Quest> _quests = [];

  late int _phraseIndex;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _checkHealth();
    _loadProfileAndQuests();

    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    _phraseIndex = dayOfYear % _dailyPhrases.length;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        Tween<double>(begin: 0, end: 1).animate(_animationController!);
    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController!.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _healthLoading = true;
      _healthError = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/health'))
          .timeout(const Duration(seconds: 5));
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      setState(() {
        _healthOk = body['status'] == 'ok';
        _healthLoading = false;
      });
    } catch (e) {
      setState(() {
        _healthOk = false;
        _healthError = e.toString();
        _healthLoading = false;
      });
    }
  }

  Future<void> _loadProfileAndQuests() async {
    final token = widget.auth.current?.token;
    if (token == null) return;
    setState(() => _profileLoading = true);

    Profile? profile;
    try {
      profile = await ProfileApi().fetchProfile(token);
    } catch (_) {
      profile = null;
    }

    List<Quest> quests = [];
    try {
      quests = await QuestsApi().fetch(token);
    } catch (_) {
      quests = [];
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _quests = quests;
      _profileLoading = false;
    });
  }

  String _greeting(AppLocalizations t, String name) {
    final hour = DateTime.now().hour;
    if (hour < 12) return t.homeGreetingMorning(name);
    if (hour < 18) return t.homeGreetingAfternoon(name);
    return t.homeGreetingEvening(name);
  }

  void _openPractice(String category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PracticeScreen(lang: widget.currentLang, category: category),
      ),
    );
  }

  Future<void> _openPracticeWithPicker() async {
    final token = widget.auth.current?.token;
    if (token == null) return;
    final category = await showCategoryPicker(context, token: token);
    if (category == null || !mounted) return;
    _openPractice(category);
  }

  void _openMultiplayer() {
    final token = widget.auth.current?.token;
    if (token == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiplayerChoiceScreen(
          lang: widget.currentLang,
          name: widget.auth.current?.displayName ?? 'You',
          token: token,
        ),
      ),
    );
  }

  void _openProfile() {
    if (widget.auth.current == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          name: widget.auth.current!.displayName,
          token: widget.auth.current!.token,
          userId: widget.auth.current!.userId,
          auth: widget.auth,
          onAccountDeleted: () {
            Navigator.of(context).pop();
            widget.onSignOut();
          },
        ),
      ),
    );
  }

  void _openQuests() {
    if (widget.auth.current == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => QuestsScreen(token: widget.auth.current!.token)))
        .then((_) => _loadProfileAndQuests());
  }

  void _openAssignedQuizzes() {
    if (widget.auth.current == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssignedQuizzesScreen(
            token: widget.auth.current!.token, lang: widget.currentLang),
      ),
    );
  }

  Future<void> _openWordSearch() async {
    final choice = await showWordSearchDifficultyPicker(context);
    if (choice == null || !mounted) return;
    final token = widget.auth.current?.token;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => choice.isDaily
            ? WordSearchScreen.daily(token: token)
            : WordSearchScreen(
                difficulty: choice.difficulty,
                category: choice.category,
                clueMode: choice.clueMode,
                token: token,
              ),
      ),
    );
  }

  void _openLeaderboard() {
    if (widget.auth.current == null) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LeaderboardScreen(token: widget.auth.current!.token)));
  }

  void _openAchievements(Profile profile) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AchievementsScreen(profile: profile)));
  }

  void _onNavTap(int index) {
    switch (index) {
      case 1:
        _openPracticeWithPicker();
        break;
      case 2:
        _openQuests();
        break;
      case 3:
        _openLeaderboard();
        break;
      case 4:
        _openProfile();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final name = widget.auth.current?.displayName ?? '';
    final profile = _profile ??
        Profile(
            displayName: name, totalXp: 0, streakDays: 0, recentMatches: []);
    final level = levelForXp(profile.totalXp);

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: _onNavTap,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_rounded), label: t.navHome),
          NavigationDestination(
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: t.navPractice),
          NavigationDestination(
              icon: const Icon(Icons.checklist_rounded), label: t.navLearn),
          NavigationDestination(
              icon: const Icon(Icons.leaderboard_rounded),
              label: t.navLeaderboard),
          NavigationDestination(
              icon: const Icon(Icons.person_rounded), label: t.navProfile),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isDesktop = width >= 900;
              final isTablet = width >= 600 && width < 900;
              final horizontalPadding =
                  isDesktop ? 48.0 : (isTablet ? 32.0 : 18.0);

              return FadeTransition(
                opacity: _fadeAnimation!,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeroHeader(context, t, name, profile, level),
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: isDesktop ? 900 : double.infinity),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalPadding, 18, horizontalPadding, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!_healthLoading && !_healthOk) ...[
                                  _buildConnectionError(t),
                                  const SizedBox(height: 20),
                                ],
                                // Highest-priority action first: playing with
                                // others is a full screen-width tap away,
                                // not buried in the Quick Play scroller below.
                                _buildMultiplayerCta(context, t),
                                const SizedBox(height: 24),
                                _sectionTitle(context, t.homeTodaysJourney),
                                const SizedBox(height: 12),
                                _buildJourney(context, t),
                                const SizedBox(height: 28),
                                if (!_profileLoading) ...[
                                  _buildDailyChallenge(context, t),
                                  const SizedBox(height: 28),
                                ],
                                _sectionTitle(context, t.homeQuickPlay),
                                const SizedBox(height: 12),
                                _buildQuickPlay(context, t),
                                const SizedBox(height: 28),
                                // Streak is already visible up in the hero
                                // header — this card adds the one thing that
                                // isn't shown there yet: progress to the next
                                // level.
                                RewardCard(
                                    totalXp: profile.totalXp,
                                    questsCompleted: const []),
                                const SizedBox(height: 28),
                                Row(
                                  children: [
                                    Expanded(
                                        child: _sectionTitle(
                                            context, t.profileAchievements)),
                                    TextButton(
                                      onPressed: () =>
                                          _openAchievements(profile),
                                      child: Text(t.homeSeeAll),
                                    ),
                                  ],
                                ),
                                _buildAchievements(context, t, profile),
                                const SizedBox(height: 20),
                                _buildDailyPhraseCard(context, t),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildHeroHeader(BuildContext context, AppLocalizations t, String name,
      Profile profile, LevelInfo level) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 600;

    // Hug the real status-bar/notch inset instead of a flat guess — a fixed
    // value either leaves a gap on phones with a short status bar or, worse,
    // sits under a taller one on others.
    final topPadding = media.padding.top + (isMobile ? 10.0 : 16.0);
    final avatarSize = isMobile ? 40.0 : 48.0;
    final logoutIconSize = isMobile ? 20.0 : 24.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: AppPalette.shadowInk,
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: GeometricPatternPainter(
                  color: AppPalette.mutedGold,
                  opacity: 0.14,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, topPadding, 18, isMobile ? 16 : 22),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BannerAvatar(name: name, size: avatarSize),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name.isEmpty ? t.appTitle : _greeting(t, name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: isMobile ? 17 : 19,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              LanguagePicker(
                  currentLanguage: widget.currentLang,
                  onLocaleChange: widget.onLocaleChange,
                  compact: isMobile),
              SizedBox(width: isMobile ? 2 : 6),
              IconButton(
                icon: Icon(Icons.logout,
                    color: colors.onPrimary, size: logoutIconSize),
                tooltip: t.signOut,
                onPressed: widget.onSignOut,
                visualDensity: isMobile ? VisualDensity.compact : null,
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: Icons.local_fire_department_rounded,
                  label: t.rewardStreakDays(profile.streakDays),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStat(
                  icon: Icons.stars_rounded,
                  label: t.levelWithTitle(level.level, level.title(t)),
                ),
              ),
            ],
          ),
        ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourney(BuildContext context, AppLocalizations t) {
    final options = categoryOptions(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
          child: FadeScrollEdge(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _JourneyStopCard(
                  option: options[i],
                  onTap: () => _openPractice(options[i].value)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => _openPractice('mixed'),
            icon: const ContinueArrowIcon(color: AppPalette.cardStock),
            label: Text(t.homeContinueLearning,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChallenge(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    Quest? quest;
    for (final q in _quests) {
      if (!q.completed) {
        quest = q;
        break;
      }
    }

    if (_quests.isEmpty) return const SizedBox.shrink();

    if (quest == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppPalette.shadowInk,
                blurRadius: 12,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.celebration_rounded,
                color: colors.onPrimary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                t.homeAllQuestsDone,
                style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

    final pct = quest.target == 0
        ? 0.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.cardStock,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.borderTaupe),
        boxShadow: [
          BoxShadow(
              color: AppPalette.shadowInk,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.bolt_rounded, color: colors.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.homeDailyChallenge,
                        style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Text(quest.description,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppPalette.mutedGoldMuted,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    t.questRewardXp(quest.rewardXp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppPalette.mutedGold,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: AppPalette.borderTaupe.withValues(alpha: 0.5),
                valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.mutedGold),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(t.questProgress(quest.progress, quest.target),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _openQuests,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(t.homePlayChallenge,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  /// The single highest-priority action on the home screen: a full-width,
  /// unmissable entry point into multiplayer, instead of it being one of
  /// three equally-weighted cards in a horizontal scroller further down.
  Widget _buildMultiplayerCta(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    // Below this width, icon + title/subtitle + button all crammed into one
    // Row leaves the text column only ~120dp — cramped and prone to awkward
    // wrapping. Stack instead: icon+text on top, a full-width button below.
    final stacked = MediaQuery.sizeOf(context).width < 400;

    final icon = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.groups_rounded, color: Colors.white, size: 28),
    );

    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.cardMultiplayerTitle,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        const SizedBox(height: 3),
        Text(
          t.cardMultiplayerSubtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              height: 1.3),
        ),
      ],
    );

    final playButton = Container(
      width: stacked ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.homePlayMultiplayer,
              style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, color: colors.primary, size: 17),
        ],
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: _openMultiplayer,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppPalette.shadowInk,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: 14),
                      Expanded(child: textBlock),
                    ],
                  ),
                  const SizedBox(height: 16),
                  playButton,
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: 14),
                  Expanded(child: textBlock),
                  const SizedBox(width: 12),
                  playButton,
                ],
              ),
      ),
    );
  }

  Widget _buildQuickPlay(BuildContext context, AppLocalizations t) {
    final items = <_QuickPlayItem>[
      _QuickPlayItem(
          icon: Icons.play_arrow_rounded,
          title: t.practice,
          subtitle: t.cardPracticeSubtitle,
          onTap: _openPracticeWithPicker),
      _QuickPlayItem(
        icon: Icons.assignment_turned_in_rounded,
        title: t.cardAssignedQuizzesTitle,
        subtitle: t.cardAssignedQuizzesSubtitle,
        onTap: _openAssignedQuizzes,
      ),
      _QuickPlayItem(
        icon: Icons.grid_on_rounded,
        title: t.wsQuickPlayTitle,
        subtitle: t.wsQuickPlaySubtitle,
        onTap: _openWordSearch,
      ),
    ];

    return SizedBox(
      height: 148,
      child: FadeScrollEdge(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _QuickPlayCard(item: items[i]),
        ),
      ),
    );
  }

  Widget _buildAchievements(
      BuildContext context, AppLocalizations t, Profile profile) {
    final achievements = achievementsFor(t, profile).take(6).toList();
    return SizedBox(
      height: 108,
      child: FadeScrollEdge(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: achievements.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) =>
              _AchievementChip(achievement: achievements[i]),
        ),
      ),
    );
  }

  Widget _buildDailyPhraseCard(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    final phrase = _dailyPhrases[_phraseIndex];

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(
          () => _phraseIndex = (_phraseIndex + 1) % _dailyPhrases.length),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.secondaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: colors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.homeDailyPhraseTitle,
                      style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    phrase.$1,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text(phrase.$2,
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            Column(
              children: [
                Icon(Icons.touch_app_rounded,
                    color: colors.onSurfaceVariant, size: 18),
                const SizedBox(height: 2),
                Text(t.homeDailyPhraseHint,
                    style: TextStyle(
                        color: colors.onSurfaceVariant, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionError(AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.incorrectRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.incorrectRed.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppPalette.incorrectRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.backendUnreachable,
                    style: const TextStyle(
                        color: AppPalette.incorrectRed, fontWeight: FontWeight.w700)),
                if (_healthError != null) ...[
                  const SizedBox(height: 4),
                  Text(_healthError!,
                      style:
                          TextStyle(color: AppPalette.incorrectRed, fontSize: 12)),
                ],
              ],
            ),
          ),
          TextButton(onPressed: _checkHealth, child: Text(t.retry)),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppPalette.cardStock,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.mutedGold, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppPalette.mutedGold, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppPalette.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyStopCard extends StatefulWidget {
  const _JourneyStopCard({required this.option, required this.onTap});
  final CategoryOption option;
  final VoidCallback onTap;

  @override
  State<_JourneyStopCard> createState() => _JourneyStopCardState();
}

class _JourneyStopCardState extends State<_JourneyStopCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: CardStock(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: SizedBox(
            width: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: AppPalette.deepTealMuted, shape: BoxShape.circle),
                  child: Image.asset(
                    option.iconAsset,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.category_rounded,
                        color: AppPalette.deepTeal),
                  ),
                ),
                const Spacer(),
                Text(
                  option.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppPalette.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  option.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppPalette.inkMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPlayItem {
  const _QuickPlayItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _QuickPlayCard extends StatelessWidget {
  const _QuickPlayCard({required this.item});
  final _QuickPlayItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: item.onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
                color: colors.shadow.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [colors.primary, colors.secondary]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.achievement});
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: unlocked ? AppPalette.mutedGold : AppPalette.cardStock,
        border: unlocked ? null : Border.all(color: AppPalette.borderTaupe),
        boxShadow: [
          BoxShadow(
              color: AppPalette.shadowInk,
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            unlocked ? achievement.icon : Icons.lock_rounded,
            color: unlocked ? AppPalette.ink : AppPalette.inkMuted,
            size: 22,
          ),
          const Spacer(),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppPalette.ink,
                fontWeight: FontWeight.w800,
                fontSize: 12.5),
          ),
          Text(
            achievement.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: unlocked
                    ? AppPalette.ink.withValues(alpha: 0.75)
                    : AppPalette.inkMuted,
                fontSize: 10.5),
          ),
        ],
      ),
    );
  }
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
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
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
