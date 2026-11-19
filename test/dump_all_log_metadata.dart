import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:huffaz_app/models/sabaq_log.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp9');
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
  
  final sLogs = logs.where((l) => l.studentId == '25afd221-3f94-4d20-b4fe-3faa1fa0cb6c').toList();
  sLogs.sort((a, b) => b.date.compareTo(a.date));
  
  final buffer = StringBuffer();
  for (final l in sLogs) {
    buffer.writeln('Date: ${l.date} | Status: ${l.status} | CreatedAt: ${l.createdAt.toIso8601String()} | Sabaq: "${l.sabaq}"');
  }
  
  File('$currentDir/test/hanas_all_logs.txt').writeAsStringSync(buffer.toString());
  print('Dump complete. Written to test/hanas_all_logs.txt');
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
