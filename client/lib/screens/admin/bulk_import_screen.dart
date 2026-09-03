import 'package:flutter/material.dart';

import '../../api/admin_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';

const _jsonTemplate = '''
[
  {
    "category_slug": "seerah",
    "difficulty": "easy",
    "prompt": {"en": "...", "ar": "...", "ur": "..."},
    "options": {"en": ["...", "..."], "ar": ["...", "..."], "ur": ["...", "..."]},
    "correct_index": 0
  }
]''';

const _csvTemplate = '''
category_slug,difficulty,prompt_en,prompt_ar,prompt_ur,option_en_1,option_en_2,option_en_3,option_en_4,option_ar_1,option_ar_2,option_ar_3,option_ar_4,option_ur_1,option_ur_2,option_ur_3,option_ur_4,correct_index
seerah,easy,...,...,...,...,...,,,...,...,,,...,...,,,0''';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key, required this.token});
  final String token;

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final AdminApi _api = AdminApi();
  final _contentController = TextEditingController();
  final _scrollController = ScrollController();
  String _format = 'json';
  bool _showTemplate = false;
  bool _importing = false;
  String? _error;
  BulkImportResult? _result;

  @override
  void dispose() {
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() {
      _importing = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _api.bulkImportQuestions(
        widget.token,
        format: _format,
        content: _contentController.text,
      );
      setState(() {
        _result = result;
        _importing = false;
      });
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
    final template = _format == 'json' ? _jsonTemplate : _csvTemplate;

    return Scaffold(
      appBar: AppHeader(
          title: t.adminBulkImport, scrollController: _scrollController),
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
                    Text(t.adminBulkImportFormat,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'json',
                            label: Text('JSON'),
                            icon: Icon(Icons.data_object_rounded)),
                        ButtonSegment(
                            value: 'csv',
                            label: Text('CSV'),
                            icon: Icon(Icons.table_rows_rounded)),
                      ],
                      selected: {_format},
                      onSelectionChanged: (s) =>
                          setState(() => _format = s.first),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showTemplate = !_showTemplate),
                      icon: Icon(_showTemplate
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded),
                      label: Text(t.adminBulkImportTemplate),
                    ),
                    if (_showTemplate)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SelectableText(template,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12)),
                      ),
                    TextField(
                      controller: _contentController,
                      minLines: 10,
                      maxLines: 18,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: t.adminBulkImportContentHint,
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: colors.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    if (_result != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.green),
                            const SizedBox(width: 10),
                            Text(
                              t.adminBulkImportCreated(_result!.created),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                      if (_result!.errors.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(t.adminBulkImportErrorsHeader,
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 6),
                        for (final err in _result!.errors)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  colors.errorContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#${err.row}: ${err.message}',
                              style: TextStyle(
                                  color: colors.onErrorContainer, fontSize: 12),
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _importing ? null : _import,
                        icon: _importing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.upload_rounded),
                        label: Text(t.adminBulkImportRun,
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
}
