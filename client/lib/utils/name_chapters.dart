import 'names_of_allah.dart';
import 'word_bank_entry.dart';

const _kChapterSize = 9;

/// One fixed 9-name slice of [kNamesOfAllah] (Chapter 1 = names 1-9, Chapter
/// 2 = 10-18, ... Chapter 11 = 91-99) — a pure, derived view over the same
/// single source of truth, not a separate copy of the data.
class NameChapter {
  const NameChapter({
    required this.index,
    required this.startNumber,
    required this.endNumber,
    required this.names,
  });

  /// 0-based chapter index (0..10).
  final int index;

  /// 1-based number of the first/last name in this chapter, e.g. 1 and 9.
  final int startNumber;
  final int endNumber;

  final List<WordEntry> names;
}

/// The 99 Names split into 11 chapters of 9 — deliberately fixed-size
/// (rather than a freeform range) so a chapter always fits comfortably in
/// the existing round UI, which is tuned for small batches.
final List<NameChapter> kNameChapters = List.generate(
  (kNamesOfAllah.length / _kChapterSize).ceil(),
  (i) {
    final start = i * _kChapterSize;
    final end = (start + _kChapterSize).clamp(0, kNamesOfAllah.length);
    return NameChapter(
      index: i,
      startNumber: start + 1,
      endNumber: end,
      names: kNamesOfAllah.sublist(start, end),
    );
  },
  growable: false,
);
