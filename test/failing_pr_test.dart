import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intentional failure to verify PR blocking behavior', () {
    expect(1, 2);
  });
}