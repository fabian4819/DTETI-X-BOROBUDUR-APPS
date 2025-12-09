import 'dart:async';
import 'package:flutter/services.dart';

/// iOS-specific altimeter data from Core Motion CMAltimeter
class IOSAltitudeUpdate {
  final double relativeAltitude; // meters
  final double pressure; // hPa
  final DateTime timestamp;

  IOSAltitudeUpdate({
    required this.relativeAltitude,
    required this.pressure,
    required this.timestamp,
  });

  factory IOSAltitudeUpdate.fromMap(Map<dynamic, dynamic> map) {
    return IOSAltitudeUpdate(
      relativeAltitude: (map['relativeAltitude'] as num).toDouble(),
      pressure: (map['pressure'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num).toInt(),
      ),
    );
  }

  @override
  String toString() =>
      'IOSAltitudeUpdate(altitude: ${relativeAltitude.toStringAsFixed(2)}m, pressure: ${pressure.toStringAsFixed(2)} hPa)';
}

/// iOS Altimeter Service using Core Motion CMAltimeter
/// Provides high-accuracy altitude tracking (~1-3m accuracy)
class IOSAltimeterService {
  static const MethodChannel _methodChannel = MethodChannel('com.borobudur.app/altimeter');
  static const EventChannel _eventChannel = EventChannel('com.borobudur.app/altimeter_stream');

  StreamSubscription<IOSAltitudeUpdate>? _subscription;
  final StreamController<IOSAltitudeUpdate> _controller = StreamController<IOSAltitudeUpdate>.broadcast();

  /// Check if CMAltimeter is available on this device
  /// Returns true for iPhone 6+ with M-series coprocessor
  Future<bool> isAvailable() async {
    try {
      final bool? available = await _methodChannel.invokeMethod<bool>('isAvailable');
      return available ?? false;
    } catch (e) {
      print('Error checking altimeter availability: $e');
      return false;
    }
  }

  /// Get current authorization status
  /// Returns: "notDetermined", "restricted", "denied", "authorized"
  Future<String> getAuthorizationStatus() async {
    try {
      final String? status = await _methodChannel.invokeMethod<String>('authorizationStatus');
      return status ?? 'unknown';
    } catch (e) {
      print('Error getting authorization status: $e');
      return 'unknown';
    }
  }

  /// Start listening to altitude updates from CMAltimeter
  void startListening(Function(IOSAltitudeUpdate) onData, {Function(dynamic)? onError}) {
    _subscription = _eventChannel.receiveBroadcastStream().map((data) {
      if (data is Map) {
        return IOSAltitudeUpdate.fromMap(data);
      }
      throw Exception('Invalid data format from iOS altimeter');
    }).listen(
      (update) {
        onData(update);
        _controller.add(update);
      },
      onError: (error) {
        print('iOS Altimeter error: $error');
        if (onError != null) {
          onError(error);
        }
      },
    );
  }

  /// Stop listening to altitude updates
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Get altitude stream
  Stream<IOSAltitudeUpdate> get altitudeStream => _controller.stream;

  /// Dispose resources
  void dispose() {
    stopListening();
    _controller.close();
  }
}
