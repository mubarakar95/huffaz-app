import 'package:supabase/supabase.dart';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  // Find Yaseen's profile
  final yaseenProfiles = await client.from('profiles').select('*').ilike('full_name', '%Yaseen%');
  print('=== YASEEN PROFILES ===');
  print(yaseenProfiles);

  if (yaseenProfiles.isNotEmpty) {
    final yaseenId = yaseenProfiles[0]['id'];
    
    // Find Abdullah under Yaseen
    final students = await client.from('students').select('*').eq('teacher_id', yaseenId).ilike('full_name', '%Abdullah%');
    print('\n=== ABDULLAH UNDER YASEEN ===');
    print(students);
    
    if (students.isNotEmpty) {
      final studentId = students[0]['id'];
      
      // Find today's and yesterday's logs
      final logs = await client.from('sabaq_logs')
          .select('*, profiles(full_name)')
          .eq('student_id', studentId)
          .order('date', ascending: false)
          .limit(5);
      print('\n=== RECENT LOGS FOR ABDULLAH ===');
      for (final l in logs) {
        print('Log ID: ${l['id']} | Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}" | Teacher ID: ${l['teacher_id']} | Profiles: ${l['profiles']}');
      }
      
      // Let's check lesson acknowledgements for Abdullah
      final acks = await client.from('lesson_acknowledgements')
          .select('*')
          .eq('student_id', studentId)
          .order('date', ascending: false);
      print('\n=== LESSON ACKNOWLEDGEMENTS ===');
      print(acks);
    }
  }
}
