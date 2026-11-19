import 'dart:math';
import 'student_utils.dart'; // To reuse getJuzForPage
import 'quran_data_mapping.dart';

class QuranSurah {
  final int number;
  final String name;
  final int ayahCount;
  final int startPage;

  const QuranSurah({
    required this.number,
    required this.name,
    required this.ayahCount,
    required this.startPage,
  });
}

const List<QuranSurah> quranSurahs = [
  QuranSurah(number: 1, name: 'Al-Fatihah', ayahCount: 7, startPage: 1),
  QuranSurah(number: 2, name: 'Al-Baqarah', ayahCount: 286, startPage: 2),
  QuranSurah(number: 3, name: "Ali 'Imran", ayahCount: 200, startPage: 50),
  QuranSurah(number: 4, name: 'An-Nisa', ayahCount: 176, startPage: 77),
  QuranSurah(number: 5, name: 'Al-Ma\'idah', ayahCount: 120, startPage: 106),
  QuranSurah(number: 6, name: 'Al-An\'am', ayahCount: 165, startPage: 128),
  QuranSurah(number: 7, name: 'Al-A\'raf', ayahCount: 206, startPage: 151),
  QuranSurah(number: 8, name: 'Al-Anfal', ayahCount: 75, startPage: 177),
  QuranSurah(number: 9, name: 'At-Tawbah', ayahCount: 129, startPage: 187),
  QuranSurah(number: 10, name: 'Yunus', ayahCount: 109, startPage: 208),
  QuranSurah(number: 11, name: 'Hud', ayahCount: 123, startPage: 221),
  QuranSurah(number: 12, name: 'Yusuf', ayahCount: 111, startPage: 235),
  QuranSurah(number: 13, name: 'Ar-Ra\'d', ayahCount: 43, startPage: 249),
  QuranSurah(number: 14, name: 'Ibrahim', ayahCount: 52, startPage: 255),
  QuranSurah(number: 15, name: 'Al-Hijr', ayahCount: 99, startPage: 262),
  QuranSurah(number: 16, name: 'An-Nahl', ayahCount: 128, startPage: 267),
  QuranSurah(number: 17, name: 'Al-Isra', ayahCount: 111, startPage: 282),
  QuranSurah(number: 18, name: 'Al-Kahf', ayahCount: 110, startPage: 293),
  QuranSurah(number: 19, name: 'Maryam', ayahCount: 98, startPage: 305),
  QuranSurah(number: 20, name: 'Ta-Ha', ayahCount: 135, startPage: 312),
  QuranSurah(number: 21, name: 'Al-Anbiya', ayahCount: 112, startPage: 322),
  QuranSurah(number: 22, name: 'Al-Hajj', ayahCount: 78, startPage: 332),
  QuranSurah(number: 23, name: 'Al-Mu\'minun', ayahCount: 118, startPage: 342),
  QuranSurah(number: 24, name: 'An-Nur', ayahCount: 64, startPage: 350),
  QuranSurah(number: 25, name: 'Al-Furqan', ayahCount: 77, startPage: 359),
  QuranSurah(number: 26, name: 'Ash-Shu\'ara', ayahCount: 227, startPage: 367),
  QuranSurah(number: 27, name: 'An-Naml', ayahCount: 93, startPage: 377),
  QuranSurah(number: 28, name: 'Al-Qasas', ayahCount: 88, startPage: 385),
  QuranSurah(number: 29, name: 'Al-\'Ankabut', ayahCount: 69, startPage: 396),
  QuranSurah(number: 30, name: 'Ar-Rum', ayahCount: 60, startPage: 404),
  QuranSurah(number: 31, name: 'Luqman', ayahCount: 34, startPage: 411),
  QuranSurah(number: 32, name: 'As-Sajdah', ayahCount: 30, startPage: 415),
  QuranSurah(number: 33, name: 'Al-Ahzab', ayahCount: 73, startPage: 418),
  QuranSurah(number: 34, name: 'Saba', ayahCount: 54, startPage: 428),
  QuranSurah(number: 35, name: 'Fatir', ayahCount: 45, startPage: 434),
  QuranSurah(number: 36, name: 'Ya-Sin', ayahCount: 83, startPage: 440),
  QuranSurah(number: 37, name: 'As-Saffat', ayahCount: 182, startPage: 446),
  QuranSurah(number: 38, name: 'Sad', ayahCount: 88, startPage: 453),
  QuranSurah(number: 39, name: 'Az-Zumar', ayahCount: 75, startPage: 458),
  QuranSurah(number: 40, name: 'Ghafir', ayahCount: 85, startPage: 467),
  QuranSurah(number: 41, name: 'Fussilat', ayahCount: 54, startPage: 477),
  QuranSurah(number: 42, name: 'Ash-Shura', ayahCount: 53, startPage: 483),
  QuranSurah(number: 43, name: 'Az-Zukhruf', ayahCount: 89, startPage: 489),
  QuranSurah(number: 44, name: 'Ad-Dukhan', ayahCount: 59, startPage: 496),
  QuranSurah(number: 45, name: 'Al-Jathiyah', ayahCount: 37, startPage: 499),
  QuranSurah(number: 46, name: 'Al-Ahqaf', ayahCount: 35, startPage: 502),
  QuranSurah(number: 47, name: 'Muhammad', ayahCount: 38, startPage: 507),
  QuranSurah(number: 48, name: 'Al-Fath', ayahCount: 29, startPage: 511),
  QuranSurah(number: 49, name: 'Al-Hujurat', ayahCount: 18, startPage: 515),
  QuranSurah(number: 50, name: 'Qaf', ayahCount: 45, startPage: 518),
  QuranSurah(number: 51, name: 'Adh-Dhariyat', ayahCount: 60, startPage: 520),
  QuranSurah(number: 52, name: 'At-Tur', ayahCount: 49, startPage: 523),
  QuranSurah(number: 53, name: 'An-Najm', ayahCount: 62, startPage: 526),
  QuranSurah(number: 54, name: 'Al-Qamar', ayahCount: 55, startPage: 528),
  QuranSurah(number: 55, name: 'Ar-Rahman', ayahCount: 78, startPage: 531),
  QuranSurah(number: 56, name: 'Al-Waqi\'ah', ayahCount: 96, startPage: 534),
  QuranSurah(number: 57, name: 'Al-Hadid', ayahCount: 29, startPage: 537),
  QuranSurah(number: 58, name: 'Al-Mujadila', ayahCount: 22, startPage: 542),
  QuranSurah(number: 59, name: 'Al-Hashr', ayahCount: 24, startPage: 545),
  QuranSurah(number: 60, name: 'Al-Mumtahanah', ayahCount: 13, startPage: 549),
  QuranSurah(number: 61, name: 'As-Saf', ayahCount: 14, startPage: 551),
  QuranSurah(number: 62, name: 'Al-Jumu\'ah', ayahCount: 11, startPage: 553),
  QuranSurah(number: 63, name: 'Al-Munafiqun', ayahCount: 11, startPage: 554),
  QuranSurah(number: 64, name: 'At-Taghabun', ayahCount: 18, startPage: 556),
  QuranSurah(number: 65, name: 'At-Talaq', ayahCount: 12, startPage: 558),
  QuranSurah(number: 66, name: 'At-Tahrim', ayahCount: 12, startPage: 560),
  QuranSurah(number: 67, name: 'Al-Mulk', ayahCount: 30, startPage: 562),
  QuranSurah(number: 68, name: 'Al-Qalam', ayahCount: 52, startPage: 564),
  QuranSurah(number: 69, name: 'Al-Haqqah', ayahCount: 52, startPage: 566),
  QuranSurah(number: 70, name: 'Al-Ma\'arij', ayahCount: 44, startPage: 568),
  QuranSurah(number: 71, name: 'Nuh', ayahCount: 28, startPage: 570),
  QuranSurah(number: 72, name: 'Al-Jinn', ayahCount: 28, startPage: 572),
  QuranSurah(number: 73, name: 'Al-Muzzammil', ayahCount: 20, startPage: 574),
  QuranSurah(number: 74, name: 'Al-Muddaththir', ayahCount: 56, startPage: 575),
  QuranSurah(number: 75, name: 'Al-Qiyamah', ayahCount: 40, startPage: 577),
  QuranSurah(number: 76, name: 'Al-Insan', ayahCount: 31, startPage: 578),
  QuranSurah(number: 77, name: 'Al-Mursalat', ayahCount: 50, startPage: 580),
  QuranSurah(number: 78, name: 'An-Naba', ayahCount: 40, startPage: 582),
  QuranSurah(number: 79, name: 'An-Nazi\'at', ayahCount: 46, startPage: 583),
  QuranSurah(number: 80, name: 'Abasa', ayahCount: 42, startPage: 585),
  QuranSurah(number: 81, name: 'At-Takwir', ayahCount: 29, startPage: 586),
  QuranSurah(number: 82, name: 'Al-Infitar', ayahCount: 19, startPage: 587),
  QuranSurah(number: 83, name: 'Al-Mutaffifin', ayahCount: 36, startPage: 587),
  QuranSurah(number: 84, name: 'Al-Inshiqaq', ayahCount: 25, startPage: 589),
  QuranSurah(number: 85, name: 'Al-Buruj', ayahCount: 22, startPage: 590),
  QuranSurah(number: 86, name: 'At-Tariq', ayahCount: 17, startPage: 591),
  QuranSurah(number: 87, name: 'Al-A\'la', ayahCount: 19, startPage: 591),
  QuranSurah(number: 88, name: 'Al-Ghashiyah', ayahCount: 26, startPage: 592),
  QuranSurah(number: 89, name: 'Al-Fajr', ayahCount: 30, startPage: 593),
  QuranSurah(number: 90, name: 'Al-Balad', ayahCount: 20, startPage: 594),
  QuranSurah(number: 91, name: 'Ash-Shams', ayahCount: 15, startPage: 595),
  QuranSurah(number: 92, name: 'Al-Layl', ayahCount: 21, startPage: 595),
  QuranSurah(number: 93, name: 'Ad-Duha', ayahCount: 11, startPage: 596),
  QuranSurah(number: 94, name: 'Ash-Sharh', ayahCount: 8, startPage: 596),
  QuranSurah(number: 95, name: 'At-Tin', ayahCount: 8, startPage: 597),
  QuranSurah(number: 96, name: 'Al-Alaq', ayahCount: 19, startPage: 597),
  QuranSurah(number: 97, name: 'Al-Qadr', ayahCount: 5, startPage: 598),
  QuranSurah(number: 98, name: 'Al-Bayyinah', ayahCount: 8, startPage: 598),
  QuranSurah(number: 99, name: 'Az-Zalzalah', ayahCount: 8, startPage: 599),
  QuranSurah(number: 100, name: 'Al-Adiyat', ayahCount: 11, startPage: 599),
  QuranSurah(number: 101, name: 'Al-Qari\'ah', ayahCount: 11, startPage: 600),
  QuranSurah(number: 102, name: 'At-Takathur', ayahCount: 8, startPage: 600),
  QuranSurah(number: 103, name: 'Al-Asr', ayahCount: 3, startPage: 601),
  QuranSurah(number: 104, name: 'Al-Humazah', ayahCount: 9, startPage: 601),
  QuranSurah(number: 105, name: 'Al-Fil', ayahCount: 5, startPage: 601),
  QuranSurah(number: 106, name: 'Quraysh', ayahCount: 4, startPage: 602),
  QuranSurah(number: 107, name: 'Al-Ma\'un', ayahCount: 7, startPage: 602),
  QuranSurah(number: 108, name: 'Al-Kawthar', ayahCount: 3, startPage: 602),
  QuranSurah(number: 109, name: 'Al-Kafirun', ayahCount: 6, startPage: 603),
  QuranSurah(number: 110, name: 'An-Nasr', ayahCount: 3, startPage: 603),
  QuranSurah(number: 111, name: 'Al-Masad', ayahCount: 5, startPage: 603),
  QuranSurah(number: 112, name: 'Al-Ikhlas', ayahCount: 4, startPage: 604),
  QuranSurah(number: 113, name: 'Al-Falaq', ayahCount: 5, startPage: 604),
  QuranSurah(number: 114, name: 'An-Nas', ayahCount: 6, startPage: 604),
];

