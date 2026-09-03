import 'package:flutter/material.dart';

import '../../api/classroom_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key, required this.token});
  final String token;

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final ClassroomApi _api = ClassroomApi();
  final _codeController = TextEditingController();
  final _scrollController = ScrollController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final joined = await _api.joinClass(widget.token, code);
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.studentJoinSuccess(joined.className))));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppHeader(
          title: t.studentJoinClassTitle, scrollController: _scrollController),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary.withValues(alpha: 0.10),
              colors.surface,
              colors.secondary.withValues(alpha: 0.08)
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: AmbientBackdrop()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [colors.primary, colors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.28),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10)),
                            ],
                          ),
                          child: const Icon(Icons.group_add_rounded,
                              size: 42, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          t.studentJoinClassTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 28),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: colors.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _codeController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  textAlign: TextAlign.center,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 4,
                                      fontSize: 20),
                                  decoration: InputDecoration(
                                    labelText: t.studentJoinCodeHint,
                                    prefixIcon: const Icon(Icons.key_rounded),
                                    filled: true,
                                    fillColor: colors.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                          color: colors.primary, width: 2),
                                    ),
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colors.errorContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            color: colors.onErrorContainer),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                                color: colors.onErrorContainer,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: (_busy ||
                                            _codeController.text.trim().isEmpty)
                                        ? null
                                        : _join,
                                    icon: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(
                                            Icons.arrow_forward_rounded),
                                    label: Text(t.studentJoinBtn,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
