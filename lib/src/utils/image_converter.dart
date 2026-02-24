import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Utility class to convert [CameraImage] to ML Kit [InputImage].
class ImageConverter {
  ImageConverter._();

  /// Converts a [CameraImage] from the camera stream into an [InputImage]
  /// that ML Kit can process.
  ///
  /// Handles platform-specific image formats:
  /// - **Android**: YUV_420_888 → NV21 bytes
  /// - **iOS**: BGRA8888 → direct bytes
  static InputImage? convert(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    final rotation = _rotationFromSensorOrientation(sensorOrientation);
    if (rotation == null) return null;

    final format = _formatFromGroup(image.format.group);
    if (format == null) return null;

    // For iOS BGRA, use the first plane directly.
    // For Android YUV, concatenate planes into NV21.
    final bytes = _getBytes(image, format);
    if (bytes == null) return null;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  static InputImageRotation? _rotationFromSensorOrientation(int orientation) {
    // On iOS, orientation is always 0 but the image is already correctly
    // oriented. On Android, we map sensor orientation to InputImageRotation.
    if (Platform.isIOS) {
      return InputImageRotation.rotation0deg;
    }
    switch (orientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return null;
    }
  }

  static InputImageFormat? _formatFromGroup(ImageFormatGroup group) {
    switch (group) {
      case ImageFormatGroup.nv21:
        return InputImageFormat.nv21;
      case ImageFormatGroup.yuv420:
        return InputImageFormat.yuv_420_888;
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      default:
        return null;
    }
  }

  static Uint8List? _getBytes(CameraImage image, InputImageFormat format) {
    if (format == InputImageFormat.bgra8888) {
      // iOS: single plane BGRA
      return image.planes.first.bytes;
    }

    if (format == InputImageFormat.nv21 ||
        format == InputImageFormat.yuv_420_888) {
      // Android: concatenate all YUV planes
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      return allBytes.done().buffer.asUint8List();
    }

    return null;
  }
}
