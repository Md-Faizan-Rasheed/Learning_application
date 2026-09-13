import 'package:flutter/material.dart';

import '../api/contributions_api.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_backdrop.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_pill.dart';

const _maxOptions = 8;

(StatusTone, IconData) _statusStyle(String reviewState) {
  switch (reviewState) {
    case 'reviewed':
      return (StatusTone.info, Icons.fact_check_rounded);
    case 'live':
      return (StatusTone.success, Icons.check_circle_rounded);
    default:
      return (StatusTone.neutral, Icons.hourglass_top_rounded);
  }
}

String _statusLabel(AppLocalizations t, String reviewState) {
  switch (reviewState) {
    case 'reviewed':
      return t.contributeStatusReviewed;
    case 'live':
      return t.contributeStatusApproved;
    default:
      return t.contributeStatusPending;
  }
}

class ContributeScreen extends StatefulWidget {
  const ContributeScreen({super.key, required this.token});
  final String token;

  @override
  State<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends State<ContributeScreen> {
  final ContributionsApi _api = ContributionsApi();

  bool _loading = true;
  String? _loadError;
  List<PublicCategory> _categories = [];
  List<Contribution> _mine = [];

  String? _categoryId;
  final _promptController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController()
  ];
  int _correctIndex = 0;
  bool _submitting = false;
  String? _submitError;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _promptController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _api.listCategories(widget.token),
        _api.listMine(widget.token),
      ]);
      setState(() {
        _categories = results[0] as List<PublicCategory>;
        _mine = results[1] as List<Contribution>;
        _categoryId ??= _categories.isNotEmpty ? _categories.first.id : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  void _addOption() =>
      setState(() => _optionControllers.add(TextEditingController()));

  void _removeOptionAt(int i) {
    setState(() {
      _optionControllers.removeAt(i).dispose();
      if (_correctIndex == i) {
        _correctIndex = 0;
      } else if (_correctIndex > i) {
        _correctIndex -= 1;
      }
      if (_correctIndex >= _optionControllers.length) {
        _correctIndex = _optionControllers.length - 1;
      }
    });
  }

  bool get _canSubmit =>
      !_submitting &&
      _categoryId != null &&
      _promptController.text.trim().isNotEmpty &&
      _optionControllers.every((c) => c.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final t = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await _api.submit(
        widget.token,
        categoryId: _categoryId!,
        prompt: _promptController.text.trim(),
        options: [for (final c in _optionControllers) c.text.trim()],
        correctIndex: _correctIndex,
      );
      _promptController.clear();
      for (final c in _optionControllers) {
        c.dispose();
      }
      _optionControllers
        ..clear()
        ..addAll([TextEditingController(), TextEditingController()]);
      _correctIndex = 0;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.contributeSubmitSuccess)));
      }
      await _load();
    } catch (e) {
      setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration(BuildContext context,
      {required String label, IconData? icon}) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primary, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppHeader(
          title: t.contributeTitle,
          scrollController: (_loading || _loadError != null)
              ? null
              : _scrollController),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
            child: _loading
                ? LoadingView(
                    message: t.contributeTitle, icon: Icons.edit_note_rounded)
                : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: _load, child: Text(t.retry)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final horizontalPadding =
                              constraints.maxWidth >= 600 ? 32.0 : 16.0;
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: ListView(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(horizontalPadding,
                                    16, horizontalPadding, 32),
                                children: [
                                  Text(t.contributeIntro,
                                      style: TextStyle(
                                          color: colors.onSurfaceVariant)),
                                  const SizedBox(height: 18),
                                  DropdownButtonFormField<String>(
                                    initialValue: _categoryId,
                                    decoration: _fieldDecoration(context,
                                        label: t.teacherCategory,
                                        icon: Icons.category_rounded),
                                    items: _categories
                                        .map((c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(c.displayName)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _categoryId = v),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _promptController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: _fieldDecoration(context,
                                        label: t.teacherQuestionHint,
                                        icon: Icons.help_outline_rounded),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    t.teacherSelectCorrectHint,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: colors.onSurfaceVariant),
                                  ),
                                  const SizedBox(height: 4),
                                  for (int j = 0;
                                      j < _optionControllers.length;
                                      j++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: Row(
                                        children: [
                                          Radio<int>(
                                            value: j,
                                            groupValue: _correctIndex,
                                            activeColor: AppPalette.correctGold,
                                            onChanged: (v) => setState(
                                                () => _correctIndex = v ?? 0),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: _optionControllers[j],
                                              onChanged: (_) => setState(() {}),
                                              decoration: InputDecoration(
                                                hintText:
                                                    t.teacherOptionHint(j + 1),
                                                isDense: true,
                                                filled: true,
                                                fillColor: j == _correctIndex
                                                    ? AppPalette.correctGold
                                                        .withValues(alpha: 0.08)
                                                    : colors
                                                        .surfaceContainerHighest
                                                        .withValues(
                                                            alpha: 0.25),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: j == _correctIndex
                                                      ? const BorderSide(
                                                          color: AppPalette.correctGold)
                                                      : BorderSide.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_optionControllers.length > 2)
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 18),
                                              onPressed: () =>
                                                  _removeOptionAt(j),
                                            ),
                                        ],
                                      ),
                                    ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _optionControllers.length >=
                                              _maxOptions
                                          ? null
                                          : _addOption,
                                      icon: const Icon(Icons.add_rounded,
                                          size: 18),
                                      label: Text(t.teacherAddOption),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_submitError != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: colors.errorContainer,
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline_rounded,
                                              color: colors.onErrorContainer),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(_submitError!,
                                                  style: TextStyle(
                                                      color: colors
                                                          .onErrorContainer))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  SizedBox(
                                    height: 52,
                                    child: FilledButton.icon(
                                      onPressed: _canSubmit ? _submit : null,
                                      icon: _submitting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white),
                                            )
                                          : const Icon(Icons.send_rounded),
                                      label: Text(t.contributeSubmitBtn,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(t.contributeMySubmissions,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 10),
                                  if (_mine.isEmpty)
                                    Text(t.contributeNoSubmissions,
                                        style: TextStyle(
                                            color: colors.onSurfaceVariant))
                                  else
                                    for (final c in _mine) ...[
                                      _MySubmissionTile(contribution: c),
                                      const SizedBox(height: 8),
                                    ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MySubmissionTile extends StatelessWidget {
  const _MySubmissionTile({required this.contribution});
  final Contribution contribution;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final style = _statusStyle(contribution.reviewState);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              contribution.promptFor('en'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          StatusPill(
              label: _statusLabel(t, contribution.reviewState),
              tone: style.$1,
              icon: style.$2),
        ],
      ),
    );
  }
}
