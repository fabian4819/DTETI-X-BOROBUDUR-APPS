import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'barometer_service.dart';

/// Temple level configuration
class TempleLevelConfig {
  final int level;
  final String name;
  final double minAltitude;
  final double maxAltitude;
  final String description;
  final Color color;

  TempleLevelConfig({
    required this.level,
    required this.name,
    required this.minAltitude,
    required this.maxAltitude,
    required this.description,
    required this.color,
  });

  factory TempleLevelConfig.fromJson(Map<String, dynamic> json) {
    return TempleLevelConfig(
      level: json['level'] as int,
      name: json['name'] as String,
      minAltitude: (json['minAltitude'] as num).toDouble(),
      maxAltitude: (json['maxAltitude'] as num).toDouble(),
      description: json['description'] as String,
      color: Color(json['color'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'name': name,
      'minAltitude': minAltitude,
      'maxAltitude': maxAltitude,
      'description': description,
      'color': color.value,
    };
  }

  @override
  String toString() => 'TempleLevelConfig(level: $level, name: $name, range: ${minAltitude.toStringAsFixed(1)}-${maxAltitude.toStringAsFixed(1)}m)';
}

/// Level transition event
class LevelTransitionEvent {
  final int fromLevel;
  final int toLevel;
  final double altitude;
  final DateTime timestamp;

  LevelTransitionEvent({
    required this.fromLevel,
    required this.toLevel,
    required this.altitude,
    required this.timestamp,
  });

  @override
  String toString() => 'LevelTransitionEvent($fromLevel → $toLevel at ${altitude.toStringAsFixed(1)}m)';
}

/// Service for detecting temple levels based on barometer readings
class LevelDetectionService {
  static final LevelDetectionService _instance = LevelDetectionService._internal();
  factory LevelDetectionService() => _instance;
  LevelDetectionService._internal();

  final BarometerService _barometerService = BarometerService();

  // Stream controllers
  final StreamController<int> _levelController = StreamController<int>.broadcast();
  final StreamController<LevelTransitionEvent> _transitionController =
      StreamController<LevelTransitionEvent>.broadcast();

  // Configuration
  List<TempleLevelConfig> _levelConfigs = [];
  int _currentLevel = 1;
  int _previousLevel = 1;
  double _hysteresisBuffer = 2.0; // meters

  // State
  bool _isInitialized = false;
  bool _isDetecting = false;
  StreamSubscription<BarometerUpdate>? _barometerSubscription;
  DateTime? _lastTransitionTime;
  static const Duration _transitionCooldown = Duration(seconds: 2);

  // Debouncing
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  // Public streams
  Stream<int> get levelStream => _levelController.stream;
  Stream<LevelTransitionEvent> get transitionStream => _transitionController.stream;

  // Public getters
  bool get isInitialized => _isInitialized;
  bool get isDetecting => _isDetecting;
  int get currentLevel => _currentLevel;
  List<TempleLevelConfig> get levelConfigs => List.unmodifiable(_levelConfigs);
  double get hysteresisBuffer => _hysteresisBuffer;

  /// Initialize the level detection service
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Load level configurations
      await _loadLevelConfigs();

      // Load hysteresis setting
      await _loadHysteresisSetting();

      _isInitialized = true;
      print('Level detection service initialized with ${_levelConfigs.length} levels');
      return true;
    } catch (e) {
      print('Error initializing level detection service: $e');
      return false;
    }
  }

  /// Load temple level configurations
  Future<void> _loadLevelConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasConfig = prefs.getBool('has_custom_level_configs') ?? false;

      if (hasConfig) {
        // For now, always use defaults to avoid parsing issues
        // Custom config can be re-enabled later with proper JSON serialization
        print('Custom configs found, but using defaults for stability');
      }

      // Always use default Borobudur temple configuration
      _levelConfigs = _getDefaultBorobudurConfig();

      // Sort by level
      _levelConfigs.sort((a, b) => a.level.compareTo(b.level));

