import 'package:supabase/supabase.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';
import 'dart:math';
import 'dart:io';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

// Mock implementations using actual project functions
List<int> getPagesFromSabaqStringMock(String sabaqStr) {
  final res = getPagesFromSabaqString(sabaqStr);
  print('    getPagesFromSabaqStringMock("$sabaqStr") returned $res');
  return res;
}

int? getJuzMilestoneForStudentMock(List<Map<String, dynamic>> logs) {
  final sabaqLogsWithPage = <Map<String, dynamic>>[];
  for (final l in logs) {
    final sabaq = l['sabaq'] as String?;
    if (sabaq != null && sabaq.isNotEmpty) {
      final pages = getPagesFromSabaqStringMock(sabaq);
      final maxP = pages.isNotEmpty ? pages.reduce((a, b) => a > b ? a : b) : 0;
      if (maxP > 0) {
        sabaqLogsWithPage.add({'log': l, 'date': l['date'], 'pNum': maxP, 'status': l['status']});
      }
    }
  }

  if (sabaqLogsWithPage.isEmpty) return 1;

  sabaqLogsWithPage.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  print('Sorted sabaqLogsWithPage (first 5):');
  for (var i = 0; i < min(sabaqLogsWithPage.length, 5); i++) {
    print('  [$i] Date: ${sabaqLogsWithPage[i]['date']} | status: ${sabaqLogsWithPage[i]['status']} | pNum: ${sabaqLogsWithPage[i]['pNum']}');
  }
  final latestActivePage = sabaqLogsWithPage[0]['pNum'] as int;
  final info = getSabaqiPageInfo(latestActivePage);
  final rawJuz = info['juz'] as int? ?? 1;
  final endPageOfJuz = rawJuz == 30 ? 604 : (rawJuz * 20 + 1);
  bool isCompleted = latestActivePage >= endPageOfJuz;
  print('latestActivePage: $latestActivePage, rawJuz: $rawJuz, endPageOfJuz: $endPageOfJuz, isCompleted: $isCompleted');
  int? activeJuzId;

  if (isCompleted) {
    print('Entering isCompleted block');
    final memorizedPages = <int>{};
    for (final l in logs) {
      final sabaq = l['sabaq'] as String?;
      if (sabaq != null) {
        memorizedPages.addAll(getPagesFromSabaqStringMock(sabaq));
      }
    }

    bool isJuzCompleted(int juzNum) {
      final juzPages = getPagesForJuz(juzNum);
      if (juzPages.isEmpty) return false;
      final count = juzPages.where((p) => memorizedPages.contains(p)).length;
      final isComp = count >= (juzPages.length * 0.8);
      print('  isJuzCompleted($juzNum): count=$count/${juzPages.length}, isComp=$isComp');
      return isComp;
    }

    int nextForwards = rawJuz + 1;
    while (nextForwards <= 30 && isJuzCompleted(nextForwards)) {
      nextForwards++;
    }

    int nextBackwards = rawJuz - 1;
    while (nextBackwards >= 1 && isJuzCompleted(nextBackwards)) {
      nextBackwards--;
    }

    print('nextForwards: $nextForwards, nextBackwards: $nextBackwards');

    if (nextForwards > 30 && nextBackwards < 1) {
      activeJuzId = rawJuz;
    } else if (nextForwards > 30) {
      activeJuzId = nextBackwards;
    } else if (nextBackwards < 1) {
      activeJuzId = nextForwards;
    } else {
      activeJuzId = nextForwards;
    }
    print('Assigned activeJuzId in isCompleted block: $activeJuzId');
  } else {
    print('Entering else block');
    activeJuzId = rawJuz;
    print('Assigned activeJuzId in else block: $activeJuzId');
  }

  print('RETURNING FROM getJuzMilestoneForStudentMock: $activeJuzId');
  return activeJuzId ?? 1;
}

