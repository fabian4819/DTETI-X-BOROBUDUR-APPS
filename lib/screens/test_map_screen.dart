import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/temple_node.dart';
import '../models/temple_feature.dart';
import '../services/level_detection_service.dart';
import '../utils/app_colors.dart';
import '../widgets/hybrid_3d_controller.dart';

/// Test Map Screen
/// Simple test screen to demonstrate the working 3D system
class TestMapScreen extends StatefulWidget {
  const TestMapScreen({super.key});

  @override
  State<TestMapScreen> createState() => _TestMapScreenState();
}

class _TestMapScreenState extends State<TestMapScreen> {
  late List<TempleNode> templeNodes;
  late List<TempleFeature> templeFeatures;
  late List<TempleLevelConfig> levelConfigs;
  late int currentLevel;
  Stream<int>? levelStream;
  late Stream<double>? altitudeStream;

  @override
  void initState() {
    super.initState();
    _initializeTestData();
  }

  void _initializeTestData() {
    // Create test temple nodes
    templeNodes = [
      TempleNode(
        id: 'f1',
        name: 'Foundation 1',
        coordinates: const LatLng(-7.607874, 110.203751),
        type: 'foundation',
        description: 'Base temple foundation',
        altitude: 0.0,
      ),
      TempleNode(
        id: 's1',
        name: 'Stupa 1',
        coordinates: const LatLng(-7.607874, 110.203751),
        type: 'stupa',
        description: 'Main stupa',
        altitude: 3.0,
        level: 1,
        distanceM: 50.0,
      ),
      TempleNode(
        id: 'g1',
        name: 'Gate 1',
        coordinates: const LatLng(-7.607874, 110.203751),
        type: 'entrance',
        description: 'Temple entrance gate',
        altitude: 1.5,
        level: 1,
      ),
    ];

    // Create test temple features
    templeFeatures = [
      TempleFeature(
        id: 's1',
        name: 'Central Stupa',
        type: 'stupa',
        latitude: -7.607874,
        longitude: 110.203751,
        level: 1,
        description: 'Main temple stupa with Buddha statue',
      ),
      TempleFeature(
        id: 'g1',
        name: 'Eastern Gate',
        type: 'entrance',
        latitude: -7.607874,
        longitude: 110.203751,
        level: 1,
        description: 'Eastern temple entrance',
      ),
      TempleFeature(
        id: 'p1',
        name: 'Pathway 1',
        type: 'pathway',
        latitude: -7.607874,
        longitude: 110.203751,
        level: 1,
        description: 'Ground level pathway',
      ),
      TempleFeature(
        id: 'r1',
        name: 'Relief Panel',
        type: 'relief',
        latitude: -7.607874,
        longitude: 110.203751,
        level: 1,
        description: 'Borobudur relief carvings',
      ),
    ];

    // Create test level configurations
    levelConfigs = LevelDetectionService.getDefaultBorobudurLevels();

    // Set initial level
    currentLevel = 1;

    // Initialize level detection
    final levelDetectionService = LevelDetectionService();
    levelStream = levelDetectionService.levelStream;
    altitudeStream = levelDetectionService.altitudeStream;

    // Listen to level changes
    altitudeStream?.listen((altitude) {
      print('Test: Altitude: ${altitude.toStringAsFixed(1)}m');
    });

    levelStream?.listen((level) {
      print('Test: Level changed to $level');
      setState(() {
        currentLevel = level;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borobudur Explorer - Test Map'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _showTestMenu(context, value),
          ),
        ],
      ),
      body: SafeArea(
        child: Hybrid3DController(
          templeNodes: templeNodes,
          templeFeatures: templeFeatures,
          currentLevel: currentLevel,
          levelConfigs: levelConfigs,
          onMapTap: (location) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Map tapped at: ${location.latitude}, ${location.longitude}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          onLevelSelected: (level) {
            print('Test: Selected level $level');
            setState(() {
              currentLevel = level;
            });
          },
          mapController: null, // Let controller be created internally
          altitudeStream: altitudeStream,
          levelStream: levelStream,
        ),
      ),
    );
  }

  void _showTestMenu(BuildContext context, String value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: 'Test 3D Map Functions',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                _testAltitudeCalibration();
              },
              child: const Text('Test Altitude Calibration'),
            ),
            ElevatedButton(
              onPressed: () {
                _testManualLevelChange();
              },
              child: const Text('Manual Level Change'),
            ),
            ElevatedButton(
              onPressed: () {
                _test3DSwitching();
              },
              child: const Text('Test 3D Switching'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _testAltitudeCalibration() async {
    final levelDetectionService = LevelDetectionService();
    try {
      await levelDetectionService.calibrateFromGroundLevel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Altitude calibrated!'),
          backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('Calibration error: $e');
    }
  }

  void _testManualLevelChange() async {
    setState(() {
      currentLevel = (currentLevel % 9) + 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Manual level set to $currentLevel'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _test3DSwitching() async {
    // Test 3D perspective switching
    await _testCameraPerspective(0.0);
    await _testCameraPerspective(45.0);
    await _testCameraPerspective(90.0);
  }

  Future<void> _testCameraPerspective(double pitch) async {
    print('Test: Setting camera pitch to ${pitch.toStringAsFixed(1)}°');
    // Implementation would depend on Mapbox camera API
  }

  @override
  void dispose() {
    _altitudeStream?.drain();
    _levelStream?.drain();
    super.dispose();
  }
}