import 'document_type.dart';

/// Data class representing the result of a document OCR scan.
///
/// Contains the classified document type, extracted nopol, and
/// additional metadata fields parsed from STNK or BPKB documents.
class DocumentOcrResult {
  /// The classified document type.
  final DocumentType documentType;

  /// The extracted license plate number (Nomor Polisi), or `null` if
  /// no valid plate was found.
  final String? plateNumber;

  /// The vehicle owner's name, or `null` if not found.
  final String? ownerName;

  /// The vehicle brand/manufacturer (Merek), or `null` if not found.
  final String? vehicleBrand;

  /// The vehicle type/model, or `null` if not found.
  final String? vehicleType;

  /// The vehicle color (Warna), or `null` if not found.
  final String? vehicleColor;

  /// The engine number (Nomor Mesin), or `null` if not found.
  final String? engineNumber;

  /// The chassis/frame number (Nomor Rangka/VIN), or `null` if not found.
  final String? chassisNumber;

  /// Classification confidence percentage (0.0 – 100.0).
  final double confidence;

  /// The full raw OCR text used for classification and extraction.
  final String rawText;

  /// Timestamp when the document was detected.
  final DateTime timestamp;

  /// Creates a [DocumentOcrResult].
  const DocumentOcrResult({
    required this.documentType,
    this.plateNumber,
    this.ownerName,
    this.vehicleBrand,
    this.vehicleType,
    this.vehicleColor,
    this.engineNumber,
    this.chassisNumber,
    required this.confidence,
    required this.rawText,
    required this.timestamp,
  });

  /// Whether any meaningful data was extracted from the document.
  bool get hasData =>
      plateNumber != null ||
      ownerName != null ||
      vehicleBrand != null ||
      vehicleType != null;

  @override
  String toString() =>
      'DocumentOcrResult(type: $documentType, plate: $plateNumber, '
      'confidence: ${confidence.toStringAsFixed(1)}%)';
}
