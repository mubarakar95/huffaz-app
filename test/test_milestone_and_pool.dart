import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:huffaz_app/providers/app_provider.dart';
import 'package:huffaz_app/models/student.dart';
import 'package:huffaz_app/models/sabaq_log.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';

void main() {
  test('debug getSabqiPagesForStudent exactly', () async {
    final currentDir = Directory.current.path;
    final tempDir = Directory('$currentDir/test_hive_temp5');
    if (!tempDir.existsSync()) {
      tempDir.createSync();
    }
    
    final studentsFile = File('$currentDir/test/students.hive');
    final logsFile = File('$currentDir/test/logs.hive');
    studentsFile.copySync('${tempDir.path}/students.hive');
    logsFile.copySync('${tempDir.path}/logs.hive');
    
    Hive.init(tempDir.path);
    final studentsBox = await Hive.openBox('students');
    final logsBox = await Hive.openBox('logs');
    
    final studentsJsonStr = studentsBox.get('students');
    final logsJsonStr = logsBox.get('logs');
    
    final List<dynamic> studentsList = jsonDecode(studentsJsonStr);
    final List<dynamic> allLogsList = jsonDecode(logsJsonStr);
    
    final List<Student> students = studentsList.map((m) => Student.fromMap(Map<String, dynamic>.from(m))).toList();
    final List<SabaqLog> logs = allLogsList.map((m) => SabaqLog.fromMap(Map<String, dynamic>.from(m))).toList();
    
    for (final s in students) {
      if (s.fullName.toLowerCase().contains('hanas') || s.fullName.toLowerCase().contains('aslah')) {
        print('==================================================');
        print('STUDENT: ${s.fullName} (ID: ${s.id})');
        
        final sLogs = logs.where((l) => l.studentId == s.id).toList();
        final todayStr = getLocalToday();

        // Exact copy of getSabqiPagesForStudent logic:
        final sabaqLogs = sLogs.where((l) =>
          l.sabaq != null &&
          l.sabaq.isNotEmpty &&
          (l.date.compareTo(todayStr) <= 0 || l.status == 'baseline_sabqi' || l.status == 'baseline')
        ).toList();

        sabaqLogs.sort((a, b) {
          final cmp = b.createdAt.compareTo(a.createdAt);
          if (cmp != 0) return cmp;
          return b.date.compareTo(a.date);
        });

        print('sabaqLogs sorted first 5:');
        for (int i = 0; i < 5 && i < sabaqLogs.length; i++) {
          print('  Date: ${sabaqLogs[i].date} | Status: ${sabaqLogs[i].status} | CreatedAt: ${sabaqLogs[i].createdAt} | Sabaq: "${sabaqLogs[i].sabaq}"');
        }

        final seen = <int>{};
        final uniqueSabaqPages = <int>[];

        for (final log in sabaqLogs) {
          final pages = getPagesFromSabaqString(log.sabaq);
          for (final p in pages) {
            if (!seen.contains(p)) {
              seen.add(p);
              uniqueSabaqPages.add(p);
            }
          }
        }

        int? activeJuzId;
        if (uniqueSabaqPages.isNotEmpty) {
          final latestPage = uniqueSabaqPages.first;
          final info = getSabaqiPageInfo(latestPage);
          activeJuzId = info['juz'] as int?;
          print('latestPage: $latestPage, computed activeJuzId: $activeJuzId');
        }

        if (activeJuzId != null) {
          final allowedJuzs = {activeJuzId, activeJuzId - 1};
          uniqueSabaqPages.removeWhere((pageNum) {
            final j = getSabaqiPageInfo(pageNum)['juz'] as int?;
            return j == null || !allowedJuzs.contains(j);
          });
        }

        final sabaqParaPages = uniqueSabaqPages.take(20).toList();
        print('sabaqParaPages pool: $sabaqParaPages');
      }
    }
    
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