int getSurahEndPage(int surahNum) {
  if (surahNum < 1 || surahNum > 114) return 604;
  if (surahNum == 114) return 604;
  return quranSurahs[surahNum].startPage - 1;
}

int getPageForAyah(int surahNum, int ayahNum) {
  if (surahNum < 1 || surahNum > 114) return 1;
  final mapping = quranPageMappings[surahNum - 1];
  if (ayahNum < 1 || ayahNum >= mapping.ayahsToPage.length) {
    return mapping.ayahsToPage.last;
  }
  return mapping.ayahsToPage[ayahNum];
}

String getSurahName(int surahNum) {
  if (surahNum < 1 || surahNum > 114) return '';
  return quranSurahs[surahNum - 1].name;
}

({int surahNum, int ayahNum}) calculateEndAyahByPages(int startSurah, int startAyah, double targetPages) {
  if (startSurah < 1 || startSurah > 114) return (surahNum: startSurah, ayahNum: startAyah);
  
  final startPage = getPageForAyah(startSurah, startAyah);
  
  // Calculate if the start ayah is at the beginning of startPage
  final firstAyahOfStartPage = getFirstAyahOnPage(startPage);
  final isStartOfPage = startSurah == firstAyahOfStartPage.surahNum && startAyah == firstAyahOfStartPage.ayahNum;
  
  // If we start in the middle of a page, that page only counts as a fraction.
  // To reach a target page count (like 2.0 pages, meaning the rest of the current page + 1 full page),
  // we adjust the targetPage to land exactly where the user expects.
  // When targetPages is 1.0, 2.0, etc., and we start mid-page, targetPage should be:
  // startPage + targetPages - 1 (rounded up/down depending on start position).
  // Specifically, if start is mid-page, and target is 2.0, the end should be the end of startPage + 1 page = startPage + 1.
  final targetPage = isStartOfPage
      ? (startPage + targetPages - 1).floor()
      : (startPage + targetPages - 1).floor(); // E.g. startPage=10, target=2.0 -> targetPage = 11.
  
  int finalSurah = startSurah;
  int finalAyah = startAyah;
  
  for (int sIdx = startSurah - 1; sIdx < 114; sIdx++) {
    final s = quranSurahs[sIdx];
    final firstPage = getPageForAyah(s.number, 1);
    if (firstPage > targetPage) break;
    
    finalSurah = s.number;
    for (int a = 1; a <= s.ayahCount; a++) {
      final p = getPageForAyah(s.number, a);
      if (p == targetPage) {
        finalAyah = a;
      } else if (p > targetPage) {
        break;
      }
    }
  }
  
  return (surahNum: finalSurah, ayahNum: finalAyah);
}

