import 'package:flutter/material.dart';

import '../../api/teacher_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';

const _difficulties = ['easy', 'medium', 'hard'];
const _maxOptions = 8;

Color _difficultyColor(String difficulty, ColorScheme colors) {
  switch (difficulty) {
    case 'easy':
      return Colors.green.shade700;
    case 'hard':
      return Colors.red.shade700;
    default:
      return Colors.amber.shade800;
  }
}

/// One question in the quiz being built — either an already-created bank
/// question (read-only, just an id + preview), a locally-drafted custom
/// question that isn't sent to the server until "Create quiz" is pressed,
/// or an AI-imported draft (also already created server-side, like a bank
/// question, but starts unconfirmed and blocks quiz publish until reviewed).
class _QuestionBlock {
  _QuestionBlock.bank(TeacherQuestion q)
      : bankQuestion = q,
        draft = null,
        isAiDraft = false,
        aiNote = null,
        confirmed = true;
  _QuestionBlock.custom()
      : bankQuestion = null,
        draft = _CustomDraft(),
        isAiDraft = false,
        aiNote = null,
        confirmed = true;
  _QuestionBlock.aiDraft(TeacherQuestion q, {String? note})
      : bankQuestion = q,
        draft = null,
        isAiDraft = true,
        aiNote = note,
        confirmed = false;

  final TeacherQuestion? bankQuestion;
  final _CustomDraft? draft;
  final bool isAiDraft;
  final String? aiNote;
  bool confirmed;

  // AI drafts already exist server-side with a real id, exactly like a bank
  // pick, so they deliberately share this getter — it drives "already has an
  // id, nothing to create()" logic, not "came from the bank picker".
  bool get isBank => bankQuestion != null;

  void dispose() => draft?.dispose();
}

/// A single-language question being authored inline, Google-Forms style:
/// one prompt, a growable list of options, one marked correct.
class _CustomDraft {
  final promptController = TextEditingController();
  final List<TextEditingController> optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int correctIndex = 0;

  void addOption() => optionControllers.add(TextEditingController());

  void removeOptionAt(int i) {
    optionControllers.removeAt(i).dispose();
    if (correctIndex == i) {
      correctIndex = 0;
    } else if (correctIndex > i) {
      correctIndex -= 1;
    }
    if (correctIndex >= optionControllers.length) {
      correctIndex = optionControllers.length - 1;
    }
  }

  bool get isValid =>
      promptController.text.trim().isNotEmpty &&
      optionControllers.every((c) => c.text.trim().isNotEmpty);

  void dispose() {
    promptController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}

class QuizBuilderScreen extends StatefulWidget {
  const QuizBuilderScreen(
      {super.key, required this.token, required this.classId});
  final String token;
  final String classId;

  @override
  State<QuizBuilderScreen> createState() => _QuizBuilderScreenState();
}

class _QuizBuilderScreenState extends State<QuizBuilderScreen> {
  final TeacherApi _api = TeacherApi();

  final _titleController = TextEditingController();
  final _timeLimitController = TextEditingController(text: '20');
  final _scrollController = ScrollController();

  bool _creating = false;
  String? _error;

  final List<_QuestionBlock> _blocks = [];
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeLimitController.dispose();
    _scrollController.dispose();
    for (final b in _blocks) {
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.listCategories(widget.token);
      setState(() => _categories = cats);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _addCustomQuestion() =>
      setState(() => _blocks.add(_QuestionBlock.custom()));

  void _removeBlock(int i) {
    setState(() {
      _blocks[i].dispose();
      _blocks.removeAt(i);
    });
  }

  Future<void> _openBankPicker() async {
    final picked = await showModalBottomSheet<List<TeacherQuestion>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _BankPickerSheet(
        token: widget.token,
        categories: _categories,
        alreadyAdded: _blocks
            .where((b) => b.isBank)
            .map((b) => b.bankQuestion!.id)
            .toSet(),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final q in picked) {
        _blocks.add(_QuestionBlock.bank(q));
      }
    });
  }

