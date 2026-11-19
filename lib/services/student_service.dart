import 'dart:convert';
import '../core/supabase_client.dart';
import '../models/student.dart';
import '../models/sabaq_log.dart';
import '../utils/quran_data.dart';
import '../utils/student_utils.dart';

class StudentService {
  /// Fetch all students for the institution + all their logs.
  /// Returns processed students with computed progress fields.
  Future<Map<String, dynamic>> fetchStudentsAndLogs({
    required String institutionId,
    required String userId,
    required String role,
    required Set<String> holidaysSet,
    required List<int> weeklyOffDays,
    required double defaultSabaqGoal,
    required double defaultSabqiGoal,
    required double defaultManzilGoal,
  }) async {
    final today = getLocalToday();

    // Fetch absent teachers today
    final List<dynamic> rawAbsences = await supabase
        .from('teacher_absences')
        .select('teacher_id')
        .eq('institution_id', institutionId)
        .eq('absence_date', today);
    final absentTeacherIds = rawAbsences.map((a) => a['teacher_id'] as String).toList();

    // Fetch students
    final rawStudents = await supabase
        .from('students')
        .select('*, parent_name, profiles!students_teacher_id_fkey(full_name), institutions(default_sabaq_goal, default_sabqi_goal, default_manzil_goal)')
        .eq('institution_id', institutionId)
        .order('full_name', ascending: true);

    // Filter students
    final studentsData = rawStudents.where((s) {
      final isPersonal = s['is_personal'] == true;
      final studentTeacherId = s['teacher_id'] as String?;

      if (isPersonal) {
        return studentTeacherId == userId;
      }

      if (role == 'teacher') {
        return studentTeacherId == userId || absentTeacherIds.contains(studentTeacherId);
      }

      return true;
    }).toList();

    if (studentsData.isEmpty) {
      return {'students': <Student>[], 'logs': <SabaqLog>[], 'studentDetails': <String, dynamic>{}};
    }

    // Fetch all logs for these students. We run two queries in parallel:
    // 1. Recent logs (up to 10000) to keep the app fast.
    // 2. All baseline logs, ensuring milestones/progress calculations are never truncated.
    final studentIds = studentsData.map((s) => s['id'] as String).toList();

    final logsFutures = studentIds.map((id) {
      return supabase
          .from('sabaq_logs')
          .select('*')
          .eq('student_id', id)
          .order('date', ascending: false);
    }).toList();

    final results = await Future.wait(logsFutures);
    final List<dynamic> allLogsRaw = [];
    for (final res in results) {
      allLogsRaw.addAll(res as List);
    }

    // Merge and deduplicate logs
    final Map<String, dynamic> uniqueLogsMap = {};
    for (final l in allLogsRaw) {
      if (l['id'] != null) uniqueLogsMap[l['id'] as String] = l;
    }

    // Parse logs
    final allLogs = uniqueLogsMap.values.map((l) => SabaqLog.fromMap(l as Map<String, dynamic>)).toList();

    // Group logs by student
    final logsByStudent = <String, List<SabaqLog>>{};
    for (final log in allLogs) {
      logsByStudent.putIfAbsent(log.studentId, () => []).add(log);
    }

    // Process each student
    final processedStudents = <Student>[];
    final studentDetails = <String, Map<String, dynamic>>{};

    for (final raw in studentsData) {
      final studentId = raw['id'] as String;
      final studentLogs = logsByStudent[studentId] ?? [];

      // Get goals (student-specific or institution default)
      final instData = raw['institutions'];
      final sGoal = (raw['sabaq_goal'] != null)
          ? (raw['sabaq_goal'] as num).toDouble()
          : (instData?['default_sabaq_goal'] as num?)?.toDouble() ?? defaultSabaqGoal;
      final sqGoal = (raw['sabqi_goal'] != null)
          ? (raw['sabqi_goal'] as num).toDouble()
          : (instData?['default_sabqi_goal'] as num?)?.toDouble() ?? defaultSabqiGoal;
      final mGoal = (raw['manzil_goal'] != null)
          ? (raw['manzil_goal'] as num).toDouble()
          : (instData?['default_manzil_goal'] as num?)?.toDouble() ?? defaultManzilGoal;

      // Compute unique memorized pages (includes baseline, daily sabaq, and revision logs)
      final uniquePages = <int>{};
      final sabaqUniquePages = <int>{}; // Strictly for active Juz (current lesson front)

      for (final log in studentLogs) {
        final sabaqPages = getPagesFromSabaqString(log.sabaq);
        uniquePages.addAll(sabaqPages);
        sabaqUniquePages.addAll(sabaqPages);

        final parsed = log.parsedManzil;
        if (parsed != null) {
          // Manzil pages
          if (parsed['manzilPages'] is List) {
            for (final item in parsed['manzilPages'] as List) {
              final pageNum = item is Map ? (item['page'] as num?)?.toInt() : null;
              if (pageNum != null && pageNum >= 1 && pageNum <= 604) {
                uniquePages.add(pageNum);
              }
            }
          }
          // Juz references in manzil string
          if (parsed['manzil'] is String) {
            final juzRegex = RegExp(r'Juz\s+(\d+)');
            for (final m in juzRegex.allMatches(parsed['manzil'] as String)) {
              final num = int.tryParse(m.group(1) ?? '');
              if (num != null && num >= 1 && num <= 30) {
                uniquePages.addAll(getPagesForJuz(num));
              }
            }
          }
          // Sabqi pages (from para list)
          if (parsed['sabqi'] is List) {
            for (final item in parsed['sabqi'] as List) {
              final text = item is String ? item : (item is Map ? (item['sabaq'] as String?) : null);
              if (text != null) {
                final m = RegExp(r'^Page (\d+)').firstMatch(text);
                if (m != null) {
                  final p = int.tryParse(m.group(1) ?? '');
                  if (p != null) uniquePages.add(p);
                }
              }
            }
          }
        }
      }

      // Count Juz completed
      double totalJuzCompleted = 0;
      for (int j = 1; j <= 30; j++) {
        final pages = getPagesForJuz(j);
        final memorized = pages.where((p) => uniquePages.contains(p)).length;
        totalJuzCompleted += memorized / pages.length;
      }
      final uniqueCount = totalJuzCompleted.floor().clamp(0, 30);
      final progressPercent = ((uniquePages.length / 604) * 100).round();

      // Current Juz (highest reached in sabaq or baseline)
      int? maxJuz;
      if (sabaqUniquePages.isNotEmpty) {
        int highest = 0;
        for (final p in sabaqUniquePages) {
          final j = getJuzForPage(p);
          if (j > highest) highest = j;
        }
        maxJuz = highest > 0 ? highest : null;
      }

      // Today's log
      final logsNotBaseline = studentLogs.where((l) => l.status != 'baseline' && l.status != 'baseline_sabqi').toList();
      final todayLog = logsNotBaseline.where((l) {
        final d = l.date.contains('T') ? l.date.split('T')[0] : l.date;
        return d == today;
      }).firstOrNull;

      Map<String, dynamic>? todayParsedManzil = todayLog?.parsedManzil;

      final isAbsentOrSick = todayLog?.status == 'absent' || todayLog?.status == 'sick';
      final todaySabaqPages = (!isAbsentOrSick && todayLog?.sabaq != null)
          ? getPagesCountFromSabaqString(todayLog!.sabaq!)
          : 0.0;
      final todaySabqiPages = (!isAbsentOrSick && todayParsedManzil != null)
          ? ((todayParsedManzil['sabqi'] as List?)?.length ?? 0).toDouble()
          : 0.0;
      double todayManzilPages = 0.0;
      if (!isAbsentOrSick && todayParsedManzil != null) {
        if (todayParsedManzil['manzilPages'] is List) {
          todayManzilPages += (todayParsedManzil['manzilPages'] as List).length.toDouble();
        }
        if (todayParsedManzil['manzil'] is String) {
          final matches = RegExp(r'Juz\s+\d+').allMatches(todayParsedManzil['manzil'] as String);
          todayManzilPages += matches.length * 20.0;
        }
      }

      // Streak
      final logMaps = studentLogs.map((l) => l.toMap()).toList();
      final streak = computeStreak(logMaps, holidaysSet, weeklyOffDays, sGoal, sqGoal, mGoal, isHafiz: progressPercent >= 100);



      final student = Student(
        id: studentId,
        fullName: raw['full_name'] as String? ?? 'Unknown',
        parentName: raw['parent_name'] as String?,
        contactNumber: raw['contact_number'] as String?,
        institutionId: raw['institution_id'] as String? ?? '',
        teacherId: raw['teacher_id'] as String?,
        teacherName: raw['profiles']?['full_name'] as String?,
        isPersonal: raw['is_personal'] == true,
        sabaqGoal: (raw['sabaq_goal'] as num?)?.toDouble(),
        sabqiGoal: (raw['sabqi_goal'] as num?)?.toDouble(),
        manzilGoal: (raw['manzil_goal'] as num?)?.toDouble(),
        progressPercent: progressPercent,
        uniqueCount: uniqueCount,
        currentJuz: maxJuz,
        streak: streak,
        todayStatus: todayLog?.status,
        todayLogId: todayLog?.id,
        todaySabaqPages: todaySabaqPages,
        todaySabqiPages: todaySabqiPages,
        todayManzilPages: todayManzilPages,
      );

      processedStudents.add(student);
      studentDetails[studentId] = {
        'student': raw,
        'logs': studentLogs.map((l) => l.toMap()).toList(),
      };
    }

    return {
      'students': processedStudents,
      'logs': allLogs,
      'studentDetails': studentDetails,
    };
  }

