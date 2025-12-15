import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter_barometer/flutter_barometer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ios_altimeter_service.dart';

/// Barometer altitude update event
class BarometerUpdate {
  final double pressure;
  final double altitude;
  final double relativeAltitude;
  final DateTime timestamp;
  final bool isFromGPS; // true if using GPS altitude (iOS), false if using barometer (Android)

  BarometerUpdate({
    required this.pressure,
    required this.altitude,
    required this.relativeAltitude,
    required this.timestamp,
    this.isFromGPS = false,
  });

  @override
  String toString() => 'BarometerUpdate(pressure: ${pressure.toStringAsFixed(2)} hPa, altitude: ${altitude.toStringAsFixed(2)}m, relativeAltitude: ${relativeAltitude.toStringAsFixed(2)}m, source: ${isFromGPS ? 'GPS' : 'Barometer'})';
}

/// Calibration type
enum CalibrationType {
  none,   // Not calibrated
  auto,   // Auto-calibrated to 256 mdpl (fallback)
  manual, // User manually calibrated at ground level
}

/// Calibration state with validity tracking
class CalibrationState {
  final CalibrationType type;
  final DateTime? timestamp;
  
  CalibrationState({
    required this.type,
    this.timestamp,
  });
  
  /// Check if calibration is still valid (< 24 hours old)
  bool get isValid {
    if (type == CalibrationType.none) return false;
    if (timestamp == null) return false;
    final age = DateTime.now().difference(timestamp!);
    return age < Duration(hours: 24);
  }
  
  /// Get calibration age in hours
  double get ageInHours {
    if (timestamp == null) return 0;
    return DateTime.now().difference(timestamp!).inMinutes / 60.0;
  }
  
  @override
  String toString() => 'CalibrationState(type: $type, age: ${ageInHours.toStringAsFixed(1)}h, valid: $isValid)';
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
  
  // Candi Borobudur specific configuration
  static const double BOROBUDUR_BASE_ELEVATION = 265.0; // meters above sea level (mdpl)
  static const double BOROBUDUR_GROUND_LEVEL = 0.0; // Ground floor reference (lantai dasar)
  static const bool AUTO_CALIBRATE_BOROBUDUR = true; // Auto-calibrate for Borobudur site

  // State
  bool _isInitialized = false;
  bool _isTracking = false;
  bool _useGPS = false; // true for iOS GPS fallback, false for Android barometer / iOS CMAltimeter
  bool _useIOSAltimeter = false; // true if using iOS CMAltimeter (high accuracy)
  StreamSubscription<FlutterBarometerEvent>? _barometerSubscription;
  StreamSubscription<Position>? _gpsSubscription;
  final IOSAltimeterService _iosAltimeter = IOSAltimeterService();

  // Calibration
  double _basePressure = _seaLevelPressure;
  double _baseAltitude = 0.0;
  double _currentRelativeAltitude = 0.0;
  bool _isCalibrated = false;
  CalibrationState _calibrationState = CalibrationState(type: CalibrationType.none);

  // Readings
  List<double> _pressureReadings = [];
  List<double> _altitudeReadings = []; // For GPS altitude smoothing
  static const int _maxReadings = 10;

  // Public streams
  Stream<BarometerUpdate> get barometerStream => _barometerController.stream;
  Stream<bool> get availabilityStream => _availabilityController.stream;

  // Public getters
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  bool get isCalibrated => _isCalibrated;
  double get currentRelativeAltitude => _currentRelativeAltitude;
  double get baseAltitude => _baseAltitude;
  double get borobudurGroundLevel => BOROBUDUR_GROUND_LEVEL;
  double get borobudurBaseElevation => BOROBUDUR_BASE_ELEVATION;
  CalibrationState get calibrationState => _calibrationState;

