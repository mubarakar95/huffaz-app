import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:huffaz_app/providers/app_provider.dart';
import 'package:huffaz_app/models/student.dart';
import 'package:huffaz_app/models/sabaq_log.dart';
import 'package:huffaz_app/utils/quran_data.dart';

void main() {
  test('debug provider methods', () async {
    final currentDir = Directory.current.path;
    final tempDir = Directory('$currentDir/test_hive_temp3');
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
        print('Logs count: ${sLogs.length}');
        
        // 1. Filter sabaq logs (excluding baseline completed Juzs, keeping daily sabaq and baseline_sabqi)
        final sabaqLogsWithPage = <Map<String, dynamic>>[];
        for (final l in sLogs) {
          if (l.sabaq.isNotEmpty && l.status != 'baseline') {
            final pages = getPagesFromSabaqString(l.sabaq);
            final maxP = pages.isNotEmpty ? pages.reduce((a, b) => a > b ? a : b) : 0;
            if (maxP > 0) {
              sabaqLogsWithPage.add({'log': l, 'date': l.date, 'pNum': maxP, 'status': l.status, 'createdAt': l.createdAt});
            }
          }
        }
        
        print('sabaqLogsWithPage length: ${sabaqLogsWithPage.length}');
        if (sabaqLogsWithPage.isNotEmpty) {
          sabaqLogsWithPage.sort((a, b) {
            final cmp = (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime);
            if (cmp != 0) return cmp;
            return (b['pNum'] as int).compareTo(a['pNum'] as int);
          });
          final latestActivePage = sabaqLogsWithPage[0]['pNum'] as int;
          final info = getSabaqiPageInfo(latestActivePage);
          final rawJuz = info['juz'] as int? ?? 1;
          print('latestActivePage: $latestActivePage, rawJuz: $rawJuz');
          
          final endPageOfJuz = rawJuz == 30 ? 604 : (rawJuz * 20 + 1);
          final latestSabaqStr = (sabaqLogsWithPage[0]['log'] as SabaqLog).sabaq;
          bool isCompleted = latestActivePage >= endPageOfJuz;
          if (!isCompleted && (latestSabaqStr.contains('Surah An-Nas') || latestSabaqStr.contains('Khatam'))) {
            isCompleted = true;
          }
          print('isCompleted: $isCompleted');
        }
      }
    }
    
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
