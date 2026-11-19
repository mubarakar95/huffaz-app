import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:huffaz_app/models/student.dart';
import 'package:huffaz_app/models/sabaq_log.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp12');
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
  
  print('=== STUDENTS MATCHING ABDULLAH / ABULLAH ===');
  Student? targetStudent;
  for (final s in students) {
    if (s.fullName.toLowerCase().contains('abullah') || s.fullName.toLowerCase().contains('abdullah')) {
      print('ID: ${s.id} | Name: ${s.fullName} | Teacher ID: ${s.teacherId}');
      targetStudent = s;
    }
  }
  
  if (targetStudent != null) {
    print('\n=== LOGS FOR STUDENT ${targetStudent.fullName} ===');
    final sLogs = logs.where((l) => l.studentId == targetStudent!.id).toList();
    sLogs.sort((a, b) => b.date.compareTo(a.date));
    for (int i = 0; i < 10 && i < sLogs.length; i++) {
      final l = sLogs[i];
      print('Log ID: ${l.id} | Date: ${l.date} | Status: ${l.status} | Sabaq: "${l.sabaq}" | Teacher: "${l.teacherName}" (${l.teacherId})');
    }
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
