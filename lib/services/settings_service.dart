import '../core/supabase_client.dart';
import '../models/profile.dart';
import '../models/teacher.dart';

class SettingsService {
  Future<AppProfile?> fetchFullProfile(String userId) async {
    final data = await supabase
        .from('profiles')
        .select('*, institutions(name, weekly_off_days, default_sabaq_goal, default_sabqi_goal, default_manzil_goal)')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return AppProfile.fromMap(data);
  }

  Future<List<String>> fetchHolidays(String institutionId) async {
    final data = await supabase
        .from('institution_holidays')
        .select('date')
        .eq('institution_id', institutionId) as List;
    return data.map((h) => h['date'] as String).toList();
  }

  Future<void> addHoliday(String institutionId, String date) async {
    await supabase.from('institution_holidays').insert({
      'institution_id': institutionId,
      'date': date,
    });
  }

  Future<void> removeHoliday(String institutionId, String date) async {
    await supabase
        .from('institution_holidays')
        .delete()
        .eq('institution_id', institutionId)
        .eq('date', date);
  }

  Future<void> updateInstitutionSettings({
    required String institutionId,
    List<int>? weeklyOffDays,
    double? defaultSabaqGoal,
    double? defaultSabqiGoal,
    double? defaultManzilGoal,
  }) async {
    final updates = <String, dynamic>{};
    if (weeklyOffDays != null) updates['weekly_off_days'] = weeklyOffDays;
    if (defaultSabaqGoal != null) updates['default_sabaq_goal'] = defaultSabaqGoal;
    if (defaultSabqiGoal != null) updates['default_sabqi_goal'] = defaultSabqiGoal;
    if (defaultManzilGoal != null) updates['default_manzil_goal'] = defaultManzilGoal;
    if (updates.isEmpty) return;
    await supabase.from('institutions').update(updates).eq('id', institutionId);
  }

  /// Create institution during onboarding
  Future<String> createInstitution(String name) async {
    final data = await supabase
        .from('institutions')
        .insert({'name': name})
        .select('id')
        .single();
    return data['id'] as String;
  }

  /// Link user profile to institution
  Future<void> linkProfileToInstitution({
    required String userId,
    required String institutionId,
    required String fullName,
    required String role,
  }) async {
    await supabase.from('profiles').upsert({
      'id': userId,
      'institution_id': institutionId,
      'full_name': fullName,
      'role': role,
    });
  }

  /// Check and accept a teacher invitation
  Future<bool> checkAndAcceptInvitation(String email) async {
    final invite = await supabase
        .from('teacher_invitations')
        .select('*')
        .eq('email', email)
        .eq('status', 'pending')
        .maybeSingle();

    if (invite == null) return false;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    await supabase.from('profiles').upsert({
      'id': userId,
      'institution_id': invite['institution_id'],
      'full_name': invite['full_name'] ?? email.split('@')[0],
      'role': 'teacher',
    });

    await supabase
        .from('teacher_invitations')
        .update({'status': 'accepted'})
        .eq('id', invite['id']);

    return true;
  }

  // -----------------------------------------------------------------------
  // Teacher Management
  // -----------------------------------------------------------------------

  /// Fetch all teachers (active + optionally inactive) for an institution.
  /// Enriches each entry with:
  ///   - studentCount: how many students are assigned to that teacher
  ///   - absenceDaysThisMonth: from teacher_absences for the given month
  Future<List<Teacher>> fetchTeachers({
    required String institutionId,
    required int year,
    required int month,
  }) async {
    // 1. Profiles (teachers + admins)
    final profilesRes = await supabase
        .from('profiles')
        .select('id, full_name, role, is_active')
        .eq('institution_id', institutionId)
        .inFilter('role', ['teacher', 'admin', 'super_admin'])
        .order('full_name') as List;


    if (profilesRes.isEmpty) return [];

    final teacherIds = profilesRes.map((p) => p['id'] as String).toList();

    // 2. Student counts per teacher
    final studentsRes = await supabase
        .from('students')
        .select('teacher_id')
        .eq('institution_id', institutionId)
        .inFilter('teacher_id', teacherIds) as List;

    final studentCounts = <String, int>{};
    for (final s in studentsRes) {
      final tid = s['teacher_id'] as String?;
      if (tid != null) {
        studentCounts[tid] = (studentCounts[tid] ?? 0) + 1;
      }
    }

    // 3. Absence days this month per teacher
    final monthStart = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final monthEnd = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    final absencesRes = await supabase
        .from('teacher_absences')
        .select('teacher_id, absence_date')
        .eq('institution_id', institutionId)
        .gte('absence_date', monthStart)
        .lte('absence_date', monthEnd) as List;

    final absenceCounts = <String, int>{};
    for (final a in absencesRes) {
      final tid = a['teacher_id'] as String?;
      if (tid != null) {
        absenceCounts[tid] = (absenceCounts[tid] ?? 0) + 1;
      }
    }

    // 4. Merge into Teacher models
    return profilesRes.map((p) {
      final id = p['id'] as String;
      return Teacher(
        id: id,
        fullName: p['full_name'] as String? ?? '',
        role: p['role'] as String? ?? 'teacher',
        isActive: p['is_active'] ?? true,
        studentCount: studentCounts[id] ?? 0,
        absenceDaysThisMonth: absenceCounts[id] ?? 0,
      );
    }).toList();
  }

  /// Soft-enable or disable a teacher by setting `is_active` on their profile.
  Future<void> setTeacherActive(String teacherId, bool active) async {
    final res = await supabase
        .from('profiles')
        .update({'is_active': active})
        .eq('id', teacherId)
        .select();
    if (res == null || (res as List).isEmpty) {
      throw Exception(
        'Database update failed. This usually means the action was blocked by Supabase Row Level Security (RLS). '
        'Please ensure you have run the migration script including the "Admins can manage teacher active status" policy.'
      );
    }
  }


  /// Fetch all absence entries for a teacher in a given year (or all time).
  Future<List<Map<String, dynamic>>> fetchTeacherAbsenceHistory(
    String teacherId, {
    int? year,
  }) async {
    List res;
    if (year != null) {
      res = await supabase
          .from('teacher_absences')
          .select('id, absence_date')
          .eq('teacher_id', teacherId)
          .gte('absence_date', '$year-01-01')
          .lte('absence_date', '$year-12-31')
          .order('absence_date', ascending: false) as List;
    } else {
      res = await supabase
          .from('teacher_absences')
          .select('id, absence_date')
          .eq('teacher_id', teacherId)
          .order('absence_date', ascending: false) as List;
    }
    return List<Map<String, dynamic>>.from(res);
  }


  /// Invite a teacher by email. Creates a row in teacher_invitations which
  /// is accepted automatically on their first login (via checkAndAcceptInvitation).
  Future<void> inviteTeacher({
    required String institutionId,
    required String email,
    String? fullName,
  }) async {
    await supabase.from('teacher_invitations').upsert({
      'institution_id': institutionId,
      'email': email.toLowerCase().trim(),
      'full_name': fullName?.trim(),
      'status': 'pending',
    }, onConflict: 'institution_id,email');
  }
}
