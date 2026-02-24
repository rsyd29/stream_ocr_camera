import 'package:flutter_test/flutter_test.dart';

import 'package:stream_ocr_camera/stream_ocr_camera.dart';

void main() {
  group('NopolValidator', () {
    group('isValid', () {
      test('accepts standard format: B 1234 ABC', () {
        expect(NopolValidator.isValid('B 1234 ABC'), isTrue);
      });

      test('accepts format: DK 9999 XYZ', () {
        expect(NopolValidator.isValid('DK 9999 XYZ'), isTrue);
      });

      test('accepts short format: D 1 A', () {
        expect(NopolValidator.isValid('D 1 A'), isTrue);
      });

      test('accepts format without trailing letters: B 1234', () {
        expect(NopolValidator.isValid('B 1234'), isTrue);
      });

      test('accepts format without spaces: B1234ABC', () {
        expect(NopolValidator.isValid('B1234ABC'), isTrue);
      });

      test('handles lowercase input', () {
        expect(NopolValidator.isValid('b 1234 abc'), isTrue);
      });

      test('rejects empty string', () {
        expect(NopolValidator.isValid(''), isFalse);
      });

      test('rejects purely numeric', () {
        expect(NopolValidator.isValid('12345'), isFalse);
      });

      test('rejects too many prefix letters', () {
        expect(NopolValidator.isValid('ABC 1234 DEF'), isFalse);
      });

      test('rejects too many digits', () {
        expect(NopolValidator.isValid('B 12345 ABC'), isFalse);
      });

      test('rejects too many suffix letters', () {
        expect(NopolValidator.isValid('B 1234 ABCD'), isFalse);
      });

      test('rejects random text', () {
        expect(NopolValidator.isValid('HELLO WORLD'), isFalse);
      });
    });

    group('clean', () {
      test('removes newlines and extra spaces', () {
        expect(NopolValidator.clean('B\n1234\nABC'), equals('B 1234 ABC'));
      });

      test('converts to uppercase', () {
        expect(NopolValidator.clean('b 1234 abc'), equals('B 1234 ABC'));
      });

      test('trims whitespace', () {
        expect(NopolValidator.clean('  B 1234 ABC  '), equals('B 1234 ABC'));
      });
    });

    group('extractPlate', () {
      test('extracts plate from multi-line text', () {
        expect(
          NopolValidator.extractPlate('Some text\nB 1234 ABC\nMore text'),
          equals('B 1234 ABC'),
        );
      });

      test('returns null for text with no plates', () {
        expect(NopolValidator.extractPlate('No plates here'), isNull);
      });

      test('extracts from single-line valid text', () {
        expect(
          NopolValidator.extractPlate('DK 9999 XYZ'),
          equals('DK 9999 XYZ'),
        );
      });
    });

    group('calculateConfidence', () {
      test('returns 100% for fully valid plate: B 1234 ABC', () {
        final result = NopolValidator.calculateConfidence('B 1234 ABC');
        expect(result.percentage, equals(100.0));
        expect(result.plateNumber, equals('B 1234 ABC'));
        expect(result.isValid, isTrue);
      });

      test('returns 100% for fully valid plate: DK 9999 XYZ', () {
        final result = NopolValidator.calculateConfidence('DK 9999 XYZ');
        expect(result.percentage, equals(100.0));
        expect(result.isValid, isTrue);
      });

      test('returns 80% for plate without suffix: B 1234', () {
        final result = NopolValidator.calculateConfidence('B 1234');
        // prefix 20 + digits 30 + partial spacing 8 + full match 20 = 78
        expect(result.percentage, equals(78.0));
        expect(result.plateNumber, equals('B 1234'));
        expect(result.isValid, isTrue);
      });

      test('returns 0% for empty string', () {
        final result = NopolValidator.calculateConfidence('');
        expect(result.percentage, equals(0.0));
        expect(result.plateNumber, isNull);
        expect(result.isValid, isFalse);
      });

      test('returns 0% for whitespace only', () {
        final result = NopolValidator.calculateConfidence('   ');
        expect(result.percentage, equals(0.0));
        expect(result.isValid, isFalse);
      });

      test('returns low confidence for random text', () {
        final result = NopolValidator.calculateConfidence('HELLO WORLD');
        expect(result.percentage, lessThan(50));
        expect(result.isValid, isFalse);
      });

      test('returns low confidence for purely numeric text', () {
        final result = NopolValidator.calculateConfidence('12345');
        expect(result.percentage, lessThan(50));
        expect(result.isValid, isFalse);
      });

      test('extracts best plate from multi-line text', () {
        final result = NopolValidator.calculateConfidence(
          'Some text\nB 1234 ABC\nMore text',
        );
        expect(result.percentage, equals(100.0));
        expect(result.plateNumber, equals('B 1234 ABC'));
        expect(result.isValid, isTrue);
      });

      test('handles lowercase input', () {
        final result = NopolValidator.calculateConfidence('b 1234 abc');
        expect(result.percentage, equals(100.0));
        expect(result.isValid, isTrue);
      });

      test('rawText preserves original input', () {
        const input = 'B 1234 ABC';
        final result = NopolValidator.calculateConfidence(input);
        expect(result.rawText, equals(input));
      });

      // ── Spacing-specific tests ─────────────────────────────────────

      test('full spacing scores 100%: B 1 ASD', () {
        final result = NopolValidator.calculateConfidence('B 1 ASD');
        expect(result.percentage, equals(100.0));
        expect(result.isValid, isTrue);
      });

      test('partial spacing scores less: B1 ASD (no prefix-digit space)', () {
        final result = NopolValidator.calculateConfidence('B1 ASD');
        // Has prefix, digit, suffix, partial spacing (8), full regex match
        // = 20 + 30 + 15 + 8 + 20 = 93
        expect(result.percentage, lessThan(100.0));
        expect(result.isValid, isTrue);
      });

      test('no spacing scores even less: B1ASD', () {
        final result = NopolValidator.calculateConfidence('B1ASD');
        // Has prefix, digit, suffix, NO spacing (0), full regex match
        // = 20 + 30 + 15 + 0 + 20 = 85
        expect(result.percentage, lessThan(93.0));
        expect(result.isValid, isTrue);
      });

      test('B1 ASD scores lower than B 1 ASD', () {
        final withSpace = NopolValidator.calculateConfidence('B 1 ASD');
        final withoutSpace = NopolValidator.calculateConfidence('B1 ASD');
        expect(withoutSpace.percentage, lessThan(withSpace.percentage));
      });
    });
  });
}
