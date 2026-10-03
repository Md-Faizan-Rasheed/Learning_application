import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../constants/maze_colors.dart';
import '../data/maze_audio_service.dart';
import '../logic/achievements/character_skin_text.dart';
import '../models/maze_character_skin.dart';
import '../models/maze_progress.dart';
import 'responsive/maze_breakpoints.dart';

/// D3 — lets the player pick among the cosmetic skins they've unlocked
/// so far (see models/maze_character_skin.dart). Purely cosmetic: picking
/// a skin never changes anything about how a level plays. Resolves with
/// the (possibly updated) [MazeProgress], same "edit a local copy, return
/// it on close" shape as pause_menu.dart's settings toggles.
Future<MazeProgress> showMazeCustomizeSheet(
  BuildContext context, {
  required MazeProgress progress,
  required int explorerLevel,
}) async {
  final result = await showModalBottomSheet<MazeProgress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CustomizeSheetContent(
      initialProgress: progress,
      explorerLevel: explorerLevel,
    ),
  );
  return result ?? progress;
}

class _CustomizeSheetContent extends StatefulWidget {
  const _CustomizeSheetContent({required this.initialProgress, required this.explorerLevel});

  final MazeProgress initialProgress;
  final int explorerLevel;

  @override
  State<_CustomizeSheetContent> createState() => _CustomizeSheetContentState();
}

class _CustomizeSheetContentState extends State<_CustomizeSheetContent> {
  late MazeProgress _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
  }

  void _select(MazeCharacterSkinDef def) {
    if (widget.explorerLevel < def.unlockLevel) return;
    MazeAudioService.instance.playButtonTap();
    setState(() => _progress = _progress.copyWith(selectedSkin: def.id));
  }

  void _close() {
    MazeAudioService.instance.playButtonTap();
    Navigator.of(context).pop(_progress);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SafeArea(
      child: MazeResponsiveSheet(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(
            color: MazeColors.boardPanel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.mazeCustomizeScreenTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              for (final def in kMazeCharacterSkins) ...[
                _SkinTile(
                  def: def,
                  name: mazeCharacterSkinNameFor(t, def.id),
                  unlocked: widget.explorerLevel >= def.unlockLevel,
                  selected: _progress.selectedSkin == def.id,
                  onTap: () => _select(def),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _close,
                  child: Text(t.mazeLibraryCloseButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.def,
    required this.name,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final MazeCharacterSkinDef def;
  final String name;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final dim = unlocked ? 1.0 : 0.45;
    return Semantics(
      button: unlocked,
      label: unlocked
          ? (selected ? '$name. ${t.mazeSkinSelectedSemantics}.' : name)
          : '$name. ${t.mazeSkinLockedAtLevel(def.unlockLevel)}.',
      excludeSemantics: true,
      child: InkWell(
        onTap: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? MazeColors.star.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? MazeColors.star : MazeColors.boardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: def.fillColor.withValues(alpha: dim),
                  shape: BoxShape.circle,
                  border: Border.all(color: def.trailColor.withValues(alpha: dim), width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: dim),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!unlocked)
                Text(
                  t.mazeSkinLockedAtLevel(def.unlockLevel),
                  style: TextStyle(color: Colors.white.withValues(alpha: dim), fontSize: 11),
                )
              else if (selected)
                const Icon(Icons.check_circle_rounded, color: MazeColors.star, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
