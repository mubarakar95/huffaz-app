import 'package:supabase/supabase.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';
import 'dart:math';

const supabaseUrl = 'https://sgzozkmnetfodbyqcctv.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnem96a21uZXRmb2RieXFjY3R2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTMzMDgsImV4cCI6MjA5MzAyOTMwOH0.D5l1UGIulIYT_bLhTl9itBTw9PESQAj0OeFdoeyJOcE';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  // Get all students to find "Hanas" and "Aslah"
  final studentRes = await client.from('students').select('*');
  final List<Map<String, dynamic>> students = List<Map<String, dynamic>>.from(studentRes);
  
  for (var s in students) {
    final name = s['full_name'].toString().toLowerCase();
    if (name.contains('hanas') || name.contains('aslah')) {
      print('==================================================');
      print('FOUND STUDENT: ${s['full_name']} (ID: ${s['id']})');
      
      final logsRes = await client.from('sabaq_logs')
          .select('*')
          .eq('student_id', s['id'])
          .order('date', ascending: false);
      final List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(logsRes);
      print('Total logs: ${logs.length}');
      
      // Let's print the top 10 logs
      print('Latest 10 logs:');
      for (int i = 0; i < min(logs.length, 10); i++) {
        print('  Date: ${logs[i]['date']} | Status: ${logs[i]['status']} | Sabaq: "${logs[i]['sabaq']}"');
      }

      // 1. Filter sabaq logs on or before today
      final todayStr = getLocalToday();
      final sabaqLogs = logs.where((l) =>
        l['sabaq'] != null &&
        l['sabaq'].toString().isNotEmpty &&
        (l['date'].toString().compareTo(todayStr) <= 0 || l['status'] == 'baseline_sabqi' || l['status'] == 'baseline')
      ).toList();

      sabaqLogs.sort((a, b) {
        final cmp = b['created_at'].toString().compareTo(a['created_at'].toString());
        if (cmp != 0) return cmp;
        return b['date'].toString().compareTo(a['date'].toString());
      });

      final seen = <int>{};
      final uniqueSabaqPages = <int>[];

      for (final log in sabaqLogs) {
        final sabaqVal = log['sabaq']?.toString() ?? '';
        final pages = getPagesFromSabaqString(sabaqVal);
        for (final p in pages) {
          if (!seen.contains(p)) {
            seen.add(p);
            uniqueSabaqPages.add(p);
          }
        }
      }

      print('All unique sabaq pages before filtering: $uniqueSabaqPages');

      // Determine activeJuzId
      int? activeJuzId;
      if (uniqueSabaqPages.isNotEmpty) {
        final latestPage = uniqueSabaqPages.first;
        final info = getSabaqiPageInfo(latestPage);
        activeJuzId = info['juz'] as int?;
        print('Latest memorized page: $latestPage, activeJuzId: $activeJuzId');
      }

      if (activeJuzId != null) {
        final allowedJuzs = {activeJuzId, activeJuzId - 1};
        print('Allowed Juzs: $allowedJuzs');
        final poolPages = List<int>.from(uniqueSabaqPages);
        poolPages.removeWhere((pageNum) {
          final j = getSabaqiPageInfo(pageNum)['juz'] as int?;
          return j == null || !allowedJuzs.contains(j);
        });
        print('Pages after restricting to allowed Juzs: $poolPages');
        
        final sabaqParaPages = poolPages.take(20).toList();
        print('Final sabaqParaPages (Sabaq Para Pool - up to 20): $sabaqParaPages');
      }
    }
  }
}
