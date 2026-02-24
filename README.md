# stream_ocr_camera

A Flutter package for **real-time OCR scanning** of Indonesian license plates (**Plat Nomor**) and vehicle documents (**STNK** & **BPKB**) using on-device Google ML Kit Text Recognition from a live camera stream.

## ✨ Features

- 🚗 **License Plate (ANPR)** — Real-time Indonesian plate detection with confidence scoring
- 📄 **STNK Scanning** — Detect and extract data from STNK documents
- 📘 **BPKB Scanning** — Detect and extract data from BPKB documents
- 🔍 **Auto-Detect** — Automatically identify document type
- 📷 **Single & Multi-plate** — Scan one plate at a time or multiple plates simultaneously
- 🔦 Flash, tap-to-focus, camera pause/resume built-in

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  stream_ocr_camera:
    path: ../stream_ocr_camera  # or your path / git url
```

### Platform Setup

**Android** — Add camera permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** — Add camera usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is required for document scanning</string>
```

## 🚀 Quick Start

### 1. License Plate Scanning (Plat Nomor)

The simplest way to scan Indonesian license plates in real-time:

```dart
import 'package:stream_ocr_camera/stream_ocr_camera.dart';

// Single plate mode (default)
AnprScannerWidget(
  onPlateDetected: (result) {
    print('Plate: ${result.plateNumber}');     // e.g. "B 1234 ABC"
    print('Confidence: ${result.confidence}%'); // e.g. 100.0
    print('Raw OCR: ${result.rawText}');
  },
)
```

**Multi-plate mode** — detect multiple plates in the same frame:

```dart
AnprScannerWidget(
  multiPlateMode: true,
  onMultiplePlatesDetected: (results) {
    for (final r in results) {
      print('Detected: ${r.plateNumber}');
    }
  },
)
```

### 2. STNK Document Scanning

Scan STNK documents to extract plate number and vehicle metadata:

```dart
DocumentScannerWidget(
  scanMode: ScanMode.stnk,
  onDocumentDetected: (result) {
    print('Document: ${result.documentType}');  // DocumentType.stnk
    print('Nopol: ${result.plateNumber}');      // e.g. "B 2562 UFO"
    print('Pemilik: ${result.ownerName}');      // e.g. "PT SERASI AUTORAYA"
    print('Merek: ${result.vehicleBrand}');     // e.g. "TOYOTA"
    print('Tipe: ${result.vehicleType}');       // e.g. "ALPHARD 3.5 Q AT"
    print('Warna: ${result.vehicleColor}');     // e.g. "SILVER METALIK"
    print('No. Mesin: ${result.engineNumber}');
    print('No. Rangka: ${result.chassisNumber}');
  },
)
```

### 3. BPKB Document Scanning

Scan BPKB identity pages to extract vehicle registration data:

```dart
DocumentScannerWidget(
  scanMode: ScanMode.bpkb,
  onDocumentDetected: (result) {
    print('Document: ${result.documentType}');  // DocumentType.bpkb
    print('Nopol: ${result.plateNumber}');      // e.g. "B 3203 UNP"
    print('Merek: ${result.vehicleBrand}');     // e.g. "VIAR"
    print('Tipe: ${result.vehicleType}');       // e.g. "V 1 Q A/T"
    print('Warna: ${result.vehicleColor}');     // e.g. "GREY"
  },
)
```

### 4. Auto-Detect Mode

Let the system automatically classify the document type:

```dart
DocumentScannerWidget(
  scanMode: ScanMode.auto,
  onDocumentDetected: (result) {
    switch (result.documentType) {
      case DocumentType.stnk:
        print('STNK detected! Nopol: ${result.plateNumber}');
        break;
      case DocumentType.bpkb:
        print('BPKB detected! Nopol: ${result.plateNumber}');
        break;
      case DocumentType.unknown:
        print('Unknown document');
        break;
    }
  },
)
```

## 📖 API Reference

### Scan Modes

| Mode | Widget | Description |
|------|--------|-------------|
| `ScanMode.plateOnly` | `DocumentScannerWidget` | License plate only (same as `AnprScannerWidget`) |
| `ScanMode.stnk` | `DocumentScannerWidget` | Scan STNK documents |
| `ScanMode.bpkb` | `DocumentScannerWidget` | Scan BPKB documents |
| `ScanMode.auto` | `DocumentScannerWidget` | Auto-detect document type |

### AnprScannerWidget

The original ANPR scanner for license plate detection.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `onPlateDetected` | `ValueChanged<AnprResult>?` | — | Callback for single plate mode |
| `onMultiplePlatesDetected` | `ValueChanged<List<AnprResult>>?` | — | Callback for multi plate mode |
| `multiPlateMode` | `bool` | `false` | Enable multi-plate detection |
| `onError` | `ValueChanged<String>?` | — | Error callback |
| `showFlashButton` | `bool` | `true` | Show flash toggle |
| `showCameraToggleButton` | `bool` | `true` | Show camera on/off toggle |
| `resolution` | `ResolutionPreset` | `high` | Camera resolution |
| `overlayColor` | `Color` | `0x99000000` | Overlay background color |
| `borderColor` | `Color` | `white` | Scanner border color |
| `successBorderColor` | `Color` | `greenAccent` | Border color on detection |

