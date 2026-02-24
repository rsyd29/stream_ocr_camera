import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'models/document_ocr_result.dart';
import 'models/document_type.dart';
import 'models/scan_mode.dart';
import 'scanner_overlay_painter.dart';
import 'utils/document_accumulator.dart';
import 'utils/document_nopol_extractor.dart';
import 'utils/image_converter.dart';
import 'utils/nopol_validator.dart';
import 'anpr_result.dart';

/// A widget for scanning vehicle documents (STNK, BPKB) or license plates
/// in real time using the camera stream.
///
/// Supports three scan modes via [scanMode]:
///
/// **Plate Only Mode** (default) — behaves like the existing ANPR scanner:
/// ```dart
/// DocumentScannerWidget(
///   scanMode: ScanMode.plateOnly,
///   onPlateDetected: (result) => print(result.plateNumber),
/// )
/// ```
///
/// **STNK Mode** — scans STNK documents and extracts nopol + metadata:
/// ```dart
/// DocumentScannerWidget(
///   scanMode: ScanMode.stnk,
///   onDocumentDetected: (result) {
///     print('Nopol: ${result.plateNumber}');
///     print('Pemilik: ${result.ownerName}');
///   },
/// )
/// ```
///
/// **BPKB Mode** — scans BPKB documents and extracts nopol + metadata:
/// ```dart
/// DocumentScannerWidget(
///   scanMode: ScanMode.bpkb,
///   onDocumentDetected: (result) {
///     print('Nopol: ${result.plateNumber}');
///     print('Merek: ${result.vehicleBrand}');
///   },
/// )
/// ```
///
/// **Auto Mode** — auto-detects the document type:
/// ```dart
/// DocumentScannerWidget(
///   scanMode: ScanMode.auto,
///   onDocumentDetected: (result) {
///     print('Type: ${result.documentType}');
///   },
/// )
/// ```
class DocumentScannerWidget extends StatefulWidget {
  /// The scanning mode. Defaults to [ScanMode.plateOnly].
  final ScanMode scanMode;

  /// Called when a license plate is detected (plate-only mode).
  final ValueChanged<AnprResult>? onPlateDetected;

  /// Called when a document (STNK/BPKB) is detected with extracted data.
  final ValueChanged<DocumentOcrResult>? onDocumentDetected;

  /// Called when an error occurs.
  final ValueChanged<String>? onError;

  /// Whether to show the flash toggle button. Defaults to `true`.
  final bool showFlashButton;

  /// Whether to show the camera toggle button. Defaults to `true`.
  final bool showCameraToggleButton;

  /// Color of the overlay background.
  final Color overlayColor;

  /// Color of the corner brackets when idle.
  final Color borderColor;

  /// Color of the corner brackets on detection success.
  final Color successBorderColor;

  /// Camera resolution. Defaults to [ResolutionPreset.veryHigh] for
  /// document modes, [ResolutionPreset.high] for plate-only.
  final ResolutionPreset? resolution;

  /// Duration the success border stays visible after detection.
  final Duration successFeedbackDuration;

  /// Creates a [DocumentScannerWidget].
  const DocumentScannerWidget({
    super.key,
    this.scanMode = ScanMode.plateOnly,
    this.onPlateDetected,
    this.onDocumentDetected,
    this.onError,
    this.showFlashButton = true,
    this.showCameraToggleButton = true,
    this.overlayColor = const Color(0x99000000),
    this.borderColor = Colors.white,
    this.successBorderColor = Colors.greenAccent,
    this.resolution,
    this.successFeedbackDuration = const Duration(seconds: 2),
  });

  @override
  State<DocumentScannerWidget> createState() => DocumentScannerWidgetState();
}

