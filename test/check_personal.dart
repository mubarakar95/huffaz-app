import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp20');
  if (!tempDir.existsSync()) {
    tempDir.createSync();
  }
  
  final studentsFile = File('$currentDir/test/students.hive');
  studentsFile.copySync('${tempDir.path}/students.hive');
  
  Hive.init(tempDir.path);
  final studentsBox = await Hive.openBox('students');
  final studentsJsonStr = studentsBox.get('students') as String;
  final List<dynamic> studentsList = jsonDecode(studentsJsonStr);
  
  for (final s in studentsList) {
    if (s['fullName'].toString().toLowerCase().contains('abdullah')) {
      print('Name: ${s['fullName']} | ID: ${s['id']} | teacherName: ${s['teacherName']} | isPersonal: ${s['isPersonal']}');
    }
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
