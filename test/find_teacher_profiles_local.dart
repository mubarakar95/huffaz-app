import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp19');
  if (!tempDir.existsSync()) {
    tempDir.createSync();
  }
  
  final studentsFile = File('$currentDir/test/students.hive');
  studentsFile.copySync('${tempDir.path}/students.hive');
  
  Hive.init(tempDir.path);
  final studentsBox = await Hive.openBox('students');
  
  final detailsStr = studentsBox.get('details') as String?;
  if (detailsStr != null) {
    final Map<String, dynamic> decoded = jsonDecode(detailsStr);
    final Map<String, Map<String, dynamic>> profiles = {};
    for (final sData in decoded.values) {
      final student = sData['student'];
      if (student != null) {
        final profile = student['profiles'];
        if (profile != null) {
          profiles[profile['id'] ?? 'null'] = Map<String, dynamic>.from(profile);
        }
      }
    }
    
    print('=== ALL TEACHER PROFILES FOUND IN HIVE ===');
    for (final pId in profiles.keys) {
      print('Teacher ID: $pId | Data: ${profiles[pId]}');
    }
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
