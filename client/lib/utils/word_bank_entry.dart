/// One searchable entry in any Word Search category. [word] is what actually
/// appears in the grid (uppercase Latin letters only, no spaces or hyphens —
/// the grid/generator only ever deals in single unbroken tokens). [displayName]
/// is the properly formatted name shown once the word is found (may include
/// punctuation the grid strips, e.g. "Ar-Rahman"). [fact] is a short one- to
/// two-sentence piece of context shown alongside it, and again in the
/// post-puzzle recap. [arabicScript] is the word's real Arabic spelling
/// (with diacritics/letters the Latin transliteration can't represent),
/// shown once found so the player sees — and, via text-to-speech, hears —
/// the actual word rather than only its Romanized stand-in.
class WordEntry {
  const WordEntry(this.word, this.displayName, this.fact, this.arabicScript);

  final String word;
  final String displayName;
  final String fact;
  final String arabicScript;
}
