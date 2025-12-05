import 'dart:async';
import 'dart:math';
import 'package:flutter_barometer/flutter_barometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Barometer altitude update event
class BarometerUpdate {
  final double pressure;
  final double altitude;
  final double relativeAltitude;
  final DateTime timestamp;

  BarometerUpdate({
    required this.pressure,
    required this.altitude,
    required this.relativeAltitude,
    required this.timestamp,
  });

  @override
  String toString() => 'BarometerUpdate(pressure: ${pressure.toStringAsFixed(2)} hPa, altitude: ${altitude.toStringAsFixed(2)}m, relativeAltitude: ${relativeAltitude.toStringAsFixed(2)}m)';
}

/// Service for managing barometer sensor and altitude calculations
class BarometerService {
  static final BarometerService _instance = BarometerService._internal();
  factory BarometerService() => _instance;
  BarometerService._internal();

  // Stream controllers
  final StreamController<BarometerUpdate> _barometerController =
      StreamController<BarometerUpdate>.broadcast();
  final StreamController<bool> _availabilityController =
      StreamController<bool>.broadcast();

  // Configuration
  static const double _seaLevelPressure = 1013.25; // hPa
  static const double _pressureLapseRate = 0.0065; // K/m
  static const double _temperatureKelvin = 288.15; // K (15°C)
  static const double _gasConstant = 8.31447; // J/(mol·K)
  static const double _gravity = 9.80665; // m/s²
  static const double _molarMass = 0.0289644; // kg/mol

  // State
  bool _isInitialized = false;
  bool _isTracking = false;
  StreamSubscription<FlutterBarometerEvent>? _barometerSubscription;

  // Calibration
  double _basePressure = _seaLevelPressure;
  double _baseAltitude = 0.0;
  double _currentRelativeAltitude = 0.0;
  bool _isCalibrated = false;

  // Readings
  List<double> _pressureReadings = [];
  static const int _maxReadings = 10;
  static const Duration _readingInterval = Duration(milliseconds: 200);

  // Public streams
  Stream<BarometerUpdate> get barometerStream => _barometerController.stream;
  Stream<bool> get availabilityStream => _availabilityController.stream;

  // Public getters
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  bool get isCalibrated => _isCalibrated;
  double get currentRelativeAltitude => _currentRelativeAltitude;

  /// Initialize the barometer service
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Check if device has barometer
      final hasBarometer = await _checkBarometerAvailability();
      _availabilityController.add(hasBarometer);

      if (!hasBarometer) {
        return false;
      }

