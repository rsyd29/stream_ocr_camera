/// A Flutter package for real-time ANPR (Automatic Number Plate Recognition)
/// of Indonesian license plates and vehicle documents (STNK/BPKB)
/// using on-device ML Kit OCR.
library;

// Existing ANPR
export 'src/anpr_result.dart';
export 'src/anpr_scanner_widget.dart';
export 'src/utils/nopol_validator.dart';

// Document scanning
export 'src/document_scanner_widget.dart';
export 'src/models/document_ocr_result.dart';
export 'src/models/document_type.dart';
export 'src/models/scan_mode.dart';
export 'src/utils/document_accumulator.dart';
export 'src/utils/document_classifier.dart';
export 'src/utils/document_nopol_extractor.dart';
