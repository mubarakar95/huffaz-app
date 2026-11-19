import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:huffaz_app/models/sabaq_log.dart';
import 'package:huffaz_app/models/student.dart';

void main() {
  group('Student', () {
    test('fromMap reads snake_case database columns', () {
      final s = Student.fromMap({
        'id': 's1',
        'full_name': 'Test Student',
        'institution_id': 'inst1',
        'is_personal': true,
        'sabaq_goal': 2,
        'profiles': {'full_name': 'Test Teacher'},
      });
      expect(s.id, 's1');
      expect(s.fullName, 'Test Student');
      expect(s.institutionId, 'inst1');
      expect(s.isPersonal, isTrue);
      expect(s.sabaqGoal, 2.0);
      expect(s.teacherName, 'Test Teacher');
    });

    test('fromMap falls back to defaults for missing fields', () {
      final s = Student.fromMap({});
      expect(s.id, '');
      expect(s.fullName, '');
      expect(s.isPersonal, isFalse);
      expect(s.streak, 0);
      expect(s.todaySabaqPages, 0.0);
    });

    test('toMap and fromMap round trip', () {
      final original = Student.fromMap({
        'id': 's1',
        'full_name': 'Test Student',
        'institution_id': 'inst1',
        'sabaq_goal': 1.5,
        'streak': 4,
      });
      final copy = Student.fromMap(original.toMap());
      expect(copy.id, original.id);
      expect(copy.fullName, original.fullName);
      expect(copy.sabaqGoal, 1.5);
      expect(copy.streak, 4);
    });
  });

  group('SabaqLog', () {
    SabaqLog build({dynamic manzil, String sabaq = ''}) => SabaqLog.fromMap({
          'id': 'l1',
          'student_id': 's1',
          'teacher_id': 't1',
          'date': '2026-01-01',
          'sabaq': sabaq,
          'manzil': manzil,
          'status': 'completed',
          'created_at': '2026-01-01T10:00:00Z',
        });

    test('fromMap reads database columns', () {
      final l = build(sabaq: '[Page 5]');
      expect(l.studentId, 's1');
      expect(l.teacherId, 't1');
      expect(l.date, '2026-01-01');
      expect(l.createdAt.toUtc().hour, 10);
    });

    test('parsedManzil handles maps, json strings and bad input', () {
      expect(build(manzil: {'a': 1}).parsedManzil, {'a': 1});
      expect(build(manzil: jsonEncode({'a': 1})).parsedManzil, {'a': 1});
      expect(build(manzil: 'not json').parsedManzil, isNull);
      expect(build(manzil: null).parsedManzil, isNull);
    });

    test('sabaqParaCount skips entries marked SKIPPED', () {
      final l = build(manzil: {
        'sabqi': [
          {'sabaq': 'Juz 1'},
          {'sabaq': '[SKIPPED]'},
          {'sabaq': null},
        ],
      });
      expect(l.sabaqParaCount, 2);
    });

    test('murajaCount ignores page -1 and skipped entries', () {
      final l = build(manzil: {
        'manzilPages': [
          {'page': 5, 'sabaq': 'x'},
          {'page': -1, 'sabaq': 'x'},
          {'page': 6, 'sabaq': '[SKIPPED]'},
        ],
      });
      expect(l.murajaCount, 1);
    });

    test('cleanSabaqText strips teacher and line suffixes', () {
      final l = build(sabaq: 'Surah Al-Baqara [Page 23] - 30 Line(s) - Heard by: Teacher');
      expect(l.cleanSabaqText, 'Surah Al-Baqara [Page 23]');
    });
  });
}
