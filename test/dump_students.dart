import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';
import 'dart:math';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp2');
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
  
  final buffer = StringBuffer();
  
  for (var s in studentsList) {
    final name = s['fullName']?.toString() ?? s['full_name']?.toString() ?? '';
    final studentId = s['id']?.toString() ?? '';
    
    if (name.toLowerCase().contains('hanas') || name.toLowerCase().contains('aslah')) {
      buffer.writeln('==================================================');
      buffer.writeln('FOUND STUDENT: $name (ID: $studentId)');
      buffer.writeln('Raw student data: $s');
      
      final studentLogs = allLogsList.where((l) => l['student_id'] == studentId || l['studentId'] == studentId).toList();
      buffer.writeln('Total logs found: ${studentLogs.length}');
      
      buffer.writeln('Latest 15 logs:');
      studentLogs.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      for (int i = 0; i < min(studentLogs.length, 15); i++) {
        final l = studentLogs[i];
        buffer.writeln('  Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}" | Manzil: "${l['manzil']}"');
      }

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

      buffer.writeln('All unique sabaq pages before filtering: $uniqueSabaqPages');

      int? activeJuzId;
      if (uniqueSabaqPages.isNotEmpty) {
        final latestPage = uniqueSabaqPages.first;
        final info = getSabaqiPageInfo(latestPage);
        activeJuzId = info['juz'] as int?;
        buffer.writeln('Latest memorized page: $latestPage, activeJuzId: $activeJuzId');
      }

      if (activeJuzId != null) {
        final allowedJuzs = {activeJuzId, activeJuzId - 1};
        buffer.writeln('Allowed Juzs: $allowedJuzs');
        
        final poolPages = List<int>.from(uniqueSabaqPages);
        poolPages.removeWhere((pageNum) {
          final j = getSabaqiPageInfo(pageNum)['juz'] as int?;
          return j == null || !allowedJuzs.contains(j);
        });
        buffer.writeln('Pages after restricting to allowed Juzs: $poolPages');
        
        final sabaqParaPages = poolPages.take(20).toList();
        buffer.writeln('Final sabaqParaPages (Sabaq Para Pool - up to 20): $sabaqParaPages');
      }
    }
  }
  
  File('$currentDir/test/dump_output.txt').writeAsStringSync(buffer.toString());
  print('Dump complete! Written to test/dump_output.txt');
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
