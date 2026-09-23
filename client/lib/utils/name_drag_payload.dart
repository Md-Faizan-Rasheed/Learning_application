import 'word_bank_entry.dart';

/// What's being dragged in the "Names of Allah" matching game: the name
/// itself, plus where it was dragged from — null means "the floating
/// pool", otherwise the meaning-box index it was sitting in. Carrying the
/// source lets a drop target tell a fresh placement from a box-to-box (or
/// box-to-pool) relocation and react accordingly. Public (not
/// screen-private) because both the meaning boxes and the pool's floating
/// cards need to agree on one concrete `Draggable`/`DragTarget` type
/// parameter for Flutter's drag-and-drop to actually connect them.
class NameDragPayload {
  const NameDragPayload({required this.entry, required this.sourceBox});
  final WordEntry entry;
  final int? sourceBox;
}
