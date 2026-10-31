import 'package:mobile/core/utils/phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('any 11 digits is a valid sign-up / invite phone, as typed', () {
    // The old check (+?[1-9]...) refused every 01... number.
    expect(isValidPhone('01712345678'), isTrue);
    expect(isValidPhone('017-1234 5678'), isTrue);
    expect(isValidPhone('12345678901'), isTrue);
    expect(cleanPhone(' 017-1234 5678 '), '01712345678');
  });

  test('anything but 11 digits is refused', () {
    expect(isValidPhone('+8801712345678'), isFalse);
    expect(isValidPhone('0171234567'), isFalse);
    expect(isValidPhone('017123456789'), isFalse);
    expect(isValidPhone('0171234567a'), isFalse);
  });
}
