import 'package:flutter/material.dart';

import '../../api/teacher_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_pill.dart';
import 'quiz_builder_screen.dart';
import 'quiz_results_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen(
      {super.key, required this.token, required this.classId});
  final String token;
  final String classId;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final TeacherApi _api = TeacherApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  TeacherClassDetail? _detail;
  List<TeacherQuiz> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.getClass(widget.token, widget.classId);
      final allQuizzes = await _api.listQuizzes(widget.token);
      setState(() {
        _detail = detail;
        _quizzes =
            allQuizzes.where((q) => q.classId == widget.classId).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _publish(TeacherQuiz quiz) async {
    try {
      await _api.publishQuiz(widget.token, quiz.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _statusLabel(AppLocalizations t, String status) {
    switch (status) {
      case 'published':
        return t.teacherStatusPublished;
      case 'closed':
        return t.teacherStatusClosed;
      default:
        return t.teacherStatusDraft;
    }
  }

  (StatusTone, IconData) _statusStyle(String status) {
    switch (status) {
      case 'published':
        return (StatusTone.success, Icons.public_rounded);
      case 'closed':
        return (StatusTone.warning, Icons.lock_rounded);
      default:
        return (StatusTone.neutral, Icons.edit_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        appBar: AppHeader(title: ''),
        body: LoadingView(
            message: t.teacherQuizzesTitle, icon: Icons.groups_rounded),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppHeader(title: ''),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(t.retry)),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppHeader(
          title: detail.name, scrollController: _scrollController),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => QuizBuilderScreen(
                      token: widget.token, classId: widget.classId),
                ),
              )
              .then((_) => _load());
        },
        icon: const Icon(Icons.add),
        label: Text(t.teacherCreateQuiz),
      ),
      body: ScreenWithAmbientBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
            return RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 16, horizontalPadding, 88),
                    children: [
                      // Invite-code panel.
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [colors.primary, colors.secondary],
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: colors.primary.withValues(alpha: 0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.teacherJoinCodeLabel.toUpperCase(),
                                    style: TextStyle(
                                      color: colors.onPrimary
                                          .withValues(alpha: 0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    detail.joinCode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_alt_rounded,
                                          size: 15,
                                          color: colors.onPrimary
                                              .withValues(alpha: 0.85)),
                                      const SizedBox(width: 4),
                                      Text(
                                        t.teacherStudentsCount(
                                            detail.students.length),
                                        style: TextStyle(
                                            color: colors.onPrimary
                                                .withValues(alpha: 0.85),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.key_rounded,
                                  color: Colors.white, size: 26),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(t.teacherQuizzesTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (_quizzes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(t.teacherNoQuizzes),
                        )
                      else
                        for (final q in _quizzes) ...[
                          _QuizRow(
                            quiz: q,
                            statusLabel: _statusLabel(t, q.status),
                            statusStyle: _statusStyle(q.status),
                            onPublish:
                                q.status == 'draft' ? () => _publish(q) : null,
                            onViewResults: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => QuizResultsScreen(
                                      token: widget.token, quizId: q.id),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  const _QuizRow({
    required this.quiz,
    required this.statusLabel,
    required this.statusStyle,
    required this.onPublish,
    required this.onViewResults,
  });

  final TeacherQuiz quiz;
  final String statusLabel;
  final (StatusTone, IconData) statusStyle;
  final VoidCallback? onPublish;
  final VoidCallback onViewResults;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

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
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.quiz_rounded, color: colors.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quiz.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                        label: statusLabel,
                        tone: statusStyle.$1,
                        icon: statusStyle.$2),
                    Text(t.teacherQuestionCount(quiz.questionCount),
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 2,
            children: [
              if (onPublish != null)
                TextButton(onPressed: onPublish, child: Text(t.teacherPublish)),
              TextButton(
                  onPressed: onViewResults, child: Text(t.teacherViewResults)),
            ],
          ),
        ],
      ),
    );
  }
}
