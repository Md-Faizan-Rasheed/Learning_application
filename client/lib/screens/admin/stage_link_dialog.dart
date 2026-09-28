import 'package:flutter/material.dart';

import '../../api/admin_api.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_pill.dart';

/// A tappable pill for a question row — for 'untagged' it opens
/// [showTagAndLinkDialog] (pick an event and, optionally, a stage in one
/// step); for 'orphaned'/'linked' it opens [showStageLinkDialog] to link,
/// change, or unlink which campaign stage the question's event feeds.
class StageLinkChip extends StatelessWidget {
  const StageLinkChip({
    super.key,
    required this.tagStatus,
    required this.stageSlug,
    required this.stages,
    required this.lang,
    required this.onTap,
  });

  /// 'untagged' | 'orphaned' | 'linked'.
  final String tagStatus;
  final String? stageSlug;
  final List<CampaignStageOption> stages;
  final String lang;
  final VoidCallback onTap;

  String _stageName() {
    for (final s in stages) {
      if (s.slug == stageSlug) return s.nameFor(lang);
    }
    return stageSlug ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    late final String label;
    late final StatusTone tone;
    late final IconData icon;
    switch (tagStatus) {
      case 'linked':
        label = t.adminTagLinkedTo(_stageName());
        tone = StatusTone.info;
        icon = Icons.link_rounded;
        break;
      case 'orphaned':
        label = t.adminTagOrphaned;
        tone = StatusTone.warning;
        icon = Icons.report_problem_rounded;
        break;
      default:
        label = t.adminNotTaggedOnly;
        tone = StatusTone.warning;
        icon = Icons.link_off_rounded;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: StatusPill(label: label, tone: tone, icon: icon),
    );
  }
}

/// Shows a dialog letting the admin pick which campaign stage the event
/// behind one tagged question should carry a movement_stage link for (or
/// unlink it entirely). Applies the change immediately via the API and
/// returns true if it was saved. Affects every question sharing that event,
/// since the link lives on the event, not the individual question.
Future<bool> showStageLinkDialog(
  BuildContext context, {
  required String token,
  required String eventId,
  required String? currentStageSlug,
  required List<CampaignStageOption> stages,
  required String lang,
}) async {
  final t = AppLocalizations.of(context)!;
  final api = AdminApi();
  String? selected = currentStageSlug;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(t.adminLinkStageDialogTitle),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.adminLinkStageDialogBody,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    RadioListTile<String?>(
                      value: null,
                      groupValue: selected,
                      dense: true,
                      title: Text(t.adminLinkStageNone),
                      onChanged: (v) => setDialogState(() => selected = v),
                    ),
                    ...stages.map(
                      (s) => RadioListTile<String?>(
                        value: s.slug,
                        groupValue: selected,
                        dense: true,
                        title: Text(s.nameFor(lang)),
                        onChanged: (v) => setDialogState(() => selected = v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.authCancel),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await api.setEventStageTag(token, eventId, selected);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text(t.adminSave),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Shown for an 'untagged' question — lets the admin pick the Seerah event
/// it belongs to and, in the same step, which campaign stage that event
/// should link to, instead of tagging via the editor and then linking
/// separately. Applies both changes immediately via the API and returns
/// true if they were saved.
Future<bool> showTagAndLinkDialog(
  BuildContext context, {
  required String token,
  required String questionId,
  required List<SeerahEvent> events,
  required List<CampaignStageOption> stages,
  required String lang,
}) async {
  final t = AppLocalizations.of(context)!;
  final api = AdminApi();
  String? selectedEventId;
  String? selectedStageSlug;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(t.adminTagAndLinkDialogTitle),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.adminTagAndLinkDialogBody,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedEventId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t.adminSeerahEventLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(t.adminSeerahEventNone),
                    ),
                    for (final e in events)
                      DropdownMenuItem<String?>(
                        value: e.id,
                        child: Text(e.nameFor(lang), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() {
                    selectedEventId = v;
                    error = null;
                  }),
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(error!, style: const TextStyle(color: AppPalette.incorrectRed, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                Text(t.adminLinkStageSectionLabel, style: Theme.of(dialogContext).textTheme.labelLarge),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      RadioListTile<String?>(
                        value: null,
                        groupValue: selectedStageSlug,
                        dense: true,
                        title: Text(t.adminLinkStageNone),
                        onChanged: (v) => setDialogState(() => selectedStageSlug = v),
                      ),
                      ...stages.map(
                        (s) => RadioListTile<String?>(
                          value: s.slug,
                          groupValue: selectedStageSlug,
                          dense: true,
                          title: Text(s.nameFor(lang)),
                          onChanged: (v) => setDialogState(() => selectedStageSlug = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.authCancel),
          ),
          FilledButton(
            onPressed: () async {
              final eventId = selectedEventId;
              if (eventId == null) {
                setDialogState(() => error = t.adminTagAndLinkEventRequired);
                return;
              }
              try {
                await api.updateQuestion(token, questionId, eventId: eventId);
                await api.setEventStageTag(token, eventId, selectedStageSlug);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text(t.adminSave),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