  Future<void> _openAiImport() async {
    final imported = await showModalBottomSheet<List<AiImportedQuestion>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) =>
          _AiImportSheet(token: widget.token, categories: _categories),
    );
    if (imported == null || imported.isEmpty) return;
    setState(() {
      for (final q in imported) {
        _blocks.add(_QuestionBlock.aiDraft(q.question, note: q.note));
      }
    });
  }

  Future<void> _confirmAiDraft(int i) async {
    final b = _blocks[i];
    try {
      await _api.confirmQuestion(widget.token, b.bankQuestion!.id);
      setState(() => b.confirmed = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  bool get _canCreate =>
      !_creating &&
      _titleController.text.trim().isNotEmpty &&
      _blocks.isNotEmpty &&
      _blocks.every((b) => b.isBank || b.draft!.isValid) &&
      _categories.isNotEmpty;

  Future<void> _createQuiz() async {
    if (!_canCreate) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final categoryId = _categories.first.id;
      final questionIds = <String>[];
      for (final b in _blocks) {
        if (b.isBank) {
          questionIds.add(b.bankQuestion!.id);
        } else {
          final d = b.draft!;
          final q = await _api.createQuestion(
            widget.token,
            categoryId: categoryId,
            prompt: d.promptController.text.trim(),
            options: [for (final c in d.optionControllers) c.text.trim()],
            correctIndex: d.correctIndex,
          );
          questionIds.add(q.id);
        }
      }
      final seconds = int.tryParse(_timeLimitController.text.trim()) ?? 20;
      await _api.createQuiz(
        widget.token,
        title: _titleController.text.trim(),
        classId: widget.classId,
        timeLimitMs: seconds * 1000,
        questionIds: questionIds,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _creating = false;
      });
    }
  }

  InputDecoration _fieldDecoration(BuildContext context,
      {required String label, required IconData icon, String? suffixText}) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      prefixIcon: Icon(icon),
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
          title: t.teacherQuizBuilderTitle,
          scrollController: _scrollController),
      body: ScreenWithAmbientBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 16, horizontalPadding, 32),
                  children: [
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      decoration: _fieldDecoration(context,
                          label: t.teacherQuizTitleHint,
                          icon: Icons.edit_note_rounded),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _timeLimitController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(context,
                          label: t.teacherTimeLimitLabel,
                          icon: Icons.timer_rounded,
                          suffixText: 's'),
                    ),
                    const SizedBox(height: 22),
                    if (_blocks.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: colors.outlineVariant,
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.quiz_outlined,
                                size: 40, color: colors.onSurfaceVariant),
                            const SizedBox(height: 10),
                            Text(
                              t.teacherNoQuestionsYet,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    else
                      for (int i = 0; i < _blocks.length; i++) ...[
                        _buildBlockCard(context, t, i),
                        const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _addCustomQuestion,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(t.teacherAddQuestion),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _categories.isEmpty ? null : _openBankPicker,
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: Text(t.teacherAddFromBank),
                        ),
                        OutlinedButton.icon(
                          onPressed: _categories.isEmpty ? null : _openAiImport,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(t.teacherImportWithAi),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                        onPressed: _canCreate ? _createQuiz : null,
                        icon: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.rocket_launch_rounded),
                        label: Text(t.teacherCreateQuizBtn,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
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

  Widget _buildBlockCard(BuildContext context, AppLocalizations t, int i) {
    final colors = Theme.of(context).colorScheme;
    final b = _blocks[i];

    if (b.isAiDraft) {
      final q = b.bankQuestion!;
      final badgeColor = b.confirmed ? Colors.green : Colors.amber.shade800;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  b.confirmed ? colors.outlineVariant : Colors.amber.shade400),
          boxShadow: [
            BoxShadow(
                color: colors.shadow.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child:
                  Icon(Icons.auto_awesome_rounded, color: badgeColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.promptFor('en'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (b.aiNote != null) ...[
                    const SizedBox(height: 4),
                    Text(b.aiNote!,
                        style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          b.confirmed
                              ? t.teacherAiConfirmed
                              : t.teacherAiNeedsReview,
                          style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11),
                        ),
                      ),
                      if (!b.confirmed) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0)),
                          onPressed: () => _confirmAiDraft(i),
                          child: Text(t.teacherAiConfirm,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: t.teacherRemoveQuestion,
              onPressed: () => _removeBlock(i),
            ),
          ],
        ),
      );
    }

    if (b.isBank) {
      final q = b.bankQuestion!;
      final diffColor = _difficultyColor(q.difficulty, colors);
      return Container(
        padding: const EdgeInsets.all(12),
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child:
                  Icon(Icons.inventory_2_rounded, color: diffColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.promptFor('en'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(t.teacherFromBankBadge,
                        style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: t.teacherRemoveQuestion,
              onPressed: () => _removeBlock(i),
            ),
          ],
        ),
      );
    }

    final d = b.draft!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [colors.primary, colors.secondary]),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: d.promptController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t.teacherQuestionHint,
                    filled: true,
                    fillColor:
                        colors.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: t.teacherRemoveQuestion,
                onPressed: () => _removeBlock(i),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.teacherSelectCorrectHint,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          for (int j = 0; j < d.optionControllers.length; j++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Radio<int>(
                    value: j,
                    groupValue: d.correctIndex,
                    activeColor: Colors.green,
                    onChanged: (v) => setState(() => d.correctIndex = v ?? 0),
                  ),
                  Expanded(
                    child: TextField(
                      controller: d.optionControllers[j],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: t.teacherOptionHint(j + 1),
                        isDense: true,
                        filled: true,
                        fillColor: j == d.correctIndex
                            ? Colors.green.withValues(alpha: 0.08)
                            : colors.surfaceContainerHighest
                                .withValues(alpha: 0.25),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: j == d.correctIndex
                              ? const BorderSide(color: Colors.green)
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (d.optionControllers.length > 2)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => d.removeOptionAt(j)),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: d.optionControllers.length >= _maxOptions
                  ? null
                  : () => setState(d.addOption),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.teacherAddOption),
            ),
          ),
        ],
      ),
    );
  }
}

