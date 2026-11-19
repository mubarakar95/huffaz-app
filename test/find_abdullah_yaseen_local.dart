import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp18');
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
  
  final studentsJsonStr = studentsBox.get('students') as String;
  final logsJsonStr = logsBox.get('logs') as String;
  
  final List<dynamic> studentsList = jsonDecode(studentsJsonStr);
  final List<dynamic> allLogsList = jsonDecode(logsJsonStr);
  
  // Find Abdullah under Yaseen
  final abdullah = studentsList.firstWhere(
    (s) => s['fullName'].toString().toLowerCase().contains('abdullah') && s['teacherName'].toString().toLowerCase().contains('yaseen'),
    orElse: () => null
  );
  
  if (abdullah != null) {
    print('Student details: $abdullah');
    final sId = abdullah['id'];
    
    final sLogs = allLogsList.where((l) => l['student_id'] == sId || l['studentId'] == sId).toList();
    sLogs.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
    
    print('\n=== RECENT LOGS FOR ABDULLAH UNDER YASEEN ===');
    for (final l in sLogs) {
      if (l['date'].toString().compareTo('2026-08-01') >= 0) {
        print('Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}" | TeacherId: ${l['teacher_id']} | LogID: ${l['id']}');
      }
    }
  } else {
    print('Abdullah under Yaseen not found!');
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
