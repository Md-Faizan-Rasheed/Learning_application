import 'package:flutter/material.dart';

import '../../api/teacher_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';
import 'class_detail_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen(
      {super.key, required this.token, required this.onSignOut});
  final String token;
  final Future<void> Function() onSignOut;

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final TeacherApi _api = TeacherApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  List<TeacherClass> _classes = [];

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
      final classes = await _api.listClasses(widget.token);
      setState(() {
        _classes = classes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createClass() async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.teacherCreateClass),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.teacherClassNameHint,
            prefixIcon: const Icon(Icons.school_rounded),
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t.teacherCreateClass),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await _api.createClass(widget.token, name);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppHeader(
        title: t.teacherHomeTitle,
        centerTitle: false,
        scrollController: (_loading || _error != null || _classes.isEmpty)
            ? null
            : _scrollController,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.signOut,
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClass,
        icon: const Icon(Icons.add),
        label: Text(t.teacherCreateClass),
      ),
      body: ScreenWithAmbientBackdrop(
        child: _loading
            ? LoadingView(
                message: t.teacherHomeTitle, icon: Icons.school_rounded)
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
                : _classes.isEmpty
                    ? Center(child: Text(t.teacherNoClasses))
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
                                  itemCount: _classes.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) => _ClassCard(
                                    cls: _classes[i],
                                    onTap: () {
                                      Navigator.of(context)
                                          .push(
                                            MaterialPageRoute(
                                              builder: (_) => ClassDetailScreen(
                                                token: widget.token,
                                                classId: _classes[i].id,
                                              ),
                                            ),
                                          )
                                          .then((_) => _load());
                                    },
                                  ),
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

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.cls, required this.onTap});

  final TeacherClass cls;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
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
                gradient:
                    LinearGradient(colors: [colors.primary, colors.secondary]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: colors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cls.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cls.joinCode,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_alt_rounded,
                              size: 14, color: colors.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            t.teacherStudentsCount(cls.studentCount),
                            style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
