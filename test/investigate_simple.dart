import 'package:supabase/supabase.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  print('Fetching all students...');
  final studentRes = await client.from('students').select('id, full_name');
  print('Total students: ${studentRes.length}');
  for (var s in studentRes) {
    print('  ID: ${s['id']} | Name: ${s['full_name']}');
  }
}
