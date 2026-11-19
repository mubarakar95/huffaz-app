import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp15');
  if (!tempDir.existsSync()) {
    tempDir.createSync();
  }
  
  final studentsFile = File('$currentDir/test/students.hive');
  studentsFile.copySync('${tempDir.path}/students.hive');
  
  Hive.init(tempDir.path);
  final studentsBox = await Hive.openBox('students');
  
  print('=== DUMPING ALL KEYS IN students.hive ===');
  for (final key in studentsBox.keys) {
    print('Key: $key');
    final val = studentsBox.get(key);
    if (val is String) {
      if (val.length > 500) {
        print('  Value (truncated): ${val.substring(0, 500)}...');
      } else {
        print('  Value: $val');
      }
    } else {
      print('  Value Type: ${val.runtimeType}');
    }
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