  /// Initialize the barometer service
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Platform detection: iOS tries CMAltimeter first, Android uses barometer
      if (Platform.isIOS) {
        print('📱 iOS detected: Checking CMAltimeter availability...');
        
        // Try iOS CMAltimeter first (high accuracy ~1-3m)
        final hasAltimeter = await _iosAltimeter.isAvailable();
        if (hasAltimeter) {
          _useIOSAltimeter = true;
          _useGPS = false;
          print('✅ iOS CMAltimeter available (±1-3m accuracy)');
          print('📏 Using Core Motion for high-accuracy altitude tracking');
          
          _availabilityController.add(true);
          _isInitialized = true;
          return true;
        }
        
        // Fallback to GPS if CMAltimeter not available
        print('⚠️ CMAltimeter not available, falling back to GPS');
        _useGPS = true;
        _useIOSAltimeter = false;
        print('📍 Using GPS altitude (±5-10m accuracy)');
        
        // Check location permission for GPS fallback
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.denied || 
              requested == LocationPermission.deniedForever) {
            print('❌ Location permission denied');
            return false;
          }
        }
        
        _availabilityController.add(true);
        _isInitialized = true;
        return true;
      }

      // Android: Check if device has barometer
      print('📊 Android detected: Checking barometer sensor...');
      final hasBarometer = await _checkBarometerAvailability();
      _availabilityController.add(hasBarometer);

      if (!hasBarometer) {
        print('❌ Barometer sensor not available');
        return false;
      }

      print('✅ Barometer sensor available (±1-2m accuracy)');

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
      flutterBarometerEvents;
      return true;
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

      if (_useIOSAltimeter) {
        // iOS: Use CMAltimeter (high accuracy)
        print('📏 Starting iOS CMAltimeter tracking...');
        
        _iosAltimeter.startListening(
          (iosUpdate) {
            _handleIOSAltimeterUpdate(iosUpdate);
          },
          onError: (error) {
            print('iOS Altimeter error: $error');
          },
        );
        
        print('✅ Altitude tracking started (iOS CMAltimeter, ±1-3m accuracy)');
      } else if (_useGPS) {
        // iOS: Use GPS altitude tracking (fallback)
        print('📍 Starting GPS altitude tracking...');
        
        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0, // Get all updates
        );
        
        _gpsSubscription = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          (Position position) {
            _handleGPSAltitude(position.altitude);
          },
          onError: (error) {
            print('GPS error: $error');
          },
        );
        
        print('✅ Altitude tracking started (GPS, ±5-10m accuracy)');
      } else {
        // Android: Use barometer sensor
        print('📊 Starting barometer tracking...');
        _barometerSubscription = flutterBarometerEvents.listen(_handleBarometerEvent);
        print('✅ Altitude tracking started (Barometer, ±1-2m accuracy)');
        
        // Auto-calibrate for Borobudur if enabled and not calibrated
        if (AUTO_CALIBRATE_BOROBUDUR && !_isCalibrated) {
          print('🏛️ Auto-calibrating for Candi Borobudur (base elevation: ${BOROBUDUR_BASE_ELEVATION}m mdpl)...');
          Future.delayed(const Duration(seconds: 2), () async {
            if (!_isCalibrated && _pressureReadings.isNotEmpty) {
              await calibrateForBorobudur();
            }
          });
        } else if (!_isCalibrated) {
          // Fallback: auto-calibrate at current location
          print('⚙️ Barometer not calibrated, will auto-calibrate after initial readings...');
          Future.delayed(const Duration(seconds: 2), () async {
            if (!_isCalibrated && _pressureReadings.isNotEmpty) {
              print('🔧 Auto-calibrating barometer at current location...');
              await calibrateHere();
            }
          });
        }
      }

      _isTracking = true;
      return true;
    } catch (e) {
      print('Error starting altitude tracking: $e');
      return false;
    }
  }

  /// Stop altitude tracking
  void stopTracking() {
    try {
      _barometerSubscription?.cancel();
      _barometerSubscription = null;
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
      _iosAltimeter.stopListening();
      _isTracking = false;

      print('Altitude tracking stopped');
    } catch (e) {
      print('Error stopping altitude tracking: $e');
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
      
      // Validate pressure reading
      if (pressure <= 0 || pressure > 1100) {
        print('⚠️ Invalid pressure from sensor: $pressure hPa - Skipping this reading');
        return;
      }

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

  /// Handle iOS CMAltimeter updates (high accuracy)
  void _handleIOSAltimeterUpdate(IOSAltitudeUpdate iosUpdate) {
    try {
      // Check if stream is closed before adding events
      if (_barometerController.isClosed) {
        return;
      }

      // iOS CMAltimeter provides relative altitude directly
      final relativeAltitude = iosUpdate.relativeAltitude;
      final pressure = iosUpdate.pressure;

      // Update current relative altitude
      _currentRelativeAltitude = relativeAltitude;

      // Calculate absolute altitude (relative + base)
      final absoluteAltitude = _baseAltitude + relativeAltitude;

      // Create update event
      final update = BarometerUpdate(
        pressure: pressure,
        altitude: absoluteAltitude,
        relativeAltitude: relativeAltitude,
        timestamp: iosUpdate.timestamp,
        isFromGPS: false, // This is from CMAltimeter, not GPS
      );

      _barometerController.add(update);
    } catch (e) {
      print('Error handling iOS altimeter update: $e');
    }
  }

  /// Handle GPS altitude updates (iOS fallback)
  void _handleGPSAltitude(double gpsAltitude) {
    try {
      // Check if stream is closed before adding events
      if (_barometerController.isClosed) {
        return;
      }

      // Add to readings buffer for smoothing
      _altitudeReadings.add(gpsAltitude);
      if (_altitudeReadings.length > _maxReadings) {
        _altitudeReadings.removeAt(0);
      }

      // Calculate smoothed altitude
      final smoothedAltitude = _getSmoothedAltitude();

      // Calculate relative altitude
      _currentRelativeAltitude = smoothedAltitude - _baseAltitude;

      // Estimate pressure from altitude using reverse barometric formula
      final estimatedPressure = _calculatePressureFromAltitude(smoothedAltitude);

      // Create update event
      final update = BarometerUpdate(
        pressure: estimatedPressure,
        altitude: smoothedAltitude,
        relativeAltitude: _currentRelativeAltitude,
        timestamp: DateTime.now(),
        isFromGPS: true, // Mark as GPS-based
      );

      _barometerController.add(update);
    } catch (e) {
      print('Error handling GPS altitude: $e');
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

  /// Get smoothed altitude value from recent GPS readings
  double _getSmoothedAltitude() {
    if (_altitudeReadings.isEmpty) return 0.0;

    // Use weighted average (more weight to recent readings)
    double weightedSum = 0.0;
    double totalWeight = 0.0;

    for (int i = 0; i < _altitudeReadings.length; i++) {
      final weight = (i + 1) / _altitudeReadings.length; // Linear weight
      weightedSum += _altitudeReadings[i] * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  /// Calculate absolute altitude from pressure using barometric formula
  double _calculateAbsoluteAltitude(double pressure) {
    try {
      // Validate pressure reading
      if (pressure <= 0 || pressure > 1100) {
        print('⚠️ Invalid pressure reading: $pressure hPa');
        return 0.0;
      }
      
      // Standard barometric formula: h = 44330 * (1 - (P/P0)^(1/5.255))
      // More accurate: h = (T0/L) * (1 - (P/P0)^((R*L)/(g*M)))
      // Using simplified formula for better accuracy
      final exponent = 1.0 / 5.255; // This is approximately (R*L)/(g*M)
      final ratio = pow(pressure / _seaLevelPressure, exponent);
      final altitude = 44330.0 * (1.0 - ratio);
      
      return altitude;
    } catch (e) {
      print('Error calculating absolute altitude: $e');
      return 0.0;
    }
  }

  /// Calculate relative altitude from base pressure
  double _calculateRelativeAltitude(double pressure) {
    try {
      // Validate pressure reading
      if (pressure <= 0 || pressure > 1100) {
        print('⚠️ Invalid pressure reading for relative altitude: $pressure hPa');
        return 0.0;
      }
      
      // Validate base pressure
      if (_basePressure <= 0 || _basePressure > 1100) {
        print('⚠️ Invalid base pressure: $_basePressure hPa, resetting to sea level');
        _basePressure = _seaLevelPressure;
      }
      
      // Calculate relative altitude using simplified formula
      // h_relative = 44330 * ((P0/P_base)^(1/5.255) - (P0/P_current)^(1/5.255))
      // Simplified: h_relative = 44330 * (1 - (P_current/P_base)^(1/5.255))
      final exponent = 1.0 / 5.255;
      final ratio = pow(pressure / _basePressure, exponent);
      final relativeAltitude = 44330.0 * (1.0 - ratio);
      
      return relativeAltitude;
    } catch (e) {
      print('Error calculating relative altitude: $e');
      return 0.0;
    }
  }

  /// Calculate pressure from altitude (reverse barometric formula for GPS)
  double _calculatePressureFromAltitude(double altitude) {
    try {
      // Reverse barometric formula: P = P0 * (1 - L*h/T0)^(g*M/(R*L))
      // Where: P0 = sea level pressure, L = lapse rate, h = altitude, 
      //        T0 = temperature, g = gravity, M = molar mass, R = gas constant
      final ratio = 1.0 - (_pressureLapseRate * altitude / _temperatureKelvin);
      final exponent = (_gravity * _molarMass) / (_gasConstant * _pressureLapseRate);
      return _seaLevelPressure * pow(ratio, exponent);
    } catch (e) {
      print('Error calculating pressure from altitude: $e');
      return _seaLevelPressure;
    }
  }

  // Calibration methods

  /// Calibrate barometer specifically for Candi Borobudur
  /// Sets the base altitude to Borobudur's ground level (default 265m mdpl)
  /// knownAltitude: The absolute altitude (mdpl) that current location should be considered as
  /// calibrationType: Type of calibration (auto or manual)
  /// This ensures relative altitude shows height from ground floor (0m = lantai dasar)
  Future<void> calibrateForBorobudur({
    double? knownAltitude,
    CalibrationType calibrationType = CalibrationType.auto,
  }) async {
    try {
      final targetAltitude = knownAltitude ?? BOROBUDUR_BASE_ELEVATION;
      
      if (_useGPS) {
        // iOS GPS calibration for Borobudur
        // Set base altitude so that current GPS reading corresponds to targetAltitude
        if (_altitudeReadings.isNotEmpty) {
          final currentGPSAltitude = _getSmoothedAltitude();
          // Adjust base so: currentGPSAltitude - base = 0 (we're at ground level)
          // Therefore: base = currentGPSAltitude - 0 = currentGPSAltitude
          // But we want base to represent the absolute elevation, so:
          _baseAltitude = targetAltitude;
          _isCalibrated = true;
          _currentRelativeAltitude = currentGPSAltitude - targetAltitude;
        } else {
          _baseAltitude = targetAltitude;
          _isCalibrated = true;
          _currentRelativeAltitude = 0.0;
        }
        
        print('🏛️ GPS calibrated for Candi Borobudur: baseAltitude=${targetAltitude}m mdpl (${calibrationType.name})');
        print('📏 Current location is at ground level (${targetAltitude}m mdpl)');
      } else if (_useIOSAltimeter) {
        // iOS CMAltimeter calibration for Borobudur
        _baseAltitude = targetAltitude;
        _isCalibrated = true;
        _currentRelativeAltitude = 0.0;
        
        print('🏛️ iOS Altimeter calibrated for Candi Borobudur: baseAltitude=${targetAltitude}m mdpl (${calibrationType.name})');
        print('📏 Relative altitude will show height from ground level (0m = lantai dasar)');
      } else {
        // Android barometer calibration for Borobudur
        if (_pressureReadings.isEmpty) {
          print('⚠️ No pressure readings available for Borobudur calibration');
          print('📊 Will calibrate once sensor data is available...');
          return;
        }

        final currentPressure = _getSmoothedPressure();
        
        // Set current pressure as base pressure (ground level)
        // Set target altitude as base altitude (absolute elevation)
        _basePressure = currentPressure;
        _baseAltitude = targetAltitude;
        _isCalibrated = true;
        _currentRelativeAltitude = 0.0;

        print('🏛️ Barometer calibrated for Candi Borobudur (${calibrationType.name}):');
        print('   • Base pressure: ${_basePressure.toStringAsFixed(2)} hPa (current ground level)');
        print('   • Base altitude: ${targetAltitude}m mdpl (absolute elevation)');
        print('   • Current location is now considered as ${targetAltitude}m mdpl');
        print('📏 Relative altitude will show height from this ground level:');
        print('   • 0m = Current location (${targetAltitude}m mdpl)');
        print('   • +10m = 10 meters above current location');
        print('   • -10m = 10 meters below current location');
      }

      // Update calibration state
      _calibrationState = CalibrationState(
        type: calibrationType,
        timestamp: DateTime.now(),
      );

      // Save calibration
      await _saveCalibration();
    } catch (e) {
      print('❌ Error calibrating for Borobudur: $e');
    }
  }

  /// Calibrate barometer at current location
  Future<void> calibrateHere({double? knownAltitude}) async {
    try {
      if (_useGPS) {
        // iOS GPS calibration
        if (_altitudeReadings.isEmpty) {
          print('No GPS altitude readings available for calibration');
          return;
        }
        
        final currentAltitude = _getSmoothedAltitude();
        _baseAltitude = knownAltitude ?? currentAltitude;
        _isCalibrated = true;
        _currentRelativeAltitude = 0.0;
        
        print('GPS altitude calibrated: baseAltitude=${_baseAltitude.toStringAsFixed(2)}m');
      } else {
        // Android barometer calibration
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

        print('Barometer calibrated: basePressure=${_basePressure.toStringAsFixed(2)} hPa, baseAltitude=${_baseAltitude.toStringAsFixed(2)}m');
      }

      // Save calibration
      await _saveCalibration();
    } catch (e) {
      print('Error calibrating: $e');
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
      
      // Save calibration state
      await prefs.setString('barometer_calibration_type', _calibrationState.type.name);
      if (_calibrationState.timestamp != null) {
        await prefs.setInt('barometer_calibration_timestamp', _calibrationState.timestamp!.millisecondsSinceEpoch);
      }
      
      print('💾 Calibration saved: ${_calibrationState}');
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

      // Load calibration state
      final typeString = prefs.getString('barometer_calibration_type');
      final timestampMs = prefs.getInt('barometer_calibration_timestamp');
      
      if (typeString != null) {
        final type = CalibrationType.values.firstWhere(
          (e) => e.name == typeString,
          orElse: () => CalibrationType.none,
        );
        final timestamp = timestampMs != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
          : null;
        
        _calibrationState = CalibrationState(
          type: type,
          timestamp: timestamp,
        );
      }

      print('📂 Loaded calibration: pressure=${_basePressure.toStringAsFixed(2)} hPa, altitude=${_baseAltitude.toStringAsFixed(2)}m, state=${_calibrationState}');
    } catch (e) {
      print('Error loading calibration: $e');
    }
  }

  /// Get temple level description based on relative altitude
  /// Returns estimated level (lantai) based on Borobudur's typical structure
  String getTempleLevelDescription(double relativeAltitude) {
    if (relativeAltitude < 5) {
      return 'Lantai Dasar (Ground Level)';
    } else if (relativeAltitude < 10) {
      return 'Lantai 1-2 (Lower Terraces)';
    } else if (relativeAltitude < 20) {
      return 'Lantai 3-5 (Middle Terraces)';
    } else if (relativeAltitude < 30) {
      return 'Lantai 6-7 (Upper Terraces)';
    } else if (relativeAltitude < 40) {
      return 'Lantai 8-9 (Top Platform)';
    } else {
      return 'Puncak Stupa (Main Stupa)';
    }
  }

  /// Get estimated temple level number (1-10) based on altitude
  /// This is a rough estimate, use LevelDetectionService for accurate detection
  int getEstimatedLevel(double relativeAltitude) {
    // Rough estimation: ~3.5-4m per level
    final level = (relativeAltitude / 3.8).round() + 1;
    return level.clamp(1, 10);
  }

  /// Get current sensor status information
  Map<String, dynamic> getStatus() {
    String dataSource;
    String accuracy;
    
    if (_useIOSAltimeter) {
      dataSource = 'iOS CMAltimeter';
      accuracy = '±1-3m';
    } else if (_useGPS) {
      dataSource = 'GPS Altitude';
      accuracy = '±5-10m';
    } else {
      dataSource = 'Barometer Sensor';
      accuracy = '±1-2m';
    }
    
    return {
      'initialized': _isInitialized,
      'tracking': _isTracking,
      'calibrated': _isCalibrated,
      'platform': Platform.isIOS ? 'iOS' : 'Android',
      'dataSource': dataSource,
      'accuracy': accuracy,
      'basePressure': _basePressure,
      'baseAltitude': _baseAltitude,
      'currentRelativeAltitude': _currentRelativeAltitude,
      'borobudurBaseElevation': BOROBUDUR_BASE_ELEVATION,
      'pressureReadingsCount': _pressureReadings.length,
      'altitudeReadingsCount': _altitudeReadings.length,
      'lastPressure': _pressureReadings.isNotEmpty ? _pressureReadings.last : null,
      'lastAltitude': _altitudeReadings.isNotEmpty ? _altitudeReadings.last : null,
    };
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _iosAltimeter.dispose();
    _barometerController.close();
    _availabilityController.close();
    _pressureReadings.clear();
    _altitudeReadings.clear();
  }
}