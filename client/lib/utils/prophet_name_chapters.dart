import 'name_chapters.dart';
import 'prophet_muhammad_names.dart';

/// The supplied list is divided into eleven fixed groups of nine.
final List<NameChapter> kProphetNameChapters = List.generate(
  (kProphetMuhammadNames.length / 9).ceil(),
  (index) {
    final start = index * 9;
    final end = (start + 9).clamp(0, kProphetMuhammadNames.length);
    return NameChapter(
      index: index,
      startNumber: start + 1,
      endNumber: end,
      names: kProphetMuhammadNames.sublist(start, end),
    );
  },
  growable: false,
);
