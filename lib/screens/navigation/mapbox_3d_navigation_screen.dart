import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/temple_node.dart';
import '../../services/temple_navigation_service.dart';
import '../../services/barometer_service.dart';
import '../../services/level_detection_service.dart';
import '../../utils/app_colors.dart';
import 'level_config_screen.dart';

class Mapbox3DNavigationScreen extends StatefulWidget {
  const Mapbox3DNavigationScreen({Key? key}) : super(key: key);

  @override
  State<Mapbox3DNavigationScreen> createState() => _Mapbox3DNavigationScreenState();
}

class _Mapbox3DNavigationScreenState extends State<Mapbox3DNavigationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  MapboxMap? _mapboxMap;
  final TempleNavigationService _navigationService = TempleNavigationService();
  final BarometerService _barometerService = BarometerService();
  final LevelDetectionService _levelDetectionService = LevelDetectionService();
  final FlutterTts _flutterTts = FlutterTts();

  // Navigation states
  TempleNode? selectedNode;
  TempleFeature? selectedFeature;
  TempleNode? destinationNode;
  TempleFeature? destinationFeature;
  TempleNode? startNode;
  TempleFeature? startFeature;
  bool useCurrentLocation = true;
  bool isNavigating = false;

  // Voice guidance
  bool _isVoiceEnabled = true;
  String _lastSpokenInstruction = '';

  // Map data
  List<RouteWaypoint> _currentRoute = [];

  // Current position
  geo.Position? _currentPosition;
  StreamSubscription<geo.Position>? _positionSubscription;
  StreamSubscription<NavigationUpdate>? _navigationSubscription;

  // Barometer and level detection
  int _currentTempleLevel = 1;
  double _currentAltitude = 0.0;
  bool _isBarometerAvailable = false;
  StreamSubscription<BarometerUpdate>? _barometerSubscription;
  StreamSubscription<int>? _levelSubscription;

  // UI states
  bool _showLoadingOverlay = false;
  NavigationUpdate? _currentNavigationUpdate;
  bool? _hasLocationPermission;

  // 3D Settings
  String lightPreset = 'day';
  String theme = 'default';
  double cameraPitch = 60.0; // 3D tilt angle
  double cameraZoom = 18.0;
  double cameraBearing = 0.0;

  // Borobudur center coordinates
  static const double borobudurLat = -7.607874;
  static const double borobudurLon = 110.203751;

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationService.initialize();
    _initializeAnimations();
    _initializeVoiceGuidance();
    _initializeLocationTracking();
    _initializeBarometerServices();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermissionStatus();
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _checkLocationPermissionStatus() async {
    final hasPermission = await _navigationService.hasLocationPermission();
    if (mounted) {
      setState(() {
        _hasLocationPermission = hasPermission;
      });
      if (hasPermission && useCurrentLocation) {
        _initializeLocationTracking();
      }
    }
  }

  void _initializeVoiceGuidance() async {
    try {
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(0.8);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('Voice guidance initialization failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _navigationSubscription?.cancel();
    _barometerSubscription?.cancel();
    _levelSubscription?.cancel();
    _pulseController.dispose();
    _flutterTts.stop();
    _navigationService.dispose();
    _barometerService.dispose();
    _levelDetectionService.dispose();
    super.dispose();
  }

  Future<void> _speakInstruction(String instruction) async {
    if (_isVoiceEnabled && instruction != _lastSpokenInstruction) {
      try {
        await _flutterTts.speak(instruction);
        _lastSpokenInstruction = instruction;
      } catch (e) {
        debugPrint('Voice guidance error: $e');
      }
    }
  }

  Future<void> _initializeBarometerServices() async {
    try {
      final barometerInitialized = await _barometerService.initialize();
      if (!barometerInitialized) {
        print('Barometer service initialization failed');
        return;
      }

      final levelDetectionInitialized = await _levelDetectionService.initialize();
      if (!levelDetectionInitialized) {
        print('Level detection service initialization failed');
        return;
      }

      setState(() {
        _isBarometerAvailable = true;
      });

      await _levelDetectionService.startDetection();

      _levelSubscription = _levelDetectionService.levelStream.listen((level) {
        if (mounted) {
          setState(() {
            _currentTempleLevel = level;
          });

          if (isNavigating) {
            _speakInstruction('Anda sekarang di lantai $level');
          }

          // Update 3D extrusion based on level
          _update3DExtrusion();
        }
      });

      _barometerSubscription = _barometerService.barometerStream.listen((update) {
        if (mounted) {
          setState(() {
            _currentAltitude = update.relativeAltitude;
          });
        }
      });

      print('Barometer and level detection services initialized successfully');
    } catch (e) {
      print('Error initializing barometer services: $e');
      setState(() {
        _isBarometerAvailable = false;
      });
    }
  }

  Future<void> _initializeLocationTracking() async {
    try {
      _hasLocationPermission ??= await _navigationService.hasLocationPermission();

      if (!_hasLocationPermission!) {
        debugPrint('Location permission not granted, showing dialog');
        _showLocationPermissionDialog();
        return;
      }

      _currentPosition = _navigationService.getCurrentLocationForTesting();

      await _navigationService.startLocationTracking();

      _positionSubscription = _navigationService.positionStream?.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          _updateUserLocationOnMap(position);
        }
      });

      _navigationSubscription = _navigationService.navigationUpdateStream?.listen((update) {
        if (mounted) {
          setState(() {
            _currentNavigationUpdate = update;
          });

          if (update.instruction.isNotEmpty) {
            _speakInstruction(update.instruction);
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize location tracking: $e');
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    // Set up the 3D map style
    await _setupMapStyle();
    
    // Add markers and layers
    await _setupMarkersAndLayers();
    
    // Set up interactions
    _setupMapInteractions();
  }

  Future<void> _setupMapStyle() async {
    if (_mapboxMap == null) return;

    try {
      // Configure the Standard style with 3D buildings
      var configs = {
        "lightPreset": lightPreset,
        "theme": theme,
        "show3dObjects": true,
      };
      
      await _mapboxMap!.style.setStyleImportConfigProperties("basemap", configs);
      
    } catch (e) {
      print('Error setting up map style: $e');
    }
  }

  Future<void> _setupMarkersAndLayers() async {
    if (_mapboxMap == null) return;

    try {
      // Add Borobudur temple 3D layers with extrusion based on level
      await _addBorobudur3DLayers();
      
      // Add point annotations for nodes and features
      await _addNodeMarkers();
      await _addFeatureMarkers();
      
    } catch (e) {
      print('Error setting up markers and layers: $e');
    }
  }

  Future<void> _addBorobudur3DLayers() async {
    if (_mapboxMap == null) return;

    try {
      // Get level configurations
      final levels = _levelDetectionService.levelConfigs;
      
      // Wait for nodes to be loaded
      int retries = 0;
      while (_navigationService.nodes.isEmpty && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }
      
      if (_navigationService.nodes.isEmpty) {
        print('No nodes loaded, using default circular polygons');
        await _addDefaultCircularLayers();
        return;
      }
      
      // Group nodes by level
      final nodesByLevel = <int, List<TempleNode>>{};
      for (final node in _navigationService.nodes.values) {
        nodesByLevel.putIfAbsent(node.level, () => []).add(node);
      }
      
      print('Nodes grouped by level: ${nodesByLevel.keys.toList()}');
      
      for (final levelConfig in levels) {
        final levelNodes = nodesByLevel[levelConfig.level] ?? [];
        
        String levelPolygon;
        if (levelNodes.length >= 3) {
          // Create polygon from actual nodes at this level
          levelPolygon = _createPolygonFromNodes(levelNodes, levelConfig.level);
        } else {
          // Fallback to circular polygon
          levelPolygon = _createLevelPolygon(
            borobudurLat,
            borobudurLon,
            levelConfig.level,
            levels.length,
          );
        }
        
        // Add source for this level
        final sourceId = 'borobudur-level-${levelConfig.level}';
        await _mapboxMap!.style.addSource(GeoJsonSource(
          id: sourceId,
          data: levelPolygon,
        ));
        
        // Add 3D extrusion layer
        final layerId = 'borobudur-3d-${levelConfig.level}';
        final colorInt = levelConfig.color.value & 0xFFFFFFFF;
        
        await _mapboxMap!.style.addLayer(FillExtrusionLayer(
          id: layerId,
          sourceId: sourceId,
          fillExtrusionColor: colorInt,
          fillExtrusionHeight: levelConfig.maxAltitude,
          fillExtrusionBase: levelConfig.minAltitude,
          fillExtrusionOpacity: _currentTempleLevel == levelConfig.level ? 1.0 : 0.7,
        ));
      }
      
      print('Added ${levels.length} 3D temple layers');
    } catch (e) {
      print('Error adding Borobudur 3D layers: $e');
    }
  }

  Future<void> _addDefaultCircularLayers() async {
    final levels = _levelDetectionService.levelConfigs;
    
    for (final levelConfig in levels) {
      final levelPolygon = _createLevelPolygon(
        borobudurLat,
        borobudurLon,
        levelConfig.level,
        levels.length,
      );
      
      final sourceId = 'borobudur-level-${levelConfig.level}';
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: sourceId,
        data: levelPolygon,
      ));
      
      final layerId = 'borobudur-3d-${levelConfig.level}';
      final colorInt = levelConfig.color.value & 0xFFFFFFFF;
      
      await _mapboxMap!.style.addLayer(FillExtrusionLayer(
        id: layerId,
        sourceId: sourceId,
        fillExtrusionColor: colorInt,
        fillExtrusionHeight: levelConfig.maxAltitude,
        fillExtrusionBase: levelConfig.minAltitude,
        fillExtrusionOpacity: _currentTempleLevel == levelConfig.level ? 1.0 : 0.7,
      ));
    }
  }

  String _createPolygonFromNodes(List<TempleNode> nodes, int level) {
    // Create convex hull from nodes
    final points = nodes.map((n) => [n.longitude, n.latitude]).toList();
    
    // Sort points to create a proper polygon (simple convex hull approximation)
    final center = _calculateCenter(points);
    points.sort((a, b) {
      final angleA = math.atan2(a[1] - center[1], a[0] - center[0]);
      final angleB = math.atan2(b[1] - center[1], b[0] - center[0]);
      return angleA.compareTo(angleB);
    });
    
    // Close the polygon
    if (points.isNotEmpty) {
      points.add(points.first);
    }
    
    return '''
    {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [${points.map((p) => '[${p[0]}, ${p[1]}]').join(', ')}]
      },
      "properties": {
        "level": $level
      }
    }
    ''';
  }

  List<double> _calculateCenter(List<List<double>> points) {
    if (points.isEmpty) return [0.0, 0.0];
    
    double sumLon = 0;
    double sumLat = 0;
    
    for (final point in points) {
      sumLon += point[0];
      sumLat += point[1];
    }
    
    return [sumLon / points.length, sumLat / points.length];
  }

  String _createLevelPolygon(double centerLat, double centerLon, int level, int totalLevels) {
    // Create decreasing radius for each level (pyramid shape)
    final baseRadius = 0.0008; // ~90 meters
    final radius = baseRadius * ((totalLevels - level + 1) / totalLevels);
    
    final points = <List<double>>[];
    const segments = 32;
    
    for (int i = 0; i <= segments; i++) {
      final angle = (i * 2 * math.pi) / segments;
      final lat = centerLat + radius * math.cos(angle);
      final lon = centerLon + radius * math.sin(angle);
      points.add([lon, lat]);
    }
    
    return '''
    {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [${points.map((p) => '[${p[0]}, ${p[1]}]').join(', ')}]
      },
      "properties": {
        "level": $level
      }
    }
    ''';
  }

  Future<void> _addNodeMarkers() async {
    if (_mapboxMap == null) return;

    try {
      final nodes = _navigationService.nodes.values.toList();
      final annotations = <CircleAnnotationOptions>[];
      
      for (final node in nodes) {
        // Skip level-only nodes
        final nodeName = node.name.toLowerCase();
        if (nodeName.contains('lantai') &&
            !nodeName.contains('tangga') &&
            !nodeName.contains('stupa')) {
          continue;
        }
        
        final annotation = CircleAnnotationOptions(
          geometry: Point(coordinates: Position(node.longitude, node.latitude)),
          circleRadius: 8.0,
          circleColor: _getNodeColor(node).value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        );
        
        annotations.add(annotation);
      }
      
      final manager = await _mapboxMap!.annotations.createCircleAnnotationManager();
      await manager.createMulti(annotations);
      
      print('Added ${annotations.length} node markers (circle annotations)');
    } catch (e) {
      print('Error adding node markers: $e');
    }
  }

  Future<void> _addFeatureMarkers() async {
    if (_mapboxMap == null) return;

    try {
      // Wait for features to be loaded from API
      int retries = 0;
      while (_navigationService.features.isEmpty && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }
      
      final features = _navigationService.features;
      
      if (features.isEmpty) {
        print('No features loaded from API');
        return;
      }
      
      final annotations = <CircleAnnotationOptions>[];
      
      for (int i = 0; i < features.length; i++) {
        final feature = features[i];
        final annotation = CircleAnnotationOptions(
          geometry: Point(coordinates: Position(feature.longitude, feature.latitude)),
          circleRadius: 10.0,
          circleColor: feature.type == 'stupa' ? Colors.blue.value : Colors.orange.value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        );
        
        annotations.add(annotation);
      }
      
      final manager = await _mapboxMap!.annotations.createCircleAnnotationManager();
      await manager.createMulti(annotations);
      
      print('Added ${annotations.length} feature markers (${features.length} features loaded)');
    } catch (e) {
      print('Error adding feature markers: $e');
    }
  }

  void _setupMapInteractions() {
    if (_mapboxMap == null) return;

    // Add tap interaction using onTapListener
    // Note: Mapbox v2.x uses different API for interactions
    // For now, we'll skip complex interactions and focus on basic functionality
    print('Map interactions setup completed');
  }

  Future<void> _updateUserLocationOnMap(geo.Position position) async {
    if (_mapboxMap == null) return;

    try {
      // Update camera to follow user
      if (isNavigating) {
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(position.longitude, position.latitude)),
            zoom: cameraZoom,
            bearing: cameraBearing,
            pitch: cameraPitch,
          ),
          MapAnimationOptions(duration: 1000, startDelay: 0),
        );
      }
    } catch (e) {
      print('Error updating user location: $e');
    }
  }

  Future<void> _update3DExtrusion() async {
    if (_mapboxMap == null) return;

    try {
      // Update opacity of layers based on current level
      final levels = _levelDetectionService.levelConfigs;
      
      for (final levelConfig in levels) {
        final layerId = 'borobudur-3d-${levelConfig.level}';
        final opacity = _currentTempleLevel == levelConfig.level ? 1.0 : 0.5;
        
        await _mapboxMap!.style.setStyleLayerProperty(
          layerId,
          'fill-extrusion-opacity',
          opacity,
        );
      }
    } catch (e) {
      print('Error updating 3D extrusion: $e');
    }
  }

  Color _getNodeColor(TempleNode node) {
    if (node.name.toLowerCase().contains('tangga')) {
      return Colors.green;
    }
    
    switch (node.type.toUpperCase()) {
      case 'STUPA':
        return Colors.orange;
      case 'FOUNDATION':
        return Colors.brown;
      case 'GATE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showLocationPermissionDialog() {
    // Implementation similar to previous version
  }

  Future<void> _startNavigation() async {
    if (destinationNode == null && destinationFeature == null) {
      _showMessage('navigation_detail.select_destination'.tr(), Colors.orange);
      return;
    }

    if (useCurrentLocation) {
      if (_currentPosition == null) {
        _showMessage('navigation_detail.location_unavailable'.tr(), Colors.red);
        return;
      }
    } else {
      if (startNode == null && startFeature == null) {
        _showMessage('navigation_detail.select_destination'.tr(), Colors.orange);
        return;
      }
    }

    setState(() {
      isNavigating = true;
    });

    _speakInstruction('Navigasi dimulai');
  }

  void _stopNavigation() {
    _navigationService.stopNavigation();
    setState(() {
      isNavigating = false;
      _currentRoute.clear();
      _currentNavigationUpdate = null;
      _lastSpokenInstruction = '';
    });
    _speakInstruction('navigation_detail.stop_navigation'.tr());
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '3D Temple Navigation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          // Level configuration
          if (_isBarometerAvailable)
            IconButton(
              icon: Icon(
                Icons.tune,
                color: AppColors.accent,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const LevelConfigScreen(),
                  ),
                );
              },
              tooltip: 'Configure Level Settings',
            ),
          
          // Voice toggle
          IconButton(
            icon: Icon(
              _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: _isVoiceEnabled ? AppColors.primary : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isVoiceEnabled = !_isVoiceEnabled;
              });
              if (_isVoiceEnabled) {
                _speakInstruction('Panduan suara diaktifkan.');
              } else {
                _flutterTts.stop();
              }
            },
          ),
          // 3D Settings
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              setState(() {
                if (value == 'day' || value == 'dusk' || value == 'night') {
                  lightPreset = value;
                } else if (value == 'default' || value == 'faded') {
                  theme = value;
                }
                _setupMapStyle();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'day', child: Text('Day Light')),
              PopupMenuItem(value: 'dusk', child: Text('Dusk Light')),
              PopupMenuItem(value: 'night', child: Text('Night Light')),
              PopupMenuItem(value: 'default', child: Text('Default Theme')),
              PopupMenuItem(value: 'faded', child: Text('Faded Theme')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapbox 3D Map
          MapWidget(
            key: const ValueKey("mapbox3d"),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(borobudurLon, borobudurLat)),
              zoom: cameraZoom,
              bearing: cameraBearing,
              pitch: cameraPitch,
            ),
            styleUri: MapboxStyles.STANDARD,
            textureView: true,
            onMapCreated: _onMapCreated,
          ),

          // Level indicator
          if (_isBarometerAvailable)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.layers, color: AppColors.primary),
                    const SizedBox(height: 4),
                    Text(
                      'Level $_currentTempleLevel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${_currentAltitude.toStringAsFixed(1)}m',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // Navigation panel
          if (isNavigating && _currentNavigationUpdate != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: _buildNavigationPanel(),
            ),

          // Bottom control panel
          if (destinationNode != null || destinationFeature != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildBottomControlPanel(),
            ),

          // Loading overlay
          if (_showLoadingOverlay)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.navigation, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentNavigationUpdate!.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _stopNavigation,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      '${_currentNavigationUpdate!.remainingDistance.toStringAsFixed(0)}m',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text('Distance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${_currentNavigationUpdate!.estimatedTime}s',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text('Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlPanel() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: (destinationNode != null || destinationFeature != null)
          ? Offset.zero
          : const Offset(0, 1),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: (destinationNode != null || destinationFeature != null) ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Destination info
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tujuan: ${destinationNode?.name ?? destinationFeature?.name}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          destinationNode = null;
                          destinationFeature = null;
                          _currentRoute.clear();
                        });
                        _showMessage('Tujuan dibatalkan', Colors.orange);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.red, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              // Action button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isNavigating ? _stopNavigation : _startNavigation,
                      icon: Icon(isNavigating ? Icons.stop : Icons.navigation),
                      label: Text(isNavigating ? 'Stop' : 'Start Navigation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isNavigating ? Colors.red : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
