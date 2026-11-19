import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';
import 'dart:math';

void main() {
  test('read local hive boxes and debug Hanas and Aslah', () async {
    final currentDir = Directory.current.path;
    print('Current directory: $currentDir');
    
    // Copy hive files to a temporary directory so Hive can open them
    final tempDir = Directory('$currentDir/test_hive_temp');
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
    
    // Fetch students list from box
    final studentsJsonStr = studentsBox.get('students');
    if (studentsJsonStr == null) {
      print('No students found in box!');
      return;
    }
    
    final List<dynamic> studentsList = jsonDecode(studentsJsonStr);
    print('Loaded ${studentsList.length} students from local box.');

    // Fetch all logs from logs box
    final logsJsonStr = logsBox.get('logs');
    if (logsJsonStr == null) {
      print('No logs found in box!');
      return;
    }
    final List<dynamic> allLogsList = jsonDecode(logsJsonStr);
    print('Loaded ${allLogsList.length} logs from local box.');

    for (var s in studentsList) {
      final name = s['fullName']?.toString() ?? s['full_name']?.toString() ?? '';
      final studentId = s['id']?.toString() ?? '';
      
      if (name.toLowerCase().contains('hanas') || name.toLowerCase().contains('aslah')) {
        print('==================================================');
        print('FOUND STUDENT: $name (ID: $studentId)');
        print('Raw student data: $s');
        
        // Filter logs for this student
        final studentLogs = allLogsList.where((l) => l['student_id'] == studentId || l['studentId'] == studentId).toList();
        print('Total logs found: ${studentLogs.length}');
        
        // Let's print the top 15 logs
        print('Latest 15 logs:');
        studentLogs.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
        for (int i = 0; i < min(studentLogs.length, 15); i++) {
          final l = studentLogs[i];
          print('  Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}" | Manzil: "${l['manzil']}"');
        }

        // Run the active Juz and Sabaq Para logic
        final sabaqLogs = studentLogs.where((l) =>
          l['sabaq'] != null &&
          l['sabaq'].toString().isNotEmpty
        ).toList();

        final seen = <int>{};
        final uniqueSabaqPages = <int>[];

        for (final log in sabaqLogs) {
          final sabaqVal = log['sabaq']?.toString() ?? '';
          final pages = getPagesFromSabaqString(sabaqVal);
          for (final p in pages) {
            if (!seen.contains(p)) {
              seen.add(p);
              uniqueSabaqPages.add(p);
            }
          }
        }

        print('All unique sabaq pages before filtering: $uniqueSabaqPages');

        int? activeJuzId;
        if (uniqueSabaqPages.isNotEmpty) {
          final latestPage = uniqueSabaqPages.first;
          final info = getSabaqiPageInfo(latestPage);
          activeJuzId = info['juz'] as int?;
          print('Latest memorized page: $latestPage, activeJuzId: $activeJuzId');
        }

        if (activeJuzId != null) {
          final allowedJuzs = {activeJuzId, activeJuzId - 1};
          print('Allowed Juzs: $allowedJuzs');
          
          final poolPages = List<int>.from(uniqueSabaqPages);
          poolPages.removeWhere((pageNum) {
            final j = getSabaqiPageInfo(pageNum)['juz'] as int?;
            return j == null || !allowedJuzs.contains(j);
          });
          print('Pages after restricting to allowed Juzs (Juz $activeJuzId & Juz ${activeJuzId - 1}): $poolPages');
          
          final sabaqParaPages = poolPages.take(20).toList();
          print('Final sabaqParaPages (Sabaq Para Pool - up to 20): $sabaqParaPages');
        }
      }
    }
    
    // Cleanup temp files
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