({int surahNum, int ayahNum}) computeSuggestedSabaqMock(
    List<Map<String, dynamic>> logs, int? activeJuzId, String targetDate) {
  final logsWithPages = <({Map<String, dynamic> log, int pageNum})>[];
  for (final l in logs) {
    final date = l['date'] as String;
    final sabaq = l['sabaq'] as String? ?? '';
    final status = l['status'] as String? ?? '';
    if (date.compareTo(targetDate) > 0) {
      print('  Skipped: date $date > targetDate $targetDate');
      continue;
    }
    if (sabaq.isEmpty) {
      print('  Skipped: sabaq is empty');
      continue;
    }
    if (sabaq.startsWith('[SKIPPED')) {
      print('  Skipped: starts with [SKIPPED');
      continue;
    }
    final pages = getPagesFromSabaqStringMock(sabaq);
    print('  Log sabaq: "$sabaq" -> parsed pages: $pages');
    if (pages.isEmpty) {
      continue;
    }
    final pageNum = pages.last;
    logsWithPages.add((log: l, pageNum: pageNum));
  }

  if (logsWithPages.isEmpty) {
    print('computeSuggestedSabaqMock: logsWithPages is empty!');
    if (activeJuzId != null && activeJuzId >= 1 && activeJuzId <= 30) {
      final juzInfo = getJuzInfo(activeJuzId);
      final startSurah = findQuranSurah(juzInfo.startSurah);
      if (startSurah != null) {
        return (surahNum: startSurah.number, ayahNum: juzInfo.startAyah);
      }
    }
    return (surahNum: 1, ayahNum: 1);
  }
  print('computeSuggestedSabaqMock: logsWithPages length is ${logsWithPages.length}');
  for (var i = 0; i < min(logsWithPages.length, 5); i++) {
    print('  [$i] date: ${logsWithPages[i].log['date']} | status: ${logsWithPages[i].log['status']} | pageNum: ${logsWithPages[i].pageNum} | sabaq: ${logsWithPages[i].log['sabaq']}');
  }

  logsWithPages.sort((a, b) {
    final dateCmp = (b.log['date'] as String).compareTo(a.log['date'] as String);
    if (dateCmp != 0) return dateCmp;
    
    final statusA = a.log['status'] as String;
    final statusB = b.log['status'] as String;
    if (statusA == 'baseline_sabqi' && statusB != 'baseline_sabqi') return -1;
    if (statusB == 'baseline_sabqi' && statusA != 'baseline_sabqi') return 1;
    
    return b.pageNum.compareTo(a.pageNum);
  });
  
  final latest = logsWithPages.first;
  final latestStatus = latest.log['status'] as String;
  final latestSabaq = latest.log['sabaq'] as String;

  if (activeJuzId != null && activeJuzId >= 1 && activeJuzId <= 30) {
    final latestJuz = getJuzForPage(latest.pageNum);
    if (latestJuz != activeJuzId) {
      final juzInfo = getJuzInfo(activeJuzId);
      final startSurah = findQuranSurah(juzInfo.startSurah);
      if (startSurah != null) {
        return (surahNum: startSurah.number, ayahNum: juzInfo.startAyah);
      }
    }
  }

  final segments = latestSabaq.split(' | ');
  final lastSegment = segments.last;

  final matchA = RegExp(r'Surah\s+(.*?)\s+\(Ayah\s+(\d+)-(\d+)\)').firstMatch(lastSegment);
  if (matchA != null) {
    final sName = matchA.group(1) ?? '';
    final toAyah = int.tryParse(matchA.group(3) ?? '') ?? 1;
    final s = findQuranSurah(sName);
    if (s != null) {
      if (toAyah < s.ayahCount) {
        return (surahNum: s.number, ayahNum: toAyah + 1);
      } else {
        final nextSurahNum = s.number + 1;
        if (nextSurahNum <= 114) {
          return (surahNum: nextSurahNum, ayahNum: 1);
        }
      }
    }
  }

  final matchB = RegExp(r'^(.*?)\s+\(\d+\)\s+to\s+(.*?)\s+\((\d+)\)').firstMatch(lastSegment);
  if (matchB != null) {
    final toSName = matchB.group(2) ?? '';
    final toAyah = int.tryParse(matchB.group(3) ?? '') ?? 1;
    final s = findQuranSurah(toSName);
    if (s != null) {
      if (toAyah < s.ayahCount) {
        return (surahNum: s.number, ayahNum: toAyah + 1);
      } else {
        final nextSurahNum = s.number + 1;
        if (nextSurahNum <= 114) {
          return (surahNum: nextSurahNum, ayahNum: 1);
        }
      }
    }
  }

  final nextPage = (latest.pageNum + 1).clamp(1, 604);
  print('computeSuggestedSabaqMock: latest.pageNum = ${latest.pageNum}, nextPage = $nextPage');
  for (final s in quranSurahs) {
    for (int a = 1; a <= s.ayahCount; a++) {
      if (getPageForAyah(s.number, a) == nextPage) {
        print('  Found next page at Surah ${s.number} (${s.name}), Ayah $a');
        return (surahNum: s.number, ayahNum: a);
      }
    }
  }

  print('  Next page NOT found in loop!');
  return (surahNum: 1, ayahNum: 1);
}

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  final studentRes = await client.from('students').select('*').limit(50);
  for (var s in studentRes) {
    print('Student: ${s['full_name']} | ID: ${s['id']}');
  }
  exit(0);
  
  final student = studentRes.first;
  final studentId = student['id'];
  
  final logsRes = await client.from('sabaq_logs').select('*').eq('student_id', studentId).order('date', ascending: false);
  final List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(logsRes);
  print('TOTAL LOGS FOR ${student['full_name']}: ${logs.length}');
  
  for (var i = 0; i < min(logs.length, 50); i++) {
    final l = logs[i];
    print('[$i] Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}"');
  }
  
  final activeJuzId = getJuzMilestoneForStudentMock(logs);
  print('activeJuzId: $activeJuzId');
  
  final suggestion = computeSuggestedSabaqMock(logs, activeJuzId, '2026-08-22');
  print('SUGGESTED NEXT SABAQ: Surah ${suggestion.surahNum}, Ayah ${suggestion.ayahNum}');
}
