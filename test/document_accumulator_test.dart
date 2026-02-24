import 'package:flutter_test/flutter_test.dart';
import 'package:stream_ocr_camera/stream_ocr_camera.dart';

void main() {
  group('DocumentAccumulator', () {
    late DocumentAccumulator accumulator;

    setUp(() {
      accumulator = DocumentAccumulator(maxFrames: 5, stabilityThreshold: 3);
    });

    test('starts with unknown classification', () {
      expect(accumulator.classifiedType, equals(DocumentType.unknown));
      expect(accumulator.confidence, equals(0));
      expect(accumulator.isStable, isFalse);
      expect(accumulator.frameCount, equals(0));
    });

    test('adds frames and accumulates text', () {
      accumulator.addFrame('Hello');
      accumulator.addFrame('World');

      expect(accumulator.frameCount, equals(2));
      expect(accumulator.combinedText, contains('Hello'));
      expect(accumulator.combinedText, contains('World'));
    });

    test('sliding window respects maxFrames', () {
      for (int i = 0; i < 10; i++) {
        accumulator.addFrame('Frame $i');
      }

      expect(accumulator.frameCount, equals(5));
      expect(accumulator.combinedText, isNot(contains('Frame 0')));
      expect(accumulator.combinedText, contains('Frame 9'));
    });

    test('classifies STNK after accumulating keyword frames', () {
      accumulator.addFrame('SURAT TANDA NOMOR KENDARAAN');
      accumulator.addFrame('STNK SAMSAT');
      accumulator.addFrame('BERLAKU SAMPAI');

      expect(accumulator.classifiedType, equals(DocumentType.stnk));
    });

    test('becomes stable after threshold consecutive classifications', () {
      // Each frame adds STNK keyword
      accumulator.addFrame('STNK dokumen');
      expect(accumulator.isStable, isFalse);

      accumulator.addFrame('STNK teks lain');
      expect(accumulator.isStable, isFalse);

      accumulator.addFrame('STNK lagi');
      expect(accumulator.isStable, isTrue);
    });

    test('stability resets when classification changes', () {
      accumulator.addFrame('STNK');
      accumulator.addFrame('STNK');
      // Not yet stable (need 3)
      expect(accumulator.isStable, isFalse);

      // Now add enough BPKB text to flip classification
      accumulator.addFrame('BPKB IDENTITAS KENDARAAN VEHICLE IDENTITY');
      accumulator.addFrame('BPKB IDENTITAS KENDARAAN VEHICLE IDENTITY');

      // Stability count resets
      expect(accumulator.isStable, isFalse);
    });

    test('ignores empty frames', () {
      accumulator.addFrame('');
      accumulator.addFrame('   ');

      expect(accumulator.frameCount, equals(0));
    });

    test('reset clears all state', () {
      accumulator.addFrame('STNK');
      accumulator.addFrame('STNK');
      accumulator.addFrame('STNK');
      expect(accumulator.isStable, isTrue);

      accumulator.reset();

      expect(accumulator.frameCount, equals(0));
      expect(accumulator.classifiedType, equals(DocumentType.unknown));
      expect(accumulator.isStable, isFalse);
      expect(accumulator.confidence, equals(0));
      expect(accumulator.combinedText, isEmpty);
    });

    test('stabilityProgress reflects progress toward threshold', () {
      expect(accumulator.stabilityProgress, equals(0.0));

      accumulator.addFrame('STNK');
      expect(accumulator.stabilityProgress, closeTo(1 / 3, 0.01));

      accumulator.addFrame('STNK');
      expect(accumulator.stabilityProgress, closeTo(2 / 3, 0.01));

      accumulator.addFrame('STNK');
      expect(accumulator.stabilityProgress, equals(1.0));
    });
  });
}
