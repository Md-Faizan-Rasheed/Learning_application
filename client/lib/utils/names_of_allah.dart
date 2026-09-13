import 'word_bank_entry.dart';

/// A selection from the 99 Names of Allah (Asma-ul-Husna). [WordEntry.word]
/// drops the hyphen so it fits the grid as a single token (e.g. "ARRAHMAN");
/// [WordEntry.displayName] keeps the standard hyphenated transliteration.
const kNamesOfAllah = <WordEntry>[
  WordEntry('ARRAHMAN', 'Ar-Rahman',
      'The Most Merciful — mentioned at the start of nearly every Surah in the Qur\'an.'),
  WordEntry('ARRAHEEM', 'Ar-Raheem',
      'The Most Compassionate — His special mercy shown to the believers.'),
  WordEntry('ALMALIK', 'Al-Malik',
      'The King — the true Sovereign over all creation.'),
  WordEntry('ALQUDDUS', 'Al-Quddus',
      'The Most Holy — utterly free from any imperfection.'),
  WordEntry('ASSALAM', 'As-Salam',
      'The Source of Peace — from whom all safety and peace flow.'),
  WordEntry('ALMUMIN', 'Al-Mu\'min',
      'The Granter of Security — gives faith and safety to His creation.'),
  WordEntry('ALAZIZ', 'Al-Aziz',
      'The Almighty — the One whose might can never be overcome.'),
  WordEntry('ALGHAFFAR', 'Al-Ghaffar',
      'The Ever-Forgiving — forgives the sins of His servants again and again.'),
  WordEntry('ALWAHHAB', 'Al-Wahhab',
      'The Bestower — gives generously without expecting anything in return.'),
  WordEntry('ARRAZZAQ', 'Ar-Razzaq',
      'The Provider — sustains every living creature.'),
  WordEntry('ALHAKEEM', 'Al-Hakeem',
      'The All-Wise — every command and decree carries perfect wisdom.'),
  WordEntry('ALKARIM', 'Al-Karim',
      'The Most Generous — gives abundantly and honors His creation.'),
  WordEntry('ASSABUR', 'As-Sabur',
      'The Most Patient — never rushes to punish, giving time to repent.'),
  WordEntry('ANNUR', 'An-Nur',
      'The Light — the Light of the heavens and the earth.'),
  WordEntry('ALWADUD', 'Al-Wadud',
      'The Most Loving — loves His righteous servants deeply.'),
  WordEntry('ALHALIM', 'Al-Haleem',
      'The Forbearing — remains gentle with His servants despite their shortcomings.'),
];