### DocumentScannerWidget

Scanner widget for documents (STNK/BPKB) and plates.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `scanMode` | `ScanMode` | `plateOnly` | The scanning mode |
| `onPlateDetected` | `ValueChanged<AnprResult>?` | — | Callback for plate-only mode |
| `onDocumentDetected` | `ValueChanged<DocumentOcrResult>?` | — | Callback for document modes |
| `onError` | `ValueChanged<String>?` | — | Error callback |
| `resolution` | `ResolutionPreset?` | auto | `high` for plates, `veryHigh` for documents |

### AnprResult

| Field | Type | Description |
|-------|------|-------------|
| `plateNumber` | `String` | Detected license plate text |
| `rawText` | `String` | Raw OCR text before cleaning |
| `confidence` | `double` | Accuracy percentage (0–100) |
| `timestamp` | `DateTime` | Detection timestamp |

### DocumentOcrResult

| Field | Type | Description |
|-------|------|-------------|
| `documentType` | `DocumentType` | `stnk`, `bpkb`, or `unknown` |
| `plateNumber` | `String?` | Extracted Nomor Polisi |
| `ownerName` | `String?` | Nama Pemilik |
| `vehicleBrand` | `String?` | Merek kendaraan |
| `vehicleType` | `String?` | Tipe / model kendaraan |
| `vehicleColor` | `String?` | Warna kendaraan |
| `engineNumber` | `String?` | Nomor Mesin |
| `chassisNumber` | `String?` | Nomor Rangka / VIN |
| `confidence` | `double` | Classification confidence (0–100) |
| `rawText` | `String` | Full combined OCR text |
| `timestamp` | `DateTime` | Detection timestamp |

## 🛠️ Utilities

These classes can be used independently for custom implementations:

### NopolValidator

Validate and score Indonesian license plate numbers:

```dart
// Validate
NopolValidator.isValid('B 1234 ABC');  // true
NopolValidator.isValid('HELLO');       // false

// Extract from multi-line text
NopolValidator.extractPlate('Some text\nB 1234 ABC\nMore text');
// → "B 1234 ABC"

// Get confidence score
final result = NopolValidator.calculateConfidence('B 1234 ABC');
print(result.percentage);   // 100.0
print(result.plateNumber);  // "B 1234 ABC"
print(result.isValid);      // true
```

### DocumentClassifier

Classify OCR text as STNK or BPKB using keyword scoring:

```dart
final result = DocumentClassifier.classify(ocrText);
print(result.type);        // DocumentType.stnk
print(result.confidence);  // 85.0
```

### DocumentNopolExtractor

Extract plate number and metadata from classified document text:

```dart
// Extract nopol
final plate = DocumentNopolExtractor.extractNopol(text, DocumentType.stnk);

// Extract all fields
final fields = DocumentNopolExtractor.extractAllFields(text, DocumentType.stnk);
print(fields.plateNumber);
print(fields.ownerName);
print(fields.vehicleBrand);
```

### DocumentAccumulator

Accumulate OCR text across multiple camera frames for stable document classification:

```dart
final accumulator = DocumentAccumulator();

// Add each frame
accumulator.addFrame(frameText);

// Check stability
if (accumulator.isStable) {
  print(accumulator.classifiedType);  // DocumentType.stnk
  print(accumulator.combinedText);    // merged text from all frames
}

// Reset for next scan
accumulator.reset();
```

## 🔧 How It Works

### License Plate Detection
1. Camera streams frames to ML Kit Text Recognition
2. Each text block is checked against the Indonesian plate regex: `[A-Z]{1,2} \d{1,4} [A-Z]{0,3}`
3. A confidence score (0–100%) is calculated based on prefix, digits, suffix, spacing, and full match
4. Results are delivered via callback immediately

### Document Detection (STNK/BPKB)
1. Camera streams frames to ML Kit Text Recognition
2. OCR text is **accumulated** across 3–10 frames using a sliding window
3. **DocumentClassifier** scores accumulated text against STNK and BPKB keyword lists
4. Once classification is **stable** (same result for 3 consecutive frames), metadata is extracted
5. **DocumentNopolExtractor** finds the plate number after document-specific labels (e.g. "NOMOR POLISI" for STNK, "NOMOR REGISTRASI" for BPKB)
6. Results with all extracted fields are delivered via callback

## 📱 Example App

The `example/` directory contains a full working demo with:
- **3-way mode switcher**: Plat Nomor / STNK / BPKB
- **Single / Multi toggle** for plate-only mode
- Document result card with extracted metadata fields
- Flash toggle, camera pause/resume, tap-to-focus

Run it:

```bash
cd example
flutter run
```

## 📄 License

MIT
