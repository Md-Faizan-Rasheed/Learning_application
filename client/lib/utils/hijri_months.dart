import 'word_bank_entry.dart';

/// All 12 months of the Hijri (Islamic lunar) calendar. A few
/// transliterations (e.g. Jumada al-Awwal) run longer than the rest — the
/// generator only places words that fit the chosen grid size, so those
/// simply appear less often on the smallest ("easy") grid rather than being
/// shortened into an inaccurate form.
const kHijriMonths = <WordEntry>[
  WordEntry('MUHARRAM', 'Muharram',
      'The first month of the Islamic calendar, and one of the four sacred months.'),
  WordEntry('SAFAR', 'Safar',
      'The second month — pre-Islamic Arabs traditionally set out for travel or war during it.'),
  WordEntry('RABIULAWWAL', 'Rabi\' al-Awwal',
      'The third month, traditionally linked to the birth of the Prophet Muhammad ﷺ.'),
  WordEntry('RABIULTHANI', 'Rabi\' al-Thani',
      'The fourth month of the Islamic year.'),
  WordEntry('JUMADALAWWAL', 'Jumada al-Awwal',
      'The fifth month; its name means "dry", from when it once fell in a dry season.'),
  WordEntry('JUMADALTHANI', 'Jumada al-Thani',
      'The sixth month of the Islamic year.'),
  WordEntry('RAJAB', 'Rajab',
      'The seventh month, and another of the four sacred months.'),
  WordEntry('SHABAN', 'Sha\'ban',
      'The eighth month — a time many Muslims spend preparing for Ramadan.'),
  WordEntry('RAMADAN', 'Ramadan',
      'The ninth month, in which Muslims fast from dawn to sunset.'),
  WordEntry('SHAWWAL', 'Shawwal',
      'The tenth month, which begins with Eid al-Fitr.'),
  WordEntry('DHULQADAH', 'Dhul-Qa\'dah',
      'The eleventh month, and a sacred month in which fighting was traditionally forbidden.'),
  WordEntry('DHULHIJJAH', 'Dhul-Hijjah',
      'The twelfth month, during which the Hajj pilgrimage and Eid al-Adha take place.'),
];
