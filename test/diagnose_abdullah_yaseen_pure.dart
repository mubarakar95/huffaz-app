import 'package:supabase/supabase.dart';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
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
}
