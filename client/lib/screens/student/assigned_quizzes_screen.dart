import 'package:flutter/material.dart';

import '../../api/classroom_api.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_pill.dart';
import 'join_class_screen.dart';
import 'teacher_quiz_screen.dart';

class AssignedQuizzesScreen extends StatefulWidget {
  const AssignedQuizzesScreen(
      {super.key, required this.token, required this.lang});
  final String token;
  final String lang;

  @override
  State<AssignedQuizzesScreen> createState() => _AssignedQuizzesScreenState();
}

class _AssignedQuizzesScreenState extends State<AssignedQuizzesScreen> {
  final ClassroomApi _api = ClassroomApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  List<AssignedQuiz> _quizzes = [];

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
      final quizzes = await _api.listAssignedQuizzes(widget.token);
      setState(() {
        _quizzes = quizzes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _statusLabel(AppLocalizations t, String status) {
    switch (status) {
      case 'in_progress':
        return t.teacherStatusInProgress;
      case 'completed':
        return t.teacherStatusCompleted;
      default:
        return t.teacherStatusNotStarted;
    }
  }

  (StatusTone, IconData) _statusStyle(String status) {
    switch (status) {
      case 'in_progress':
        return (StatusTone.info, Icons.hourglass_top_rounded);
      case 'completed':
        return (StatusTone.success, Icons.check_circle_rounded);
      default:
        return (StatusTone.neutral, Icons.play_circle_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
        title: t.studentAssignedQuizzesTitle,
        scrollController: (_loading || _error != null || _quizzes.isEmpty)
            ? null
            : _scrollController,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(
                  builder: (_) => JoinClassScreen(token: widget.token)))
              .then((_) => _load());
        },
        icon: const Icon(Icons.group_add),
        label: Text(t.studentJoinAClass),
      ),
      body: ScreenWithAmbientBackdrop(
        child: _loading
            ? LoadingView(
                message: t.studentAssignedQuizzesTitle,
                icon: Icons.assignment_rounded)
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: Text(t.retry)),
                      ],
                    ),
                  )
                : _quizzes.isEmpty
                    ? Center(child: Text(t.studentNoQuizzes))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final horizontalPadding =
                              constraints.maxWidth >= 600 ? 32.0 : 16.0;
                          return RefreshIndicator(
                            onRefresh: _load,
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 900),
                                child: ListView.separated(
                                  controller: _scrollController,
                                  padding: EdgeInsets.fromLTRB(
                                      horizontalPadding,
                                      16,
                                      horizontalPadding,
                                      88),
                                  itemCount: _quizzes.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final q = _quizzes[i];
                                    final done = q.attemptStatus == 'completed';
                                    final style = _statusStyle(q.attemptStatus);
                                    return _QuizCard(
                                      quiz: q,
                                      statusLabel:
                                          _statusLabel(t, q.attemptStatus),
                                      statusStyle: style,
                                      done: done,
                                      onTap: done
                                          ? null
                                          : () {
                                              Navigator.of(context)
                                                  .push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          TeacherQuizScreen(
                                                        token: widget.token,
                                                        quizId: q.quizId,
                                                        lang: widget.lang,
                                                      ),
                                                    ),
                                                  )
                                                  .then((_) => _load());
                                            },
                                    );
                                  },
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

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.quiz,
    required this.statusLabel,
    required this.statusStyle,
    required this.done,
    required this.onTap,
  });

  final AssignedQuiz quiz;
  final String statusLabel;
  final (StatusTone, IconData) statusStyle;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surface, colors.surfaceContainerHighest],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
                color: colors.shadow.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: done ? AppPalette.mutedGold : colors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.shadowInk,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(done ? Icons.check_rounded : Icons.quiz_rounded,
                  color: done ? AppPalette.ink : colors.onPrimary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quiz.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(quiz.className,
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 12)),
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
                      if (done && quiz.score != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded,
                                size: 14, color: AppPalette.mutedGold),
                            const SizedBox(width: 2),
                            Text('${quiz.score}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              done ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: done ? AppPalette.correctGold : colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
