import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for persisting lesson acknowledgements to Supabase.
/// An acknowledgement records that a teacher has confirmed a student's
/// pending lessons for a given date were genuinely not completed
/// (not a forgotten log entry).
class AcknowledgementService {
  final _supabase = Supabase.instance.client;

  /// Fetches the Set of student IDs that have been acknowledged
  /// for the given [date] (format: 'YYYY-MM-DD').
  /// If [institutionId] is provided, returns all acknowledgements across the institution.
  Future<Set<String>> fetchAcknowledgedStudentIds(
      String? teacherId, String date, {String? institutionId}) async {
    try {
      dynamic query = _supabase.from('lesson_acknowledgements').select('student_id').eq('date', date);
      if (institutionId != null && institutionId.isNotEmpty) {
        query = query.eq('institution_id', institutionId);
      } else if (teacherId != null && teacherId.isNotEmpty) {
        query = query.eq('teacher_id', teacherId);
      }
      final response = await query;
      return (response as List)
          .map((row) => row['student_id'] as String)
          .toSet();
    } catch (e) {
      // Fail silently — acknowledgements are non-critical
      debugPrint('[AcknowledgementService] fetchAcknowledgedStudentIds error: $e');
      return {};
    }
  }

  /// Upserts an acknowledgement for [studentId] by [teacherId] on [date].
  /// Safe to call multiple times — uses upsert with the unique constraint.
  Future<void> acknowledge({
    required String teacherId,
    required String studentId,
    required String date,
    String? institutionId,
  }) async {
    await _supabase.from('lesson_acknowledgements').upsert({
      'teacher_id': teacherId,
      'student_id': studentId,
      'date': date,
      if (institutionId != null) 'institution_id': institutionId,
    }, onConflict: 'teacher_id,student_id,date');
  }

  /// Removes an acknowledgement (for potential undo support in future).
  Future<void> removeAcknowledgement({
    required String teacherId,
    required String studentId,
    required String date,
  }) async {
    await _supabase
        .from('lesson_acknowledgements')
        .delete()
        .eq('teacher_id', teacherId)
        .eq('student_id', studentId)
        .eq('date', date);
  }
}
