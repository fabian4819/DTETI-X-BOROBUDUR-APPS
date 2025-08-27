import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_point.dart';
import '../utils/app_colors.dart';

class CustomMarkerService {
  static final CustomMarkerService _instance = CustomMarkerService._internal();
  factory CustomMarkerService() => _instance;
  CustomMarkerService._internal();

  final Map<String, BitmapDescriptor> _cachedMarkers = {};

  Future<BitmapDescriptor> getCustomMarker(
    LocationPoint location, {
    bool isSelected = false,
    bool isDestination = false,
    bool isStart = false,
  }) async {
    final key = '${location.type}_$isSelected}_$isDestination}_$isStart';
    
    if (_cachedMarkers.containsKey(key)) {
      return _cachedMarkers[key]!;
    }

    final marker = await _createCustomMarker(
      location, 
      isSelected: isSelected, 
      isDestination: isDestination,
      isStart: isStart,
    );
    
    _cachedMarkers[key] = marker;
    return marker;
  }

  Future<BitmapDescriptor> _createCustomMarker(
    LocationPoint location, {
    bool isSelected = false,
    bool isDestination = false,
    bool isStart = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(60, 80);
    
    final paint = Paint()..isAntiAlias = true;

    // Determine colors based on state and type
    Color markerColor = _getMarkerColor(location, isSelected, isDestination, isStart);
    Color shadowColor = Colors.black.withAlpha(76);
    
    // Draw shadow
    final shadowPath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2 + 2, size.height - 8),
        radius: 12,
      ));
    paint.color = shadowColor;
    canvas.drawPath(shadowPath, paint);

    // Draw main marker shape
    final markerPath = Path()
      ..moveTo(size.width / 2, size.height - 10)
      ..quadraticBezierTo(size.width / 2 - 20, size.height / 2, size.width / 2 - 20, 25)
      ..quadraticBezierTo(size.width / 2 - 20, 5, size.width / 2, 5)
      ..quadraticBezierTo(size.width / 2 + 20, 5, size.width / 2 + 20, 25)
      ..quadraticBezierTo(size.width / 2 + 20, size.height / 2, size.width / 2, size.height - 10)
      ..close();
    
    // Fill marker
    paint.color = markerColor;
    canvas.drawPath(markerPath, paint);
    
    // Draw border
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    paint.color = markerColor.withAlpha(204);
    canvas.drawPath(markerPath, paint);
    
    // Reset paint for icon
    paint.style = PaintingStyle.fill;
    
    // Draw inner circle for icon
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width / 2, 25),
      15,
      paint,
    );
    
    // Draw icon based on type
    await _drawLocationIcon(canvas, location, Offset(size.width / 2, 25));
    
    // Draw type indicator
    if (isDestination || isStart || isSelected) {
      String text = isDestination ? 'T' : isStart ? 'S' : '●';
      _drawText(canvas, text, Offset(size.width / 2, size.height - 20), 
               Colors.white, 12, FontWeight.bold);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(pngBytes);
  }

  Future<void> _drawLocationIcon(Canvas canvas, LocationPoint location, Offset center) async {
    final paint = Paint()..isAntiAlias = true;
    
    switch (location.type) {
      case 'FOUNDATION':
        // Draw circle for foundation
        paint.color = Colors.brown;
        canvas.drawCircle(center, 8, paint);
        paint.color = Colors.white;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 2;
        canvas.drawCircle(center, 8, paint);
        break;
        
      case 'GATE':
        // Draw gate icon
        paint.color = _getGateColor(location.direction);
        final rect = Rect.fromCenter(center: center, width: 14, height: 14);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
        
        // Draw direction arrow
        paint.color = Colors.white;
        _drawArrow(canvas, center, location.direction);
        break;
        
      case 'STUPA':
        // Draw stupa icon (triangle)
        paint.color = AppColors.accent;
        final path = Path()
          ..moveTo(center.dx, center.dy - 10)
          ..lineTo(center.dx - 8, center.dy + 6)
          ..lineTo(center.dx + 8, center.dy + 6)
          ..close();
        canvas.drawPath(path, paint);
        
        // Draw white outline
        paint.color = Colors.white;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 2;
        canvas.drawPath(path, paint);
        break;
        
      default:
        // Default marker
        paint.color = AppColors.primary;
        canvas.drawCircle(center, 8, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset center, String direction) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final path = Path();
    
    switch (direction) {
      case 'NORTH':
        path.moveTo(center.dx, center.dy - 5);
        path.lineTo(center.dx - 4, center.dy + 2);
        path.lineTo(center.dx + 4, center.dy + 2);
        break;
      case 'SOUTH':
        path.moveTo(center.dx, center.dy + 5);
        path.lineTo(center.dx - 4, center.dy - 2);
        path.lineTo(center.dx + 4, center.dy - 2);
        break;
      case 'EAST':
        path.moveTo(center.dx + 5, center.dy);
        path.lineTo(center.dx - 2, center.dy - 4);
        path.lineTo(center.dx - 2, center.dy + 4);
        break;
      case 'WEST':
        path.moveTo(center.dx - 5, center.dy);
        path.lineTo(center.dx + 2, center.dy - 4);
        path.lineTo(center.dx + 2, center.dy + 4);
        break;
      default:
        // Default to circle
        canvas.drawCircle(center, 3, paint);
        return;
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color, 
                double fontSize, FontWeight fontWeight) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  Color _getMarkerColor(LocationPoint location, bool isSelected, bool isDestination, bool isStart) {
    if (isDestination) return AppColors.accent;
    if (isStart) return Colors.green;
    if (isSelected) return AppColors.primary;
    
    switch (location.type) {
      case 'FOUNDATION':
        return Colors.brown;
      case 'GATE':
        return _getGateColor(location.direction);
      case 'STUPA':
        return AppColors.accent;
      default:
        return AppColors.secondary;
    }
  }

  Color _getGateColor(String direction) {
    switch (direction) {
      case 'SOUTH': return Colors.red;
      case 'EAST': return Colors.orange;
      case 'NORTH': return Colors.blue;
      case 'WEST': return Colors.green;
      default: return AppColors.primary;
    }
  }

  Future<BitmapDescriptor> getCurrentLocationMarker() async {
    const key = 'current_location';
    
    if (_cachedMarkers.containsKey(key)) {
      return _cachedMarkers[key]!;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(40, 40);
    
    final paint = Paint()..isAntiAlias = true;

    // Draw shadow
    paint.color = Colors.black.withAlpha(76);
    canvas.drawCircle(Offset(size.width / 2 + 1, size.height / 2 + 1), 18, paint);
    
    // Draw outer circle
    paint.color = Colors.blue.withAlpha(127);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 18, paint);
    
    // Draw inner circle
    paint.color = Colors.blue;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 12, paint);
    
    // Draw center dot
    paint.color = Colors.white;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 6, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final marker = BitmapDescriptor.bytes(pngBytes);
    _cachedMarkers[key] = marker;
    return marker;
  }

  void clearCache() {
    _cachedMarkers.clear();
  }
}