/// A modal sheet for browsing/filter the public bank and checking off
/// questions to import into the quiz being built.
class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({
    required this.token,
    required this.categories,
    required this.alreadyAdded,
  });

  final String token;
  final List<Category> categories;
  final Set<String> alreadyAdded;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final TeacherApi _api = TeacherApi();
  bool _loading = true;
  String? _error;
  List<TeacherQuestion> _questions = [];
  String? _categoryId;
  String? _difficulty;
  final Set<String> _checked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final qs = await _api.listBankQuestions(
        widget.token,
        categoryId: _categoryId,
        difficulty: _difficulty,
      );
      setState(() {
        _questions = qs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.teacherBankPickerTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: () {
                      final picked = _questions
                          .where((q) => _checked.contains(q.id))
                          .toList();
                      Navigator.of(context).pop(picked);
                    },
                    child: Text(t.teacherDone),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  DropdownButton<String?>(
                    hint: Text(t.teacherCategory),
                    value: _categoryId,
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(t.catMixedTitle)),
                      ...widget.categories.map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.displayName))),
                    ],
                    onChanged: (v) {
                      setState(() => _categoryId = v);
                      _load();
                    },
                  ),
                  DropdownButton<String?>(
                    hint: Text(t.teacherDifficulty),
                    value: _difficulty,
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(t.catMixedTitle)),
                      ..._difficulties.map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: _difficultyColor(d, colors),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(d),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _difficulty = v);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _questions.isEmpty
                          ? Center(child: Text(t.teacherNoQuestionsYet))
                          : ListView.builder(
                              controller: scrollController,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: _questions.length,
                              itemBuilder: (context, i) {
                                final q = _questions[i];
                                final locked =
                                    widget.alreadyAdded.contains(q.id);
                                final diffColor =
                                    _difficultyColor(q.difficulty, colors);
                                return CheckboxListTile(
                                  value: locked || _checked.contains(q.id),
                                  onChanged: locked
                                      ? null
                                      : (v) {
                                          setState(() {
                                            if (v == true) {
                                              _checked.add(q.id);
                                            } else {
                                              _checked.remove(q.id);
                                            }
                                          });
                                        },
                                  title: Text(q.promptFor('en'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  secondary: Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                        color: diffColor,
                                        shape: BoxShape.circle),
                                  ),
                                  subtitle: Text(q.difficulty,
                                      style: TextStyle(
                                          color: diffColor,
                                          fontWeight: FontWeight.w600)),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}

/// A modal sheet where the teacher pastes freeform text (any format) and an
/// LLM extracts it into structured draft questions, returned to the builder
/// to add as unconfirmed `_QuestionBlock.aiDraft` blocks.
class _AiImportSheet extends StatefulWidget {
  const _AiImportSheet({required this.token, required this.categories});

  final String token;
  final List<Category> categories;

  @override
  State<_AiImportSheet> createState() => _AiImportSheetState();
}

class _AiImportSheetState extends State<_AiImportSheet> {
  final TeacherApi _api = TeacherApi();
  final _textController = TextEditingController();
  String? _categoryId;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) _categoryId = widget.categories.first.id;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_categoryId == null || _textController.text.trim().isEmpty) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final imported = await _api.aiImportQuestions(
        widget.token,
        categoryId: _categoryId!,
        text: _textController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(imported);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _importing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text(t.teacherAiImportTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                  labelText: t.teacherCategory,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
                items: widget.categories
                    .map((c) => DropdownMenuItem(
                        value: c.id, child: Text(c.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                minLines: 8,
                maxLines: 14,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: t.teacherAiPasteHint,
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
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
                              style:
                                  TextStyle(color: colors.onErrorContainer))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: (_importing ||
                          _categoryId == null ||
                          _textController.text.trim().isEmpty)
                      ? null
                      : _import,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(t.teacherAiImportBtn,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
