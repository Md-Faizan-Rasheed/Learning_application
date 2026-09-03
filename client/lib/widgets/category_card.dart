import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class CategoryCard extends StatefulWidget {
  const CategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _active => _pressed || _hovered;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,

            // IMPORTANT:
            // No width: double.infinity here.

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),

              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surface,
                  colors.surfaceContainerHighest,
                ],
              ),

              border: Border.all(
                color: _active
                    ? colors.primary.withValues(alpha: 0.65)
                    : colors.outlineVariant,
                width: _active ? 1.5 : 1,
              ),

              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(
                    alpha: _active ? 0.16 : 0.08,
                  ),
                  blurRadius: _active ? 18 : 10,
                  offset: Offset(
                    0,
                    _active ? 7 : 4,
                  ),
                ),
              ],
            ),

            child: Row(
              children: [
                _buildIcon(context),

                const SizedBox(width: 14),

                Expanded(
                  child: _buildContent(context),
                ),

                const SizedBox(width: 10),

                _buildArrow(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(
              alpha: _active ? 0.30 : 0.16,
            ),
            blurRadius: _active ? 15 : 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        widget.icon,
        size: 28,
        color: colors.onPrimary,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          widget.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 7),

        Row(
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 15,
              color: colors.primary,
            ),

            const SizedBox(width: 5),

            Flexible(
              child: Text(
                AppLocalizations.of(context)!.cardPlayChallenge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArrow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _active
            ? colors.primary
            : colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 19,
        color: _active
            ? colors.onPrimary
            : colors.onSurfaceVariant,
      ),
    );
  }
}