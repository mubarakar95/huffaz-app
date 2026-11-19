import '../core/supabase_client.dart';

class DashboardService {
  /// Mirrors getDashboardData() from Next.js actions.ts
  Future<Map<String, dynamic>> getDashboardData() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final profileResp = await supabase
        .from('profiles')
        .select('role, institution_id, full_name')
        .eq('id', user.id)
        .maybeSingle();

    if (profileResp == null || profileResp['institution_id'] == null) {
      return {
        'totalStudents': 0,
        'totalTeachers': 0,
        'todayLoggedCount': 0,
        'todayAbsentCount': 0,
        'yesterdayLoggedCount': 0,
        'yesterdayLoggedPersonalCount': 0,
        'recentLogs': []
      };
    }

    final institutionId = profileResp['institution_id'] as String;
    final isTeacher = profileResp['role'] == 'teacher';
    final today = _getLocalToday();
    final yesterday = _getLocalYesterday();

    final studentsQuery = supabase
        .from('students')
        .select('id, teacher_id, is_personal')
        .eq('institution_id', institutionId);

    final profilesQuery = supabase
        .from('profiles')
        .select('id, role')
        .eq('institution_id', institutionId);

    final todayLogsQuery = supabase
        .from('sabaq_logs')
        .select('id, student_id, status, students!inner(institution_id, teacher_id, is_personal)')
        .eq('date', today)
        .eq('students.institution_id', institutionId);

    final yesterdayLogsQuery = supabase
        .from('sabaq_logs')
        .select('id, student_id, status, students!inner(institution_id, teacher_id, is_personal)')
        .eq('date', yesterday)
        .eq('students.institution_id', institutionId);

    dynamic recentLogsQuery = supabase
        .from('sabaq_logs')
        .select('id, student_id, date, sabaq, manzil, status, created_at, students!inner(full_name, institution_id, teacher_id, is_personal), profiles(full_name)');
    if (isTeacher) {
      recentLogsQuery = recentLogsQuery.eq('students.teacher_id', user.id);
    } else {
      recentLogsQuery = recentLogsQuery.eq('students.institution_id', institutionId);
    }
    recentLogsQuery = recentLogsQuery.order('created_at', ascending: false).limit(10);

    // Parallel fetches
    final results = await Future.wait(<Future<dynamic>>[
      studentsQuery,
      profilesQuery,
      todayLogsQuery,
      yesterdayLogsQuery,
      recentLogsQuery,
    ]);

    final allStudentsRaw = results[0] as List;
    final allProfiles = results[1] as List;
    final todayLogsRaw = results[2] as List;
    final yesterdayLogsRaw = results[3] as List;
    final recentLogsRaw = results[4] as List;

    // 1. Institution students (completely exclude all personal profiles)
    final institutionStudents = allStudentsRaw.where((s) => s['is_personal'] != true).toList();

    // 2. Personal (assigned) students specifically for user.id (excluding personal profiles)
    final personalAssignedStudents = allStudentsRaw.where((s) {
      final isPersonal = s['is_personal'] == true;
      final tId = s['teacher_id'] as String?;
      return tId == user.id && isPersonal != true;
    }).toList();

    // 3. Institution logs today
    final institutionTodayLogs = todayLogsRaw.where((l) {
      final sMap = l['students'] as Map?;
      return sMap != null && sMap['is_personal'] != true;
    }).toList();

    // 4. Personal logs today
    final personalTodayLogs = todayLogsRaw.where((l) {
      final sMap = l['students'] as Map?;
      if (sMap != null) {
        final tId = sMap['teacher_id'] as String?;
        final isPersonal = sMap['is_personal'] == true;
        return tId == user.id && isPersonal != true;
      }
      return false;
    }).toList();

    // 5. Institution logs yesterday
    final institutionYesterdayLogs = yesterdayLogsRaw.where((l) {
      final sMap = l['students'] as Map?;
      return sMap != null && sMap['is_personal'] != true;
    }).toList();

    // 6. Personal logs yesterday
    final personalYesterdayLogs = yesterdayLogsRaw.where((l) {
      final sMap = l['students'] as Map?;
      if (sMap != null) {
        final tId = sMap['teacher_id'] as String?;
        final isPersonal = sMap['is_personal'] == true;
        return tId == user.id && isPersonal != true;
      }
      return false;
    }).toList();

    // Recent logs (exclude personal profiles completely for admin, allow for teacher's own feed)
    final recentLogs = recentLogsRaw.where((l) {
      final sMap = l['students'] as Map?;
      if (sMap != null) {
        final isPersonal = sMap['is_personal'] == true;
        final tId = sMap['teacher_id'] as String?;
        if (isPersonal) {
          return tId == user.id && isTeacher;
        }
      }
      return true;
    }).toList();

    // Filter assigned students for primary dashboard counters
    final assignedStudents = isTeacher
        ? personalAssignedStudents
        : institutionStudents;

    final totalStudentsCount = institutionStudents.length; // Exclude personal from total enrolled
    final totalAssignedStudentsCount = assignedStudents.length;

    // Today's logs
    final todayLogs = isTeacher ? personalTodayLogs : institutionTodayLogs;
    final todayLogged = todayLogs.length;

    final todayAbsent = todayLogs.where((l) {
      final s = (l['status'] as String?) ?? '';
      return s == 'absent' || s == 'sick' || s == 'other';
    }).length;

    // Yesterday's logs
    final yesterdayLogs = isTeacher ? personalYesterdayLogs : institutionYesterdayLogs;
    final yesterdayLogged = yesterdayLogs.length;

    final todayLoggedPersonalCount = personalTodayLogs.length;
    final yesterdayLoggedPersonalCount = personalYesterdayLogs.length;

    // Calculate staff members (admins + active teachers with students)
    final activeTeacherIds = allStudentsRaw
        .map((s) => s['teacher_id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

    final staffCount = allProfiles.where((p) {
      final role = p['role'] as String?;
      final id = p['id'] as String?;
      if (role == 'admin') return true;
      if (role == 'teacher' && activeTeacherIds.contains(id)) return true;
      return false;
    }).length;

    return {
      'totalStudents': totalStudentsCount,
      'totalAssignedStudents': totalAssignedStudentsCount,
      'totalPersonalStudents': personalAssignedStudents.length,
      'todayLoggedPersonalCount': todayLoggedPersonalCount,
      'yesterdayLoggedPersonalCount': yesterdayLoggedPersonalCount,
      'totalTeachers': staffCount,
      'todayLoggedCount': todayLogged,
      'todayAbsentCount': todayAbsent,
      'yesterdayLoggedCount': yesterdayLogged,
      'recentLogs': recentLogs,
    };
  }

  String _getLocalToday() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _getLocalYesterday() {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
