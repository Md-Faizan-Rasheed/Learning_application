import 'package:flutter/material.dart';

import '../api/campaign_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/card_stock.dart';

/// Pushed from MultiplayerScreen._handleCampaignProgress the moment a
/// campaign stage's momentum reaches its target. "Continue" is what
/// actually claims the XP reward — arriving here doesn't award it
/// automatically, so a player can see what they earned before it's granted.
class StageClearedScreen extends StatefulWidget {
  const StageClearedScreen({
    super.key,
    required this.token,
    required this.stageId,
    required this.progress,
    required this.target,
  });

  final String? token;
  final String stageId;
  final int progress;
  final int target;

  @override
  State<StageClearedScreen> createState() => _StageClearedScreenState();
}

class _StageClearedScreenState extends State<StageClearedScreen> {
  final CampaignApi _api = CampaignApi();
  bool _claiming = false;
  String? _error;

  Future<void> _continue() async {
    final token = widget.token;
    if (token == null) {
      Navigator.of(context)
        ..pop()
        ..pop();
      return;
    }
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      await _api.claimStageReward(token, widget.stageId);
      if (!mounted) return;
      Navigator.of(context)
        ..pop()
        ..pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CardStock(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            color: AppPalette.mutedGold, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          t.stageClearedTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.questProgress(widget.progress, widget.target),
                          style: TextStyle(color: AppPalette.inkMuted),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppPalette.incorrectRed, fontSize: 12.5)),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _claiming ? null : _continue,
                            child: _claiming
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  )
                                : Text(t.stageClearedContinue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
