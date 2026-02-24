/// Data class representing a detected license plate result.
class AnprResult {
  /// The detected license plate number text.
  final String plateNumber;

  /// The raw text before cleaning/validation.
  final String rawText;

  /// Timestamp when the plate was detected.
  final DateTime timestamp;

  /// OCR confidence/accuracy percentage (0.0 - 100.0).
  ///
  /// Calculated based on how well the raw OCR text matches
  /// the Indonesian nopol regex pattern components:
  /// - Prefix letters (25%), Digits (35%), Suffix letters (20%), Full match (20%).
  final double confidence;

  /// Creates an [AnprResult].
  const AnprResult({
    required this.plateNumber,
    required this.rawText,
    required this.timestamp,
    this.confidence = 0,
  });

  @override
  String toString() =>
      'AnprResult(plateNumber: $plateNumber, rawText: $rawText, '
      'confidence: ${confidence.toStringAsFixed(1)}%, timestamp: $timestamp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnprResult &&
          runtimeType == other.runtimeType &&
          plateNumber == other.plateNumber;

  @override
  int get hashCode => plateNumber.hashCode;
}
