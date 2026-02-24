import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'anpr_result.dart';
import 'scanner_overlay_painter.dart';
import 'utils/image_converter.dart';
import 'utils/nopol_validator.dart';

/// A reusable widget that provides a full-screen camera scanner for
/// detecting Indonesian license plates (ANPR) in real time.
///
/// Supports two modes:
///
/// **Single Plate Mode** (default):
/// ```dart
/// AnprScannerWidget(
///   onPlateDetected: (result) {
///     print('Detected: ${result.plateNumber}');
///   },
/// )
/// ```
///
/// **Multi Plate Mode** — detects all visible plates simultaneously:
/// ```dart
/// AnprScannerWidget(
///   multiPlateMode: true,
///   onMultiplePlatesDetected: (results) {
///     for (final r in results) {
///       print('Detected: ${r.plateNumber}');
///     }
///   },
/// )
/// ```
class AnprScannerWidget extends StatefulWidget {
  /// Called when a valid license plate is detected (single plate mode).
  final ValueChanged<AnprResult>? onPlateDetected;

  /// Called when one or more plates are detected (multi plate mode).
  ///
  /// Only called when [multiPlateMode] is `true`.
  /// The list contains all unique plates detected in the current frame.
  final ValueChanged<List<AnprResult>>? onMultiplePlatesDetected;

  /// Called when an error occurs (camera init, OCR, etc).
  final ValueChanged<String>? onError;

  /// When `true`, the scanner detects **all** visible license plates
  /// in the frame simultaneously. The ROI target area is expanded to
  /// cover a larger portion of the screen.
  ///
  /// Use [onMultiplePlatesDetected] to receive results in this mode.
  ///
  /// Defaults to `false` (single plate mode).
  final bool multiPlateMode;

  /// Whether to show the flash toggle button. Defaults to `true`.
  final bool showFlashButton;

  /// Whether to show the camera on/off toggle button. Defaults to `true`.
  final bool showCameraToggleButton;

  /// Color of the overlay background. Defaults to semi-transparent black.
  final Color overlayColor;

  /// Color of the corner brackets when idle (no detection).
  final Color borderColor;

  /// Color of the corner brackets when a plate is detected.
  final Color successBorderColor;

  /// Aspect ratio of the target area relative to screen width.
  /// Default is 0.85 (85% of screen width).
  /// In [multiPlateMode], defaults to 0.95.
  final double? targetAreaWidthRatio;

  /// Height ratio of target area relative to its width.
  /// Default is 0.35 (landscape rectangle).
  /// In [multiPlateMode], defaults to 0.70 (taller to capture more plates).
  final double? targetAreaHeightRatio;

  /// Camera resolution. Defaults to [ResolutionPreset.high].
  final ResolutionPreset resolution;

  /// Duration the border stays green after detection.
  final Duration successFeedbackDuration;

  /// Creates an [AnprScannerWidget].
  const AnprScannerWidget({
    super.key,
    this.onPlateDetected,
    this.onMultiplePlatesDetected,
    this.onError,
    this.multiPlateMode = false,
    this.showFlashButton = true,
    this.showCameraToggleButton = true,
    this.overlayColor = const Color(0x99000000),
    this.borderColor = Colors.white,
    this.successBorderColor = Colors.greenAccent,
    this.targetAreaWidthRatio,
    this.targetAreaHeightRatio,
    this.resolution = ResolutionPreset.high,
    this.successFeedbackDuration = const Duration(seconds: 2),
  });

  @override
  State<AnprScannerWidget> createState() => AnprScannerWidgetState();
}

