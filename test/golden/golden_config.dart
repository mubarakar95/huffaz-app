import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel comparator that tolerates tiny anti-aliasing differences, so goldens
/// recorded on macOS still pass on the Linux CI runner.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.005});

  final double tolerance;

  @override
  Future<bool> compare(List<int> imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent > tolerance) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return true;
  }
}

/// Call once at the top of a golden test file's `main`.
void useTolerantGoldens(String testFilePath, {double tolerance = 0.005}) {
  goldenFileComparator =
      TolerantGoldenComparator(Uri.parse(testFilePath), tolerance: tolerance);
}
