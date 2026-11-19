import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

void main() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  final client = Supabase.instance.client;
  
  // Find student
  final studentRes = await client.from('students').select('*').ilike('full_name', '%Adil%');
  print('Student matches: $studentRes');
  if (studentRes.isNotEmpty) {
    for (var student in studentRes) {
      final studentId = student['id'];
      final logsRes = await client.from('sabaq_logs').select('*').eq('student_id', studentId).order('date', ascending: false);
      print('TOTAL LOGS FOR ${student['full_name']}: ${logsRes.length}');
      for (var i = 0; i < logsRes.length; i++) {
        final l = logsRes[i];
        print('[$i] Date: ${l['date']} | Status: ${l['status']} | Sabaq: "${l['sabaq']}" | Manzil: ${l['manzil']}');
      }
    }
  }
}
