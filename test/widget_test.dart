import 'package:flutter_test/flutter_test.dart';
import 'package:esep_pro/store.dart';

void main() {
  test('numStr shows whole numbers without decimals', () {
    expect(numStr(5.0), '5');
    expect(numStr(2.5), '2.5');
  });

  test('pnum parses comma decimals and spaces', () {
    expect(pnum('1 234,5'), 1234.5);
  });
}
