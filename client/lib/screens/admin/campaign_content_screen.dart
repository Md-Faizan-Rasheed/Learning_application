import 'package:flutter/material.dart';

import '../../api/admin_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

/// Full CRUD + reorder management for the two pieces of static campaign
/// content that previously required a direct DB edit to change: the
/// ordered list of campaign stages (campaign_stages) and the Seerah events
/// questions get tagged to (seerah_events). Stage order is the only one of
/// the two with a real game-mechanic meaning (it's the sequence players
/// unlock stages in), so only stages get drag-to-reorder — event order has
/// no such meaning (see campaign/repository.py:list_events).
class CampaignContentScreen extends StatefulWidget {
  const CampaignContentScreen({super.key, required this.token});
  final String token;

  @override
  State<CampaignContentScreen> createState() => _CampaignContentScreenState();
}

class _CampaignContentScreenState extends State<CampaignContentScreen>
    with SingleTickerProviderStateMixin {
  final AdminApi _api = AdminApi();
  late final TabController _tabController;

  bool _stagesLoading = true;
  String? _stagesError;
  List<CampaignStageOption> _stages = [];

  bool _eventsLoading = true;
  String? _eventsError;
  List<SeerahEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _loadStages();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStages() async {
    setState(() {
      _stagesLoading = true;
      _stagesError = null;
    });
    try {
      final stages = await _api.listCampaignStages(widget.token);
      setState(() {
        _stages = stages;
        _stagesLoading = false;
      });
    } catch (e) {
      setState(() {
        _stagesError = e.toString();
        _stagesLoading = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _eventsLoading = true;
      _eventsError = null;
    });
    try {
      final events = await _api.listSeerahEvents(widget.token);
      setState(() {
        _events = events;
        _eventsLoading = false;
      });
    } catch (e) {
      setState(() {
        _eventsError = e.toString();
        _eventsLoading = false;
      });
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  // ---- Stages ----

  Future<void> _onReorderStages(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final previous = _stages;
    final updated = [..._stages];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _stages = updated);
    try {
      final result =
          await _api.reorderCampaignStages(widget.token, updated.map((s) => s.id).toList());
      if (mounted) setState(() => _stages = result);
    } catch (e) {
      if (mounted) setState(() => _stages = previous);
      _showError(e);
    }
  }

  Future<void> _openStageDialog({CampaignStageOption? stage}) async {
    final t = AppLocalizations.of(context)!;
    final slugCtl = TextEditingController(text: stage?.slug ?? '');
    final nameEnCtl = TextEditingController(text: stage?.name['en'] as String? ?? '');
    final nameUrCtl = TextEditingController(text: stage?.name['ur'] as String? ?? '');
    final nameArCtl = TextEditingController(text: stage?.name['ar'] as String? ?? '');
    final descEnCtl = TextEditingController(text: stage?.description?['en'] as String? ?? '');
    final descUrCtl = TextEditingController(text: stage?.description?['ur'] as String? ?? '');
    final descArCtl = TextEditingController(text: stage?.description?['ar'] as String? ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(stage == null ? t.adminCreateStage : t.adminEditStage),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(slugCtl, t.adminStageSlugHint, Icons.tag_rounded),
                const SizedBox(height: 10),
                _dialogField(nameEnCtl, t.adminNameEnHint, Icons.title_rounded),
                const SizedBox(height: 10),
                _dialogField(nameUrCtl, t.adminNameUrHint, Icons.title_rounded),
                const SizedBox(height: 10),
                _dialogField(nameArCtl, t.adminNameArHint, Icons.title_rounded),
                const SizedBox(height: 10),
                _dialogField(descEnCtl, t.adminDescriptionEnHint, Icons.notes_rounded),
                const SizedBox(height: 10),
                _dialogField(descUrCtl, t.adminDescriptionUrHint, Icons.notes_rounded),
                const SizedBox(height: 10),
                _dialogField(descArCtl, t.adminDescriptionArHint, Icons.notes_rounded),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.authCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(stage == null ? t.adminCreateBtn : t.adminSave),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final slug = slugCtl.text.trim();
    final nameEn = nameEnCtl.text.trim();
    final nameUr = nameUrCtl.text.trim();
    final nameAr = nameArCtl.text.trim();
    if (slug.isEmpty || nameEn.isEmpty || nameUr.isEmpty || nameAr.isEmpty) return;
    final name = {'en': nameEn, 'ur': nameUr, 'ar': nameAr};
    final description = _optionalTrilingual(descEnCtl.text, descUrCtl.text, descArCtl.text);

    try {
      if (stage == null) {
        await _api.createCampaignStage(widget.token, slug: slug, name: name, description: description);
      } else {
        await _api.updateCampaignStage(widget.token, stage.id,
            slug: slug, name: name, description: description);
      }
      await _loadStages();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteStage(CampaignStageOption stage) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.adminDeleteStage),
        content: Text(t.adminDeleteStageConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.authCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.adminDeleteStage),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteCampaignStage(widget.token, stage.id);
      await _loadStages();
    } catch (e) {
      _showError(e);
    }
  }

  // ---- Events ----

  Future<void> _openEventDialog({SeerahEvent? event}) async {
    final t = AppLocalizations.of(context)!;
    final slugCtl = TextEditingController(text: event?.slug ?? '');
    final nameEnCtl = TextEditingController(text: event?.name['en'] as String? ?? '');
    final nameUrCtl = TextEditingController(text: event?.name['ur'] as String? ?? '');
    final nameArCtl = TextEditingController(text: event?.name['ar'] as String? ?? '');
    final yearCtl =
        TextEditingController(text: event?.yearHijri != null ? '${event!.yearHijri}' : '');
    final summaryEnCtl = TextEditingController(text: event?.summary?['en'] as String? ?? '');
    final summaryUrCtl = TextEditingController(text: event?.summary?['ur'] as String? ?? '');
    final summaryArCtl = TextEditingController(text: event?.summary?['ar'] as String? ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(event == null ? t.adminCreateEvent : t.adminEditEvent),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(slugCtl, t.adminEventSlugHint, Icons.tag_rounded),
                const SizedBox(height: 10),
                _dialogField(nameEnCtl, t.adminNameEnHint, Icons.title_rounded),
                const SizedBox(height: 10),
                _dialogField(nameUrCtl, t.adminNameUrHint, Icons.title_rounded),
                const SizedBox(height: 10),
                _dialogField(nameArCtl, t.adminNameArHint, Icons.title_rounded),
                const SizedBox(height: 10),
                _dialogField(yearCtl, t.adminYearHijriHint, Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                _dialogField(summaryEnCtl, t.adminSummaryEnHint, Icons.notes_rounded, maxLines: 3),
                const SizedBox(height: 10),
                _dialogField(summaryUrCtl, t.adminSummaryUrHint, Icons.notes_rounded, maxLines: 3),
                const SizedBox(height: 10),
                _dialogField(summaryArCtl, t.adminSummaryArHint, Icons.notes_rounded, maxLines: 3),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.authCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(event == null ? t.adminCreateBtn : t.adminSave),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final slug = slugCtl.text.trim();
    final nameEn = nameEnCtl.text.trim();
    final nameUr = nameUrCtl.text.trim();
    final nameAr = nameArCtl.text.trim();
    if (slug.isEmpty || nameEn.isEmpty || nameUr.isEmpty || nameAr.isEmpty) return;
    final name = {'en': nameEn, 'ur': nameUr, 'ar': nameAr};
    final yearHijri = int.tryParse(yearCtl.text.trim());
    final summary = _optionalTrilingual(summaryEnCtl.text, summaryUrCtl.text, summaryArCtl.text);

    try {
      if (event == null) {
        await _api.createSeerahEvent(widget.token,
            slug: slug, name: name, yearHijri: yearHijri, summary: summary);
      } else {
        await _api.updateSeerahEvent(widget.token, event.id,
            slug: slug, name: name, yearHijri: yearHijri, summary: summary);
      }
      await _loadEvents();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteEvent(SeerahEvent event) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.adminDeleteEvent),
        content: Text(t.adminDeleteEventConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.authCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.adminDeleteEvent),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteSeerahEvent(widget.token, event.id);
      await _loadEvents();
    } catch (e) {
      _showError(e);
    }
  }

  // ---- Shared helpers ----

  Map<String, String>? _optionalTrilingual(String en, String ur, String ar) {
    final e = en.trim();
    final u = ur.trim();
    final a = ar.trim();
    if (e.isEmpty && u.isEmpty && a.isEmpty) return null;
    return {'en': e, 'ur': u, 'ar': a};
  }

  Widget _dialogField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
        title: t.adminCampaignContentTitle,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [Tab(text: t.adminStagesTab), Tab(text: t.adminEventsTab)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tabController.index == 0
            ? () => _openStageDialog()
            : () => _openEventDialog(),
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? t.adminCreateStage : t.adminCreateEvent),
      ),
      body: ScreenWithAmbientBackdrop(
        child: TabBarView(
          controller: _tabController,
          children: [_buildStagesTab(), _buildEventsTab()],
        ),
      ),
    );
  }

  Widget _buildStagesTab() {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    if (_stagesLoading) {
      return LoadingView(message: t.adminStagesTab, icon: Icons.map_rounded);
    }
    if (_stagesError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_stagesError!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadStages, child: Text(t.retry)),
          ],
        ),
      );
    }
    if (_stages.isEmpty) {
      return Center(child: Text(t.adminNoStagesYet));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              t.adminReorderStagesHint,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
            itemCount: _stages.length,
            onReorder: _onReorderStages,
            itemBuilder: (context, i) {
              final s = _stages[i];
              return _StageCard(
                key: ValueKey(s.id),
                stage: s,
                index: i,
                onEdit: () => _openStageDialog(stage: s),
                onDelete: () => _deleteStage(s),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventsTab() {
    final t = AppLocalizations.of(context)!;
    if (_eventsLoading) {
      return LoadingView(message: t.adminEventsTab, icon: Icons.auto_stories_rounded);
    }
    if (_eventsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_eventsError!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadEvents, child: Text(t.retry)),
          ],
        ),
      );
    }
    if (_events.isEmpty) {
      return Center(child: Text(t.adminNoEventsYet));
    }
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 88),
        itemCount: _events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = _events[i];
          return _EventCard(
            event: e,
            onEdit: () => _openEventDialog(event: e),
            onDelete: () => _deleteEvent(e),
          );
        },
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required super.key,
    required this.stage,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final CampaignStageOption stage;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
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
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle_rounded, color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration:
                  BoxDecoration(color: colors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${stage.orderNo}',
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stage.nameFor(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    stage.slug,
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 11, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.edit_rounded), tooltip: t.adminEditStage, onPressed: onEdit),
            IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: t.adminDeleteStage,
                onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onEdit, required this.onDelete});

  final SeerahEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: colors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.auto_stories_rounded, color: colors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.nameFor(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      event.slug,
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                    if (event.yearHijri != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${event.yearHijri} AH',
                            style: TextStyle(fontSize: 11, color: colors.primary)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.edit_rounded), tooltip: t.adminEditEvent, onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: t.adminDeleteEvent,
              onPressed: onDelete),
        ],
      ),
    );
  }
}
