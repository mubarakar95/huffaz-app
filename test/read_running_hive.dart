import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:hive/hive.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp24');
  if (!tempDir.existsSync()) {
    tempDir.createSync();
  }
  
  print('Streaming settings.hive from emulator as binary bytes...');
  final res = Process.runSync('adb', [
    'shell',
    'run-as',
    'com.huffaz.huffaz_app',
    'cat',
    '/data/data/com.huffaz.huffaz_app/app_flutter/settings.hive'
  ], stdoutEncoding: null); // stdoutEncoding: null makes stdout a List<int>
  
  if (res.exitCode == 0 && res.stdout != null) {
    final bytes = res.stdout as List<int>;
    print('Successfully received ${bytes.length} bytes.');
    
    File('$currentDir/test/settings.hive').writeAsBytesSync(bytes);
    
    Hive.init(tempDir.path);
    final settingsBox = await Hive.openBox('settings', bytes: Uint8List.fromList(bytes));
    
    print('=== DUMPING ALL KEYS IN settings.hive ===');
    for (final key in settingsBox.keys) {
      print('Key: $key');
      final val = settingsBox.get(key);
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
  } else {
    print('Failed to steam settings.hive: ${res.stderr}');
  }
  
  try {
    tempDir.deleteSync(recursive: true);
  } catch (_) {}
}
