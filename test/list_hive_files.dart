import 'dart:io';

void main() {
  final dir = Directory('${Directory.current.path}/test');
  for (final f in dir.listSync()) {
    print(f.path);
  }
}
