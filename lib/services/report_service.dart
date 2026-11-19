import '../models/student.dart';
import '../models/sabaq_log.dart';
import '../utils/quran_data.dart';

class ReportService {
  Future<List<Student>> fetchDailyReport({
    required String date,
    required List<Student> cachedStudents,
    required List<SabaqLog> cachedLogs,
  }) async {
    // Group logs by student ID for the target date
    final logMap = <String, SabaqLog>{};
    for (final log in cachedLogs) {
      final logDate = log.date.contains('T') ? log.date.split('T')[0] : log.date;
      if (logDate == date) {
        logMap[log.studentId] = log;
      }
    }

    return cachedStudents.map((student) {
      final log = logMap[student.id];
      if (log == null) {
        // Not logged yet
        return student.copyWith(
          todayStatus: null,
          todayLogId: null,
          todaySabaqPages: 0.0,
          todaySabqiPages: 0.0,
          todayManzilPages: 0.0,
        );
      }

      final isAbsentOrSick = log.status == 'absent' || log.status == 'sick' || log.status == 'other';
      final parsedManzil = log.parsedManzil;

      final sabaqPages = (!isAbsentOrSick) ? getPagesCountFromSabaqString(log.sabaq) : 0.0;
      
      final sabqiItems = (parsedManzil?['sabqi'] as List?);
      final sabqiPages = (!isAbsentOrSick && sabqiItems != null)
          ? sabqiItems.length.toDouble()
          : 0.0;

      double manzilPages = 0.0;
      if (!isAbsentOrSick && parsedManzil != null) {
        final manzilPageItems = (parsedManzil['manzilPages'] as List?);
        if (manzilPageItems != null) {
          manzilPages += manzilPageItems.length.toDouble();
        }
        if (parsedManzil['manzil'] is String) {
          final matches = RegExp(r'Juz\s+\d+').allMatches(parsedManzil['manzil'] as String);
          manzilPages += matches.length * 20.0;
        }
      }

      return student.copyWith(
        todayStatus: log.status,
        todayLogId: log.id,
        todaySabaqPages: sabaqPages,
        todaySabqiPages: sabqiPages,
        todayManzilPages: manzilPages,
      );
    }).toList();
  }