({int surahNum, int ayahNum}) getFirstAyahOnPage(int page) {
  for (int sIdx = 0; sIdx < 114; sIdx++) {
    final s = quranSurahs[sIdx];
    final lastPage = getPageForAyah(s.number, s.ayahCount);
    if (lastPage < page) continue;
    
    for (int a = 1; a <= s.ayahCount; a++) {
      if (getPageForAyah(s.number, a) == page) {
        return (surahNum: s.number, ayahNum: a);
      }
    }
  }
  return (surahNum: 1, ayahNum: 1);
}

QuranSurah? findQuranSurah(String name) {
  final cleanInput = name.trim();
  const Map<String, String> juzSurahMap = {
    'Al-Faatiha': 'Al-Fatiha',
    'Al-Baqara': 'Al-Baqarah',
    'Aal-i-Imraan': "Ali 'Imran",
    'Al-Maaida': "Al-Ma'idah",
    "Al-An'aam": "Al-An'am",
    "Al-A'raaf": "Al-A'raf",
    'Al-Anfaal': 'Al-Anfal',
    'At-Tawba': 'At-Tawbah',
    'Hood': 'Hud',
    'Yoosuf': 'Yusuf',
    'Al-Muminoon': "Al-Mu'minun",
    'Al-Furqaan': 'Al-Furqan',
    'Al-Ankaboot': "Al-'Ankabut",
    'Al-Ahzaab': 'Al-Ahzab',
    'Ya-Seen': 'Ya-Sin',
    'Az-Zariyat': 'Adh-Dhariyat',
    'Al-Mujaadila': 'Al-Mujadila',
  };
  final mappedName = juzSurahMap[cleanInput] ?? cleanInput;
  final cleanName = mappedName.replaceAll(RegExp(r"['\-\s]"), '').toLowerCase();
  for (final s in quranSurahs) {
    final cleanS = s.name.replaceAll(RegExp(r"['\-\s]"), '').toLowerCase();
    if (cleanS == cleanName) return s;
  }
  for (final s in quranSurahs) {
    final cleanS = s.name.replaceAll(RegExp(r"['\-\s]"), '').toLowerCase();
    if (cleanS.contains(cleanName) || cleanName.contains(cleanS)) return s;
  }
  return null;
}

