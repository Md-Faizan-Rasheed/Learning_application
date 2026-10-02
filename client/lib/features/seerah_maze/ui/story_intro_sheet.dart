import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../constants/maze_constants.dart';
import '../constants/maze_destination_icons.dart';
import '../data/maze_audio_service.dart';
import '../data/maze_environments.dart';
import '../data/maze_levels.dart';
import '../models/maze_intro_scene.dart';
import '../models/maze_level.dart';
import '../painters/character_painter.dart';
import '../painters/intro_scene_painter.dart';
import 'responsive/maze_breakpoints.dart';

/// Where this level's optional voice-over narration clip would live, if
/// one has been recorded. Mirrors MazeAudioService's path convention
/// (relative to assets/, no leading "assets/") and its "missing file
/// means the feature stays silent" rule — see B3's "if an audio asset
/// exists for the level and language, show a play button; if not, hide
/// it."
String mazeNarrationAssetPath(int levelId, String languageCode) =>
    'sounds/maze/narration/level${levelId}_$languageCode.mp3';

/// Real existence probe: attempts to load the asset and reports whether
/// that succeeded, without holding onto the loaded bytes. Never thrown
/// into the UI — a missing asset is the expected, common case.
Future<bool> _defaultAssetExists(String assetPath) async {
  try {
    await rootBundle.load('assets/$assetPath');
    return true;
  } catch (_) {
    return false;
  }
}

/// Shows the pre-level story card. Resolves to `true` if the player taps
/// Start, or `null`/`false` if dismissed without starting.
///
/// [probeAssetExists] lets a test substitute a fake narration-asset check
/// instead of hitting the real asset bundle; production call sites never
/// pass it.
Future<bool?> showMazeStoryIntroSheet(
  BuildContext context,
  MazeLevel level, {
  Future<bool> Function(String assetPath)? probeAssetExists,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _StoryIntroContent(
      level: level,
      probeAssetExists: probeAssetExists ?? _defaultAssetExists,
    ),
  );
}

class _StoryIntroContent extends StatefulWidget {
  const _StoryIntroContent({required this.level, required this.probeAssetExists});

  final MazeLevel level;
  final Future<bool> Function(String assetPath) probeAssetExists;

  @override
  State<_StoryIntroContent> createState() => _StoryIntroContentState();
}

class _StoryIntroContentState extends State<_StoryIntroContent> with TickerProviderStateMixin {
  late final AnimationController _sceneController;
  late final AnimationController _typewriterController;
  Duration _sceneElapsed = Duration.zero;
  Duration? _lastSceneTick;

  bool _narrationAvailable = false;
  bool _narrationPlaying = false;
  bool _narrationLoading = false;
  AudioPlayer? _narrationPlayer;

  bool _reduceMotion = false;
  String _story = '';
  bool _narrationProbeStarted = false;

