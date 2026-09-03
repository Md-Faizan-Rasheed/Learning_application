import 'package:flutter/material.dart';

import '../../api/admin_api.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ambient_backdrop.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_pill.dart';
import 'question_list_screen.dart';
import 'reports_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen(
      {super.key, required this.token, required this.onSignOut});
  final String token;
  final Future<void> Function() onSignOut;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AdminApi _api = AdminApi();
  final _scrollController = ScrollController();
  bool _loading = true;
  String? _error;
  List<AdminCategory> _categories = [];

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
      final cats = await _api.listCategories(widget.token);
      setState(() {
        _categories = cats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createCategory() async {
    await _openCategoryDialog();
  }

  Future<void> _editCategory(AdminCategory category) async {
    await _openCategoryDialog(category: category);
  }

  Future<void> _openCategoryDialog({AdminCategory? category}) async {
    final t = AppLocalizations.of(context)!;
    final slugController = TextEditingController(text: category?.slug ?? '');
    final nameController =
        TextEditingController(text: category?.displayName ?? '');
    final descController = TextEditingController();
    bool isActive = category?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
              category == null ? t.adminCreateCategory : t.adminEditCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: slugController,
                enabled: category == null,
                autofocus: category == null,
                decoration: InputDecoration(
                  hintText: t.adminCategorySlugHint,
                  prefixIcon: const Icon(Icons.tag_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: t.adminCategoryNameHint,
                  prefixIcon: const Icon(Icons.title_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  hintText: t.adminCategoryDescHint,
                  prefixIcon: const Icon(Icons.notes_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              if (category != null) ...[
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isActive ? t.adminActive : t.adminInactive),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(category == null ? t.adminCreateBtn : t.adminSave),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      if (category == null) {
        if (slugController.text.trim().isEmpty ||
            nameController.text.trim().isEmpty) {
          return;
        }
        await _api.createCategory(
          widget.token,
          slug: slugController.text.trim(),
          displayName: nameController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
        );
      } else {
        await _api.updateCategory(
          widget.token,
          category.id,
          displayName: nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
          isActive: isActive,
        );
      }
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
        title: t.adminHomeTitle,
        centerTitle: false,
        scrollController:
            (_loading || _error != null || _categories.isEmpty)
                ? null
                : _scrollController,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: t.adminReportsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => ReportsScreen(token: widget.token)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.signOut,
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCategory,
        icon: const Icon(Icons.add),
        label: Text(t.adminCreateCategory),
      ),
      body: ScreenWithAmbientBackdrop(
        child: _loading
            ? LoadingView(
                message: t.adminHomeTitle,
                icon: Icons.dashboard_customize_rounded)
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
                : _categories.isEmpty
                    ? Center(child: Text(t.adminNoCategories))
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
                                  itemCount: _categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) => _CategoryCard(
                                    category: _categories[i],
                                    onEdit: () => _editCategory(_categories[i]),
                                    onOpenQuestions: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => QuestionListScreen(
                                            token: widget.token,
                                            categories: _categories,
                                            initialCategoryId:
                                                _categories[i].id,
                                          ),
                                        ),
                                      );
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(
      {required this.category,
      required this.onEdit,
      required this.onOpenQuestions});

  final AdminCategory category;
  final VoidCallback onEdit;
  final VoidCallback onOpenQuestions;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onOpenQuestions,
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
              child: const Icon(Icons.category_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.displayName,
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
                          category.slug,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: colors.primary),
                        ),
                      ),
                      StatusPill(
                        label:
                            category.isActive ? t.adminActive : t.adminInactive,
                        tone: category.isActive
                            ? StatusTone.success
                            : StatusTone.neutral,
                        icon: category.isActive
                            ? Icons.check_circle_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: t.adminEditCategory,
                onPressed: onEdit),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
