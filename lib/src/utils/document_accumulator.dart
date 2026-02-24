import '../models/document_type.dart';
import 'document_classifier.dart';

/// Accumulates OCR text from multiple camera stream frames using a
/// sliding window, enabling more reliable document classification.
///
/// Because document text (STNK/BPKB) is dense and may not be fully
/// captured in a single frame, this class collects text across several
/// frames before attempting classification.
///
/// Example:
/// ```dart
/// final accumulator = DocumentAccumulator();
///
/// // Called on each camera frame:
/// accumulator.addFrame(recognizedText);
///
/// // Check classification when enough frames are collected:
/// if (accumulator.isStable) {
///   final type = accumulator.classifiedType;
///   final text = accumulator.combinedText;
/// }
/// ```
class DocumentAccumulator {
  /// Maximum number of frames to keep in the sliding window.
  final int maxFrames;

  /// Number of consecutive frames with the same classification
  /// required before the result is considered stable.
  final int stabilityThreshold;

  final List<String> _textBuffer = [];
  DocumentType? _lastClassifiedType;
  int _stabilityCount = 0;
  ClassifyResult? _lastResult;

  /// Creates a [DocumentAccumulator].
  ///
  /// [maxFrames] defaults to 10 (sliding window size).
  /// [stabilityThreshold] defaults to 3 (consecutive frames needed for
  /// a stable classification).
  DocumentAccumulator({this.maxFrames = 10, this.stabilityThreshold = 3});

  /// Adds a new frame's OCR text to the accumulator and updates
  /// the classification.
  void addFrame(String ocrText) {
    if (ocrText.trim().isEmpty) return;

    _textBuffer.add(ocrText);
    if (_textBuffer.length > maxFrames) {
      _textBuffer.removeAt(0);
    }

    // Re-classify with combined text
    final result = DocumentClassifier.classify(combinedText);
    _lastResult = result;

    if (result.type == _lastClassifiedType &&
        result.type != DocumentType.unknown) {
      _stabilityCount++;
    } else {
      _lastClassifiedType = result.type;
      _stabilityCount = 1;
    }
  }

  /// The combined text from all frames in the buffer.
  String get combinedText => _textBuffer.join(' ');

  /// The current classified document type (may change between frames).
  DocumentType get classifiedType => _lastResult?.type ?? DocumentType.unknown;

  /// The classification confidence percentage.
  double get confidence => _lastResult?.confidence ?? 0;

  /// Whether the classification is stable — the same type has been
  /// detected for [stabilityThreshold] consecutive frames.
  bool get isStable =>
      _stabilityCount >= stabilityThreshold &&
      classifiedType != DocumentType.unknown;

  /// The number of frames currently in the buffer.
  int get frameCount => _textBuffer.length;

  /// Progress towards a stable classification (0.0 – 1.0).
  double get stabilityProgress =>
      (_stabilityCount / stabilityThreshold).clamp(0.0, 1.0);

  /// Resets the accumulator, clearing all buffered frames.
  void reset() {
    _textBuffer.clear();
    _lastClassifiedType = null;
    _stabilityCount = 0;
    _lastResult = null;
  }
}