  @override
  void initState() {
    super.initState();
    // A plain per-frame ticker, not a meaningful 0..1 animation — the
    // scene painter needs an ever-increasing elapsed clock (rise-to-rest,
    // stars appearing one by one), so this reads lastElapsedDuration
    // diffs the same way maze_board.dart's cave lantern/ambient-field
    // clocks do, rather than relying on the controller's own wrapped
    // value.
    _sceneController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_onSceneTick)
      ..repeat();
    // Duration is set once the actual story text length is known — see
    // didChangeDependencies, which runs before the first real frame.
    _typewriterController = AnimationController(vsync: this)..addListener(() => setState(() {}));
  }

  void _onSceneTick() {
    if (_reduceMotion) return;
    final now = _sceneController.lastElapsedDuration ?? Duration.zero;
    final delta = _lastSceneTick == null ? Duration.zero : now - _lastSceneTick!;
    _lastSceneTick = now;
    setState(() => _sceneElapsed += delta);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = AppLocalizations.of(context)!;
    _story = mazeLevelTextFor(t, widget.level.id).story;
    _reduceMotion = MediaQuery.of(context).disableAnimations;

    // Localizations.localeOf(context) (inside _probeNarration) registers a
    // dependency on an inherited widget, which initState() isn't allowed
    // to do — didChangeDependencies is the right place for it, guarded so
    // the async probe only ever starts once.
    if (!_narrationProbeStarted) {
      _narrationProbeStarted = true;
      _probeNarration();
    }

    if (_typewriterController.duration == null) {
      final charCount = _story.characters.length;
      final charDuration = MazeConstants.introTypewriterCharDelay * charCount;
      _typewriterController.duration = charDuration > MazeConstants.introTypewriterMaxDuration
          ? MazeConstants.introTypewriterMaxDuration
          : (charDuration < MazeConstants.introTypewriterMinDuration
              ? MazeConstants.introTypewriterMinDuration
              : charDuration);
      if (_reduceMotion) {
        _typewriterController.value = 1;
      } else {
        _typewriterController.forward();
      }
    }
  }

  Future<void> _probeNarration() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final path = mazeNarrationAssetPath(widget.level.id, languageCode);
    final exists = await widget.probeAssetExists(path);
    if (mounted && exists) setState(() => _narrationAvailable = true);
  }

  @override
  void dispose() {
    _sceneController.dispose();
    _typewriterController.dispose();
    _narrationPlayer?.dispose();
    super.dispose();
  }

  void _skipReveal() {
    if (_typewriterController.value < 1) _typewriterController.value = 1;
  }

  Future<void> _toggleNarration() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final path = mazeNarrationAssetPath(widget.level.id, languageCode);
    if (_narrationPlaying) {
      await _narrationPlayer?.stop();
      if (mounted) setState(() => _narrationPlaying = false);
      return;
    }
    setState(() => _narrationLoading = true);
    try {
      final player = _narrationPlayer ??= AudioPlayer();
      player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _narrationPlaying = false);
      });
      await player.play(AssetSource(path));
      if (mounted) setState(() => _narrationPlaying = true);
    } catch (_) {
      // Per the class doc comment: a missing/corrupt clip stays silent,
      // never an error the player sees.
    } finally {
      if (mounted) setState(() => _narrationLoading = false);
    }
  }

  String _formatThreshold(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return minutes > 0 ? '$minutes:${seconds.toString().padLeft(2, '0')}' : '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final level = widget.level;
    final levelText = mazeLevelTextFor(t, level.id);
    final environment = mazeEnvironmentFor(level.id);
    final motif = mazeIntroSceneMotifFor(environment.id);

    final revealedChars = (_story.characters.length * _typewriterController.value)
        .round()
        .clamp(0, _story.characters.length);
    final revealedStory = _story.characters.take(revealedChars).toString();
    final isFullyRevealed = revealedChars >= _story.characters.length;

    return SafeArea(
      child: MazeResponsiveSheet(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: MazeColors.boardPanel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // B3 — the procedural animated scene, clipped to a fixed
              // height band so it reads as a "stage" behind the card
              // rather than taking over the whole sheet.
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: MazeConstants.introSceneHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: environment.backgroundGradient,
                          ),
                        ),
                        child: CustomPaint(
                          painter: IntroScenePainter(
                            motif: motif,
                            theme: environment,
                            t: _sceneElapsed.inMilliseconds / 1000,
                            reduceMotion: _reduceMotion,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 8,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: CustomPaint(
                            painter: CharacterPainter(
                              center: const Offset(22, 32),
                              cellSize: 80,
                              usesLightMarker: level.usesLightMarker,
                              bobOffset: 0,
                              scale: 1,
                              trail: const [],
                              shakeOffset: 0,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 8,
                        child: Icon(
                          mazeDestinationIconFor(level.destinationKind),
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 26,
                        ),
                      ),
                      if (_narrationAvailable)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Semantics(
                            button: true,
                            label: _narrationPlaying ? t.mazeNarrationStop : t.mazeNarrationPlay,
                            child: _NarrationButton(
                              playing: _narrationPlaying,
                              loading: _narrationLoading,
                              onTap: _toggleNarration,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${t.mazeLevelNumber(level.id)}: ${t.mazeLevelRoute(levelText.character, levelText.destination)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              // B3 — the typewriter reveal. Tapping anywhere on the story
              // text jumps straight to the full text ("skippable by tap").
              GestureDetector(
                key: const Key('mazeStorySkipArea'),
                onTap: _skipReveal,
                behavior: HitTestBehavior.opaque,
                child: Semantics(
                  liveRegion: true,
                  hint: isFullyRevealed ? null : t.mazeStorySkipHint,
                  child: Text(
                    isFullyRevealed ? _story : revealedStory,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _GoalChip(
                    icon: Icons.timer_rounded,
                    label: t.mazeGoalTimeChip(_formatThreshold(level.starTimeThreshold)),
                  ),
                  _GoalChip(
                    icon: Icons.star_rounded,
                    label: t.mazeGoalStarsChip(MazeConstants.collectibleStarCount),
                  ),
                  _GoalChip(
                    icon: Icons.emoji_events_rounded,
                    label: t.mazeGoalBothChip,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    MazeAudioService.instance.playButtonTap();
                    Navigator.of(context).pop(true);
                  },
                  child:
                      Text(t.mazeStartButton, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NarrationButton extends StatelessWidget {
  const _NarrationButton({required this.playing, required this.loading, required this.onTap});

  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.4),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 18,
              ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: colors.onSecondaryContainer)),
        ],
      ),
    );
  }
}
