import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/category_picker_dialog.dart';
import 'multiplayer_screen.dart';

const _kRoomSeatChoices = [4, 6, 8];

/// Landing screen for "Multiplayer" — choose quick matchmaking against
/// whoever else is looking for a game, or create/join a private room with
/// real friends via a short invite code.
class MultiplayerChoiceScreen extends StatelessWidget {
  const MultiplayerChoiceScreen({
    super.key,
    required this.lang,
    required this.name,
    required this.token,
  });

  final String lang;
  final String name;
  final String token;

  Future<void> _quickMatch(BuildContext context) async {
    final category = await showCategoryPicker(context, token: token);
    if (category == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiplayerScreen(
          lang: lang,
          name: name,
          token: token,
          category: category,
        ),
      ),
    );
  }

  Future<void> _createRoom(BuildContext context) async {
    final category = await showCategoryPicker(context, token: token);
    if (category == null || !context.mounted) return;
    final maxSeats = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _CreateRoomSheet(category: category),
    );
    if (maxSeats == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiplayerScreen(
          lang: lang,
          name: name,
          token: token,
          category: category,
          mode: MultiplayerMode.hostRoom,
          maxSeats: maxSeats,
        ),
      ),
    );
  }

  Future<void> _joinRoom(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => const _JoinRoomDialog(),
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiplayerScreen(
          lang: lang,
          name: name,
          token: token,
          mode: MultiplayerMode.joinRoom,
          roomCode: code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppHeader(title: t.mpChoiceTitle),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ChoiceCard(
                        icon: Icons.bolt_rounded,
                        title: t.mpChoiceQuickMatch,
                        subtitle: t.mpChoiceQuickMatchSubtitle,
                        colors: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
                        onTap: () => _quickMatch(context),
                      ),
                      const SizedBox(height: 14),
                      _ChoiceCard(
                        icon: Icons.add_circle_rounded,
                        title: t.mpChoiceCreateRoom,
                        subtitle: t.mpChoiceCreateRoomSubtitle,
                        colors: const [Color(0xFF16A34A), Color(0xFF0D9488)],
                        onTap: () => _createRoom(context),
                      ),
                      const SizedBox(height: 14),
                      _ChoiceCard(
                        icon: Icons.meeting_room_rounded,
                        title: t.mpChoiceJoinRoom,
                        subtitle: t.mpChoiceJoinRoomSubtitle,
                        colors: const [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        onTap: () => _joinRoom(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: colors.surface,
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRoomSheet extends StatefulWidget {
  const _CreateRoomSheet({required this.category});
  final String category;

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  int _maxSeats = 4;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.mpCreateRoomTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Text(
            t.mpMaxSeatsLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: [
              for (final n in _kRoomSeatChoices)
                ButtonSegment(value: n, label: Text('$n')),
            ],
            selected: {_maxSeats},
            onSelectionChanged: (s) => setState(() => _maxSeats = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _maxSeats),
            icon: const Icon(Icons.add_circle_rounded),
            label: Text(t.mpCreateRoomTitle),
          ),
        ],
      ),
    );
  }
}

class _JoinRoomDialog extends StatefulWidget {
  const _JoinRoomDialog();

  @override
  State<_JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<_JoinRoomDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(t.mpJoinRoomTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 6,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: t.mpJoinRoomCodeHint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.authCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(t.mpJoinRoomButton),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
