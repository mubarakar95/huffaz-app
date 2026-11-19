import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp16');
  if (!tempDir.existsSync()) {
    tempDir.createSync();
  }
  
  final studentsFile = File('$currentDir/test/students.hive');
  studentsFile.copySync('${tempDir.path}/students.hive');
  
  Hive.init(tempDir.path);
  final studentsBox = await Hive.openBox('students');
  
  final details = studentsBox.get('details') as String?;
  if (details != null) {
    final Map<String, dynamic> decoded = jsonDecode(details);
    final Set<String> teachersInfo = {};
    for (final sId in decoded.keys) {
      final sData = decoded[sId];
      final profile = sData['student']?['profiles'];
      if (profile != null) {
        teachersInfo.add('ID: ${profile['id']} | Name: ${profile['full_name']}');
      }
    }
    print('=== TEACHERS IN DETAILS ===');
    for (final t in teachersInfo) {
      print(t);
    }
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
