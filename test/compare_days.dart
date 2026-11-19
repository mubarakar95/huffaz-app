import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:huffaz_app/models/sabaq_log.dart';

void main() {
  test('inspect createdAt dates', () async {
    final currentDir = Directory.current.path;
    final tempDir = Directory('$currentDir/test_hive_temp8');
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
    
    for (final l in sLogs) {
      if (l.sabaq.contains('Page 20') || l.sabaq.contains('Page 21') || l.sabaq.contains('Page 36') || l.sabaq.contains('Page 37')) {
        print('Date: ${l.date} | Status: ${l.status} | CreatedAt: ${l.createdAt.toIso8601String()} | Sabaq: "${l.sabaq}"');
      }
    }
    
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
