import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huffaz_app/core/supabase_client.dart';

void main() {
  HttpOverrides.global = null; // Restore real HttpClient
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagnose Abdullah under Yaseen', () async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    
    final client = Supabase.instance.client;
    
    // Find Yaseen
    final teachers = await client.from('profiles').select('id, full_name, role').ilike('full_name', '%Yaseen%');
    print('Yaseen Teachers: $teachers');
    
    // Find all Abdullahs
    final students = await client.from('students').select('id, full_name, teacher_id').ilike('full_name', '%Abdullah%');
    print('Abdullah Students: $students');
    
    for (final s in students) {
      final sId = s['id'] as String;
      final logs = await client.from('sabaq_logs').select('*').eq('student_id', sId).order('date', ascending: false);
      print('\nStudent: ${s['full_name']} (ID: $sId)');
      print('Logs count: ${logs.length}');
      if (logs.isNotEmpty) {
        print('Latest 5 logs:');
        for (int i = 0; i < 5 && i < logs.length; i++) {
          final l = logs[i];
          print('  ID: ${l['id']} | Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}" | Teacher ID: ${l['teacher_id']} | CreatedAt: ${l['created_at']}');
        }
      }
    }
  });
}
