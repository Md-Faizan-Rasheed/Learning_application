import 'package:flutter/material.dart';

class _CategoryOption {
  const _CategoryOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.colors,
  });

  final String value;
  final String title;
  final String subtitle;
  final String iconAsset;
  final List<Color> colors;
}

const _categoryOptions = [
  _CategoryOption(
    value: 'seerah',
    title: 'Seerah',
    subtitle: 'Life of the Prophet ﷺ',
    iconAsset: 'assets/images/seerah_icon.png',
    colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
  ),
  _CategoryOption(
    value: 'arabic',
    title: 'Arabic',
    subtitle: 'Language & vocabulary',
    iconAsset: 'assets/images/arabic_icon.png',
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
  ),
  _CategoryOption(
    value: 'mixed',
    title: 'Mixed',
    subtitle: 'A bit of everything',
    iconAsset: 'assets/images/mixed_icon.png',
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  ),
];

/// A gamified category-selection dialog: colorful gradient "power-up" tiles
/// instead of a plain text list. Returns the chosen category value, or null
/// if dismissed.
Future<String?> showCategoryPicker(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose your challenge',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a category to test your knowledge',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 22),
              for (int i = 0; i < _categoryOptions.length; i++) ...[
                _CategoryOptionCard(
                  option: _categoryOptions[i],
                  onTap: () => Navigator.pop(ctx, _categoryOptions[i].value),
                ),
                if (i != _categoryOptions.length - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _CategoryOptionCard extends StatefulWidget {
  const _CategoryOptionCard({required this.option, required this.onTap});

  final _CategoryOption option;
  final VoidCallback onTap;

  @override
  State<_CategoryOptionCard> createState() => _CategoryOptionCardState();
}

class _CategoryOptionCardState extends State<_CategoryOptionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: option.colors,
            ),
            boxShadow: [
              BoxShadow(
                color: option.colors.first.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  option.iconAsset,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.category_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