/// State for [DocumentScannerWidget].
class DocumentScannerWidgetState extends State<DocumentScannerWidget>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  TextRecognizer? _textRecognizer;
  bool _isProcessing = false;
  bool _isDetected = false;
  Timer? _successTimer;

  // Flash & camera pause
  bool _isFlashOn = false;
  bool _isCameraPaused = false;
  CameraDescription? _activeCamera;

  // Tap-to-focus
  Offset? _focusPoint;
  late AnimationController _focusAnimController;
  late Animation<double> _focusAnimation;

  // Plate-only mode
  String? _lastDetectedPlate;

  // Document mode
  late DocumentAccumulator _accumulator;
  bool _documentDetected = false;

  ResolutionPreset get _effectiveResolution =>
      widget.resolution ??
      (widget.scanMode == ScanMode.plateOnly
          ? ResolutionPreset.high
          : ResolutionPreset.veryHigh);

  double get _targetWidthRatio =>
      widget.scanMode == ScanMode.plateOnly ? 0.85 : 0.90;

  double get _targetHeightRatio =>
      widget.scanMode == ScanMode.plateOnly ? 0.35 : 0.65;

  String get _instructionText {
    return switch (widget.scanMode) {
      ScanMode.plateOnly => 'Arahkan kamera ke plat nomor',
      ScanMode.stnk => 'Arahkan kamera ke dokumen STNK',
      ScanMode.bpkb => 'Arahkan kamera ke dokumen BPKB',
      ScanMode.auto => 'Arahkan kamera ke dokumen kendaraan',
    };
  }

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer();
    _accumulator = DocumentAccumulator();

    _focusAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _focusAnimation = CurvedAnimation(
      parent: _focusAnimController,
      curve: Curves.easeOutCubic,
    );
    _focusAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _focusPoint = null);
        });
      }
    });

    _initializeCamera();
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _focusAnimController.dispose();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _textRecognizer?.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        widget.onError?.call('No cameras available');
        return;
      }

      _activeCamera = cameras.first;
      _cameraController = CameraController(
        _activeCamera!,
        _effectiveResolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});

      _cameraController!.startImageStream((image) {
        _processCameraImage(image, _activeCamera!);
      });
    } catch (e) {
      widget.onError?.call('Camera init error: $e');
    }
  }

  // ── Flash ──────────────────────────────────────────────────────────

  Future<void> toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      if (mounted) setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint('Flash toggle error: $e');
    }
  }

  // ── Camera pause / resume ──────────────────────────────────────────

  bool get isCameraPaused => _isCameraPaused;

  Future<void> pauseCamera() async {
    if (_isCameraPaused) return;
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
        _cameraController = null;
      }
    } catch (e) {
      debugPrint('Pause camera error: $e');
    }
    if (mounted) {
      setState(() {
        _isCameraPaused = true;
        _isFlashOn = false;
      });
    }
  }

  Future<void> resumeCamera() async {
    if (!_isCameraPaused) return;
    if (mounted) setState(() => _isCameraPaused = false);
    await _initializeCamera();
  }

  Future<void> toggleCamera() async {
    if (_isCameraPaused) {
      await resumeCamera();
    } else {
      await pauseCamera();
    }
  }

  // ── Tap to Focus ───────────────────────────────────────────────────

  void _onTapToFocus(TapDownDetails details, Size screenSize) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    final tapPosition = details.localPosition;
    final x = tapPosition.dx / screenSize.width;
    final y = tapPosition.dy / screenSize.height;
    try {
      _cameraController!.setFocusPoint(Offset(x, y));
      _cameraController!.setExposurePoint(Offset(x, y));
    } catch (e) {
      debugPrint('Focus error: $e');
    }
    setState(() => _focusPoint = tapPosition);
    _focusAnimController.reset();
    _focusAnimController.forward();
  }

  // ── OCR Processing ─────────────────────────────────────────────────

  Future<void> _processCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = ImageConverter.convert(image, camera);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final recognizedText = await _textRecognizer!.processImage(inputImage);

      final screenSize = _getScreenSize();
      if (screenSize == null) {
        _isProcessing = false;
        return;
      }

      final targetRect = _calculateTargetRect(screenSize);

      final imageSize = Size(
        inputImage.metadata!.size.width,
        inputImage.metadata!.size.height,
      );
      final scaleX = screenSize.width / imageSize.height;
      final scaleY = screenSize.height / imageSize.width;

      if (widget.scanMode == ScanMode.plateOnly) {
        _processPlateOnly(recognizedText, targetRect, scaleX, scaleY);
      } else {
        _processDocument(recognizedText, targetRect, scaleX, scaleY);
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ── Plate Only Mode ────────────────────────────────────────────────

  void _processPlateOnly(
    RecognizedText recognizedText,
    Rect targetRect,
    double scaleX,
    double scaleY,
  ) {
    for (final block in recognizedText.blocks) {
      final blockRect = _scaleRect(block.boundingBox, scaleX, scaleY);
      if (!targetRect.overlaps(blockRect)) continue;

      final confidence = NopolValidator.calculateConfidence(block.text);
      if (confidence.plateNumber != null &&
          confidence.plateNumber != _lastDetectedPlate) {
        _lastDetectedPlate = confidence.plateNumber;

        HapticFeedback.selectionClick();

        final result = AnprResult(
          plateNumber: confidence.plateNumber!,
          rawText: block.text,
          timestamp: DateTime.now(),
          confidence: confidence.percentage,
        );

        if (!mounted) return;
        setState(() => _isDetected = true);
        widget.onPlateDetected?.call(result);
        _resetSuccessAfterDelay();
        break;
      }
    }
  }

  // ── Document Mode ──────────────────────────────────────────────────

  void _processDocument(
    RecognizedText recognizedText,
    Rect targetRect,
    double scaleX,
    double scaleY,
  ) {
    // Collect all text blocks within the target area
    final buffer = StringBuffer();
    for (final block in recognizedText.blocks) {
      final blockRect = _scaleRect(block.boundingBox, scaleX, scaleY);
      if (targetRect.overlaps(blockRect)) {
        buffer.writeln(block.text);
      }
    }

    final frameText = buffer.toString();
    if (frameText.trim().isEmpty) return;

    _accumulator.addFrame(frameText);

    // Update UI with progress
    if (mounted) setState(() {});

    // Check if we have a stable classification
    if (!_accumulator.isStable || _documentDetected) return;

    final classifiedType = _accumulator.classifiedType;

    // In targeted mode, verify the detected type matches the requested mode
    if (widget.scanMode == ScanMode.stnk &&
        classifiedType != DocumentType.stnk) {
      return;
    }
    if (widget.scanMode == ScanMode.bpkb &&
        classifiedType != DocumentType.bpkb) {
      return;
    }

    // Extract fields from combined text
    final combinedText = _accumulator.combinedText;
    final fields = DocumentNopolExtractor.extractAllFields(
      combinedText,
      classifiedType,
    );

    // Only fire callback if we found at least a plate number
    if (fields.plateNumber == null) return;

    _documentDetected = true;

    HapticFeedback.mediumImpact();

    final result = DocumentOcrResult(
      documentType: classifiedType,
      plateNumber: fields.plateNumber,
      ownerName: fields.ownerName,
      vehicleBrand: fields.vehicleBrand,
      vehicleType: fields.vehicleType,
      vehicleColor: fields.vehicleColor,
      engineNumber: fields.engineNumber,
      chassisNumber: fields.chassisNumber,
      confidence: _accumulator.confidence,
      rawText: combinedText,
      timestamp: DateTime.now(),
    );

    if (!mounted) return;
    setState(() => _isDetected = true);
    widget.onDocumentDetected?.call(result);
    _resetSuccessAfterDelay();
  }

  // ── Public API ─────────────────────────────────────────────────────

  /// Resets the document detection state so a new document can be scanned.
  void resetDetection() {
    _accumulator.reset();
    _documentDetected = false;
    _lastDetectedPlate = null;
    if (mounted) setState(() => _isDetected = false);
  }

  // ── Shared Helpers ─────────────────────────────────────────────────

  void _resetSuccessAfterDelay() {
    _successTimer?.cancel();
    _successTimer = Timer(widget.successFeedbackDuration, () {
      if (mounted) {
        setState(() {
          _isDetected = false;
          _lastDetectedPlate = null;
        });
      }
    });
  }

  Rect _scaleRect(Rect rect, double scaleX, double scaleY) {
    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  Size? _getScreenSize() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  Rect _calculateTargetRect(Size screenSize) {
    final targetWidth = screenSize.width * _targetWidthRatio;
    final targetHeight = targetWidth * _targetHeightRatio;
    final left = (screenSize.width - targetWidth) / 2;
    final top = (screenSize.height - targetHeight) / 2;
    return Rect.fromLTWH(left, top, targetWidth, targetHeight);
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isCameraPaused) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_outlined,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kamera dijeda',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap tombol kamera untuk melanjutkan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.showCameraToggleButton)
            Positioned(
              bottom: 24,
              left: 24,
              child: SafeArea(
                right: false,
                top: false,
                child: _buildCameraToggleButton(),
              ),
            ),
        ],
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        final targetRect = _calculateTargetRect(screenSize);

        return GestureDetector(
          onTapDown: _isCameraPaused
              ? null
              : (details) => _onTapToFocus(details, screenSize),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCameraPreview(screenSize),

              // Scanner overlay
              CustomPaint(
                painter: ScannerOverlayPainter(
                  targetRect: targetRect,
                  borderColor: _isDetected
                      ? widget.successBorderColor
                      : widget.borderColor,
                  overlayColor: widget.overlayColor,
                ),
                size: screenSize,
              ),

              // Instruction text
              Positioned(
                top: targetRect.top - 48,
                left: 0,
                right: 0,
                child: Text(
                  _instructionText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Document scanning progress (document modes only)
              if (widget.scanMode != ScanMode.plateOnly && !_documentDetected)
                Positioned(
                  bottom: targetRect.bottom + 16,
                  left: targetRect.left,
                  right: screenSize.width - targetRect.right,
                  child: _buildScanProgress(),
                ),

              // Flash button
              if (widget.showFlashButton && !_isCameraPaused)
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: SafeArea(
                    left: false,
                    top: false,
                    child: _buildFlashButton(),
                  ),
                ),

              // Camera toggle button
              if (widget.showCameraToggleButton)
                Positioned(
                  bottom: 24,
                  left: 24,
                  child: SafeArea(
                    right: false,
                    top: false,
                    child: _buildCameraToggleButton(),
                  ),
                ),

              // Tap-to-focus indicator
              if (_focusPoint != null && !_isCameraPaused)
                Positioned(
                  left: _focusPoint!.dx - 30,
                  top: _focusPoint!.dy - 30,
                  child: _buildFocusIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Scan Progress Indicator ────────────────────────────────────────

  Widget _buildScanProgress() {
    final progress = _accumulator.stabilityProgress;
    final type = _accumulator.classifiedType;

    final String label;
    if (type == DocumentType.unknown) {
      label = 'Mendeteksi dokumen...';
    } else {
      final typeName = type == DocumentType.stnk ? 'STNK' : 'BPKB';
      if (_accumulator.isStable) {
        label = '$typeName terdeteksi ✓';
      } else {
        label = 'Membaca $typeName...';
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              type == DocumentType.unknown ? Colors.amber : Colors.tealAccent,
            ),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Reusable button builders ───────────────────────────────────────

  Widget _buildFlashButton() {
    return GestureDetector(
      onTap: toggleFlash,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _isFlashOn
              ? Colors.amber.withValues(alpha: 0.9)
              : Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          _isFlashOn ? Icons.flash_on : Icons.flash_off,
          color: _isFlashOn ? Colors.black : Colors.white70,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildCameraToggleButton() {
    return GestureDetector(
      onTap: toggleCamera,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _isCameraPaused
              ? Colors.redAccent.withValues(alpha: 0.8)
              : Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          _isCameraPaused ? Icons.videocam_off : Icons.videocam,
          color: _isCameraPaused ? Colors.white : Colors.white70,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildFocusIndicator() {
    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        final scale = 1.5 - (_focusAnimation.value * 0.5);
        final opacity = _focusAnimation.value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraPreview(Size screenSize) {
    final previewSize = _cameraController!.value.previewSize!;
    final previewAspectRatio = previewSize.height / previewSize.width;
    final screenAspectRatio = screenSize.width / screenSize.height;

    double scale;
    if (previewAspectRatio > screenAspectRatio) {
      scale = screenSize.height / (screenSize.width / previewAspectRatio);
    } else {
      scale = screenSize.width / (screenSize.height * previewAspectRatio);
    }
    scale = scale.clamp(1.0, 2.0);

    return Center(
      child: Transform.scale(
        scale: scale,
        child: CameraPreview(_cameraController!),
      ),
    );
  }
}