  Future<Map<String, dynamic>> fetchWeeklyReport({
    required String endDateStr,
    required List<Student> cachedStudents,
    required List<SabaqLog> cachedLogs,
    required Set<String> holidaysSet,
    required List<int> weeklyOffDays,
    required double defaultSabaqGoal,
    required double defaultSabqiGoal,
    required double defaultManzilGoal,
  }) async {
    final DateTime endDate = DateTime.tryParse(endDateStr) ?? DateTime.now();
    
    // Generate last 7 dates from oldest to newest
    final List<String> dateStrings = [];
    final List<DateTime> dates = [];
    for (int i = 6; i >= 0; i--) {
      final d = endDate.subtract(Duration(days: i));
      dates.add(d);
      dateStrings.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    // Group logs by student and date
    final studentLogMap = <String, Map<String, SabaqLog>>{};
    for (final log in cachedLogs) {
      final logDate = log.date.contains('T') ? log.date.split('T')[0] : log.date;
      if (dateStrings.contains(logDate)) {
        studentLogMap.putIfAbsent(log.studentId, () => {})[logDate] = log;
      }
    }

    final result = <String, dynamic>{};
    final List<Map<String, dynamic>> studentWeeklyDataList = [];

    for (final student in cachedStudents) {
      final logsForStudent = studentLogMap[student.id] ?? {};
      final isHafiz = student.progressPercent >= 100;
      
      final sabaqGoal = isHafiz ? 0.0 : (student.sabaqGoal ?? defaultSabaqGoal);
      final sabqiGoal = isHafiz ? 0.0 : (student.sabqiGoal ?? defaultSabqiGoal);
      final manzilGoal = student.manzilGoal ?? defaultManzilGoal;

      double sabaqTotal = 0.0;
      double sabqiTotal = 0.0;
      double manzilTotal = 0.0;

      double sabaqExpectedTotal = 0.0;
      double sabqiExpectedTotal = 0.0;
      double manzilExpectedTotal = 0.0;

      final List<Map<String, dynamic>> dailyDots = [];

      for (int i = 0; i < 7; i++) {
        final d = dates[i];
        final dateStr = dateStrings[i];
        final isWeekend = weeklyOffDays.contains(d.weekday);
        final isHoliday = holidaysSet.contains(dateStr);
        final log = logsForStudent[dateStr];

        if (!isWeekend && !isHoliday) {
          sabaqExpectedTotal += sabaqGoal;
          sabqiExpectedTotal += sabqiGoal;
          manzilExpectedTotal += manzilGoal;
        }

        String sabaqColor = 'grey';
        String sabqiColor = 'grey';
        String manzilColor = 'grey';
        String sabaqTooltip = '';
        String sabqiTooltip = '';
        String manzilTooltip = '';

        if (isHoliday) {
          sabaqColor = 'grey';
          sabqiColor = 'grey';
          manzilColor = 'grey';
          sabaqTooltip = '$dateStr: Holiday';
          sabqiTooltip = '$dateStr: Holiday';
          manzilTooltip = '$dateStr: Holiday';
        } else if (isWeekend) {
          sabaqColor = 'grey';
          sabqiColor = 'grey';
          manzilColor = 'grey';
          sabaqTooltip = '$dateStr: Off Day';
          sabqiTooltip = '$dateStr: Off Day';
          manzilTooltip = '$dateStr: Off Day';
        } else if (log == null) {
          sabaqColor = 'red';
          sabqiColor = 'red';
          manzilColor = 'red';
          sabaqTooltip = '$dateStr: No record';
          sabqiTooltip = '$dateStr: No record';
          manzilTooltip = '$dateStr: No record';
        } else {
          final isAbsentOrSick = log.status == 'absent' || log.status == 'sick' || log.status == 'other';
          final preserveStreak = log.sabaq != null && log.sabaq.contains('[PRESERVE_STREAK]');

          if (isAbsentOrSick) {
            final c = preserveStreak ? 'green' : 'red';
            sabaqColor = c;
            sabqiColor = c;
            manzilColor = c;
            final tStr = preserveStreak ? 'Absent (Streak Preserved)' : log.status.toUpperCase();
            sabaqTooltip = '$dateStr: $tStr';
            sabqiTooltip = '$dateStr: $tStr';
            manzilTooltip = '$dateStr: $tStr';
          } else {
            // Normal log
            final sabaqPages = getPagesCountFromSabaqString(log.sabaq);
            
            final sabqiItems = (log.parsedManzil?['sabqi'] as List?);
            final sabqiPages = (sabqiItems != null) ? sabqiItems.length.toDouble() : 0.0;

            double manzilPages = 0.0;
            final parsedManzil = log.parsedManzil;
            if (parsedManzil != null) {
              final manzilPageItems = (parsedManzil['manzilPages'] as List?);
              if (manzilPageItems != null) {
                manzilPages += manzilPageItems.length.toDouble();
              }
              if (parsedManzil['manzil'] is String) {
                final matches = RegExp(r'Juz\s+\d+').allMatches(parsedManzil['manzil'] as String);
                manzilPages += matches.length * 20.0;
              }
            }

            sabaqTotal += sabaqPages;
            sabqiTotal += sabqiPages;
            manzilTotal += manzilPages;

            // Sabaq status
            if (sabaqGoal <= 0) {
              sabaqColor = 'grey';
              sabaqTooltip = '$dateStr: Goal inactive';
            } else if (sabaqPages >= sabaqGoal) {
              sabaqColor = 'green';
              sabaqTooltip = '$dateStr: Goal met (${sabaqPages.toStringAsFixed(1)}/${sabaqGoal.toStringAsFixed(1)} pgs)';
            } else if (sabaqPages > 0) {
              sabaqColor = 'amber';
              sabaqTooltip = '$dateStr: Partial (${sabaqPages.toStringAsFixed(1)}/${sabaqGoal.toStringAsFixed(1)} pgs)';
            } else {
              sabaqColor = 'red';
              sabaqTooltip = '$dateStr: Skipped (0/${sabaqGoal.toStringAsFixed(1)} pgs)';
            }

            // Sabqi status
            if (sabqiGoal <= 0) {
              sabqiColor = 'grey';
              sabqiTooltip = '$dateStr: Goal inactive';
            } else if (sabqiPages >= sabqiGoal) {
              sabqiColor = 'green';
              sabqiTooltip = '$dateStr: Goal met (${sabqiPages.toStringAsFixed(1)}/${sabqiGoal.toStringAsFixed(1)} pgs)';
            } else if (sabqiPages > 0) {
              sabqiColor = 'amber';
              sabqiTooltip = '$dateStr: Partial (${sabqiPages.toStringAsFixed(1)}/${sabqiGoal.toStringAsFixed(1)} pgs)';
            } else {
              sabqiColor = 'red';
              sabqiTooltip = '$dateStr: Skipped (0/${sabqiGoal.toStringAsFixed(1)} pgs)';
            }

            // Manzil status
            if (manzilGoal <= 0) {
              manzilColor = 'grey';
              manzilTooltip = '$dateStr: Goal inactive';
            } else if (manzilPages >= manzilGoal) {
              manzilColor = 'green';
              manzilTooltip = '$dateStr: Goal met (${manzilPages.toStringAsFixed(1)}/${manzilGoal.toStringAsFixed(1)} pgs)';
            } else if (manzilPages > 0) {
              manzilColor = 'amber';
              manzilTooltip = '$dateStr: Partial (${manzilPages.toStringAsFixed(1)}/${manzilGoal.toStringAsFixed(1)} pgs)';
            } else {
              manzilColor = 'red';
              manzilTooltip = '$dateStr: Skipped (0/${manzilGoal.toStringAsFixed(1)} pgs)';
            }
          }
        }

        dailyDots.add({
          'date': dateStr,
          'sabaqColor': sabaqColor,
          'sabqiColor': sabqiColor,
          'manzilColor': manzilColor,
          'sabaqTooltip': sabaqTooltip,
          'sabqiTooltip': sabqiTooltip,
          'manzilTooltip': manzilTooltip,
        });
      }

      studentWeeklyDataList.add({
        'student': student,
        'dailyDots': dailyDots,
        'sabaqTotal': sabaqTotal,
        'sabaqGoal': sabaqExpectedTotal,
        'sabqiTotal': sabqiTotal,
        'sabqiGoal': sabqiExpectedTotal,
        'manzilTotal': manzilTotal,
        'manzilGoal': manzilExpectedTotal,
      });
    }

    result['students'] = studentWeeklyDataList;
    return result;
  }

  Future<Map<String, dynamic>> fetchMonthlyReport({
    required int year,
    required int month,
    required List<Student> cachedStudents,
    required List<SabaqLog> cachedLogs,
    required Set<String> holidaysSet,
    required List<int> weeklyOffDays,
    required double defaultSabaqGoal,
    required double defaultSabqiGoal,
    required double defaultManzilGoal,
  }) async {
    final totalDays = DateTime(year, month + 1, 0).day;
    final String monthPrefix = '$year-${month.toString().padLeft(2, '0')}';

    // Group logs by student
    final studentLogMap = <String, List<SabaqLog>>{};
    for (final log in cachedLogs) {
      final logDate = log.date.contains('T') ? log.date.split('T')[0] : log.date;
      if (logDate.startsWith(monthPrefix)) {
        studentLogMap.putIfAbsent(log.studentId, () => []).add(log);
      }
    }

    final result = <String, dynamic>{};
    final List<Map<String, dynamic>> studentMonthlyDataList = [];

    for (final student in cachedStudents) {
      final logsForStudent = studentLogMap[student.id] ?? [];
      final logMap = {for (var log in logsForStudent) (log.date.contains('T') ? log.date.split('T')[0] : log.date): log};
      
      final isHafiz = student.progressPercent >= 100;
      
      final sabaqGoal = isHafiz ? 0.0 : (student.sabaqGoal ?? defaultSabaqGoal);
      final sabqiGoal = isHafiz ? 0.0 : (student.sabqiGoal ?? defaultSabqiGoal);
      final manzilGoal = student.manzilGoal ?? defaultManzilGoal;

      double sabaqTotal = 0.0;
      double sabqiTotal = 0.0;
      double manzilTotal = 0.0;

      double sabaqExpectedTotal = 0.0;
      double sabqiExpectedTotal = 0.0;
      double manzilExpectedTotal = 0.0;

      int absentCount = 0;
      int sickCount = 0;

      for (int dayNum = 1; dayNum <= totalDays; dayNum++) {
        final d = DateTime(year, month, dayNum);
        final dateStr = '$year-${month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
        final isWeekend = weeklyOffDays.contains(d.weekday);
        final isHoliday = holidaysSet.contains(dateStr);
        final log = logMap[dateStr];

        if (!isWeekend && !isHoliday) {
          sabaqExpectedTotal += sabaqGoal;
          sabqiExpectedTotal += sabqiGoal;
          manzilExpectedTotal += manzilGoal;
        }

        if (log != null) {
          if (log.status == 'absent') {
            absentCount++;
          } else if (log.status == 'sick') {
            sickCount++;
          } else if (log.status != 'other' && log.status != 'sick' && log.status != 'absent') {
            final sabaqPages = getPagesCountFromSabaqString(log.sabaq);
            
            final sabqiItems = (log.parsedManzil?['sabqi'] as List?);
            final sabqiPages = (sabqiItems != null) ? sabqiItems.length.toDouble() : 0.0;

            double manzilPages = 0.0;
            final parsedManzil = log.parsedManzil;
            if (parsedManzil != null) {
              final manzilPageItems = (parsedManzil['manzilPages'] as List?);
              if (manzilPageItems != null) {
                manzilPages += manzilPageItems.length.toDouble();
              }
              if (parsedManzil['manzil'] is String) {
                final matches = RegExp(r'Juz\s+\d+').allMatches(parsedManzil['manzil'] as String);
                manzilPages += matches.length * 20.0;
              }
            }

            sabaqTotal += sabaqPages;
            sabqiTotal += sabqiPages;
            manzilTotal += manzilPages;
          }
        }
      }

      final totalLogged = sabaqTotal + sabqiTotal + manzilTotal;
      final totalExpected = sabaqExpectedTotal + sabqiExpectedTotal + manzilExpectedTotal;
      final completionPercent = totalExpected > 0 ? (totalLogged / totalExpected) * 100 : 0.0;

      studentMonthlyDataList.add({
        'student': student,
        'sabaqTotal': sabaqTotal,
        'sabaqGoal': sabaqExpectedTotal,
        'sabqiTotal': sabqiTotal,
        'sabqiGoal': sabqiExpectedTotal,
        'manzilTotal': manzilTotal,
        'manzilGoal': manzilExpectedTotal,
        'totalLogged': totalLogged,
        'totalExpected': totalExpected,
        'completionPercent': completionPercent,
        'absentCount': absentCount,
        'sickCount': sickCount,
      });
    }

    result['students'] = studentMonthlyDataList;
    return result;
  }
}
