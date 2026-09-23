import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One saved reference — enough to both show it in a "Saved" list and to
/// re-open the exact same card (category/situation/ref index) from there.
class SavedReference {
  const SavedReference({
    required this.categoryId,
    required this.categoryLabel,
    required this.situationId,
    required this.situationLabel,
    required this.refIndex,
  });

  final String categoryId;
  final String categoryLabel;
  final String situationId;
  final String situationLabel;
  final int refIndex;

  String get _key => '$categoryId/$situationId/$refIndex';

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'categoryLabel': categoryLabel,
        'situationId': situationId,
        'situationLabel': situationLabel,
        'refIndex': refIndex,
      };

  factory SavedReference.fromJson(Map<String, dynamic> json) =>
      SavedReference(
        categoryId: json['categoryId'] as String,
        categoryLabel: json['categoryLabel'] as String,
        situationId: json['situationId'] as String,
        situationLabel: json['situationLabel'] as String,
        refIndex: json['refIndex'] as int,
      );
}

/// Local bookmarking for "Find My Ayah" cards — same
/// SharedPreferences-backed, singleton pattern as WordSearchStats and
/// NamesOnWaterProgress. No backend: a saved list is a per-device
/// convenience, not profile data.
class AyahBookmarks {
  AyahBookmarks._();

  static final AyahBookmarks instance = AyahBookmarks._();

  static const _key = 'find_my_ayah_bookmarks';

  Future<List<SavedReference>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SavedReference.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isSaved(SavedReference ref) async {
    final saved = await all();
    return saved.any((s) => s._key == ref._key);
  }

  /// Toggles [ref]'s saved state and returns the new state (true = now saved).
  Future<bool> toggle(SavedReference ref) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await all();
    final existingIndex = saved.indexWhere((s) => s._key == ref._key);
    bool nowSaved;
    if (existingIndex >= 0) {
      saved.removeAt(existingIndex);
      nowSaved = false;
    } else {
      saved.add(ref);
      nowSaved = true;
    }
    await prefs.setString(
        _key, jsonEncode(saved.map((s) => s.toJson()).toList()));
    return nowSaved;
  }
}
