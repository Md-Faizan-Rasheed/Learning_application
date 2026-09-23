/// One entry in a "Today's ___" home-screen card: an Arabic phrase/hadith/
/// ayah, its widely-published English rendering, and (for hadith/ayat) a
/// source reference.
///
/// [arabic] is deliberately nullable: for phrases (everyday expressions)
/// exact wording is low-stakes, but hadith and Qur'an text is transmitted
/// scripture where a single misremembered diacritic matters — so this file
/// only fills in Arabic script for the handful of short, extremely
/// well-known entries below, and otherwise leaves it null (the card falls
/// back to showing just the English translation + reference). Every entry
/// here is still a good-faith best effort and, being religious content, is
/// worth a scholarly spot-check before being treated as authoritative — the
/// same standard applied to `names_of_allah.dart`.
class DailyEntry {
  const DailyEntry(this.english, {this.arabic, this.reference});

  final String english;
  final String? arabic;
  final String? reference;
}

const kDailyPhrases = <DailyEntry>[
  DailyEntry('Peace be upon you', arabic: 'السلام عليكم'),
  DailyEntry('May Allah bless you', arabic: 'بارك الله فيك'),
  DailyEntry('God willing', arabic: 'إن شاء الله'),
  DailyEntry('Praise be to Allah', arabic: 'الحمد لله'),
  DailyEntry('May Allah reward you with good', arabic: 'جزاك الله خيرا'),
  DailyEntry('Good morning', arabic: 'صباح الخير'),
  DailyEntry('Go with peace / goodbye', arabic: 'مع السلامة'),
  DailyEntry('Thank you very much', arabic: 'شكرا جزيلا'),
  DailyEntry('Welcome', arabic: 'أهلا وسهلا'),
  DailyEntry('May every year find you well', arabic: 'كل عام وأنتم بخير'),
  DailyEntry('Seeker of knowledge', arabic: 'طالب العلم'),
  DailyEntry('Knowledge is light', arabic: 'العلم نور'),
];

const kDailyHadiths = <DailyEntry>[
  DailyEntry(
    'Actions are judged by intentions, and every person will get what they intended.',
    arabic: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
    reference: 'Sahih al-Bukhari 1 · Sahih Muslim 1907',
  ),
  DailyEntry(
    'The best among you are those who learn the Qur\'an and teach it.',
    arabic: 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
    reference: 'Sahih al-Bukhari 5027',
  ),
  DailyEntry(
    'None of you truly believes until he loves for his brother what he loves for himself.',
    arabic: 'لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ',
    reference: 'Sahih al-Bukhari 13 · Sahih Muslim 45',
  ),
  DailyEntry(
    'Smiling at your brother is charity.',
    reference: 'Jami at-Tirmidhi 1956',
  ),
  DailyEntry(
    'Cleanliness is half of faith.',
    arabic: 'الطُّهُورُ شَطْرُ الْإِيمَانِ',
    reference: 'Sahih Muslim 223',
  ),
  DailyEntry(
    'The strong person is not the one who can wrestle, but the one who controls himself when angry.',
    reference: 'Sahih al-Bukhari 6114',
  ),
  DailyEntry(
    'Whoever believes in Allah and the Last Day should speak good or remain silent.',
    arabic: 'مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الْآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ',
    reference: 'Sahih al-Bukhari 6018',
  ),
  DailyEntry(
    'The believer who reads the Qur\'an is like a citron: its fragrance is sweet and its taste is sweet.',
    reference: 'Sahih al-Bukhari 5059 · Sahih Muslim 797',
  ),
  DailyEntry(
    'Modesty is a branch of faith.',
    arabic: 'الْحَيَاءُ شُعْبَةٌ مِنَ الْإِيمَانِ',
    reference: 'Sahih al-Bukhari 9 · Sahih Muslim 35',
  ),
  DailyEntry(
    'Seeking knowledge is an obligation upon every Muslim.',
    arabic: 'طَلَبُ الْعِلْمِ فَرِيضَةٌ عَلَى كُلِّ مُسْلِمٍ',
    reference: 'Sunan Ibn Majah 224',
  ),
  DailyEntry(
    'A good word is charity.',
    arabic: 'الْكَلِمَةُ الطَّيِّبَةُ صَدَقَةٌ',
    reference: 'Sahih al-Bukhari 2989 · Sahih Muslim 1009',
  ),
  DailyEntry(
    'The most beloved of deeds to Allah are those that are most consistent, even if small.',
    reference: 'Sahih al-Bukhari 6465 · Sahih Muslim 782',
  ),
];

const kDailyAyats = <DailyEntry>[
  DailyEntry(
    'Allah does not burden a soul beyond that it can bear.',
    arabic: 'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
    reference: 'Al-Baqarah 2:286',
  ),
  DailyEntry(
    'Indeed, with hardship [will be] ease.',
    arabic: 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
    reference: 'Ash-Sharh 94:5',
  ),
  DailyEntry(
    'Say, "He is Allah, [who is] One."',
    arabic: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
    reference: 'Al-Ikhlas 112:1',
  ),
  DailyEntry(
    'It is You we worship and You we ask for help.',
    arabic: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
    reference: 'Al-Fatiha 1:5',
  ),
  DailyEntry(
    'And whoever relies upon Allah — then He is sufficient for him.',
    arabic: 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
    reference: 'At-Talaq 65:3',
  ),
  DailyEntry(
    'Verily, in the remembrance of Allah do hearts find rest.',
    arabic: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
    reference: 'Ar-Ra\'d 13:28',
  ),
  DailyEntry(
    'Indeed, Allah is with the patient.',
    arabic: 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
    reference: 'Al-Baqarah 2:153',
  ),
  DailyEntry(
    'So remember Me; I will remember you.',
    arabic: 'فَاذْكُرُونِي أَذْكُرْكُمْ',
    reference: 'Al-Baqarah 2:152',
  ),
  DailyEntry(
    'No fear will there be concerning the allies of Allah, nor will they grieve.',
    reference: 'Yunus 10:62',
  ),
  DailyEntry(
    'But perhaps you hate a thing and it is good for you.',
    arabic: 'وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ',
    reference: 'Al-Baqarah 2:216',
  ),
  DailyEntry(
    'And cooperate in righteousness and piety.',
    arabic: 'وَتَعَاوَنُوا عَلَى الْبِرِّ وَالتَّقْوَىٰ',
    reference: 'Al-Ma\'idah 5:2',
  ),
  DailyEntry(
    'And be kind to your parents.',
    reference: 'Al-Isra 17:23',
  ),
];

/// Deterministic index into a pool of length [poolLength] for "today" —
/// the same day-of-year calculation across all three "Today's ___" cards,
/// so each one advances automatically at midnight with no stored state and
/// no network call, and (for a given pool) is identical for every player on
/// the same calendar day.
int dailyIndexFor(int poolLength, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
  return dayOfYear % poolLength;
}
