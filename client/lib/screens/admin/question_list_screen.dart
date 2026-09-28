import 'package:flutter/material.dart';

import '../../api/admin_api.dart';
import '../../l10n/app_localizations.dart';
import 'stage_link_dialog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_pill.dart';
import 'bulk_import_screen.dart';
import 'question_editor_screen.dart';

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
  static const _pageSize = 100;

  final AdminApi _api = AdminApi();
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<AdminQuestionListItem> _questions = [];
  int _totalCount = 0;
  String? _categoryId;
  String? _reviewState;
  // null = all; otherwise "untagged" | "orphaned" | "linked" — see
  // AdminQuestionListItem.tagStatus.
  String? _tagStatus;
  _AdminQuestionSummary? _summary;
  List<CampaignStageOption> _stages = [];
  List<SeerahEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    _load();
    _loadSummary();
    _loadStages();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Resets to page one — called on first load and whenever a filter
  /// changes. Fetches the first page and the total count for the current
  /// filters together, since list_questions alone is always capped at
  /// _pageSize rows and can't say how many more exist beyond that.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final search = _searchController.text.trim();
      final results = await Future.wait([
        _api.listQuestions(
          widget.token,
          categoryId: _categoryId,
          reviewState: _reviewState,
          search: search,
          tagStatus: _tagStatus,
          limit: _pageSize,
          offset: 0,
        ),
        _api.countQuestions(
          widget.token,
          categoryId: _categoryId,
          reviewState: _reviewState,
          search: search,
          tagStatus: _tagStatus,
        ),
      ]);
      setState(() {
        _questions = results[0] as List<AdminQuestionListItem>;
        _totalCount = results[1] as int;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _questions.length >= _totalCount) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _api.listQuestions(
        widget.token,
        categoryId: _categoryId,
        reviewState: _reviewState,
        search: _searchController.text.trim(),
        tagStatus: _tagStatus,
        limit: _pageSize,
        offset: _questions.length,
      );
      setState(() {
        _questions = [..._questions, ...more];
        _loadingMore = false;
      });
    } catch (e) {
      setState(() => _loadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// A fixed, app-wide overview — deliberately independent of the active
  /// category/state/tagging filters above, so it always answers "how many
  /// questions do we have overall" regardless of what's currently filtered.
  /// Seven small counts, each a separate call to the same count endpoint
  /// the filtered list already uses; failures here are non-fatal — the
  /// panel just stays hidden rather than blocking the question list itself.
  Future<void> _loadSummary() async {
    try {
      final results = await Future.wait([
        _api.countQuestions(widget.token),
        _api.countQuestions(widget.token, reviewState: 'live'),
        _api.countQuestions(widget.token, reviewState: 'draft'),
        _api.countQuestions(widget.token, reviewState: 'reviewed'),
        _api.countQuestions(widget.token, tagStatus: 'untagged'),
        _api.countQuestions(widget.token, tagStatus: 'orphaned'),
        _api.countQuestions(widget.token, tagStatus: 'linked'),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = _AdminQuestionSummary(
          total: results[0],
          live: results[1],
          draft: results[2],
          reviewed: results[3],
          untagged: results[4],
          orphaned: results[5],
          linked: results[6],
        );
      });
    } catch (_) {
      // Non-fatal — see doc comment above.
    }
  }

  /// Feeds the stage-link dialog's picker — loaded once, independent of the
  /// question list/filters. Non-fatal on error: the link action just stays
  /// unavailable rather than blocking the question list itself.
  Future<void> _loadStages() async {
    try {
      final stages = await _api.listCampaignStages(widget.token);
      if (!mounted) return;
      setState(() => _stages = stages);
    } catch (_) {
      // Non-fatal — see doc comment above.
    }
  }

  /// Feeds the tag-and-link dialog's event picker — same data source as the
  /// editor's Seerah-event dropdown. Non-fatal on error, same as _loadStages.
  Future<void> _loadEvents() async {
    try {
      final events = await _api.listSeerahEvents(widget.token);
      if (!mounted) return;
      setState(() => _events = events);
    } catch (_) {
      // Non-fatal — see doc comment above.
    }
  }

  /// Tapped from a question row's tag/stage pill. An untagged question gets
  /// the combined "pick an event, then a stage" dialog; an already-tagged
  /// one (orphaned or linked) goes straight to the stage picker.
  Future<void> _openTagOrLink(AdminQuestionListItem q) async {
    final lang = Localizations.localeOf(context).languageCode;
    final changed = q.eventId == null
        ? await showTagAndLinkDialog(
            context,
            token: widget.token,
            questionId: q.id,
            events: _events,
            stages: _stages,
            lang: lang,
          )
        : await showStageLinkDialog(
            context,
            token: widget.token,
            eventId: q.eventId!,
            currentStageSlug: q.stageSlug,
            stages: _stages,
            lang: lang,
          );
    if (changed && mounted) {
      final t = AppLocalizations.of(context)!;
      await Future.wait([_load(), _loadSummary()]);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.adminLinkStageSuccess)));
      }
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
    _loadSummary();
  }

  /// Same idea as the teacher panel's "Import with AI", but the result
  /// lands as a public draft bank row (see AdminApi.aiImportQuestions)
  /// instead of a private per-teacher question — no separate confirm step
  /// is needed since the normal draft/reviewed/live pipeline already
  /// covers that.
  Future<void> _openAiImport() async {
    final imported = await showModalBottomSheet<List<AdminAiImportedQuestion>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _AdminAiImportSheet(
        token: widget.token,
        categories: widget.categories,
        events: _events,
        initialCategoryId: _categoryId,
      ),
    );
    if (imported == null || imported.isEmpty) return;
    await Future.wait([_load(), _loadSummary()]);
    if (!mounted) return;
    final t = AppLocalizations.of(context)!;
    final needsReview = imported.where((q) => q.note != null).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          needsReview > 0
              ? t.adminAiImportSuccessWithReview(imported.length, needsReview)
              : t.adminAiImportSuccess(imported.length),
        ),
      ),
    );
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
    _loadSummary();
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
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: t.teacherImportWithAi,
            onPressed: _openAiImport,
          ),
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
                          if (_summary != null) ...[
                            _SummaryRow(summary: _summary!),
                            const SizedBox(height: 12),
                          ],
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
                              // Which questions still need a real, working
                              // campaign tag — "orphaned" is tagged to an
                              // event with no stage link, so it's exactly
                              // as invisible to campaign play as untagged.
                              DropdownButton<String?>(
                                hint: Text(t.adminAllTagging),
                                value: _tagStatus,
                                items: [
                                  DropdownMenuItem(
                                      value: null,
                                      child: Text(t.adminAllTagging)),
                                  DropdownMenuItem(
                                      value: 'untagged',
                                      child: Text(t.adminNotTaggedOnly)),
                                  DropdownMenuItem(
                                      value: 'orphaned',
                                      child: Text(t.adminTagOrphaned)),
                                  DropdownMenuItem(
                                      value: 'linked',
                                      child: Text(t.adminTagLinked)),
                                ],
                                onChanged: (v) {
                                  setState(() => _tagStatus = v);
                                  _load();
                                },
                              ),
                            ],
                          ),
                          if (!_loading && _error == null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                t.adminQuestionsShownCount(
                                    _questions.length, _totalCount),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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
                                      onRefresh: () =>
                                          Future.wait([_load(), _loadSummary()]),
                                      child: ListView.separated(
                                        padding: EdgeInsets.fromLTRB(
                                            horizontalPadding,
                                            8,
                                            horizontalPadding,
                                            88),
                                        itemCount: _questions.length +
                                            (_questions.length < _totalCount
                                                ? 1
                                                : 0),
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, i) {
                                          if (i >= _questions.length) {
                                            return Center(
                                              child: Padding(
                                                padding: const EdgeInsets
                                                    .symmetric(vertical: 8),
                                                child: _loadingMore
                                                    ? const SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2),
                                                      )
                                                    : OutlinedButton(
                                                        onPressed: _loadMore,
                                                        child: Text(
                                                            t.adminLoadMoreQuestions(
                                                                _totalCount -
                                                                    _questions
                                                                        .length)),
                                                      ),
                                              ),
                                            );
                                          }
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
                                                            StageLinkChip(
                                                              tagStatus:
                                                                  q.tagStatus,
                                                              stageSlug: q
                                                                  .stageSlug,
                                                              stages: _stages,
                                                              lang: Localizations
                                                                      .localeOf(
                                                                          context)
                                                                  .languageCode,
                                                              onTap: () =>
                                                                  _openTagOrLink(
                                                                      q),
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

/// App-wide question counts — see _QuestionListScreenState._loadSummary.
class _AdminQuestionSummary {
  const _AdminQuestionSummary({
    required this.total,
    required this.live,
    required this.draft,
    required this.reviewed,
    required this.untagged,
    required this.orphaned,
    required this.linked,
  });

  final int total;
  final int live;
  final int draft;
  final int reviewed;
  final int untagged;
  // Tagged to an event with no campaign-stage link — invisible to campaign
  // play despite having event_id set. See content/repository.py's
  // _TAG_STATUS_EXPR for exactly how this is computed.
  final int orphaned;
  final int linked;
}

/// A compact row of stat chips summarizing the whole question bank —
/// independent of whatever filters are currently active below it.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final _AdminQuestionSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Same three tones StatusPill already uses everywhere else on this
        // screen (success/info -> primary, neutral -> onSurfaceVariant,
        // warning -> mutedGold) — Untagged/Orphaned reuse the exact warning
        // color the per-row badges below use for those same two states.
        _StatChip(label: t.adminSummaryTotal, count: summary.total, color: colors.onSurfaceVariant),
        _StatChip(label: t.adminReviewLive, count: summary.live, color: colors.primary),
        _StatChip(label: t.adminReviewDraft, count: summary.draft, color: colors.onSurfaceVariant),
        _StatChip(label: t.adminReviewReviewed, count: summary.reviewed, color: colors.primary),
        _StatChip(label: t.adminTagLinked, count: summary.linked, color: colors.primary),
        _StatChip(
            label: t.adminTagOrphaned, count: summary.orphaned, color: AppPalette.mutedGold),
        _StatChip(
            label: t.adminNotTaggedOnly, count: summary.untagged, color: AppPalette.mutedGold),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

/// A modal sheet where an admin pastes freeform text (any format) and an
/// LLM extracts it into structured draft questions — the admin-panel
/// counterpart of teacher/quiz_builder_screen.dart's _AiImportSheet. Unlike
/// that one, results are inserted straight into the public bank (as
/// 'draft') rather than returned for local review, so this sheet just
/// reports what the API already created.
class _AdminAiImportSheet extends StatefulWidget {
  const _AdminAiImportSheet({
    required this.token,
    required this.categories,
    required this.events,
    this.initialCategoryId,
  });

  final String token;
  final List<AdminCategory> categories;
  final List<SeerahEvent> events;
  final String? initialCategoryId;

  @override
  State<_AdminAiImportSheet> createState() => _AdminAiImportSheetState();
}

class _AdminAiImportSheetState extends State<_AdminAiImportSheet> {
  final AdminApi _api = AdminApi();
  final _textController = TextEditingController();
  String? _categoryId;
  String? _eventId;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String? get _selectedCategorySlug {
    for (final c in widget.categories) {
      if (c.id == _categoryId) return c.slug;
    }
    return null;
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
        eventId: _selectedCategorySlug == 'seerah' ? _eventId : null,
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
    final lang = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              const SizedBox(height: 6),
              Text(
                t.adminAiImportBody,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
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
                onChanged: (v) => setState(() {
                  _categoryId = v;
                  _eventId = null;
                }),
              ),
              if (_selectedCategorySlug == 'seerah') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _eventId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t.adminSeerahEventLabel,
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(t.adminSeerahEventNone),
                    ),
                    for (final e in widget.events)
                      DropdownMenuItem<String?>(
                        value: e.id,
                        child: Text(e.nameFor(lang), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _eventId = v),
                ),
              ],
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
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
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
                      Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: colors.onErrorContainer))),
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
