import 'package:huffaz_app/models/sabaq_log.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';
import 'dart:math';

// Helper mimicking getPagesFromSabaqString
List<int> getPagesFromSabaqStringMock(String sabaqStr) {
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
  return [];
}

// Helper mimicking getJuzMilestoneForStudent
int? getJuzMilestoneForStudentMock(List<SabaqLog> logs) {
  final sabaqLogsWithPage = <Map<String, dynamic>>[];
  for (final l in logs) {
    if (l.sabaq != null && l.sabaq!.isNotEmpty) {
      final pages = getPagesFromSabaqStringMock(l.sabaq!);
      final maxP = pages.isNotEmpty ? pages.reduce((a, b) => a > b ? a : b) : 0;
      if (maxP > 0) {
        sabaqLogsWithPage.add({'log': l, 'date': l.date, 'pNum': maxP, 'status': l.status});
      }
    }
  }

  int? activeJuzId;

  if (sabaqLogsWithPage.isNotEmpty) {
    sabaqLogsWithPage.sort((a, b) {
      final dateCmp = (b['date'] as String).compareTo(a['date'] as String);
      if (dateCmp != 0) return dateCmp;
      if (a['status'] == 'baseline_sabqi' && b['status'] != 'baseline_sabqi') return -1;
      if (b['status'] == 'baseline_sabqi' && a['status'] != 'baseline_sabqi') return 1;
      return (b['pNum'] as int).compareTo(a['pNum'] as int);
    });

    final latestActivePage = sabaqLogsWithPage[0]['pNum'] as int;
    final info = getSabaqiPageInfo(latestActivePage);
    final rawJuz = info['juz'] as int? ?? 1;

    final endPageOfJuz = rawJuz == 30 ? 604 : (rawJuz * 20 + 1);
    final latestSabaqStr = (sabaqLogsWithPage[0]['log'] as SabaqLog).sabaq ?? '';

    bool isCompleted = latestActivePage >= endPageOfJuz;
    if (!isCompleted && (latestSabaqStr.contains('Surah An-Nas') || latestSabaqStr.contains('Khatam'))) {
      isCompleted = true;
    }

    if (isCompleted) {
      final memorizedPages = <int>{};
      for (final log in logs) {
        final sabaqPages = getPagesFromSabaqStringMock(log.sabaq);
        memorizedPages.addAll(sabaqPages);
      }

      bool isJuzCompleted(int juzNum) {
        final juzPages = getPagesForJuz(juzNum);
        if (juzPages.isEmpty) return false;
        final count = juzPages.where((p) => memorizedPages.contains(p)).length;
        return count >= (juzPages.length * 0.8);
      }

      int nextForwards = rawJuz + 1;
      while (nextForwards <= 30 && isJuzCompleted(nextForwards)) {
        nextForwards++;
      }
      activeJuzId = nextForwards <= 30 ? nextForwards : rawJuz;
    } else {
      activeJuzId = rawJuz;
    }
  }

  return activeJuzId;
}

// Helper mimicking _computeSuggestedSabaq
({int surahNum, int ayahNum}) computeSuggestedSabaqMock(
    List<SabaqLog> logs, int? activeJuzId, String targetDate) {
  final logsWithPages = <({SabaqLog log, int pageNum})>[];
  for (final l in logs) {
    if (l.date.compareTo(targetDate) > 0) continue;
    if (l.sabaq.isEmpty) continue;
    if (l.sabaq.startsWith('[SKIPPED')) continue;
    final pages = getPagesFromSabaqStringMock(l.sabaq);
    if (pages.isEmpty) continue;
    final pageNum = pages.last;
    logsWithPages.add((log: l, pageNum: pageNum));
  }

  if (logsWithPages.isEmpty) {
    print('logsWithPages is empty!');
    if (activeJuzId != null && activeJuzId >= 1 && activeJuzId <= 30) {
      final juzInfo = getJuzInfo(activeJuzId);
      final startSurah = findQuranSurah(juzInfo.startSurah);
      if (startSurah != null) {
        return (surahNum: startSurah.number, ayahNum: juzInfo.startAyah);
      }
    }
    return (surahNum: 1, ayahNum: 1);
  }

  logsWithPages.sort((a, b) {
    final dateCmp = b.log.date.compareTo(a.log.date);
    if (dateCmp != 0) return dateCmp;
    if (a.log.status == 'baseline_sabqi' && b.log.status != 'baseline_sabqi') return -1;
    if (b.log.status == 'baseline_sabqi' && a.log.status != 'baseline_sabqi') return 1;
    return b.pageNum.compareTo(a.pageNum);
  });
  final latest = logsWithPages.first;

  print('latest log: ${latest.log.date} | status: ${latest.log.status} | page: ${latest.pageNum}');

  if (activeJuzId != null && activeJuzId >= 1 && activeJuzId <= 30) {
    final latestJuz = getJuzForPage(latest.pageNum);
    if (latestJuz != activeJuzId) {
      print('Juz transition: latestJuz=$latestJuz, activeJuzId=$activeJuzId');
      final juzInfo = getJuzInfo(activeJuzId);
      final startSurah = findQuranSurah(juzInfo.startSurah);
      if (startSurah != null) {
        return (surahNum: startSurah.number, ayahNum: juzInfo.startAyah);
      }
    }
  }

  final segments = latest.log.sabaq.split(' | ');
  final lastSegment = segments.last;

  final nextPage = (latest.pageNum + 1).clamp(1, 604);
  for (final s in quranSurahs) {
    for (int a = 1; a <= s.ayahCount; a++) {
      if (getPageForAyah(s.number, a) == nextPage) {
        return (surahNum: s.number, ayahNum: a);
      }
    }
  }

  return (surahNum: 1, ayahNum: 1);
}

void main() {
  print('Result for [BASELINE_SABAQI] [Page 20]: ${getPagesFromSabaqString("[BASELINE_SABAQI] [Page 20]")}');
  print('Result for [BASELINE] [Page 604]: ${getPagesFromSabaqString("[BASELINE] [Page 604]")}');
}
