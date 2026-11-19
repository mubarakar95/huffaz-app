import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

void main() async {
  print('Connecting to Supabase...');
  try {
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    final studentRes = await client.from('students').select('*');
    print('Fetched ${studentRes.length} students.');
    Map<String, dynamic>? yasir;
    for (var s in studentRes) {
      if (s['full_name'].toString().toLowerCase().contains('yasir')) {
        yasir = s;
      }
    }

    if (yasir == null) {
      print('Yasir not found! Existing students:');
      for (var s in studentRes) {
        print('  - ${s['full_name']} (${s['id']})');
      }
      exit(0);
    }

    print('Yasir Student details: $yasir');
    final studentId = yasir['id'];

    final logsRes = await client
        .from('sabaq_logs')
        .select('*')
        .eq('student_id', studentId)
        .order('date', ascending: false);
    final List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(logsRes);
    print('Total logs for Yasir: ${logs.length}');

    print('\n--- ALL LOGS FOR YASIR ---');
    for (var i = 0; i < logs.length; i++) {
      final l = logs[i];
      print('[$i] Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}" | Manzil: "${l['manzil']}"');
    }
  } catch (e, stack) {
    print('Error occurred: $e');
    print(stack);
  }
  exit(0);
}
