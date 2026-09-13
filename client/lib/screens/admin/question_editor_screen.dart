import 'package:flutter/material.dart';

import '../../api/admin_api.dart';
import '../../api/game_api.dart' show ApiException;
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/option_tile.dart';

const _difficulties = ['easy', 'medium', 'hard'];
const _langs = [
  ('en', 'English'),
  ('ur', 'اردو'),
  ('ar', 'العربية'),
];
const _maxOptions = 8;

Color _difficultyColor(String difficulty) {
  switch (difficulty) {
    case 'easy':
      return AppPalette.deepTeal;
    case 'hard':
      return AppPalette.incorrectRed;
    default:
      return AppPalette.mutedGold;
  }
}

class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({
    super.key,
    required this.token,
    required this.categories,
    this.questionId,
    this.initialCategoryId,
  });

  final String token;
  final List<AdminCategory> categories;
  final String? questionId;
  final String? initialCategoryId;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  final AdminApi _api = AdminApi();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _reviewState;

  String? _categoryId;
  String _difficulty = 'medium';
  final Map<String, TextEditingController> _promptControllers = {
    for (final l in _langs) l.$1: TextEditingController(),
  };
  final Map<String, List<TextEditingController>> _optionControllers = {
    for (final l in _langs)
      l.$1: [TextEditingController(), TextEditingController()],
  };
  int _correctIndex = 0;
  final _scrollController = ScrollController();

  bool get _isEditing => widget.questionId != null;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    if (_isEditing) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    for (final c in _promptControllers.values) {
      c.dispose();
    }
    for (final list in _optionControllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = await _api.getQuestion(widget.token, widget.questionId!);
      setState(() {
        _categoryId = q.categoryId;
        _difficulty = q.difficulty;
        _reviewState = q.reviewState;
        _correctIndex = q.correctIndex;
        for (final l in _langs) {
          _promptControllers[l.$1]!.text = q.prompt[l.$1] ?? '';
          final opts = q.options[l.$1] ?? const <String>[];
          final controllers = _optionControllers[l.$1]!;
          for (final c in controllers) {
            c.dispose();
          }
          controllers.clear();
          for (final o in opts) {
            controllers.add(TextEditingController(text: o));
          }
          while (controllers.length < 2) {
            controllers.add(TextEditingController());
          }
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _optionCount => _optionControllers['en']!.length;

  void _addOption() {
    setState(() {
      for (final l in _langs) {
        _optionControllers[l.$1]!.add(TextEditingController());
      }
    });
  }

  void _removeOptionAt(int i) {
    setState(() {
      for (final l in _langs) {
        _optionControllers[l.$1]!.removeAt(i).dispose();
      }
      if (_correctIndex == i) {
        _correctIndex = 0;
      } else if (_correctIndex > i) {
        _correctIndex -= 1;
      }
      if (_correctIndex >= _optionCount) {
        _correctIndex = _optionCount - 1;
      }
    });
  }

  bool get _canSave =>
      !_saving &&
      _categoryId != null &&
      _promptControllers.values.every((c) => c.text.trim().isNotEmpty) &&
      _optionControllers.values
          .every((list) => list.every((c) => c.text.trim().isNotEmpty));

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final prompt = {
      for (final l in _langs) l.$1: _promptControllers[l.$1]!.text.trim()
    };
    final options = {
      for (final l in _langs)
        l.$1: [for (final c in _optionControllers[l.$1]!) c.text.trim()],
    };
    try {
      if (_isEditing) {
        await _api.updateQuestion(
          widget.token,
          widget.questionId!,
          categoryId: _categoryId,
          difficulty: _difficulty,
          prompt: prompt,
          options: options,
          correctIndex: _correctIndex,
        );
      } else {
        await _api.createQuestion(
          widget.token,
          categoryId: _categoryId!,
          difficulty: _difficulty,
          prompt: prompt,
          options: options,
          correctIndex: _correctIndex,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _setReviewState(String state) async {
    if (!_isEditing) return;
    try {
      await _api.reviewQuestion(widget.token, widget.questionId!, state);
      setState(() => _reviewState = state);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.adminDeleteConfirmTitle),
        content: Text(t.adminDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.incorrectRed),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.adminDeleteQuestion),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteQuestion(widget.token, widget.questionId!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      final message = (e is ApiException && e.statusCode == 409)
          ? t.adminDeleteInUseError
          : e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _openPreview() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: DefaultTabController(
            length: _langs.length,
            child: Column(
              children: [
                const SizedBox(height: 8),
                TabBar(tabs: [for (final l in _langs) Tab(text: l.$2)]),
                Expanded(
                  child: TabBarView(children: [
                    for (final l in _langs) _buildPreviewTab(l.$1)
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                          MaterialLocalizations.of(context).closeButtonLabel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTab(String lang) {
    final direction = lang == 'en' ? TextDirection.ltr : TextDirection.rtl;
    return Directionality(
      textDirection: direction,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _promptControllers[lang]!.text,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            for (int j = 0; j < _optionCount; j++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OptionTile(
                  text: _optionControllers[lang]![j].text,
                  selected: false,
                  state: j == _correctIndex
                      ? OptionState.correct
                      : OptionState.neutral,
                  onTap: null,
                ),
              ),
          ],
        ),
      ),
    );
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
        title: _isEditing ? t.adminEditQuestionTitle : t.adminNewQuestion,
        scrollController: _loading ? null : _scrollController,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_rounded),
            tooltip: t.adminPreview,
            onPressed: _loading ? null : _openPreview,
          ),
          if (_isEditing)
            IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: t.adminDeleteQuestion,
                onPressed: _delete),
        ],
      ),
      body: ScreenWithAmbientBackdrop(
        child: _loading
            ? LoadingView(
                message: t.adminEditQuestionTitle, icon: Icons.quiz_rounded)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth >= 600 ? 32.0 : 16.0;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 16, horizontalPadding, 32),
                        children: [
                          if (_isEditing) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _reviewActionChip(t.adminMarkDraft, 'draft',
                                    Icons.edit_note_rounded),
                                _reviewActionChip(t.adminMarkReviewed,
                                    'reviewed', Icons.fact_check_rounded),
                                _reviewActionChip(t.adminPublishLive, 'live',
                                    Icons.public_rounded),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],
                          DropdownButtonFormField<String>(
                            initialValue: _categoryId,
                            decoration: _fieldDecoration(context,
                                label: t.teacherCategory,
                                icon: Icons.category_rounded),
                            items: widget.categories
                                .map((c) => DropdownMenuItem(
                                    value: c.id, child: Text(c.displayName)))
                                .toList(),
                            onChanged: (v) => setState(() => _categoryId = v),
                          ),
                          const SizedBox(height: 14),
                          Text(t.teacherDifficulty,
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final d in _difficulties)
                                ChoiceChip(
                                  label: Text(d),
                                  selected: _difficulty == d,
                                  selectedColor: _difficultyColor(d)
                                      .withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _difficulty == d
                                        ? _difficultyColor(d)
                                        : colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _difficulty = d),
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          for (final l in _langs) ...[
                            _buildLanguageSection(context, t, l.$1, l.$2),
                            const SizedBox(height: 16),
                          ],
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: colors.errorContainer,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color: colors.onErrorContainer),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(_error!,
                                          style: TextStyle(
                                              color: colors.onErrorContainer))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _canSave ? _save : null,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _isEditing ? t.adminSave : t.adminCreateBtn,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _reviewActionChip(String label, String state, IconData icon) {
    final selected = _reviewState == state;
    final colors = Theme.of(context).colorScheme;
    return ActionChip(
      avatar:
          Icon(icon, size: 16, color: selected ? Colors.white : colors.primary),
      label: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : colors.primary,
              fontWeight: FontWeight.w700)),
      backgroundColor:
          selected ? colors.primary : colors.primary.withValues(alpha: 0.1),
      onPressed: () => _setReviewState(state),
    );
  }

  Widget _buildLanguageSection(
      BuildContext context, AppLocalizations t, String lang, String label) {
    final colors = Theme.of(context).colorScheme;
    final direction = lang == 'en' ? TextDirection.ltr : TextDirection.rtl;
    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(label,
                    style: TextStyle(
                        color: colors.secondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _promptControllers[lang],
            onChanged: (_) => setState(() {}),
            textDirection: direction,
            decoration: _fieldDecoration(context,
                label: t.teacherCustomPromptHint(label)),
          ),
          const SizedBox(height: 10),
          for (int j = 0; j < _optionCount; j++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Radio<int>(
                    value: j,
                    groupValue: _correctIndex,
                    activeColor: AppPalette.correctGold,
                    onChanged: (v) => setState(() => _correctIndex = v ?? 0),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[lang]![j],
                      onChanged: (_) => setState(() {}),
                      textDirection: direction,
                      decoration: InputDecoration(
                        hintText: t.teacherCustomOptionHint(j + 1, label),
                        isDense: true,
                        filled: true,
                        fillColor: j == _correctIndex
                            ? AppPalette.correctGold.withValues(alpha: 0.12)
                            : colors.surfaceContainerHighest
                                .withValues(alpha: 0.25),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: j == _correctIndex
                              ? const BorderSide(color: AppPalette.correctGold)
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (_optionCount > 2)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _removeOptionAt(j),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _optionCount >= _maxOptions ? null : _addOption,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.teacherAddOption),
            ),
          ),
        ],
      ),
    );
  }
}
