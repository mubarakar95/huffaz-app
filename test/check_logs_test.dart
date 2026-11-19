import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:huffaz_app/core/supabase_client.dart';
import 'package:huffaz_app/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  HttpOverrides.global = null; // Restore real HttpClient
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('diagnose app provider getSabqiPagesForStudent', () async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    
    final client = Supabase.instance.client;
    final students = await client.from('students').select('*').ilike('full_name', '%Adil%');
    print('Students: $students');
    if (students.isNotEmpty) {
      for (final s in students) {
        final logs = await client.from('sabaq_logs').select('*').eq('student_id', s['id']).order('date', ascending: false);
        print('Logs for ${s['full_name']}:');
        for (final l in logs) {
          print('Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}" | Manzil: ${l['manzil']}');
        }
      }
    }
  });
}
