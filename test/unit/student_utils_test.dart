import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:huffaz_app/utils/student_utils.dart';

Map<String, dynamic> log(String date, String sabaq,
    {String status = 'completed', dynamic manzil = ''}) {
  return {'date': date, 'sabaq': sabaq, 'status': status, 'manzil': manzil};
}

void main() {
  group('juz and page mapping', () {
    test('getJuzForPage maps boundary pages', () {
      expect(getJuzForPage(1), 1);
      expect(getJuzForPage(21), 1);
      expect(getJuzForPage(22), 2);
      expect(getJuzForPage(41), 2);
      expect(getJuzForPage(42), 3);
      expect(getJuzForPage(581), 29);
      expect(getJuzForPage(582), 30);
      expect(getJuzForPage(604), 30);
    });

    test('getPagesForJuz returns the expected ranges', () {
      final juz1 = getPagesForJuz(1);
      expect(juz1.first, 1);
      expect(juz1.last, 21);
      expect(juz1.length, 21);

      final juz2 = getPagesForJuz(2);
      expect(juz2.first, 22);
      expect(juz2.last, 41);

      final juz30 = getPagesForJuz(30);
      expect(juz30.first, 582);
      expect(juz30.last, 604);
    });

    test('all 30 juz cover pages 1 to 604 exactly once', () {
      final all = [for (var j = 1; j <= 30; j++) ...getPagesForJuz(j)];
      expect(all.length, 604);
      expect(all.toSet().length, 604);
      expect(all.first, 1);
      expect(all.last, 604);
    });

    test('every page maps back to the juz that contains it', () {
      for (var j = 1; j <= 30; j++) {
        for (final p in getPagesForJuz(j)) {
          expect(getJuzForPage(p), j, reason: 'page $p should be in juz $j');
        }
      }
    });
  });

  group('shiftDate', () {
    test('formats as yyyy-MM-dd', () {
      expect(shiftDate(DateTime(2026, 3, 5), 0), '2026-03-05');
    });

    test('rolls over months and years', () {
      expect(shiftDate(DateTime(2026, 1, 31), 1), '2026-02-01');
      expect(shiftDate(DateTime(2026, 1, 1), -1), '2025-12-31');
    });

    test('handles leap years', () {
      expect(shiftDate(DateTime(2024, 2, 28), 1), '2024-02-29');
      expect(shiftDate(DateTime(2025, 2, 28), 1), '2025-03-01');
    });
  });

  group('getStreakTier', () {
    test('uses the documented thresholds', () {
      expect(getStreakTier(0)['tier'], 'none');
      expect(getStreakTier(1)['tier'], 'ember');
      expect(getStreakTier(2)['tier'], 'ember');
      expect(getStreakTier(3)['tier'], 'warm');
      expect(getStreakTier(6)['tier'], 'warm');
      expect(getStreakTier(7)['tier'], 'hot');
      expect(getStreakTier(13)['tier'], 'hot');
      expect(getStreakTier(14)['tier'], 'legend');
      expect(getStreakTier(100)['tier'], 'legend');
    });

    test('returns labels', () {
      expect(getStreakTier(14)['label'], 'Legendary Streak');
      expect(getStreakTier(0)['label'], 'No Streak');
    });
  });

  group('getStudentStatus', () {
    final now = DateTime.now();

    test('missing or unparseable last log is Inactive', () {
      expect(getStudentStatus(10, null), 'Inactive');
      expect(getStudentStatus(10, 'not-a-date'), 'Inactive');
    });

    test('recent log with enough velocity is Active', () {
      expect(getStudentStatus(5.0, shiftDate(now, -1)), 'Active');
    });

    test('recent log with low velocity Needs Attention', () {
      expect(getStudentStatus(4.9, shiftDate(now, -1)), 'Needs Attention');
    });

    test('stale log is Inactive whatever the velocity', () {
      expect(getStudentStatus(20, shiftDate(now, -20)), 'Inactive');
    });
  });

  group('computeWeeklyVelocity', () {
    final now = DateTime.now();

    test('sums pages from logs inside the last week', () {
      final logs = [
        log(shiftDate(now, 0), '[Page 23]'),
        log(shiftDate(now, -3), '[Page 30-32]'),
      ];
      expect(computeWeeklyVelocity(logs), 4);
    });

    test('ignores old logs, future logs and skipped lessons', () {
      final logs = [
        log(shiftDate(now, -10), '[Page 10]'),
        log(shiftDate(now, 2), '[Page 11]'),
        log(shiftDate(now, -1), '[SKIPPED: holiday]'),
      ];
      expect(computeWeeklyVelocity(logs), 0);
    });

    test('is zero with no logs', () {
      expect(computeWeeklyVelocity([]), 0);
    });
  });

  group('computeStreak', () {
    final now = DateTime.now();
    String day(int delta) => shiftDate(now, delta);

    int streak(List<Map<String, dynamic>> logs,
        {Set<String> holidays = const {},
        List<int> off = const [],
        bool hafiz = false,
        double manzilGoal = 0}) {
      return computeStreak(logs, holidays, off, 1, 0, manzilGoal,
          isHafiz: hafiz);
    }

    test('is zero with no logs', () {
      expect(streak([]), 0);
    });

    test('counts consecutive days ending today', () {
      final logs = [
        log(day(0), '[Page 10]'),
        log(day(-1), '[Page 9]'),
        log(day(-2), '[Page 8]'),
      ];
      expect(streak(logs), 3);
    });

    test('a missing day breaks the streak', () {
      final logs = [
        log(day(0), '[Page 10]'),
        log(day(-1), '[Page 9]'),
        log(day(-3), '[Page 7]'),
      ];
      expect(streak(logs), 2);
    });

    test('today not logged yet does not reset a streak from yesterday', () {
      final logs = [
        log(day(-1), '[Page 9]'),
        log(day(-2), '[Page 8]'),
      ];
      expect(streak(logs), 2);
    });

    test('holidays are skipped without breaking the streak', () {
      final logs = [
        log(day(0), '[Page 10]'),
        log(day(-2), '[Page 8]'),
      ];
      expect(streak(logs, holidays: {day(-1)}), 2);
    });

    test('weekly off days are skipped without breaking the streak', () {
      final offWeekday = now.subtract(const Duration(days: 1)).weekday;
      final logs = [
        log(day(0), '[Page 10]'),
        log(day(-2), '[Page 8]'),
      ];
      expect(streak(logs, off: [offWeekday]), 2);
    });

    test('a sick day breaks the streak', () {
      final logs = [
        log(day(0), '[Page 10]'),
        log(day(-1), '', status: 'sick'),
        log(day(-2), '[Page 8]'),
      ];
      expect(streak(logs), 1);
    });

    test('a sick day marked PRESERVE_STREAK keeps the streak alive', () {
      final logs = [
        log(day(0), '[Page 10]'),
        log(day(-1), '[PRESERVE_STREAK]', status: 'sick'),
        log(day(-2), '[Page 8]'),
      ];
      expect(streak(logs), 2);
    });

    test('baseline entries never count', () {
      final logs = [log(day(0), '[BASELINE] [1-20]', status: 'baseline')];
      expect(streak(logs), 0);
    });

    test('a skipped lesson does not extend the streak', () {
      final logs = [log(day(0), '[SKIPPED: not ready]')];
      expect(streak(logs), 0);
    });

    test('hafiz mode only needs the manzil goal', () {
      final manzil = jsonEncode({
        'manzilPages': [
          {'page': 5, 'sabaq': 'x', 'surahName': 'Baqara'}
        ],
      });
      final logs = [log(day(0), '', manzil: manzil)];
      expect(streak(logs, hafiz: true, manzilGoal: 1), 1);
    });
  });
}