/// State for [AnprScannerWidget]. Access via `GlobalKey<AnprScannerWidgetState>`
/// to call [resetDetectionHistory], [toggleFlash], etc.
class AnprScannerWidgetState extends State<AnprScannerWidget>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  TextRecognizer? _textRecognizer;
  bool _isProcessing = false;
  bool _isDetected = false;
  Timer? _successTimer;

  // Flash state
  bool _isFlashOn = false;

  // Camera pause state
  bool _isCameraPaused = false;
  CameraDescription? _activeCamera;

  // Tap-to-focus state
  Offset? _focusPoint;
  late AnimationController _focusAnimController;
  late Animation<double> _focusAnimation;

  // Single plate mode state
  String? _lastDetectedPlate;

  // Multi plate mode state — tracks all plates detected across frames
  final Set<String> _detectedPlatesHistory = {};

  double get _effectiveWidthRatio =>
      widget.targetAreaWidthRatio ?? (widget.multiPlateMode ? 0.95 : 0.85);

  double get _effectiveHeightRatio =>
      widget.targetAreaHeightRatio ?? (widget.multiPlateMode ? 1.20 : 0.35);

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer();

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
          if (mounted) {
            setState(() => _focusPoint = null);
          }
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
        widget.resolution,
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

  // ── Flash Control ───────────────────────────────────────────────────

  /// Toggles the camera flash/torch on or off.
  Future<void> toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      if (mounted) {
        setState(() => _isFlashOn = !_isFlashOn);
      }
    } catch (e) {
      debugPrint('Flash toggle error: $e');
    }
  }

  // ── Camera Pause / Resume ─────────────────────────────────────────

  /// Whether the camera is currently paused.
  bool get isCameraPaused => _isCameraPaused;

  /// Pauses the camera and fully releases the hardware to save battery.
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

  /// Resumes the camera by re-initializing it from scratch.
  Future<void> resumeCamera() async {
    if (!_isCameraPaused) return;

    if (mounted) {
      setState(() => _isCameraPaused = false);
    }

    await _initializeCamera();
  }

  /// Toggles the camera between paused and active states.
  Future<void> toggleCamera() async {
    if (_isCameraPaused) {
      await resumeCamera();
    } else {
      await pauseCamera();
    }
  }

  // ── Tap to Focus ────────────────────────────────────────────────────

  void _onTapToFocus(TapDownDetails details, Size screenSize) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final tapPosition = details.localPosition;

    // Convert tap position to normalized coordinates (0.0 - 1.0)
    final x = tapPosition.dx / screenSize.width;
    final y = tapPosition.dy / screenSize.height;

    try {
      _cameraController!.setFocusPoint(Offset(x, y));
      _cameraController!.setExposurePoint(Offset(x, y));
    } catch (e) {
      debugPrint('Focus error: $e');
    }

    // Show focus indicator animation
    setState(() => _focusPoint = tapPosition);
    _focusAnimController.reset();
    _focusAnimController.forward();
  }

  // ── OCR Processing ──────────────────────────────────────────────────

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

      // Calculate scale factors to map image coordinates to screen
      final imageSize = Size(
        inputImage.metadata!.size.width,
        inputImage.metadata!.size.height,
      );
      final scaleX = screenSize.width / imageSize.height;
      final scaleY = screenSize.height / imageSize.width;

      if (widget.multiPlateMode) {
        _processMultiPlate(recognizedText, targetRect, scaleX, scaleY);
      } else {
        _processSinglePlate(recognizedText, targetRect, scaleX, scaleY);
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ── Single Plate Mode ───────────────────────────────────────────────

  void _processSinglePlate(
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
        _onSingleDetectionSuccess(
          confidence.plateNumber!,
          block.text,
          confidence.percentage,
        );
        break;
      }
    }
  }

  void _onSingleDetectionSuccess(
    String plate,
    String rawText,
    double confidence,
  ) {
    HapticFeedback.selectionClick();

    final result = AnprResult(
      plateNumber: plate,
      rawText: rawText,
      timestamp: DateTime.now(),
      confidence: confidence,
    );

    if (!mounted) return;

    setState(() => _isDetected = true);
    widget.onPlateDetected?.call(result);

    _resetSuccessAfterDelay();
  }

  // ── Multi Plate Mode ────────────────────────────────────────────────

  void _processMultiPlate(
    RecognizedText recognizedText,
    Rect targetRect,
    double scaleX,
    double scaleY,
  ) {
    final List<AnprResult> newlyDetected = [];
    final now = DateTime.now();

    for (final block in recognizedText.blocks) {
      final blockRect = _scaleRect(block.boundingBox, scaleX, scaleY);
      if (!targetRect.overlaps(blockRect)) continue;

      final confidence = NopolValidator.calculateConfidence(block.text);
      if (confidence.plateNumber != null &&
          !_detectedPlatesHistory.contains(confidence.plateNumber)) {
        _detectedPlatesHistory.add(confidence.plateNumber!);
        newlyDetected.add(
          AnprResult(
            plateNumber: confidence.plateNumber!,
            rawText: block.text,
            timestamp: now,
            confidence: confidence.percentage,
          ),
        );
      }
    }

    if (newlyDetected.isNotEmpty) {
      _onMultiDetectionSuccess(newlyDetected);
    }
  }

  void _onMultiDetectionSuccess(List<AnprResult> results) {
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    setState(() => _isDetected = true);
    widget.onMultiplePlatesDetected?.call(results);

    _resetSuccessAfterDelay();
  }

  // ── Shared Helpers ──────────────────────────────────────────────────

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

  /// Resets the multi-plate detection history so plates can be re-detected.
  void resetDetectionHistory() {
    _detectedPlatesHistory.clear();
    _lastDetectedPlate = null;
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
    final targetWidth = screenSize.width * _effectiveWidthRatio;
    final targetHeight = targetWidth * _effectiveHeightRatio;
    final left = (screenSize.width - targetWidth) / 2;
    final top = (screenSize.height - targetHeight) / 2;
    return Rect.fromLTWH(left, top, targetWidth, targetHeight);
  }

  @override
  Widget build(BuildContext context) {
    // Show paused overlay when camera is off
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
          // Camera toggle button (still visible when paused)
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
              // Camera preview
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
                  widget.multiPlateMode
                      ? 'Arahkan kamera ke area plat nomor'
                      : 'Arahkan kamera ke plat nomor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Multi plate mode badge
              if (widget.multiPlateMode && _detectedPlatesHistory.isNotEmpty)
                Positioned(
                  top: targetRect.bottom + 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_detectedPlatesHistory.length} plat terdeteksi',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

              // Camera paused overlay
              if (_isCameraPaused)
                Container(
                  color: Colors.black87,
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

              // Flash toggle button (hidden when paused)
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
        final scale = 1.5 - (_focusAnimation.value * 0.5); // 1.5 → 1.0
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
