import 'package:flutter_test/flutter_test.dart';
import 'package:hicall/services/phone_service.dart';

void main() {
  group('PhoneService.normalize', () {
    test('normalizes common formatting to E.164', () {
      expect(PhoneService.normalize(' +1 (415) 555-0123 '), '+14155550123');
    });

    test('accepts valid international numbers without formatting', () {
      expect(PhoneService.normalize('+442071838750'), '+442071838750');
    });

    test('rejects local numbers without a country code', () {
      expect(() => PhoneService.normalize('4155550123'), throwsFormatException);
    });

    test('rejects extensions and invalid symbols', () {
      expect(() => PhoneService.normalize('+1 415 555 0123 ext 9'), throwsFormatException);
    });

    test('rejects numbers outside E.164 length bounds', () {
      expect(() => PhoneService.normalize('+1234567'), throwsFormatException);
      expect(() => PhoneService.normalize('+1234567890123456'), throwsFormatException);
    });
  });
}
