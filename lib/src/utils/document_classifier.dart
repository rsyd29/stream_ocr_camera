import '../models/document_type.dart';

/// Result of a document classification attempt.
class ClassifyResult {
  /// The classified document type.
  final DocumentType type;

  /// Confidence percentage (0.0 – 100.0).
  final double confidence;

  /// Creates a [ClassifyResult].
  const ClassifyResult({required this.type, required this.confidence});

  @override
  String toString() =>
      'ClassifyResult(type: $type, confidence: ${confidence.toStringAsFixed(1)}%)';
}

/// Classifies OCR text as STNK, BPKB, or unknown using keyword-based scoring.
///
/// Each keyword has a weight: **primary keywords** (unique identifiers) score
/// 3 points, **secondary keywords** score 1 point. A minimum of 3 points is
/// required for a confident classification.
///
/// Example usage:
/// ```dart
/// final result = DocumentClassifier.classify(ocrText);
/// if (result.type == DocumentType.stnk) {
///   // Handle STNK document
/// }
/// ```
class DocumentClassifier {
  DocumentClassifier._();

  // ── STNK Keywords ─────────────────────────────────────────────────

  /// Primary keywords unique to STNK documents (3 pts each).
  static const _stnkPrimaryKeywords = [
    'SURAT TANDA NOMOR KENDARAAN',
    'VEHICLE REGISTRATION CERTIFICATE',
    'STNK',
  ];

  /// Secondary keywords that commonly appear on STNK (1 pt each).
  static const _stnkSecondaryKeywords = [
    'SAMSAT',
    'BERLAKU SAMPAI',
    'TANDA BUKTI PELUNASAN',
    'NOTICE PAJAK',
    'KEWAJIBAN PEMBAYARAN',
    'NOMOR POLISI',
  ];

  // ── BPKB Keywords ─────────────────────────────────────────────────

  /// Primary keywords unique to BPKB documents (3 pts each).
  static const _bpkbPrimaryKeywords = [
    'IDENTITAS KENDARAAN',
    'VEHICLE IDENTITY',
    'BUKU PEMILIK KENDARAAN',
    'BPKB',
  ];

  /// Secondary keywords that commonly appear on BPKB (1 pt each).
  static const _bpkbSecondaryKeywords = [
    'NOMOR REGISTRASI',
    'ISI SILINDER',
    'TAHUN PEMBUATAN',
    'NOMOR RANGKA',
    'CYLINDER CAPACITY',
    'MANUFACTURE YEAR',
  ];

  /// Maximum possible score for STNK classification.
  static final int _stnkMaxScore =
      _stnkPrimaryKeywords.length * 3 + _stnkSecondaryKeywords.length;

  /// Maximum possible score for BPKB classification.
  static final int _bpkbMaxScore =
      _bpkbPrimaryKeywords.length * 3 + _bpkbSecondaryKeywords.length;

  /// Minimum score required for a confident classification.
  static const int _minThreshold = 3;

  /// Classifies the given [ocrText] as a document type.
  ///
  /// Scores the text against STNK and BPKB keyword lists, then returns
  /// the highest-scoring type if it meets the minimum threshold.
  static ClassifyResult classify(String ocrText) {
    final text = ocrText.toUpperCase();

    final stnkScore = _score(
      text,
      _stnkPrimaryKeywords,
      _stnkSecondaryKeywords,
    );
    final bpkbScore = _score(
      text,
      _bpkbPrimaryKeywords,
      _bpkbSecondaryKeywords,
    );

    if (stnkScore >= _minThreshold && stnkScore > bpkbScore) {
      return ClassifyResult(
        type: DocumentType.stnk,
        confidence: _toPercentage(stnkScore, _stnkMaxScore),
      );
    }

    if (bpkbScore >= _minThreshold && bpkbScore > stnkScore) {
      return ClassifyResult(
        type: DocumentType.bpkb,
        confidence: _toPercentage(bpkbScore, _bpkbMaxScore),
      );
    }

    return const ClassifyResult(type: DocumentType.unknown, confidence: 0);
  }

  /// Calculates the total keyword score for [text].
  static int _score(String text, List<String> primary, List<String> secondary) {
    int score = 0;
    for (final kw in primary) {
      if (text.contains(kw)) score += 3;
    }
    for (final kw in secondary) {
      if (text.contains(kw)) score += 1;
    }
    return score;
  }

  /// Converts a raw score to a percentage (0.0 – 100.0).
  static double _toPercentage(int score, int maxScore) {
    if (maxScore <= 0) return 0;
    return (score / maxScore * 100).clamp(0, 100);
  }
}
