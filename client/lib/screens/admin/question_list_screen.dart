import 'package:flutter/material.dart';

import '../../api/admin_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_pill.dart';
import 'bulk_import_screen.dart';
import 'question_editor_screen.dart';

Color _difficultyColor(String difficulty) {
  switch (difficulty) {
    case 'easy':
      return Colors.green.shade700;
    case 'hard':
      return Colors.red.shade700;
    default:
      return Colors.amber.shade800;
  }
}

(StatusTone, IconData) _reviewStyle(String state) {
  switch (state) {
    case 'reviewed':
      return (StatusTone.info, Icons.fact_check_rounded);
    case 'live':
      return (StatusTone.success, Icons.public_rounded);
    default:
      return (StatusTone.neutral, Icons.edit_note_rounded);
  }
}

String _reviewLabel(AppLocalizations t, String state) {
  switch (state) {
    case 'reviewed':
      return t.adminReviewReviewed;
    case 'live':
      return t.adminReviewLive;
    default:
      return t.adminReviewDraft;
  }
}

class QuestionListScreen extends StatefulWidget {
  const QuestionListScreen({
    super.key,
    required this.token,
    required this.categories,
    this.initialCategoryId,
  });

  final String token;
  final List<AdminCategory> categories;
  final String? initialCategoryId;

  @override
  State<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionListScreen> {
  final AdminApi _api = AdminApi();
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<AdminQuestionListItem> _questions = [];
  String? _categoryId;
  String? _reviewState;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qs = await _api.listQuestions(
        widget.token,
        categoryId: _categoryId,
        reviewState: _reviewState,
        search: _searchController.text.trim(),
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

  String _categoryName(String id) {
    for (final c in widget.categories) {
      if (c.id == id) return c.displayName;
    }
    return '';
  }

  Future<void> _openBulkImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BulkImportScreen(token: widget.token)),
    );
    _load();
  }

  Future<void> _openEditor({String? questionId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(
          token: widget.token,
          categories: widget.categories,
          questionId: questionId,
          initialCategoryId: _categoryId,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppHeader(
        title: t.adminQuestionsTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: t.adminBulkImport,
            onPressed: _openBulkImport,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(t.adminNewQuestion),
      ),
      body: ScreenWithAmbientBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 12, horizontalPadding, 4),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            onSubmitted: (_) => _load(),
                            decoration: InputDecoration(
                              hintText: t.adminSearchHint,
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: colors.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              suffixIcon: IconButton(
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  onPressed: _load),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              DropdownButton<String?>(
                                hint: Text(t.adminAllCategories),
                                value: _categoryId,
                                items: [
                                  DropdownMenuItem(
                                      value: null,
                                      child: Text(t.adminAllCategories)),
                                  ...widget.categories.map((c) =>
                                      DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.displayName))),
                                ],
                                onChanged: (v) {
                                  setState(() => _categoryId = v);
                                  _load();
                                },
                              ),
                              DropdownButton<String?>(
                                hint: Text(t.adminAllStates),
                                value: _reviewState,
                                items: [
                                  DropdownMenuItem(
                                      value: null,
                                      child: Text(t.adminAllStates)),
                                  DropdownMenuItem(
                                      value: 'draft',
                                      child: Text(t.adminReviewDraft)),
                                  DropdownMenuItem(
                                      value: 'reviewed',
                                      child: Text(t.adminReviewReviewed)),
                                  DropdownMenuItem(
                                      value: 'live',
                                      child: Text(t.adminReviewLive)),
                                ],
                                onChanged: (v) {
                                  setState(() => _reviewState = v);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: _loading
                          ? LoadingView(
                              message: t.adminQuestionsTitle,
                              icon: Icons.quiz_rounded)
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_error!),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                          onPressed: _load,
                                          child: Text(t.retry)),
                                    ],
                                  ),
                                )
                              : _questions.isEmpty
                                  ? Center(child: Text(t.adminNoQuestions))
                                  : RefreshIndicator(
                                      onRefresh: _load,
                                      child: ListView.separated(
                                        padding: EdgeInsets.fromLTRB(
                                            horizontalPadding,
                                            8,
                                            horizontalPadding,
                                            88),
                                        itemCount: _questions.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, i) {
                                          final q = _questions[i];
                                          final diffColor =
                                              _difficultyColor(q.difficulty);
                                          final style =
                                              _reviewStyle(q.reviewState);
                                          return InkWell(
                                            onTap: () =>
                                                _openEditor(questionId: q.id),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: colors.surface,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color:
                                                        colors.outlineVariant),
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: colors.shadow
                                                          .withValues(
                                                              alpha: 0.05),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 3)),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                        color: diffColor
                                                            .withValues(
                                                                alpha: 0.15),
                                                        shape: BoxShape.circle),
                                                    child: Icon(
                                                        Icons
                                                            .help_outline_rounded,
                                                        color: diffColor,
                                                        size: 18),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          q.promptPreview,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700),
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        Wrap(
                                                          spacing: 8,
                                                          runSpacing: 4,
                                                          crossAxisAlignment:
                                                              WrapCrossAlignment
                                                                  .center,
                                                          children: [
                                                            StatusPill(
                                                                label: _reviewLabel(
                                                                    t,
                                                                    q.reviewState),
                                                                tone: style.$1,
                                                                icon: style.$2),
                                                            Text(
                                                              _categoryName(
                                                                  q.categoryId),
                                                              style: TextStyle(
                                                                  color: colors
                                                                      .onSurfaceVariant,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                      Icons
                                                          .chevron_right_rounded,
                                                      color: colors
                                                          .onSurfaceVariant),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
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
}
