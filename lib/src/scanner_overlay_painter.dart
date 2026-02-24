import 'dart:math';

import 'package:flutter/material.dart';

/// A [CustomPainter] that draws a scanner overlay with a transparent
/// rectangular cutout (target area) in the center of the screen.
///
/// The overlay consists of:
/// - A semi-transparent dark background covering the entire canvas.
/// - A transparent rectangular cutout representing the scan target area.
/// - Corner bracket decorations around the cutout.
class ScannerOverlayPainter extends CustomPainter {
  /// The rectangle defining the target area cutout.
  final Rect targetRect;

  /// Color of the corner brackets and border.
  final Color borderColor;

  /// Color of the semi-transparent overlay.
  final Color overlayColor;

  /// Width of the corner bracket strokes.
  final double borderWidth;

  /// Length of the corner bracket lines.
  final double cornerLength;

  /// Creates a [ScannerOverlayPainter].
  ScannerOverlayPainter({
    required this.targetRect,
    this.borderColor = Colors.white,
    this.overlayColor = const Color(0x99000000),
    this.borderWidth = 3.0,
    this.cornerLength = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw the semi-transparent overlay with a cutout
    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    // Create a path that covers the whole screen minus the target rect
    final overlayPath = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, overlayPaint);

    // Draw corner brackets
    _drawCornerBrackets(canvas, size);
  }

  void _drawCornerBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final double cl = min(cornerLength, targetRect.width / 4);
    final double r = 12.0; // corner radius

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(targetRect.left, targetRect.top + cl)
        ..lineTo(targetRect.left, targetRect.top + r)
        ..arcToPoint(
          Offset(targetRect.left + r, targetRect.top),
          radius: Radius.circular(r),
        )
        ..lineTo(targetRect.left + cl, targetRect.top),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(targetRect.right - cl, targetRect.top)
        ..lineTo(targetRect.right - r, targetRect.top)
        ..arcToPoint(
          Offset(targetRect.right, targetRect.top + r),
          radius: Radius.circular(r),
        )
        ..lineTo(targetRect.right, targetRect.top + cl),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(targetRect.left, targetRect.bottom - cl)
        ..lineTo(targetRect.left, targetRect.bottom - r)
        ..arcToPoint(
          Offset(targetRect.left + r, targetRect.bottom),
          radius: Radius.circular(r),
        )
        ..lineTo(targetRect.left + cl, targetRect.bottom),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(targetRect.right - cl, targetRect.bottom)
        ..lineTo(targetRect.right - r, targetRect.bottom)
        ..arcToPoint(
          Offset(targetRect.right, targetRect.bottom - r),
          radius: Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(targetRect.right, targetRect.bottom - cl),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.overlayColor != overlayColor;
  }
}
