import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:huffaz_app/models/student.dart';
import 'package:huffaz_app/models/sabaq_log.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp13');
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
  
  // Find all teachers from logs (since we don't have direct teacher records easily, we can find teacher names in logs, or check students' profiles)
  print('=== CHECKING STUDENTS WITH NAME ABDULLAH / ABULLAH ===');
  for (final s in students) {
    if (s.fullName.toLowerCase().contains('abdullah') || s.fullName.toLowerCase().contains('abullah')) {
      final sLogs = logs.where((l) => l.studentId == s.id).toList();
      print('Student: ${s.fullName} (ID: ${s.id})');
      print('  Assigned Teacher ID on Student Profile: ${s.teacherId}');
      
      // Look at the teacher names in the logs of this student
      final teacherNames = sLogs.map((l) => l.teacherName).toSet().toList();
      print('  Teacher names in logs: $teacherNames');
      
      final sabaqHeardBy = sLogs.map((l) {
        if (l.sabaq.contains('Heard by:')) {
          final match = RegExp(r'Heard by:\s*([^\s"]+)').firstMatch(l.sabaq);
          return match?.group(1);
        }
        return null;
      }).where((name) => name != null).toSet().toList();
      print('  Heard by names in Sabaq logs: $sabaqHeardBy');
      
      if (sLogs.isNotEmpty) {
        sLogs.sort((a, b) => b.date.compareTo(a.date));
        print('  Latest Log: Date: ${sLogs[0].date} | Status: ${sLogs[0].status} | Sabaq: "${sLogs[0].sabaq}" | Teacher ID: ${sLogs[0].teacherId}');
      }
    }
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