List<int> getPagesInRange(int startSurah, int startAyah, int endSurah, int endAyah) {
  if (startSurah < 1 || startSurah > 114 || endSurah < 1 || endSurah > 114) return [];
  final Set<int> pages = {};
  for (int sNum = startSurah; sNum <= endSurah; sNum++) {
    final sAyah = (sNum == startSurah) ? startAyah : 1;
    final eAyah = (sNum == endSurah) ? endAyah : quranSurahs[sNum - 1].ayahCount;
    for (int a = sAyah; a <= eAyah; a++) {
      final p = getPageForAyah(sNum, a);
      if (p >= 1 && p <= 604) {
        pages.add(p);
      }
    }
  }
  final sorted = pages.toList()..sort();
  return sorted;
}

double calculatePageSpanFromAyahs(int startSurah, int startAyah, int endSurah, int endAyah) {
  final startPage = getPageForAyah(startSurah, startAyah);
  final endPage = getPageForAyah(endSurah, endAyah);
  
  int getTotalAyahsOnPage(int page) {
    int count = 0;
    for (int sNum = 1; sNum <= 114; sNum++) {
      final mapping = quranPageMappings[sNum - 1];
      for (int a = 1; a < mapping.ayahsToPage.length; a++) {
        if (mapping.ayahsToPage[a] == page) {
          count++;
        }
      }
    }
    return count;
  }

  int getSelectedAyahsOnPage(int page) {
    int count = 0;
    for (int sNum = startSurah; sNum <= endSurah; sNum++) {
      final mapping = quranPageMappings[sNum - 1];
      final sAyah = (sNum == startSurah) ? startAyah : 1;
      final eAyah = (sNum == endSurah) ? endAyah : mapping.ayahsToPage.length - 1;
      for (int a = sAyah; a <= eAyah; a++) {
        if (mapping.ayahsToPage[a] == page) {
          count++;
        }
      }
    }
    return count;
  }

  double totalSpan = 0.0;
  for (int p = startPage; p <= endPage; p++) {
    final totalAyahs = getTotalAyahsOnPage(p);
    if (totalAyahs == 0) continue;
    
    final selectedAyahs = getSelectedAyahsOnPage(p);
    totalSpan += selectedAyahs / totalAyahs.toDouble();
  }
  return totalSpan;
}

