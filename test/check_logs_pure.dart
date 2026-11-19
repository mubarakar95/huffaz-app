import 'package:supabase/supabase.dart';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  // Find student
  // Find student
  final studentRes = await client.from('students').select('*').eq('id', '101fdabf-cf90-4649-aa26-a9cd2f32e21d');
  print('Student matches: $studentRes');
  if (studentRes.isNotEmpty) {
    for (var student in studentRes) {
      final studentId = student['id'];
      final logsRes = await client.from('sabaq_logs').select('*').eq('student_id', studentId).order('date', ascending: false);
      print('TOTAL LOGS FOR ${student['full_name']}: ${logsRes.length}');
      
      // Calculate unique pages
      final uniquePages = <int>{};
      for (var l in logsRes) {
        // Parse sabaq string
        final sabaqStr = l['sabaq']?.toString() ?? '';
        final cleanStr = sabaqStr
            .replaceAll('[BASELINE]', '')
            .replaceAll('[BASELINE_SABAQI]', '')
            .replaceAll('[', '')
            .replaceAll(']', '')
            .trim();
        final List<int> pages = [];
        final matches = RegExp(r'(\d+)(?:\s*-\s*(\d+))?').allMatches(cleanStr);
        for (final m in matches) {
          final start = int.tryParse(m.group(1) ?? '') ?? 0;
          final end = m.group(2) != null ? (int.tryParse(m.group(2)!) ?? start) : start;
          if (start > 0) {
            for (int p = start; p <= end; p++) {
              if (p >= 1 && p <= 604) pages.add(p);
            }
          }
        }
        uniquePages.addAll(pages);
      }
      
      print('Unique Pages count: ${uniquePages.length}');
      print('Unique Pages: $uniquePages');
      
      // Check which Juzs are completed
      final List<int> completedJuzs = [];
      final List<int> partialJuzs = [];
      for (int j = 1; j <= 30; j++) {
        int startPage = j == 1 ? 1 : (j - 1) * 20 + 2;
        int endPage = j == 30 ? 604 : j * 20 + 1;
        final pagesInJuz = [for (int i = startPage; i <= endPage; i++) i];
        final completedPages = pagesInJuz.where((p) => uniquePages.contains(p)).length;
        if (completedPages == pagesInJuz.length) {
          completedJuzs.add(j);
        } else if (completedPages > 0) {
          partialJuzs.add(j);
          print('Juz $j: $completedPages / ${pagesInJuz.length} pages completed');
        }
      }
      print('Completed Juzs: $completedJuzs');
      print('Partial Juzs: $partialJuzs');
    }
  }
}
