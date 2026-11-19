import 'package:supabase/supabase.dart';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    print('Querying profiles...');
    final p = await client.from('profiles').select('*').limit(5);
    print('Profiles: ${p.length}');
  } catch (e) {
    print('Profiles error: $e');
  }

  try {
    print('Querying students...');
    final s = await client.from('students').select('*').limit(5);
    print('Students: ${s.length}');
  } catch (e) {
    print('Students error: $e');
  }

  try {
    print('Querying sabaq_logs...');
    final l = await client.from('sabaq_logs').select('*').limit(5);
    print('Sabaq logs: ${l.length}');
  } catch (e) {
    print('Sabaq logs error: $e');
  }

  try {
    print('Querying institutions...');
    final inst = await client.from('institutions').select('*').limit(5);
    print('Institutions: ${inst.length}');
  } catch (e) {
    print('Institutions error: $e');
  }
}
