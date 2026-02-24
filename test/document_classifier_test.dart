import 'package:flutter_test/flutter_test.dart';
import 'package:stream_ocr_camera/stream_ocr_camera.dart';

void main() {
  group('DocumentClassifier', () {
    group('classify', () {
      test('classifies STNK text correctly', () {
        const ocrText = '''
          KEPOLISIAN NEGARA REPUBLIK INDONESIA
          SURAT TANDA NOMOR KENDARAAN BERMOTOR
          VEHICLE REGISTRATION CERTIFICATE
          NOMOR POLISI: B 2562 UFO
          NAMA PEMILIK: PT SERASI AUTORAYA
          MERK: TOYOTA
          TYPE: ALPHARD 3.5 Q AT
          BERLAKU SAMPAI: 17-10-2023
          SAMSAT
        ''';

        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.stnk));
        expect(result.confidence, greaterThan(50));
      });

      test('classifies BPKB text correctly', () {
        const ocrText = '''
          II. IDENTITAS KENDARAAN
          VEHICLE IDENTITY
          1. Nomor Registrasi: B 3203 UNP
          2. Merek: VIAR
          3. Type: V 1 Q A/T
          4. Jenis: SEPEDA MOTOR
          5. Model: SCOOTER
          6. Tahun Pembuatan: 2017
          7. Isi Silinder: 800 W
          8. Warna: GREY
          9. Nomor Rangka/NIK/VIN: MF3VRO1SCHL000002
          10. Nomor Mesin: YR001FMG17000001
        ''';

        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.bpkb));
        expect(result.confidence, greaterThan(50));
      });

      test('classifies STNK with primary keyword only', () {
        const ocrText = 'STNK';
        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.stnk));
      });

      test('classifies BPKB with primary keyword only', () {
        const ocrText = 'BPKB';
        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.bpkb));
      });

      test('returns unknown for random text', () {
        const ocrText = 'Hello World 12345';
        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.unknown));
        expect(result.confidence, equals(0));
      });

      test('returns unknown for empty text', () {
        final result = DocumentClassifier.classify('');
        expect(result.type, equals(DocumentType.unknown));
      });

      test('STNK wins over BPKB when score is higher', () {
        const ocrText = '''
          SURAT TANDA NOMOR KENDARAAN BERMOTOR
          VEHICLE REGISTRATION CERTIFICATE
          STNK
          SAMSAT
          BERLAKU SAMPAI
        ''';
        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.stnk));
      });

      test('handles case insensitive text', () {
        const ocrText = 'surat tanda nomor kendaraan bermotor';
        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.stnk));
      });

      test('secondary keywords alone are not enough (below threshold)', () {
        // Only 2 secondary keywords = 2 points, below threshold of 3
        const ocrText = 'SAMSAT BERLAKU SAMPAI';
        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.unknown));
      });

      test('3+ secondary keywords are enough to classify', () {
        // 3 secondary keywords = 3 points = meets threshold
        const ocrText = 'SAMSAT BERLAKU SAMPAI NOTICE PAJAK';
        final result = DocumentClassifier.classify(ocrText);
        expect(result.type, equals(DocumentType.stnk));
      });
    });
  });
}