double getPagesCountFromSabaqString(String sabaqStr) {
  if (sabaqStr.isEmpty) return 0.0;
  if (sabaqStr.contains('[SKIPPED')) return 0.0;
  
  final match = RegExp(r'\((\d+(\.\d+)?)\s*Page[s]?\)').firstMatch(sabaqStr);
  if (match != null) {
    final val = double.tryParse(match.group(1) ?? '');
    if (val != null) return val;
  }
  
  return getPagesFromSabaqString(sabaqStr).length.toDouble();
}

List<int> getPagesFromSabaqString(String sabaqStr) {
  if (sabaqStr.startsWith('[SKIPPED') || sabaqStr.trim().isEmpty) return [];

  if (sabaqStr.startsWith('[BASELINE]') || sabaqStr.startsWith('[BASELINE_SABAQI]')) {
    final cleanStr = sabaqStr
        .replaceAll('[BASELINE]', '')
        .replaceAll('[BASELINE_SABAQI]', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .trim();
    
    final List<int> pages = [];
    final matches = RegExp(r'(\d+)(?:\s*-\s*(\d+))?').allMatches(cleanStr);
    for (final m in matches) {
      final start = int.tryParse(m.group(1) ?? '') ?? 0;
      final end = m.group(2) != null ? (int.tryParse(m.group(2)!) ?? start) : start;
      if (start > 0) {
        for (int p = min(start, end); p <= max(start, end); p++) {
          if (p >= 1 && p <= 604) pages.add(p);
        }
      }
    }
    return pages..sort();
  }

  // 1. Check Juz range / reference: e.g. "Juz 1", "Juz 1 to 5", "Juz 1-5"
  final juzMatches = RegExp(r'Juz\s+(\d+)(?:\s*(?:to|-)\s*(?:Juz\s*)?(\d+))?', caseSensitive: false).allMatches(sabaqStr);
  if (juzMatches.isNotEmpty) {
    final Set<int> juzPages = {};
    for (final m in juzMatches) {
      final j1 = int.tryParse(m.group(1) ?? '');
      final j2 = int.tryParse(m.group(2) ?? '') ?? j1;
      if (j1 != null && j2 != null) {
        int startJuz = min(j1, j2).clamp(1, 30);
        int endJuz = max(j1, j2).clamp(1, 30);
        for (int j = startJuz; j <= endJuz; j++) {
          juzPages.addAll(getPagesForJuz(j));
        }
      }
    }
    if (juzPages.isNotEmpty) {
      return juzPages.toList()..sort();
    }
  }

  final parts = sabaqStr.split(' | ');
  final List<int> allPages = [];

  for (final part in parts) {
    // A. Prioritize exact [Page N] and (X Page) tags from sabaq string if present
    final pageMatch = RegExp(r'\[Page (\d+)(?:-(\d+))?\]').firstMatch(part);
    if (pageMatch != null) {
      final startPage = int.tryParse(pageMatch.group(1) ?? '') ?? 0;
      final endPage = pageMatch.group(2) != null ? (int.tryParse(pageMatch.group(2)!) ?? startPage) : startPage;
      if (startPage > 0) {
        if (pageMatch.group(2) != null) {
          // Explicit range: parse all pages in this range (ignore fractional counts)
          for (int p = min(startPage, endPage); p <= max(startPage, endPage); p++) {
            if (p >= 1 && !allPages.contains(p)) allPages.add(p);
          }
        } else {
          // Single page: check if there's a page count to loop back (e.g. 2 Page)
          final countMatch = RegExp(r'(\d+(?:\.\d+)?) Page').firstMatch(part);
          if (countMatch != null) {
            final count = double.parse(countMatch.group(1)!).ceil();
            for (int i = 0; i < count; i++) {
              final p = endPage - i;
              if (p >= 1 && !allPages.contains(p)) allPages.add(p);
            }
          } else {
            if (!allPages.contains(endPage)) allPages.add(endPage);
          }
        }
      }
      continue; // Success! Skip format regexes to prevent wrong estimation
    }

    bool matched = false;

    // Format A: "Surah Al-Baqara (Ayah 1-7)"
    final matchA = RegExp(r'Surah\s+(.*?)\s+\(Ayah\s+(\d+)-(\d+)\)').firstMatch(part);
    if (matchA != null) {
      final surahName = matchA.group(1)?.trim() ?? '';
      final aFrom = int.tryParse(matchA.group(2) ?? '') ?? 1;
      final aTo = int.tryParse(matchA.group(3) ?? '') ?? 1;
      final surah = findQuranSurah(surahName);
      if (surah != null) {
        final pages = getPagesInRange(surah.number, aFrom, surah.number, aTo);
        for (final p in pages) {
          if (!allPages.contains(p)) allPages.add(p);
        }
        matched = true;
      }
    }

    if (!matched) {
      // Format B: "Al-Baqara (286) to Ali 'Imran (10)"
      final matchB = RegExp(r'^(.*?)\s*\((\d+)\)\s+to\s+(.*?)\s*\((\d+)\)').firstMatch(part);
      if (matchB != null) {
        final s1Name = matchB.group(1)?.trim() ?? '';
        final a1 = int.tryParse(matchB.group(2) ?? '') ?? 1;
        final s2Name = matchB.group(3)?.trim() ?? '';
        final a2 = int.tryParse(matchB.group(4) ?? '') ?? 1;
        final surah1 = findQuranSurah(s1Name);
        final surah2 = findQuranSurah(s2Name);
        if (surah1 != null && surah2 != null) {
          final pages = getPagesInRange(surah1.number, a1, surah2.number, a2);
          for (final p in pages) {
            if (!allPages.contains(p)) allPages.add(p);
          }
          matched = true;
        }
      }
    }

    if (!matched && pageMatch != null) {
      final startPage = int.tryParse(pageMatch.group(1) ?? '') ?? 0;
      final endPage = pageMatch.group(2) != null ? (int.tryParse(pageMatch.group(2)!) ?? startPage) : startPage;
      for (int p = min(startPage, endPage); p <= max(startPage, endPage); p++) {
        if (p >= 1 && !allPages.contains(p)) allPages.add(p);
      }
    }
  }

  allPages.sort();
  return allPages;
}

Map<String, dynamic> getSabaqiPageInfo(int page) {
  int juz = getJuzForPage(page);
  
  String surahName = '';
  for (int i = 0; i < quranSurahs.length; i++) {
    if (quranSurahs[i].startPage <= page && page <= getSurahEndPage(quranSurahs[i].number)) {
      surahName = quranSurahs[i].name;
      break;
    }
  }
  
  return {
    'juz': juz,
    'surahName': surahName,
  };
}

Map<int, List<Map<String, dynamic>>> getJuzSurahsMap() {
  Map<int, List<Map<String, dynamic>>> map = {};
  
  for (var surah in quranSurahs) {
    int startJuz = getJuzForPage(surah.startPage);
    int endJuz = getJuzForPage(getSurahEndPage(surah.number));
    
    for (int j = startJuz; j <= endJuz; j++) {
      if (!map.containsKey(j)) {
        map[j] = [];
      }
      map[j]!.add({
        'surahNum': surah.number,
        'surahName': surah.name,
        'startPage': surah.startPage,
        'endPage': getSurahEndPage(surah.number),
      });
    }
  }
  
  return map;
}

class JuzData {
  final int id;
  final String name;
  final String arabicName;
  final String startSurah;
  final int startAyah;

  const JuzData({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.startSurah,
    required this.startAyah,
  });
}

const List<JuzData> juzData = [
  JuzData(id: 1, name: 'Alif Lam Meem', arabicName: 'الم', startSurah: 'Al-Faatiha', startAyah: 1),
  JuzData(id: 2, name: 'Sayaqool', arabicName: 'سيقول', startSurah: 'Al-Baqara', startAyah: 142),
  JuzData(id: 3, name: 'Tilkal Rusull', arabicName: 'تلك الرسل', startSurah: 'Al-Baqara', startAyah: 253),
  JuzData(id: 4, name: 'Lan Tana Loo', arabicName: 'لن تنالوا', startSurah: 'Aal-i-Imraan', startAyah: 93),
  JuzData(id: 5, name: 'Wal Mohsanat', arabicName: 'والمحصنات', startSurah: 'An-Nisaa', startAyah: 24),
  JuzData(id: 6, name: 'La Yuhibbullah', arabicName: 'لا يحب الله', startSurah: 'An-Nisaa', startAyah: 148),
  JuzData(id: 7, name: 'Wa Iza Samiu', arabicName: 'وإذا سمعوا', startSurah: 'Al-Maaida', startAyah: 82),
  JuzData(id: 8, name: 'Wa Lau Annana', arabicName: 'ولو أننا', startSurah: 'Al-An\'aam', startAyah: 111),
  JuzData(id: 9, name: 'Qalal Malao', arabicName: 'قال الملأ', startSurah: 'Al-A\'raaf', startAyah: 88),
  JuzData(id: 10, name: 'Wa A\'lamu', arabicName: 'واعلموا', startSurah: 'Al-Anfaal', startAyah: 41),
  JuzData(id: 11, name: 'Yatazeroon', arabicName: 'يعتذرون', startSurah: 'At-Tawba', startAyah: 93),
  JuzData(id: 12, name: 'Wa Mamin Da\'abat', arabicName: 'وما من دابة', startSurah: 'Hood', startAyah: 6),
  JuzData(id: 13, name: 'Wa Ma Ubrioo', arabicName: 'وما أبرئ', startSurah: 'Yoosuf', startAyah: 53),
  JuzData(id: 14, name: 'Rubama', arabicName: 'ربما', startSurah: 'Al-Hijr', startAyah: 1),
  JuzData(id: 15, name: 'Subhanallazi', arabicName: 'سبحان الذي', startSurah: 'Al-Israa', startAyah: 1),
  JuzData(id: 16, name: 'Qal Alam', arabicName: 'قال ألم', startSurah: 'Al-Kahf', startAyah: 75),
  JuzData(id: 17, name: 'Iqtaraba', arabicName: 'اقترب', startSurah: 'Al-Anbiyaa', startAyah: 1),
  JuzData(id: 18, name: 'Qadd Aflaha', arabicName: 'قد أفلح', startSurah: 'Al-Muminoon', startAyah: 1),
  JuzData(id: 19, name: 'Wa Qalallazina', arabicName: 'وقال الذين', startSurah: 'Al-Furqaan', startAyah: 21),
  JuzData(id: 20, name: 'A\'man Khalaqa', arabicName: 'أمن خلق', startSurah: 'An-Naml', startAyah: 56),
  JuzData(id: 21, name: 'Utlu Ma Oohiya', arabicName: 'اتل ما أوحي', startSurah: 'Al-Ankaboot', startAyah: 46),
  JuzData(id: 22, name: 'Wa Manyaqnut', arabicName: 'ومن يقنت', startSurah: 'Al-Ahzaab', startAyah: 31),
  JuzData(id: 23, name: 'Wa Mali', arabicName: 'ومالي', startSurah: 'Ya-Seen', startAyah: 28),
  JuzData(id: 24, name: 'Faman Azlamu', arabicName: 'فمن أظلم', startSurah: 'Az-Zumar', startAyah: 32),
  JuzData(id: 25, name: 'Ilayhi Yuraddu', arabicName: 'إليه يرد', startSurah: 'Fussilat', startAyah: 47),
  JuzData(id: 26, name: 'Ha\'a Meem', arabicName: 'حم', startSurah: 'Al-Ahqaf', startAyah: 1),
  JuzData(id: 27, name: 'Qala Fama Khatbukum', arabicName: 'قال فما خطبكم', startSurah: 'Az-Zariyat', startAyah: 31),
  JuzData(id: 28, name: 'Qadd Sami Allah', arabicName: 'قد سمع الله', startSurah: 'Al-Mujaadila', startAyah: 1),
  JuzData(id: 29, name: 'Tabarakallazi', arabicName: 'تبارك الذي', startSurah: 'Al-Mulk', startAyah: 1),
  JuzData(id: 30, name: 'Amma Yatasa\'aloon', arabicName: 'عم يتساءلون', startSurah: 'An-Naba', startAyah: 1),
];

JuzData getJuzInfo(int juzId) {
  if (juzId < 1 || juzId > 30) return juzData[0];
  return juzData[juzId - 1];
}
