import 'package:flutter/material.dart';

import '../../api/moderation_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.token});
  final String token;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ModerationApi _api = ModerationApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  List<AdminReport> _reports = [];

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
      final reports = await _api.listReports(widget.token, status: 'open');
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(AdminReport report, String status) async {
    try {
      await _api.setReportStatus(widget.token, report.id, status);
      if (!mounted) return;
      setState(() => _reports.removeWhere((r) => r.id == report.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _reasonLabel(AppLocalizations t, String reason) => switch (reason) {
        'inappropriate_name' => t.mpReasonInappropriateName,
        'cheating' => t.mpReasonCheating,
        'harassment' => t.mpReasonHarassment,
        'spam' => t.mpReasonSpam,
        _ => t.mpReasonOther,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
        title: t.adminReportsTitle,
        scrollController: (_loading || _error != null || _reports.isEmpty)
            ? null
            : _scrollController,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackdrop()),
          SafeArea(
            child: _loading
                ? LoadingView(
                    message: t.adminReportsTitle, icon: Icons.flag_outlined)
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
                    : _reports.isEmpty
                        ? Center(child: Text(t.adminNoReports))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final horizontalPadding =
                                    constraints.maxWidth >= 600 ? 32.0 : 16.0;
                                return Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 900),
                                    child: ListView.separated(
                                      controller: _scrollController,
                                      padding: EdgeInsets.fromLTRB(
                                          horizontalPadding, 16, horizontalPadding, 32),
                                      itemCount: _reports.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, i) => _ReportCard(
                                        report: _reports[i],
                                        reasonLabel: _reasonLabel(t, _reports[i].reason),
                                        onReviewed: () =>
                                            _setStatus(_reports[i], 'reviewed'),
                                        onDismissed: () =>
                                            _setStatus(_reports[i], 'dismissed'),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.reasonLabel,
    required this.onReviewed,
    required this.onDismissed,
  });

  final AdminReport report;
  final String reasonLabel;
  final VoidCallback onReviewed;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: colors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.adminReportSummary(report.reporterName, report.reportedName),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(reasonLabel,
                style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
          if (report.details != null && report.details!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(report.details!,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismissed,
                  child: Text(t.adminDismiss),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onReviewed,
                  child: Text(t.adminMarkReviewed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
