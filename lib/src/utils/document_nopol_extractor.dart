import '../models/document_type.dart';
import 'nopol_validator.dart';

/// Extracts license plate numbers (Nopol) and vehicle metadata from OCR text,
/// using document-type-specific label patterns.
///
/// For STNK documents, nopol is found after labels like "NOMOR POLISI".
/// For BPKB documents, nopol is found after labels like "NOMOR REGISTRASI".
///
/// Example:
/// ```dart
/// final nopol = DocumentNopolExtractor.extractNopol(
///   ocrText,
///   DocumentType.stnk,
/// );
/// ```
class DocumentNopolExtractor {
  DocumentNopolExtractor._();

  // ── Nopol extraction patterns per document type ────────────────────

  /// STNK: nopol appears after "NOMOR POLISI" or "NO. POL".
  static final List<RegExp> _stnkNopolPatterns = [
    RegExp(
      r'NOMOR\s*POLISI\s*[:\-]?\s*([A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3})',
      caseSensitive: false,
    ),
    RegExp(
      r'NO\.?\s*POL\.?\s*[:\-]?\s*([A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3})',
      caseSensitive: false,
    ),
  ];

  /// BPKB: nopol appears after "NOMOR REGISTRASI" or "NO. REG".
  static final List<RegExp> _bpkbNopolPatterns = [
    RegExp(
      r'NOMOR\s*REGISTRASI\s*[:\-]?\s*([A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3})',
      caseSensitive: false,
    ),
    RegExp(
      r'NO\.?\s*REG\.?\s*[:\-]?\s*([A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{0,3})',
      caseSensitive: false,
    ),
  ];

  // ── Metadata field patterns ────────────────────────────────────────

  static final RegExp _ownerPattern = RegExp(
    r'(?:NAMA\s*PEMILIK|ATAS\s*NAMA|NAMA)\s*[:\-]?\s*([A-Z][A-Z\s\.]{2,})',
    caseSensitive: false,
  );

  static final RegExp _brandPattern = RegExp(
    r'(?:MERK|MEREK)\s*[:\-]?\s*([A-Z][A-Z\s\d]{1,})',
    caseSensitive: false,
  );

  static final RegExp _typePattern = RegExp(
    r'(?:TYPE|TIPE|MODEL)\s*[:\-]?\s*([A-Z\d][A-Z\d\s\.\/]{1,})',
    caseSensitive: false,
  );

  static final RegExp _colorPattern = RegExp(
    r'WARNA\s*[:\-]?\s*([A-Z][A-Z\s]{1,})',
    caseSensitive: false,
  );

  static final RegExp _enginePattern = RegExp(
    r'(?:NOMOR\s*MESIN|NO\.?\s*MESIN)\s*[:\-]?\s*([A-Z\d][A-Z\d\-]{4,})',
    caseSensitive: false,
  );

  static final RegExp _chassisPattern = RegExp(
    r'(?:NOMOR\s*RANGKA|NO\.?\s*RANGKA|NIK|VIN)\s*[:\-/]?\s*([A-Z\d][A-Z\d]{4,})',
    caseSensitive: false,
  );

  /// Extracts nopol from OCR text based on the document type.
  ///
  /// First tries document-specific label patterns (e.g. "NOMOR POLISI" for
  /// STNK). Falls back to [NopolValidator.extractPlate] if no label is found.
  static String? extractNopol(String ocrText, DocumentType type) {
    final text = ocrText.toUpperCase();

    final patterns = switch (type) {
      DocumentType.stnk => _stnkNopolPatterns,
      DocumentType.bpkb => _bpkbNopolPatterns,
      DocumentType.unknown => <RegExp>[
        ..._stnkNopolPatterns,
        ..._bpkbNopolPatterns,
      ],
    };

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)!;
        final cleaned = NopolValidator.clean(raw);
        if (NopolValidator.isValid(cleaned)) return cleaned;
      }
    }

    // Fallback: scan entire text for any valid nopol
    return NopolValidator.extractPlate(ocrText);
  }

  /// Extracts the vehicle owner's name from OCR text.
  static String? extractOwnerName(String ocrText) =>
      _extractField(ocrText, _ownerPattern);

  /// Extracts the vehicle brand/manufacturer from OCR text.
  static String? extractVehicleBrand(String ocrText) =>
      _extractField(ocrText, _brandPattern);

  /// Extracts the vehicle type/model from OCR text.
  static String? extractVehicleType(String ocrText) =>
      _extractField(ocrText, _typePattern);

  /// Extracts the vehicle color from OCR text.
  static String? extractVehicleColor(String ocrText) =>
      _extractField(ocrText, _colorPattern);

  /// Extracts the engine number from OCR text.
  static String? extractEngineNumber(String ocrText) =>
      _extractField(ocrText, _enginePattern);

  /// Extracts the chassis/frame number (VIN) from OCR text.
  static String? extractChassisNumber(String ocrText) =>
      _extractField(ocrText, _chassisPattern);

  /// Extracts all available metadata fields at once.
  static DocumentFields extractAllFields(String ocrText, DocumentType type) {
    return DocumentFields(
      plateNumber: extractNopol(ocrText, type),
      ownerName: extractOwnerName(ocrText),
      vehicleBrand: extractVehicleBrand(ocrText),
      vehicleType: extractVehicleType(ocrText),
      vehicleColor: extractVehicleColor(ocrText),
      engineNumber: extractEngineNumber(ocrText),
      chassisNumber: extractChassisNumber(ocrText),
    );
  }

  static String? _extractField(String ocrText, RegExp pattern) {
    final match = pattern.firstMatch(ocrText.toUpperCase());
    if (match == null) return null;
    final value = match.group(1)?.trim();
    return (value != null && value.isNotEmpty) ? value : null;
  }
}

/// Container for all extracted document metadata fields.
class DocumentFields {
  final String? plateNumber;
  final String? ownerName;
  final String? vehicleBrand;
  final String? vehicleType;
  final String? vehicleColor;
  final String? engineNumber;
  final String? chassisNumber;

  const DocumentFields({
    this.plateNumber,
    this.ownerName,
    this.vehicleBrand,
    this.vehicleType,
    this.vehicleColor,
    this.engineNumber,
    this.chassisNumber,
  });
}
