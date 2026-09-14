import 'package:flutter/material.dart';

/// A gradient app bar used across every screen so the app reads as one
/// consistent product instead of a stack of default Material bars.
///
/// Fades/slides in once on first build, and — when a screen hands it the
/// `ScrollController` already attached to its own scrolling content — grows
/// its shadow, overlays a soft scrim, and shrinks its title slightly as the
/// user scrolls the first ~100px. [scrollController] is optional and purely
/// additive: omit it and this renders exactly as a static header, same as
/// before.
class AppHeader extends StatefulWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.bottom,
    this.scrollController,
    this.backgroundColor,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final ScrollController? scrollController;

  /// Overrides the default teal→gold gradient with a flat fill — for a
  /// screen whose own background needs one coherent solid tone instead
  /// (e.g. Names of Allah's water panel). Every other screen omits this
  /// and keeps the shared gradient.
  final Color? backgroundColor;

  @override
  State<AppHeader> createState() => _AppHeaderState();

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}

class _AppHeaderState extends State<AppHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // 0 at rest, 1 once the bound scroll view has scrolled ~100px.
  double _scrollProgress = 0;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    final curved = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _fade = curved;
    _slide = Tween<Offset>(begin: const Offset(0, -0.18), end: Offset.zero)
        .animate(curved);
    _entrance.forward();
    widget.scrollController?.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant AppHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_handleScroll);
      widget.scrollController?.addListener(_handleScroll);
    }
  }

  void _handleScroll() {
    final controller = widget.scrollController;
    final offset = (controller != null && controller.hasClients)
        ? controller.offset
        : 0.0;
    final next = (offset / 100).clamp(0.0, 1.0);
    // Throttle: only rebuild when the change is actually visible.
    if ((next - _scrollProgress).abs() > 0.01) {
      setState(() => _scrollProgress = next);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_handleScroll);
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final isTablet = width >= 600 && width < 900;

    final baseTitleSize = isDesktop ? 23.0 : (isTablet ? 21.5 : 20.0);
    final titleSize = baseTitleSize - (_scrollProgress * 2);

    const restingShadowAlpha = 0.35;
    const scrolledShadowAlpha = 0.55;
    final shadowAlpha = restingShadowAlpha +
        _scrollProgress * (scrolledShadowAlpha - restingShadowAlpha);
    final elevation = 6 + _scrollProgress * 6;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: AppBar(
          title: Text(
            widget.title,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: titleSize),
          ),
          centerTitle: widget.centerTitle,
          leading: widget.leading,
          actions: widget.actions,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: elevation,
          shadowColor: colors.primary.withValues(alpha: shadowAlpha),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
          ),
          flexibleSpace: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  gradient: widget.backgroundColor == null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colors.primary, colors.secondary],
                        )
                      : null,
                ),
              ),
              // Scroll-reactive scrim: adds depth/legibility as content
              // scrolls underneath, without needing a true collapsing header.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: _scrollProgress * 0.10),
                ),
              ),
            ],
          ),
          bottom: widget.bottom,
        ),
      ),
    );
  }
}
