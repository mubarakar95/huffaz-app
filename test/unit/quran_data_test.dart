import 'package:flutter_test/flutter_test.dart';
import 'package:huffaz_app/utils/quran_data.dart';

void main() {
  group('getPagesFromSabaqString', () {
    test('returns no pages for empty or skipped entries', () {
      expect(getPagesFromSabaqString(''), isEmpty);
      expect(getPagesFromSabaqString('   '), isEmpty);
      expect(getPagesFromSabaqString('[SKIPPED: sick]'), isEmpty);
    });

    test('parses a single page tag', () {
      expect(getPagesFromSabaqString('[Page 23]'), [23]);
    });

    test('parses an explicit page range', () {
      expect(getPagesFromSabaqString('[Page 30-32]'), [30, 31, 32]);
    });

    test('counts back when a page count follows a single page', () {
      const sabaq =
          'Surah Al-Baqara (Ayah 142-153) [Page 23] - 30 Line(s) (2 Page) - Heard by: Teacher';
      expect(getPagesFromSabaqString(sabaq), containsAll([22, 23]));
    });

    test('parses baseline entries and keeps pages inside the mushaf', () {
      final pages = getPagesFromSabaqString('[BASELINE] [1-3] [600-700]');
      expect(pages.take(3), [1, 2, 3]);
      expect(pages.every((p) => p >= 1 && p <= 604), isTrue);
    });

    test('expands a juz reference to its pages', () {
      final pages = getPagesFromSabaqString('Juz 2');
      expect(pages.first, 22);
      expect(pages.last, 41);
    });
  });
}
