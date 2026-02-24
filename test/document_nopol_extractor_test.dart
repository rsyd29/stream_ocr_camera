import 'package:flutter_test/flutter_test.dart';
import 'package:stream_ocr_camera/stream_ocr_camera.dart';

void main() {
  group('DocumentNopolExtractor', () {
    group('extractNopol', () {
      test('extracts nopol from STNK text after NOMOR POLISI', () {
        const ocrText = '''
          SURAT TANDA NOMOR KENDARAAN BERMOTOR
          NOMOR POLISI: B 2562 UFO
          NAMA PEMILIK: PT SERASI AUTORAYA
        ''';

        final nopol = DocumentNopolExtractor.extractNopol(
          ocrText,
          DocumentType.stnk,
        );
        expect(nopol, equals('B 2562 UFO'));
      });

      test('extracts nopol from STNK text after NO. POL', () {
        const ocrText = '''
          NO. POL B 1234 ABC
          MERK: TOYOTA
        ''';

        final nopol = DocumentNopolExtractor.extractNopol(
          ocrText,
          DocumentType.stnk,
        );
        expect(nopol, equals('B 1234 ABC'));
      });

      test('extracts nopol from BPKB text after NOMOR REGISTRASI', () {
        const ocrText = '''
          II. IDENTITAS KENDARAAN
          1. Nomor Registrasi: B 3203 UNP
          2. Merek: VIAR
        ''';

        final nopol = DocumentNopolExtractor.extractNopol(
          ocrText,
          DocumentType.bpkb,
        );
        expect(nopol, equals('B 3203 UNP'));
      });

      test('falls back to NopolValidator if label not found', () {
        const ocrText = '''
          Random text
          B 5678 XYZ
          More random text
        ''';

        final nopol = DocumentNopolExtractor.extractNopol(
          ocrText,
          DocumentType.stnk,
        );
        expect(nopol, equals('B 5678 XYZ'));
      });

      test('returns null when no valid nopol found', () {
        const ocrText = 'Hello World no plate here';

        final nopol = DocumentNopolExtractor.extractNopol(
          ocrText,
          DocumentType.stnk,
        );
        expect(nopol, isNull);
      });

      test('extracts nopol with unknown document type', () {
        const ocrText = 'NOMOR POLISI: DK 9999 XYZ';

        final nopol = DocumentNopolExtractor.extractNopol(
          ocrText,
          DocumentType.unknown,
        );
        expect(nopol, equals('DK 9999 XYZ'));
      });
    });

    group('extractAllFields', () {
      test('extracts multiple fields from STNK text', () {
        const ocrText = '''
          NOMOR POLISI: B 2562 UFO
          NAMA PEMILIK: PT SERASI AUTORAYA
          MERK: TOYOTA
          TYPE: ALPHARD
          WARNA: SILVER METALIK
          NOMOR MESIN: N05177277
          NOMOR RANGKA: 3TNRK30H7H8023200
        ''';

        final fields = DocumentNopolExtractor.extractAllFields(
          ocrText,
          DocumentType.stnk,
        );

        expect(fields.plateNumber, equals('B 2562 UFO'));
        expect(fields.ownerName, isNotNull);
        expect(fields.vehicleBrand, isNotNull);
        expect(fields.vehicleType, isNotNull);
        expect(fields.vehicleColor, isNotNull);
      });

      test('extracts fields from BPKB text', () {
        const ocrText = '''
          NOMOR REGISTRASI: B 3203 UNP
          MEREK: VIAR
          TYPE: V 1 Q A/T
          WARNA: GREY
          NOMOR MESIN: YR001FMG17000001
          NOMOR RANGKA: MF3VRO1SCHL000002
        ''';

        final fields = DocumentNopolExtractor.extractAllFields(
          ocrText,
          DocumentType.bpkb,
        );

        expect(fields.plateNumber, equals('B 3203 UNP'));
        expect(fields.vehicleBrand, isNotNull);
        expect(fields.vehicleColor, isNotNull);
      });
    });

    group('individual field extractors', () {
      test('extractOwnerName finds name after NAMA PEMILIK', () {
        const text = 'NAMA PEMILIK: PT SERASI AUTORAYA';
        expect(DocumentNopolExtractor.extractOwnerName(text), isNotNull);
      });

      test('extractVehicleBrand finds brand after MERK', () {
        const text = 'MERK: TOYOTA';
        expect(DocumentNopolExtractor.extractVehicleBrand(text), isNotNull);
      });

      test('extractVehicleColor finds color after WARNA', () {
        const text = 'WARNA: SILVER METALIK';
        expect(DocumentNopolExtractor.extractVehicleColor(text), isNotNull);
      });

      test('extractEngineNumber finds engine number', () {
        const text = 'NOMOR MESIN: N05177277';
        expect(DocumentNopolExtractor.extractEngineNumber(text), isNotNull);
      });

      test('extractChassisNumber finds chassis number', () {
        const text = 'NOMOR RANGKA: 3TNRK30H7H8023200';
        expect(DocumentNopolExtractor.extractChassisNumber(text), isNotNull);
      });

      test('returns null when field not found', () {
        const text = 'Some random text';
        expect(DocumentNopolExtractor.extractOwnerName(text), isNull);
        expect(DocumentNopolExtractor.extractVehicleBrand(text), isNull);
        expect(DocumentNopolExtractor.extractVehicleColor(text), isNull);
        expect(DocumentNopolExtractor.extractEngineNumber(text), isNull);
        expect(DocumentNopolExtractor.extractChassisNumber(text), isNull);
      });
    });
  });
}
