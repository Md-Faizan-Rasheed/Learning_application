import 'package:flutter/material.dart';

import '../../api/teacher_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/leaderboard.dart'
    show podiumColors, podiumOrFlatDecoration, podiumRankBadge;
import '../../widgets/loading_view.dart';
import '../../widgets/status_pill.dart';

class QuizResultsScreen extends StatefulWidget {
  const QuizResultsScreen(
      {super.key, required this.token, required this.quizId});
  final String token;
  final String quizId;

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final TeacherApi _api = TeacherApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  QuizResults? _results;

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
      final results = await _api.getQuizResults(widget.token, widget.quizId);
      setState(() {
        _results = results;
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
        return (StatusTone.neutral, Icons.circle_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
        title: t.teacherResultsTitle,
        scrollController: (_loading || _error != null) ? null : _scrollController,
      ),
      body: ScreenWithAmbientBackdrop(
        child: _loading
            ? LoadingView(
                message: t.teacherResultsTitle, icon: Icons.leaderboard_rounded)
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding =
                          constraints.maxWidth >= 600 ? 32.0 : 16.0;
                      // Sort completed students to the top by score so the podium
                      // treatment lands on the actual top scorers.
                      final students = [..._results!.students]..sort((a, b) {
                          final aScored =
                              a.status == 'completed' ? (a.score ?? 0) : -1;
                          final bScored =
                              b.status == 'completed' ? (b.score ?? 0) : -1;
                          return bScored.compareTo(aScored);
                        });

                      return RefreshIndicator(
                        onRefresh: _load,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: ListView(
                              controller: _scrollController,
                              padding: EdgeInsets.fromLTRB(
                                  horizontalPadding, 16, horizontalPadding, 24),
                              children: [
                                Text(_results!.quiz.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatTile(
                                        icon: Icons.stars_rounded,
                                        label: t.teacherAverageScore(
                                          _results!.averageScore == null
                                              ? '—'
                                              : _results!.averageScore!
                                                  .toStringAsFixed(1),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _StatTile(
                                        icon: Icons.task_alt_rounded,
                                        label: t.teacherCompletionRate(
                                            (_results!.completionRate * 100)
                                                .round()),
                                        progress: _results!.completionRate,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                for (int i = 0; i < students.length; i++) ...[
                                  _StudentRow(
                                    student: students[i],
                                    index: students[i].status == 'completed'
                                        ? i
                                        : podiumColors.length,
                                    statusLabel:
                                        _statusLabel(t, students[i].status),
                                    statusStyle:
                                        _statusStyle(students[i].status),
                                  ),
                                  const SizedBox(height: 8),
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, this.progress});

  final IconData icon;
  final String label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: colors.outlineVariant.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.index,
    required this.statusLabel,
    required this.statusStyle,
  });

  final QuizStudentResult student;
  final int index;
  final String statusLabel;
  final (StatusTone, IconData) statusStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPodium = index < podiumColors.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: podiumOrFlatDecoration(index: index, colors: colors),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: isPodium
                ? podiumRankBadge(index, size: 30)
                : Icon(Icons.person_rounded, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: isPodium ? FontWeight.w800 : FontWeight.w600),
                ),
                const SizedBox(height: 3),
                StatusPill(
                    label: statusLabel,
                    tone: statusStyle.$1,
                    icon: statusStyle.$2),
              ],
            ),
          ),
          if (student.score != null)
            Text(
              '${student.correctCount}/${student.totalQuestions} · ${student.score}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}
