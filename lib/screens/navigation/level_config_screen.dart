import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/barometer_service.dart';
import '../../services/level_detection_service.dart';
import '../../utils/app_colors.dart';

/// Screen for configuring temple level elevation thresholds
class LevelConfigScreen extends StatefulWidget {
  const LevelConfigScreen({super.key});

  @override
  State<LevelConfigScreen> createState() => _LevelConfigScreenState();
}

class _LevelConfigScreenState extends State<LevelConfigScreen> {
  final LevelDetectionService _levelDetectionService = LevelDetectionService();
  final BarometerService _barometerService = BarometerService();

  List<TempleLevelConfig> _levelConfigs = [];
  bool _isLoading = true;
  double _hysteresisBuffer = 2.0;

  // Real-time sensor data
  double _currentAltitude = 0.0;
  int _detectedLevel = 1;
  bool _isTracking = false;

  // Controllers for text inputs
  final Map<int, TextEditingController> _minControllers = {};
  final Map<int, TextEditingController> _maxControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    // Stop tracking
    _levelDetectionService.stopDetection();

    // Dispose controllers
    for (final controller in _minControllers.values) {
      controller.dispose();
    }
    for (final controller in _maxControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      // Initialize services
      await _levelDetectionService.initialize();
      await _barometerService.initialize();

      // Load current configurations
      setState(() {
        _levelConfigs = List.from(_levelDetectionService.levelConfigs);
        _hysteresisBuffer = _levelDetectionService.hysteresisBuffer;
        _isLoading = false;
      });

      // Initialize text controllers
      _initializeControllers();

      // Start level detection for real-time feedback
      _startLevelDetection();

      // Listen to level changes
      _levelDetectionService.levelStream.listen((level) {
        if (mounted) {
          setState(() {
            _detectedLevel = level;
          });
        }
      });

      // Listen to barometer updates
      _barometerService.barometerStream.listen((update) {
        if (mounted) {
          setState(() {
            _currentAltitude = update.relativeAltitude;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error initializing configuration: $e');
    }
  }

  void _initializeControllers() {
    for (final config in _levelConfigs) {
      _minControllers[config.level] = TextEditingController(
        text: config.minAltitude.toStringAsFixed(1),
      );
      _maxControllers[config.level] = TextEditingController(
        text: config.maxAltitude.toStringAsFixed(1),
      );
    }
  }

  Future<void> _startLevelDetection() async {
    final started = await _levelDetectionService.startDetection();
    if (mounted) {
      setState(() {
        _isTracking = started;
      });
    }
  }

  void _updateLevelConfig(int level, {double? minAltitude, double? maxAltitude}) {
    final index = _levelConfigs.indexWhere((config) => config.level == level);
    if (index >= 0) {
      final config = _levelConfigs[index];
      final updatedConfig = TempleLevelConfig(
        level: config.level,
        name: config.name,
        minAltitude: minAltitude ?? config.minAltitude,
        maxAltitude: maxAltitude ?? config.maxAltitude,
        description: config.description,
        color: config.color,
      );

      setState(() {
        _levelConfigs[index] = updatedConfig;
      });

      // Update service
      _levelDetectionService.updateLevelConfig(updatedConfig);
    }
  }

  Future<void> _saveConfiguration() async {
    try {
      // Validate configurations
      for (int i = 0; i < _levelConfigs.length; i++) {
        final config = _levelConfigs[i];
        if (config.minAltitude >= config.maxAltitude) {
          _showError('Invalid range for level ${config.level}: minimum must be less than maximum');
          return;
        }

        // Check for overlaps with adjacent levels
        if (i > 0) {
          final prevConfig = _levelConfigs[i - 1];
          if (config.minAltitude < prevConfig.maxAltitude) {
            _showError('Level ${config.level} overlaps with level ${prevConfig.level}');
            return;
          }
        }
      }

      // Save all configurations
      for (final config in _levelConfigs) {
        await _levelDetectionService.updateLevelConfig(config);
      }

      // Save hysteresis
      await _levelDetectionService.setHysteresisBuffer(_hysteresisBuffer);

      _showSuccess('Configuration saved successfully!');
    } catch (e) {
      _showError('Error saving configuration: $e');
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await _showConfirmation(
      'Reset to Defaults',
      'This will reset all level configurations to default Borobudur settings. Continue?',
    );

    if (confirmed) {
      await _levelDetectionService.resetToDefaults();
      await _initializeData();
      _showSuccess('Reset to default configurations');
    }
  }

  Future<void> _calibrateHere() async {
    // Show dialog with options
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kalibrasi Barometer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih metode kalibrasi:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.temple_buddhist, color: Colors.orange),
              title: const Text('Auto Borobudur'),
              subtitle: const Text('Set base altitude 265m mdpl (lantai dasar candi)'),
              onTap: () => Navigator.of(context).pop('borobudur'),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.blue),
              title: const Text('Lokasi Saat Ini'),
              subtitle: const Text('Set posisi sekarang sebagai 0m referensi'),
              onTap: () => Navigator.of(context).pop('here'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      if (result == 'borobudur') {
        // Calibrate for Borobudur specifically
        await _barometerService.calibrateForBorobudur();
        if (mounted) {
          _showSuccess('✅ Barometer dikalibrasi untuk Candi Borobudur\n📏 Base altitude: 265m mdpl\n📍 0m = Lantai dasar candi');
        }
      } else if (result == 'here') {
        // Calibrate at current location
        await _barometerService.calibrateHere();
        if (mounted) {
          _showSuccess('✅ Barometer dikalibrasi di lokasi saat ini\n📍 Posisi sekarang = 0m referensi');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('❌ Kalibrasi gagal: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showConfirmation(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Level Configuration'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Level Configuration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _calibrateHere,
            tooltip: 'Calibrate Here',
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to Defaults',
          ),
        ],
      ),
      body: Column(
        children: [
          // Real-time status panel
          _buildStatusPanel(),

          // Hysteresis control
          _buildHysteresisPanel(),

          // Level configurations
          Expanded(
            child: _buildLevelConfigurations(),
          ),

          // Save button with SafeArea
          SafeArea(
            child: _buildSaveButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    final barometerStatus = _barometerService.getStatus();
    final isCalibrated = barometerStatus['calibrated'] as bool? ?? false;
    final baseAltitude = barometerStatus['baseAltitude'] as double? ?? 0.0;
    final isBorobudurCalibrated = (baseAltitude - _barometerService.borobudurBaseElevation).abs() < 1.0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tracking status
          Row(
            children: [
              Icon(
                _isTracking ? Icons.sensors : Icons.sensors_off,
                color: _isTracking ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isTracking ? 'Tracking Active' : 'Tracking Inactive',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _isTracking ? Colors.green : Colors.red,
                  ),
                ),
              ),
              Switch(
                value: _isTracking,
                onChanged: (value) async {
                  if (value) {
                    await _startLevelDetection();
                  } else {
                    _levelDetectionService.stopDetection();
                    setState(() {
                      _isTracking = false;
                    });
                  }
                },
              ),
            ],
          ),
          
          // Calibration status
          if (isCalibrated) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isBorobudurCalibrated ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isBorobudurCalibrated ? Colors.orange : Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isBorobudurCalibrated ? Icons.temple_buddhist : Icons.location_on,
                    size: 16,
                    color: isBorobudurCalibrated ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isBorobudurCalibrated 
                        ? '🏛️ Kalibrasi Borobudur (${baseAltitude.toStringAsFixed(0)}m mdpl)'
                        : '📍 Kalibrasi Custom (${baseAltitude.toStringAsFixed(1)}m)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isBorobudurCalibrated ? Colors.orange[800] : Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem(
                  'Current Altitude',
                  '${_currentAltitude.toStringAsFixed(1)}m',
                  Icons.height,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusItem(
                  'Detected Level',
                  'Lantai $_detectedLevel',
                  Icons.layers,
                  _getLevelConfig(_detectedLevel)?.color ?? AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHysteresisPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Hysteresis Buffer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_hysteresisBuffer.toStringAsFixed(1)}m',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Buffer zone to prevent rapid level switching when near boundaries',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _hysteresisBuffer,
            min: 0.5,
            max: 5.0,
            divisions: 9,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() {
                _hysteresisBuffer = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLevelConfigurations() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _levelConfigs.length,
      itemBuilder: (context, index) {
        final config = _levelConfigs[index];
        return _buildLevelConfigCard(config);
      },
    );
  }

  Widget _buildLevelConfigCard(TempleLevelConfig config) {
    final isCurrentLevel = config.level == _detectedLevel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentLevel
            ? Border.all(color: config.color, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: config.color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${config.level}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          config.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCurrentLevel ? config.color : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(config.description),
            const SizedBox(height: 4),
            Text(
              '${config.minAltitude.toStringAsFixed(1)} - ${config.maxAltitude.toStringAsFixed(1)}m',
              style: TextStyle(
                fontSize: 12,
                color: isCurrentLevel ? config.color : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Min altitude input
                Row(
                  children: [
                    const Text('Min Altitude (m):'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minControllers[config.level],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          final altitude = double.tryParse(value);
                          if (altitude != null) {
                            _updateLevelConfig(config.level, minAltitude: altitude);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Max altitude input
                Row(
                  children: [
                    const Text('Max Altitude (m):'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxControllers[config.level],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          final altitude = double.tryParse(value);
                          if (altitude != null) {
                            _updateLevelConfig(config.level, maxAltitude: altitude);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _saveConfiguration,
        icon: const Icon(Icons.save),
        label: const Text('Save Configuration'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  TempleLevelConfig? _getLevelConfig(int level) {
    try {
      return _levelConfigs.firstWhere((config) => config.level == level);
    } catch (e) {
      return null;
    }
  }
}