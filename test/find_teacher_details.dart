import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp14');
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
  
  // Let's print the logged-in user profile if stored in Hive
  print('=== CHECKING HIVE BOXES FOR LOGGED IN USER ===');
  for (final key in studentsBox.keys) {
    if (key.toString().contains('profile') || key.toString().contains('user')) {
      print('studentsBox Key: $key | Value: ${studentsBox.get(key)}');
    }
  }
  
  // Let's check profiles key if any
  try {
    final profilesBox = await Hive.openBox('profiles');
    print('profilesBox keys: ${profilesBox.keys}');
  } catch (_) {}

  // Let's dump all teacher names found in sabaq logs
  final logsJsonStr = logsBox.get('logs');
  final List<dynamic> allLogsList = jsonDecode(logsJsonStr);
  final Set<String> teachers = {};
  for (final l in allLogsList) {
    final tName = l['teacherName'] ?? l['profiles']?['full_name'];
    if (tName != null) {
      teachers.add(tName.toString());
    }
  }
  print('\n=== ALL TEACHERS FOUND IN LOGS ===');
  print(teachers.toList());
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
