import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One segment of a [BreadcrumbTrail] — [onTap] null marks it as the
/// current, non-interactive segment (rendered bold/gold); every other
/// segment is dimmed and tappable to jump back to that level directly,
/// not just one step at a time like a plain back arrow.
class BreadcrumbItem {
  const BreadcrumbItem({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
}

/// A persistent "Home ▸ Faith" trail so a multi-level drill-down always
/// shows what level you're on and how you got there, instead of relying
/// on the back arrow alone. Kept deliberately small/quiet — it sits above
/// the hero content, not competing with it, but never scrolls away.
class BreadcrumbTrail extends StatelessWidget {
  const BreadcrumbTrail({super.key, required this.items});

  final List<BreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right_rounded, size: 15, color: AppPalette.inkMuted),
        ));
      }
      final item = items[i];
      final isCurrent = item.onTap == null;
      children.add(
        GestureDetector(
          onTap: item.onTap,
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              color: isCurrent ? AppPalette.deepTeal : AppPalette.inkMuted,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
