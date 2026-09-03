import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api/admin_api.dart' show AdminCategory;
import '../api/content_api.dart';
import '../api/social_api.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/category_options.dart';
import '../widgets/loading_view.dart';
import 'practice_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen(
      {super.key,
      required this.token,
      required this.myUserId,
      required this.appName});

  final String token;
  final String myUserId;
  final String appName;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final SocialApi _api = SocialApi();

  bool _loading = true;
  String? _error;
  String? _myCode;
  List<Friend> _friends = [];
  List<IncomingRequest> _requests = [];
  List<Challenge> _challenges = [];

  final _codeController = TextEditingController();
  bool _sendingRequest = false;
  String? _addFriendError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.myFriendCode(widget.token),
        _api.myFriends(widget.token),
        _api.incomingRequests(widget.token),
        _api.myChallenges(widget.token),
      ]);
      setState(() {
        _myCode = results[0] as String;
        _friends = results[1] as List<Friend>;
        _requests = results[2] as List<IncomingRequest>;
        _challenges = results[3] as List<Challenge>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _sendingRequest = true;
      _addFriendError = null;
    });
    try {
      await _api.sendFriendRequest(widget.token, code);
      _codeController.clear();
      if (mounted) setState(() => _sendingRequest = false);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _addFriendError = e.toString();
          _sendingRequest = false;
        });
      }
    }
  }

  Future<void> _respond(IncomingRequest r, bool accept) async {
    try {
      await _api.respondToRequest(widget.token, r.id, accept);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _removeFriend(Friend f) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.friendsRemoveTitle),
        content: Text(t.friendsRemoveBody(f.displayName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.friendsRemoveConfirm)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.removeFriend(widget.token, f.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _startChallenge(Friend friend) async {
    final t = AppLocalizations.of(context)!;
    final picked = await showModalBottomSheet<(String, int)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _ChallengeSetupSheet(friend: friend, t: t, token: widget.token),
    );
    if (picked == null || !mounted) return;
    final (category, questionCount) = picked;

    try {
      final challenge = await _api.createChallenge(
        widget.token,
        opponentId: friend.id,
        category: category,
        questionCount: questionCount,
      );
      if (!mounted) return;
      await _playChallenge(challenge);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _playChallenge(Challenge c) async {
    final t = AppLocalizations.of(context)!;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(
          lang: t.localeName,
          category: c.category,
          challengeId: c.id,
          questionCount: c.questionCount,
          token: widget.token,
          myUserId: widget.myUserId,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _shareCode(AppLocalizations t) {
    final code = _myCode;
    if (code == null) return;
    Share.share(t.friendsShareCodeText(widget.appName, code));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppHeader(
          title: t.friendsTitle,
          bottom: TabBar(tabs: [
            Tab(text: t.friendsTabFriends),
            Tab(text: t.friendsTabChallenges)
          ]),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: AmbientBackdrop()),
            SafeArea(
              child: _loading
                  ? LoadingView(
                      message: t.friendsLoading, icon: Icons.people_alt_rounded)
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                FilledButton(
                                    onPressed: _load, child: Text(t.retry)),
                              ],
                            ),
                          ),
                        )
                      : TabBarView(
                          children: [
                            _buildFriendsTab(context, t),
                            _buildChallengesTab(context, t),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, 16, horizontalPadding, 32),
            children: [
              _buildMyCodeCard(context, t),
              const SizedBox(height: 20),
              Text(t.friendsAddTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: t.friendsAddHint,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sendingRequest ? null : _sendRequest,
                    child: Text(_sendingRequest ? '…' : t.friendsAddBtn),
                  ),
                ],
              ),
              if (_addFriendError != null) ...[
                const SizedBox(height: 8),
                Text(_addFriendError!,
                    style: TextStyle(color: colors.error, fontSize: 13)),
              ],
              if (_requests.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(t.friendsRequestsTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final r in _requests)
                  _RequestTile(
                      request: r,
                      onAccept: () => _respond(r, true),
                      onDecline: () => _respond(r, false)),
              ],
              const SizedBox(height: 24),
              Text(t.friendsListTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (_friends.isEmpty)
                Text(t.friendsEmpty,
                    style: TextStyle(color: colors.onSurfaceVariant))
              else
                for (final f in _friends)
                  _FriendTile(
                      friend: f,
                      onChallenge: () => _startChallenge(f),
                      onRemove: () => _removeFriend(f)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyCodeCard(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.friendsMyCodeTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            _myCode ?? '',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white)),
                  onPressed: () {
                    final code = _myCode;
                    if (code == null) return;
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.friendsCodeCopied)));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(t.friendsCopyCode),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white)),
                  onPressed: () => _shareCode(t),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(t.share),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesTab(BuildContext context, AppLocalizations t) {
    final colors = Theme.of(context).colorScheme;
    final myTurn = _challenges
        .where((c) => c.status == 'pending' && c.myTurnToPlay(widget.myUserId))
        .toList();
    final waiting = _challenges
        .where((c) => c.status == 'pending' && !c.myTurnToPlay(widget.myUserId))
        .toList();
    final completed =
        _challenges.where((c) => c.status == 'completed').toList();

    if (_challenges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.challengesEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, 16, horizontalPadding, 32),
            children: [
              if (myTurn.isNotEmpty) ...[
                Text(t.challengesYourTurn,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final c in myTurn)
                  _ChallengeTile(
                      challenge: c,
                      myUserId: widget.myUserId,
                      onTap: () => _playChallenge(c)),
                const SizedBox(height: 20),
              ],
              if (waiting.isNotEmpty) ...[
                Text(t.challengesWaiting,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final c in waiting)
                  _ChallengeTile(
                      challenge: c, myUserId: widget.myUserId, onTap: null),
                const SizedBox(height: 20),
              ],
              if (completed.isNotEmpty) ...[
                Text(t.challengesCompleted,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                for (final c in completed)
                  _ChallengeTile(
                      challenge: c, myUserId: widget.myUserId, onTap: null),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(
      {required this.request, required this.onAccept, required this.onDecline});
  final IncomingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(request.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            onPressed: onAccept,
            icon:
                Icon(Icons.check_circle_rounded, color: Colors.green.shade600),
          ),
          IconButton(
            onPressed: onDecline,
            icon: Icon(Icons.cancel_rounded, color: colors.error),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile(
      {required this.friend,
      required this.onChallenge,
      required this.onRemove});
  final Friend friend;
  final VoidCallback onChallenge;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  t.friendsXpAndStreak(friend.totalXp, friend.streakDays),
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.friendsChallengeBtn,
            onPressed: onChallenge,
            icon: Icon(Icons.sports_kabaddi_rounded, color: colors.primary),
          ),
          IconButton(
            tooltip: t.friendsRemoveConfirm,
            onPressed: onRemove,
            icon: Icon(Icons.person_remove_rounded,
                color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile(
      {required this.challenge, required this.myUserId, required this.onTap});
  final Challenge challenge;
  final String myUserId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final iAmChallenger = challenge.challengerId == myUserId;
    final opponentName =
        iAmChallenger ? challenge.opponentName : challenge.challengerName;

    String subtitle;
    if (challenge.status == 'pending') {
      subtitle = onTap != null
          ? t.challengesTapToPlay
          : t.challengeWaitingOn(opponentName);
    } else if (challenge.winnerId == null) {
      subtitle = t.challengeTied;
    } else if (challenge.winnerId == myUserId) {
      subtitle = t.challengeYouWon(opponentName);
    } else {
      subtitle = t.challengeYouLost(opponentName);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.outlineVariant)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opponentName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.play_circle_fill_rounded, color: colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeSetupSheet extends StatefulWidget {
  const _ChallengeSetupSheet(
      {required this.friend, required this.t, required this.token});
  final Friend friend;
  final AppLocalizations t;
  final String token;

  @override
  State<_ChallengeSetupSheet> createState() => _ChallengeSetupSheetState();
}

class _ChallengeSetupSheetState extends State<_ChallengeSetupSheet> {
  String _category = 'mixed';
  int _questionCount = 8;
  late final Future<List<AdminCategory>?> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = ContentApi()
        .listCategories(widget.token)
        .then<List<AdminCategory>?>((v) => v)
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.challengeSetupTitle(widget.friend.displayName),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<AdminCategory>?>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }
              final options = resolveCategoryOptions(t, snapshot.data);
              if (!options.any((o) => o.value == _category)) {
                _category = options.first.value;
              }
              return DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: t.friendsChallengeCategory,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                items: [
                  for (final o in options)
                    DropdownMenuItem(value: o.value, child: Text(o.title))
                ],
                onChanged: (v) => setState(() => _category = v ?? 'mixed'),
              );
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _questionCount,
            decoration: InputDecoration(
              labelText: t.friendsChallengeQuestionCount,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: const [5, 8, 10]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (v) => setState(() => _questionCount = v ?? 8),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, (_category, _questionCount)),
            icon: const Icon(Icons.sports_kabaddi_rounded),
            label: Text(t.friendsChallengeBtn),
          ),
        ],
      ),
    );
  }
}
