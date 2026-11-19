import 'package:flutter_test/flutter_test.dart';
import 'package:huffaz_app/utils/quran_data.dart';

void main() {
  test('test single page with page count', () {
    final sabaqStr = "Surah Al-Baqara (Ayah 142-153) [Page 23] - 30 Line(s) (2 Page) - Heard by: Nuhman";
    final pages = getPagesFromSabaqString(sabaqStr);
    print('PARSED PAGES: $pages');
    expect(pages, containsAll([22, 23]));
  });
}
