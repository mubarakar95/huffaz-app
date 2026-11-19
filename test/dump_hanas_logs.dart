import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:huffaz_app/models/sabaq_log.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp4');
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
  
  // Hanas ID: 25afd221-3f94-4d20-b4fe-3faa1fa0cb6c
  final sLogs = logs.where((l) => l.studentId == '25afd221-3f94-4d20-b4fe-3faa1fa0cb6c').toList();
  sLogs.sort((a, b) => b.date.compareTo(a.date));
  
  for (final l in sLogs) {
    if (l.sabaq.isNotEmpty) {
      print('Date: ${l.date} | Status: ${l.status} | CreatedAt: ${l.createdAt} | Sabaq: "${l.sabaq}"');
    }
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