      // Load calibration data
      await _loadCalibration();

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing barometer service: $e');
      return false;
    }
  }

  /// Check if device has barometer sensor
  Future<bool> _checkBarometerAvailability() async {
    try {
      // Try to access barometer sensor
      final barometerStream = flutterBarometerEvents;
      return barometerStream != null;
    } catch (e) {
      print('Barometer not available: $e');
      return false;
    }
  }

  /// Start altitude tracking
  Future<bool> startTracking() async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }

      if (_isTracking) return true;

      _barometerSubscription = flutterBarometerEvents.listen(_handleBarometerEvent);
      _isTracking = true;

      print('Barometer tracking started');
      return true;
    } catch (e) {
      print('Error starting barometer tracking: $e');
      return false;
    }
  }

  /// Stop altitude tracking
  void stopTracking() {
    try {
      _barometerSubscription?.cancel();
      _barometerSubscription = null;
      _isTracking = false;

      print('Barometer tracking stopped');
    } catch (e) {
      print('Error stopping barometer tracking: $e');
    }
  }

  /// Handle barometer sensor events
  void _handleBarometerEvent(FlutterBarometerEvent event) {
    try {
      // Check if stream is closed before adding events
      if (_barometerController.isClosed) {
        return;
      }
      
      final pressure = event.pressure;

      // Add to readings buffer for smoothing
      _pressureReadings.add(pressure);
      if (_pressureReadings.length > _maxReadings) {
        _pressureReadings.removeAt(0);
      }

      // Calculate smoothed pressure
      final smoothedPressure = _getSmoothedPressure();

      // Calculate altitudes
      final absoluteAltitude = _calculateAbsoluteAltitude(smoothedPressure);
      _currentRelativeAltitude = _calculateRelativeAltitude(smoothedPressure);

      // Create update event
      final update = BarometerUpdate(
        pressure: smoothedPressure,
        altitude: absoluteAltitude,
        relativeAltitude: _currentRelativeAltitude,
        timestamp: DateTime.now(),
      );

      _barometerController.add(update);
    } catch (e) {
      print('Error handling barometer event: $e');
    }
  }

  /// Get smoothed pressure value from recent readings
  double _getSmoothedPressure() {
    if (_pressureReadings.isEmpty) return _seaLevelPressure;

    // Use weighted average (more weight to recent readings)
    double weightedSum = 0.0;
    double totalWeight = 0.0;

    for (int i = 0; i < _pressureReadings.length; i++) {
      final weight = (i + 1) / _pressureReadings.length; // Linear weight
      weightedSum += _pressureReadings[i] * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? weightedSum / totalWeight : _seaLevelPressure;
  }

  /// Calculate absolute altitude from pressure using barometric formula
  double _calculateAbsoluteAltitude(double pressure) {
    try {
      final exponent = (_gasConstant * _temperatureKelvin) / (_molarMass * _gravity);
      final ratio = pow(pressure / _seaLevelPressure, exponent);
      return _temperatureKelvin * (1.0 - ratio) / _pressureLapseRate;
    } catch (e) {
      print('Error calculating absolute altitude: $e');
      return 0.0;
    }
  }

  /// Calculate relative altitude from base pressure
  double _calculateRelativeAltitude(double pressure) {
    try {
      final exponent = (_gasConstant * _temperatureKelvin) / (_molarMass * _gravity);
      final ratio = pow(pressure / _basePressure, exponent);
      final relativeAltitude = _temperatureKelvin * (1.0 - ratio) / _pressureLapseRate;
      return relativeAltitude - _baseAltitude;
    } catch (e) {
      print('Error calculating relative altitude: $e');
      return 0.0;
    }
  }

  /// Calibrate barometer at current location
  Future<void> calibrateHere({double? knownAltitude}) async {
    try {
      if (_pressureReadings.isEmpty) {
        print('No pressure readings available for calibration');
        return;
      }

      final currentPressure = _getSmoothedPressure();
      _basePressure = currentPressure;

      if (knownAltitude != null) {
        _baseAltitude = knownAltitude;
      } else {
        _baseAltitude = _calculateAbsoluteAltitude(currentPressure);
      }

      _isCalibrated = true;
      _currentRelativeAltitude = 0.0;

      // Save calibration
      await _saveCalibration();

      print('Barometer calibrated: basePressure=${_basePressure.toStringAsFixed(2)} hPa, baseAltitude=${_baseAltitude.toStringAsFixed(2)}m');
    } catch (e) {
      print('Error calibrating barometer: $e');
    }
  }

  /// Reset calibration to default values
  Future<void> resetCalibration() async {
    try {
      _basePressure = _seaLevelPressure;
      _baseAltitude = 0.0;
      _isCalibrated = false;
      _currentRelativeAltitude = 0.0;

      await _saveCalibration();
      print('Barometer calibration reset');
    } catch (e) {
      print('Error resetting calibration: $e');
    }
  }

  /// Set manual calibration values
  Future<void> setManualCalibration(double basePressure, double baseAltitude) async {
    try {
      _basePressure = basePressure;
      _baseAltitude = baseAltitude;
      _isCalibrated = true;

      await _saveCalibration();
      print('Manual calibration set: pressure=$basePressure hPa, altitude=$baseAltitude m');
    } catch (e) {
      print('Error setting manual calibration: $e');
    }
  }

  /// Save calibration data to persistent storage
  Future<void> _saveCalibration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('barometer_base_pressure', _basePressure);
      await prefs.setDouble('barometer_base_altitude', _baseAltitude);
      await prefs.setBool('barometer_calibrated', _isCalibrated);
    } catch (e) {
      print('Error saving calibration: $e');
    }
  }

  /// Load calibration data from persistent storage
  Future<void> _loadCalibration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _basePressure = prefs.getDouble('barometer_base_pressure') ?? _seaLevelPressure;
      _baseAltitude = prefs.getDouble('barometer_base_altitude') ?? 0.0;
      _isCalibrated = prefs.getBool('barometer_calibrated') ?? false;

      print('Loaded calibration: pressure=${_basePressure.toStringAsFixed(2)} hPa, altitude=${_baseAltitude.toStringAsFixed(2)}m, calibrated=$_isCalibrated');
    } catch (e) {
      print('Error loading calibration: $e');
    }
  }

  /// Get current sensor status information
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'tracking': _isTracking,
      'calibrated': _isCalibrated,
      'basePressure': _basePressure,
      'baseAltitude': _baseAltitude,
      'currentRelativeAltitude': _currentRelativeAltitude,
      'pressureReadingsCount': _pressureReadings.length,
      'lastPressure': _pressureReadings.isNotEmpty ? _pressureReadings.last : null,
    };
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _barometerController.close();
    _availabilityController.close();
    _pressureReadings.clear();
  }
}