import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:huffaz_app/models/sabaq_log.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp11');
  if (!tempDir.existsSync()) {
    tempDir.createSync();
  }
  
  final logsFile = File('$currentDir/test/logs.hive');
  logsFile.copySync('${tempDir.path}/logs.hive');
  
  Hive.init(tempDir.path);
  final logsBox = await Hive.openBox('logs');
  
  final logsJsonStr = logsBox.get('logs');
  final List<dynamic> allLogsList = jsonDecode(logsJsonStr);
  final List<SabaqLog> logs = allLogsList.map((m) => SabaqLog.fromMap(Map<String, dynamic>.from(m))).toList();
  
  final sLogs = logs.where((l) => l.studentId == '25afd221-3f94-4d20-b4fe-3faa1fa0cb6c' && l.date == '2026-08-25').toList();
  
  for (final l in sLogs) {
    print('Date: ${l.date}');
    print('Sabaq: ${l.sabaq}');
    print('Manzil raw: ${l.manzil}');
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