      print('Loaded ${_levelConfigs.length} level configurations');
    } catch (e) {
      print('Error loading level configs, using defaults: $e');
      _levelConfigs = _getDefaultBorobudurConfig();
    }
  }

  /// Get default Borobudur temple level configuration
  List<TempleLevelConfig> _getDefaultBorobudurConfig() {
    return [
      TempleLevelConfig(
        level: 1,
        name: 'Lantai 1 - Alas Candi',
        minAltitude: 0.0,
        maxAltitude: 15.0,
        description: 'Dasar dan jalan masuk utama',
        color: Color(0xFF8B4513), // Brown
      ),
      TempleLevelConfig(
        level: 2,
        name: 'Lantai 2 - Kamadhatu',
        minAltitude: 15.0,
        maxAltitude: 25.0,
        description: 'Alam duniawi, relief cerita rakyat',
        color: Color(0xFFA0522D), // Sienna
      ),
      TempleLevelConfig(
        level: 3,
        name: 'Lantai 3 - Kamadhatu',
        minAltitude: 25.0,
        maxAltitude: 35.0,
        description: 'Lanjutan alam duniawi',
        color: Color(0xFFCD853F), // Peru
      ),
      TempleLevelConfig(
        level: 4,
        name: 'Lantai 4 - Rupadhatu',
        minAltitude: 35.0,
        maxAltitude: 45.0,
        description: 'Alam antara, candi Buddha',
        color: Color(0xFFD2691E), // Chocolate
      ),
      TempleLevelConfig(
        level: 5,
        name: 'Lantai 5 - Rupadhatu',
        minAltitude: 45.0,
        maxAltitude: 55.0,
        description: 'Lanjutan alam antara',
        color: Color(0xFFDEB887), // Burlywood
      ),
      TempleLevelConfig(
        level: 6,
        name: 'Lantai 6 - Arupadhatu',
        minAltitude: 55.0,
        maxAltitude: 65.0,
        description: 'Awal alam tanpa bentuk',
        color: Color(0xFFF4A460), // Sandy brown
      ),
      TempleLevelConfig(
        level: 7,
        name: 'Lantai 7 - Arupadhatu',
        minAltitude: 65.0,
        maxAltitude: 75.0,
        description: 'Lanjutan alam tanpa bentuk',
        color: Color(0xFFFFD700), // Gold
      ),
      TempleLevelConfig(
        level: 8,
        name: 'Lantai 8 - Arupadhatu',
        minAltitude: 75.0,
        maxAltitude: 85.0,
        description: 'Puncak stupa utama',
        color: Color(0xFFFFE4B5), // Moccasin
      ),
      TempleLevelConfig(
        level: 9,
        name: 'Lantai 9 - Puncak',
        minAltitude: 85.0,
        maxAltitude: 100.0,
        description: 'Puncak tertinggi, stupa utama',
        color: Color(0xFF00CED1), // Dark turquoise
      ),
    ];
  }

  /// Load hysteresis setting
  Future<void> _loadHysteresisSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hysteresisBuffer = prefs.getDouble('level_detection_hysteresis') ?? 2.0;
    } catch (e) {
      print('Error loading hysteresis setting: $e');
    }
  }

  /// Start level detection
  Future<bool> startDetection() async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }

      if (_isDetecting) return true;

      // Ensure barometer service is tracking
      final trackingStarted = await _barometerService.startTracking();
      if (!trackingStarted) {
        print('Failed to start barometer tracking for level detection');
        return false;
      }

      _barometerSubscription = _barometerService.barometerStream.listen(_handleBarometerUpdate);
      _isDetecting = true;

      print('Level detection started');
      return true;
    } catch (e) {
      print('Error starting level detection: $e');
      return false;
    }
  }

  /// Stop level detection
  void stopDetection() {
    try {
      _barometerSubscription?.cancel();
      _barometerSubscription = null;
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _isDetecting = false;

      print('Level detection stopped');
    } catch (e) {
      print('Error stopping level detection: $e');
    }
  }

  /// Handle barometer updates for level detection
  void _handleBarometerUpdate(BarometerUpdate update) {
    try {
      final altitude = update.relativeAltitude;
      final detectedLevel = _detectLevelFromAltitude(altitude);

      if (detectedLevel != _currentLevel) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(_debounceDelay, () {
          _processLevelChange(detectedLevel, altitude);
        });
      }
    } catch (e) {
      print('Error handling barometer update for level detection: $e');
    }
  }

  /// Detect level from altitude reading
  int _detectLevelFromAltitude(double altitude) {
    for (final config in _levelConfigs) {
      // Apply hysteresis for current level
      double minThreshold = config.minAltitude;
      double maxThreshold = config.maxAltitude;

      if (config.level == _currentLevel) {
        minThreshold -= _hysteresisBuffer;
        maxThreshold += _hysteresisBuffer;
      }

      if (altitude >= minThreshold && altitude < maxThreshold) {
        return config.level;
      }
    }

    // Fallback to nearest level
    return _findNearestLevel(altitude);
  }

  /// Find nearest level for altitude outside all ranges
  int _findNearestLevel(double altitude) {
    int nearestLevel = 1;
    double minDistance = double.infinity;

    for (final config in _levelConfigs) {
      final levelCenter = (config.minAltitude + config.maxAltitude) / 2;
      final distance = (altitude - levelCenter).abs();

      if (distance < minDistance) {
        minDistance = distance;
        nearestLevel = config.level;
      }
    }

    return nearestLevel;
  }

  /// Process level change with cooldown check
  void _processLevelChange(int newLevel, double altitude) {
    final now = DateTime.now();

    // Check cooldown period
    if (_lastTransitionTime != null &&
        now.difference(_lastTransitionTime!) < _transitionCooldown) {
      return;
    }

    _previousLevel = _currentLevel;
    _currentLevel = newLevel;
    _lastTransitionTime = now;

    // Create transition event
    final transition = LevelTransitionEvent(
      fromLevel: _previousLevel,
      toLevel: _currentLevel,
      altitude: altitude,
      timestamp: now,
    );

    // Send events
    _levelController.add(_currentLevel);
    _transitionController.add(transition);

    print('Level transition: $transition');
  }

  /// Update level configuration
  Future<void> updateLevelConfig(TempleLevelConfig config) async {
    try {
      final index = _levelConfigs.indexWhere((c) => c.level == config.level);
      if (index >= 0) {
        _levelConfigs[index] = config;
        await _saveLevelConfigs();
        print('Updated level ${config.level} configuration');
      }
    } catch (e) {
      print('Error updating level config: $e');
    }
  }

  /// Update hysteresis buffer
  Future<void> setHysteresisBuffer(double buffer) async {
    try {
      _hysteresisBuffer = buffer;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('level_detection_hysteresis', buffer);
      print('Hysteresis buffer set to ${buffer.toStringAsFixed(1)}m');
    } catch (e) {
      print('Error setting hysteresis buffer: $e');
    }
  }

  /// Save level configurations
  Future<void> _saveLevelConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = _levelConfigs.map((config) {
        return '${config.level}:${config.name}:${config.minAltitude}:${config.maxAltitude}:${config.description}:${config.color.value}';
      }).toList();
      await prefs.setStringList('temple_level_configs', configsJson);
    } catch (e) {
      print('Error saving level configs: $e');
    }
  }

  /// Reset to default configurations
  Future<void> resetToDefaults() async {
    try {
      _levelConfigs = _getDefaultBorobudurConfig();
      await _saveLevelConfigs();
      print('Reset to default level configurations');
    } catch (e) {
      print('Error resetting to defaults: $e');
    }
  }

  /// Get level configuration by level number
  TempleLevelConfig? getLevelConfig(int level) {
    try {
      return _levelConfigs.firstWhere((config) => config.level == level);
    } catch (e) {
      return null;
    }
  }

  /// Manually set current level (for testing or override)
  void setCurrentLevel(int level) {
    if (level < 1 || level > _levelConfigs.length) return;

    _previousLevel = _currentLevel;
    _currentLevel = level;
    _levelController.add(_currentLevel);

    print('Manual level set to $level');
  }

  /// Get current level information
  Map<String, dynamic> getStatus() {
    final currentConfig = getLevelConfig(_currentLevel);

    return {
      'initialized': _isInitialized,
      'detecting': _isDetecting,
      'currentLevel': _currentLevel,
      'previousLevel': _previousLevel,
      'levelCount': _levelConfigs.length,
      'hysteresisBuffer': _hysteresisBuffer,
      'lastTransitionTime': _lastTransitionTime?.toIso8601String(),
      'currentLevelConfig': currentConfig?.toString(),
    };
  }

  /// Dispose resources
  void dispose() {
    stopDetection();
    _levelController.close();
    _transitionController.close();
  }
}