  /// Submit a log entry for a student
  Future<void> submitLog({
    required String studentId,
    required String date,
    required String sabaq,
    required dynamic manzil, // Map or null
    required String status,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Check if log already exists for this date
    final existing = await supabase
        .from('sabaq_logs')
        .select('id')
        .eq('student_id', studentId)
        .eq('date', date)
        .neq('status', 'baseline')
        .neq('status', 'baseline_sabqi')
        .maybeSingle();

    final manzilStr = manzil != null ? jsonEncode(manzil) : null;

    if (existing != null) {
      await supabase.from('sabaq_logs').update({
        'sabaq': sabaq,
        'manzil': manzilStr,
        'status': status,
        'teacher_id': user.id,
      }).eq('id', existing['id']);
    } else {
      await supabase.from('sabaq_logs').insert({
        'student_id': studentId,
        'teacher_id': user.id,
        'date': date,
        'sabaq': sabaq,
        'manzil': manzilStr,
        'status': status,
      });
    }
  }

  /// Submits a log entry, merging only the provided fields with any existing
  /// log for the same student+date. Fields set to null are left unchanged.
  Future<void> mergeLog({
    required String studentId,
    required String date,
    String? sabaq,
    dynamic manzil,
    String? status,
    String? institutionId,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final existing = await supabase
        .from('sabaq_logs')
        .select('id, sabaq, manzil, status')
        .eq('student_id', studentId)
        .eq('date', date)
        .neq('status', 'baseline')
        .neq('status', 'baseline_sabqi')
        .maybeSingle();

    if (existing != null) {
      final updateData = <String, dynamic>{};
      updateData['teacher_id'] = user.id;
      if (sabaq != null) {
        String finalSabaq = sabaq;
        final existingSabaq = existing['sabaq'] as String? ?? '';
        if (existingSabaq.isNotEmpty && !existingSabaq.startsWith('[SKIPPED') && !sabaq.startsWith('[SKIPPED')) {
          final start = _parseStartFromSabaq(existingSabaq);
          final end = _parseEndFromSabaq(sabaq);
          if (start != null && end != null) {
            final startSurah = findQuranSurah(start.surahName);
            final endSurah = findQuranSurah(end.surahName);
            if (startSurah != null && endSurah != null) {
              final pageSpan = calculatePageSpanFromAyahs(startSurah.number, start.ayahNum, endSurah.number, end.ayahNum);
              final lines = (pageSpan * 15.0).round().clamp(0, 9060);
              final startPage = getPageForAyah(startSurah.number, start.ayahNum);
              final endPage = getPageForAyah(endSurah.number, end.ayahNum);
              final pageRangeStr = startPage == endPage ? '$endPage' : '$startPage-$endPage';
              final fromSurahName = startSurah.name;
              final toSurahName = endSurah.name;
              final heardMatch = RegExp(r'Heard by:\s*(.+)').firstMatch(sabaq);
              final heardBy = heardMatch != null ? heardMatch.group(1) : null;

              if (startSurah.number == endSurah.number) {
                finalSabaq = 'Surah $fromSurahName (Ayah ${start.ayahNum}-${end.ayahNum}) [Page $pageRangeStr] - $lines Line(s) (${pageSpan.toStringAsFixed(2)} Page)';
              } else {
                finalSabaq = '$fromSurahName (${start.ayahNum}) to $toSurahName (${end.ayahNum}) [Page $pageRangeStr] - $lines Line(s) (${pageSpan.toStringAsFixed(2)} Page)';
              }
              if (heardBy != null && heardBy.trim().isNotEmpty) {
                finalSabaq += ' - Heard by: ${heardBy.trim()}';
              }
            }
          }
        }
        updateData['sabaq'] = finalSabaq;
      }
      if (manzil != null) updateData['manzil'] = jsonEncode(manzil);
      if (status != null) updateData['status'] = status;

      // Check if the resulting log entry is completely empty
      final finalSabaq = updateData['sabaq'] ?? existing['sabaq'] ?? '';
      final finalManzilRaw = updateData['manzil'] ?? existing['manzil'];
      final finalStatus = updateData['status'] ?? existing['status'] ?? 'good';

      Map parsed = {};
      if (finalManzilRaw is Map) {
        parsed = finalManzilRaw;
      } else if (finalManzilRaw is String && finalManzilRaw.isNotEmpty) {
        try {
          parsed = jsonDecode(finalManzilRaw);
        } catch (_) {}
      }

      final hasSabaq = finalSabaq.toString().trim().isNotEmpty;
      final hasSabqi = parsed['sabqi'] != null && (parsed['sabqi'] as List).isNotEmpty;
      final hasManzilPages = parsed['manzilPages'] != null && (parsed['manzilPages'] as List).isNotEmpty;
      final hasManzilText = parsed['manzil'] != null && (parsed['manzil'] as String).trim().isNotEmpty;
      final hasStatus = finalStatus != 'good' && finalStatus != 'present' && finalStatus.isNotEmpty;

      if (!hasSabaq && !hasSabqi && !hasManzilPages && !hasManzilText && !hasStatus) {
        final res = await supabase.from('sabaq_logs').delete().eq('id', existing['id']).select();
        if (res.isEmpty) {
          throw Exception('Permission denied or session expired (0 rows modified)');
        }
      } else {
        final res = await supabase.from('sabaq_logs').update(updateData).eq('id', existing['id']).select();
        if (res.isEmpty) {
          throw Exception('Permission denied or session expired (0 rows modified)');
        }
      }
    } else {
      await supabase.from('sabaq_logs').insert({
        'student_id': studentId,
        'teacher_id': user.id,
        'date': date,
        'sabaq': sabaq ?? '',
        'manzil': manzil != null ? jsonEncode(manzil) : jsonEncode(<String, dynamic>{}),
        'status': status ?? 'good',
        if (institutionId != null) 'institution_id': institutionId,
      });
    }
  }

  Future<void> addStudent({
    required String institutionId,
    required String? teacherId,
    required String fullName,
    String? parentName,
    String? contactNumber,
    double? sabaqGoal,
    double? sabqiGoal,
    double? manzilGoal,
    bool isPersonal = false,
  }) async {
    await supabase.from('students').insert({
      'institution_id': institutionId,
      if (teacherId != null) 'teacher_id': teacherId,
      'full_name': fullName,
      'parent_name': parentName,
      'contact_number': contactNumber,
      'sabaq_goal': sabaqGoal,
      'sabqi_goal': sabqiGoal,
      'manzil_goal': manzilGoal,
      'is_personal': isPersonal,
    });
  }

  /// Update an existing student's details and custom goals.
  Future<void> updateStudent({
    required String studentId,
    required String fullName,
    required String? parentName,
    required String? contactNumber,
    required String? teacherId,
    required double? sabaqGoal,
    required double? sabqiGoal,
    required double? manzilGoal,
    required bool isPersonal,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await supabase.from('students').update({
      'full_name': fullName,
      'parent_name': parentName,
      'contact_number': contactNumber,
      'teacher_id': isPersonal ? user.id : teacherId,
      'sabaq_goal': sabaqGoal,
      'sabqi_goal': sabqiGoal,
      'manzil_goal': manzilGoal,
      'is_personal': isPersonal,
    }).eq('id', studentId);
  }

  /// Delete a student by ID
  Future<void> deleteStudent(String studentId) async {
    await supabase.from('sabaq_logs').delete().eq('student_id', studentId);
    await supabase.from('students').delete().eq('id', studentId);
  }

  /// Get institution people (teachers + students) for "Heard By" picker
  Future<Map<String, dynamic>> getInstitutionPeople(String institutionId, String userId) async {
    final results = await Future.wait([
      supabase
          .from('profiles')
          .select('id, full_name, role, is_active')
          .eq('institution_id', institutionId)
          .eq('is_active', true)
          .order('full_name'),
      supabase
          .from('students')
          .select('id, full_name, teacher_id, is_personal')
          .eq('institution_id', institutionId)
          .order('full_name'),
    ]);
    final rawStudents = results[1] as List;
    final filteredStudents = rawStudents.where((s) {
      final isPersonal = s['is_personal'] == true;
      final tId = s['teacher_id'] as String?;
      if (isPersonal) {
        return tId == userId;
      }
      return true;
    }).toList();

    return {
      'teachers': results[0] as List,
      'students': filteredStudents,
    };
  }


  /// Bulk saves sabaq and sabqi baseline pages by deleting previous ones and inserting anew
  Future<void> saveBaseline({
    required String studentId,
    required String teacherId,
    required List<int> sabaqPages,
    required List<int> sabqiPages,
    required String institutionId,
  }) async {
    // 1. Delete all existing baseline logs for this student within the 2000-01-01 to 2000-01-31 range
    await supabase
        .from('sabaq_logs')
        .delete()
        .eq('student_id', studentId)
        .inFilter('status', ['baseline', 'baseline_sabqi'])
        .gte('date', '2000-01-01')
        .lte('date', '2000-01-31');

    final List<Map<String, dynamic>> inserts = [];
    final nowStr = DateTime.now().toIso8601String();

    // 2. Format completed Juz baseline pages as ranges and save in a single row on 2000-01-01
    if (sabaqPages.isNotEmpty) {
      sabaqPages.sort();
      final List<String> ranges = [];
      int start = sabaqPages[0];
      int end = sabaqPages[0];
      for (int i = 1; i < sabaqPages.length; i++) {
        if (sabaqPages[i] == end + 1) {
          end = sabaqPages[i];
        } else {
          if (start == end) {
            ranges.add('$start');
          } else {
            ranges.add('$start-$end');
          }
          start = sabaqPages[i];
          end = sabaqPages[i];
        }
      }
      if (start == end) {
        ranges.add('$start');
      } else {
        ranges.add('$start-$end');
      }
      final sabaqString = '[BASELINE] [Page ${ranges.join(', ')}]';
      inserts.add({
        'student_id': studentId,
        'teacher_id': teacherId,
        'date': '2000-01-01',
        'sabaq': sabaqString,
        'status': 'baseline',
        'created_at': nowStr,
        'institution_id': institutionId,
        'manzil': null,
      });
    }

    // 3. Map sabaq para baseline pages (one row per page, incrementing day)
    for (int idx = 0; idx < sabqiPages.length; idx++) {
      final pageNum = sabqiPages[idx];
      final dayStr = (idx + 2).toString().padLeft(2, '0');
      inserts.add({
        'student_id': studentId,
        'teacher_id': teacherId,
        'date': '2000-01-$dayStr',
        'sabaq': '[BASELINE_SABAQI] [Page $pageNum]',
        'status': 'baseline_sabqi',
        'created_at': nowStr,
        'institution_id': institutionId,
        'manzil': null,
      });
    }

    // 4. Bulk insert if not empty
    if (inserts.isNotEmpty) {
      await supabase.from('sabaq_logs').insert(inserts);
    }
  }

  /// Delete a log entry
  Future<void> deleteLog(String logId) async {
    final res = await supabase.from('sabaq_logs').delete().eq('id', logId).select();
    if (res.isEmpty) {
      throw Exception('Permission denied or session expired (0 rows modified)');
    }
  }

  /// Targeted re-fetch: pulls only a single student's logs from Supabase.
  /// Used after a log write so we sync just that one student, not the whole institution.
  Future<List<SabaqLog>> fetchLogsForStudent(String studentId) async {
    final List<dynamic> res = await supabase
        .from('sabaq_logs')
        .select('*')
        .eq('student_id', studentId)
        .order('date', ascending: false);
    return res
        .map((l) => SabaqLog.fromMap(l as Map<String, dynamic>))
        .toList();
  }

  /// Fetch scheduled absences for a teacher
  Future<List<Map<String, dynamic>>> fetchScheduledAbsences(String teacherId) async {
    final response = await supabase
        .from('teacher_absences')
        .select('id, absence_date')
        .eq('teacher_id', teacherId)
        .order('absence_date', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Mark teacher absence (insert or delete from database)
  Future<void> markTeacherAbsence({
    required String teacherId,
    required String institutionId,
    required String date,
    required bool isAbsent,
  }) async {
    if (isAbsent) {
      await supabase.from('teacher_absences').upsert({
        'teacher_id': teacherId,
        'institution_id': institutionId,
        'absence_date': date,
      }, onConflict: 'teacher_id,absence_date');
    } else {
      await supabase
          .from('teacher_absences')
          .delete()
          .eq('teacher_id', teacherId)
          .eq('absence_date', date);
    }
  }

  /// Fetch all absent teachers for today in an institution
  Future<List<Map<String, dynamic>>> fetchAbsentTeachersToday(String institutionId, String todayStr) async {
    final response = await supabase
        .from('teacher_absences')
        .select('absence_date, teacher_id, profiles(full_name)')
        .eq('institution_id', institutionId)
        .eq('absence_date', todayStr);
    return List<Map<String, dynamic>>.from(response as List);
  }

  ({String surahName, int ayahNum})? _parseStartFromSabaq(String sabaq) {
    final matchA = RegExp(r'Surah\s+(.*?)\s+\(Ayah\s+(\d+)-(\d+)\)').firstMatch(sabaq);
    if (matchA != null) {
      return (
        surahName: matchA.group(1) ?? '',
        ayahNum: int.tryParse(matchA.group(2) ?? '') ?? 1,
      );
    }
    final matchB = RegExp(r'^(.*?)\s+\((\d+)\)\s+to').firstMatch(sabaq);
    if (matchB != null) {
      return (
        surahName: matchB.group(1) ?? '',
        ayahNum: int.tryParse(matchB.group(2) ?? '') ?? 1,
      );
    }
    return null;
  }

  ({String surahName, int ayahNum})? _parseEndFromSabaq(String sabaq) {
    final matchA = RegExp(r'Surah\s+(.*?)\s+\(Ayah\s+(\d+)-(\d+)\)').firstMatch(sabaq);
    if (matchA != null) {
      return (
        surahName: matchA.group(1) ?? '',
        ayahNum: int.tryParse(matchA.group(3) ?? '') ?? 1,
      );
    }
    final matchB = RegExp(r'to\s+(.*?)\s+\((\d+)\)').firstMatch(sabaq);
    if (matchB != null) {
      return (
        surahName: matchB.group(1) ?? '',
        ayahNum: int.tryParse(matchB.group(2) ?? '') ?? 1,
      );
    }
    return null;
  }
}

// -----------------------------------------------------------------------
// Extensions appended for Teacher Management feature
// -----------------------------------------------------------------------

extension TeacherManagementService on StudentService {
  /// Bulk-reassign a list of students to a new teacher (or null = unassigned).
  Future<void> reassignStudents({
    required List<String> studentIds,
    String? newTeacherId,
  }) async {
    if (studentIds.isEmpty) return;
    await supabase
        .from('students')
        .update({'teacher_id': newTeacherId})
        .inFilter('id', studentIds);
  }

  /// Schedule an absence for any teacher (admin action).
  /// Wraps the existing [markTeacherAbsence] with a specific teacherId.
  Future<void> scheduleAbsenceForTeacher({
    required String teacherId,
    required String institutionId,
    required String date,
  }) async {
    await markTeacherAbsence(
      teacherId: teacherId,
      institutionId: institutionId,
      date: date,
      isAbsent: true,
    );
  }
}

