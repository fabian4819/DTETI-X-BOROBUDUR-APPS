import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import '../../models/temple_node.dart';
import '../../services/temple_navigation_service.dart';
import '../../services/barometer_service.dart';
import '../../services/level_detection_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/location_helper.dart';
import '../../config/map_config.dart';
import '../../data/borobudur_facilities_data.dart';
import 'level_config_screen.dart';

// Enum for location mode
enum LocationMode {
  currentLocation,
  customLocation,
}

// Enum for map center mode
enum MapCenterMode {
  currentLocation, // Map centered on user's actual location
  borobudurLocation, // Map centered on Borobudur temple
}

class Mapbox3DNavigationScreen extends StatefulWidget {
  const Mapbox3DNavigationScreen({Key? key}) : super(key: key);

  @override
  State<Mapbox3DNavigationScreen> createState() => _Mapbox3DNavigationScreenState();
}

class _Mapbox3DNavigationScreenState extends State<Mapbox3DNavigationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Global key for MapWidget to prevent recreate error on iOS
  // ⚠️ IMPORTANT: Do NOT use Hot Restart (R) - use Hot Reload (r) or full restart
  // Hot Restart will cause "recreating_view" error on iOS MapView
  final GlobalKey _mapKey = GlobalKey();
  
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
  bool showNavigationPreview = false;
  double? previewDistance;
  int? previewDuration; // in seconds
  
  // Location mode
  LocationMode _locationMode = LocationMode.currentLocation;
  geo.Position? _customStartLocation; // Custom location selection
  bool _isSelectingStartLocation = false;
  bool _isSelectingNodeFromMap = false; // For selecting node from map
  bool _showLocationModePanel = false;

  // Calibration management
  bool _isAtBorobudur = false;
  bool _hasShownCalibrationPrompt = false; // Session flag

  // Map center mode
  MapCenterMode _mapCenterMode = MapCenterMode.borobudurLocation;

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
  double _currentAltitude = 0.0; // Relative altitude (from ground level)
  double _currentAbsoluteAltitude = 0.0; // Absolute altitude (mdpl)
  double _currentPressure = 0.0;
  bool _isBarometerAvailable = false;
  StreamSubscription<BarometerUpdate>? _barometerSubscription;
  StreamSubscription<int>? _levelSubscription;

  // UI states
  bool _showLoadingOverlay = false;
  NavigationUpdate? _currentNavigationUpdate;
  bool? _hasLocationPermission;

  // 3D Settings (matched with bolobudur-app)
  String lightPreset = 'day';
  String theme = 'default';
  double cameraPitch = 0.0; // Top-down view (like bolobudur-app)
  double cameraZoom = 17.0; // Zoom level from bolobudur-app
  double cameraBearing = 0.0;
  bool _show3DBuildings = false;
  
  // Level filter state
  Set<int> _selectedLevels = {}; // Empty = show all levels
  bool _showAllLevels = true; // Disabled to match bolobudur-app (flat 2D map)

  // Borobudur center coordinates
  static const double borobudurLat = -7.607874;
  static const double borobudurLon = 110.203751;

  // Track which levels have markers
  final Set<int> _levelsWithMarkers = {};
  
  // Multi-stage navigation state
  int _navigationStage = 0; // 0 = no navigation, 1 = to entrance, 2 = inside temple
  TempleNode? _finalDestinationNode;
  TempleFeature? _finalDestinationFeature;
  static const int ENTRANCE_GATE_ID = 128; // Pintu Akses Masuk Candi
  static const String ENTRY_NODE_ID = 'lantai1_tangga_21'; // Entry point inside temple
  
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
      
      // Restart barometer tracking if it was stopped
      if (_isBarometerAvailable && !_barometerService.isTracking) {
        print('🔄 Resuming barometer tracking...');
        _barometerService.startTracking();
        _levelDetectionService.startDetection();
      }
      
      // Re-subscribe to streams if needed
      if (_isBarometerAvailable && _barometerSubscription == null) {
        print('🔄 Re-subscribing to barometer stream...');
        _barometerSubscription = _barometerService.barometerStream.listen((update) {
          if (mounted) {
            setState(() {
              _currentAltitude = update.relativeAltitude;
              _currentAbsoluteAltitude = update.altitude;
              _currentPressure = update.pressure;
            });
            print('📏 Altitude Update: ${update.relativeAltitude.toStringAsFixed(2)}m (relative) | ${update.altitude.toStringAsFixed(2)}m (absolute) | Pressure: ${update.pressure.toStringAsFixed(2)} hPa');
          }
        });
        
        _levelSubscription = _levelDetectionService.levelStream.listen((level) {
          if (mounted) {
            setState(() {
              _currentTempleLevel = level;
            });
            print('🏛️ Level detected: $level');
            
            if (isNavigating) {
              _speakInstruction('Anda sekarang di lantai $level');
            }
            
            _update3DExtrusion();
            _updateMarkersVisibility();
            _update3DBuildingVisibility(level);
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // Optional: Stop tracking when app is paused to save battery
      // Uncomment if needed:
      // _barometerService.stopTracking();
      // _levelDetectionService.stopDetection();
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _checkLocationPermissionStatus() async {
    print('🔍 Checking location permission status...');
    final hasPermission = await _navigationService.hasLocationPermission();
    print('Permission status: $hasPermission');
    
    setState(() {
      _hasLocationPermission = hasPermission;
    });

    if (hasPermission && _positionSubscription == null) {
      print('⚠️ Permission granted but no position subscription, reinitializing...');
      await _initializeLocationTracking();
    } else if (!hasPermission) {
      print('❌ No location permission');
    } else {
      print('✅ Location tracking already active');
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
    
    // Clear navigation state to prevent duplicate cards on return
    destinationNode = null;
    destinationFeature = null;
    startNode = null;
    startFeature = null;
    showNavigationPreview = false;
    isNavigating = false;
    _navigationStage = 0;
    _finalDestinationNode = null;
    _finalDestinationFeature = null;
    
    // Don't dispose barometer and level detection services as they are singletons
    // and should keep running even when navigating away from this screen
    // _barometerService.dispose();
    // _levelDetectionService.dispose();
    
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
      print('🔧 Starting barometer services initialization...');
      
      final barometerInitialized = await _barometerService.initialize();
      print('📊 Barometer initialized: $barometerInitialized');
      
      if (!barometerInitialized) {
        print('❌ Barometer service initialization failed');
        return;
      }

      final levelDetectionInitialized = await _levelDetectionService.initialize();
      print('📏 Level detection initialized: $levelDetectionInitialized');
      
      if (!levelDetectionInitialized) {
        print('❌ Level detection service initialization failed');
        return;
      }

      setState(() {
        _isBarometerAvailable = true;
      });
      
      print('✅ Barometer available, starting tracking...');

      // Start barometer tracking
      await _barometerService.startTracking();
      print('✅ Barometer tracking started');
      
      // Check if barometer is actually tracking
      print('📡 Barometer tracking status: ${_barometerService.isTracking}');
      
      // Auto-calibrate to 256 mdpl (silent, background) as fallback
      // This will be used if user doesn't manually calibrate
      final calibrationState = _barometerService.calibrationState;
      if (!calibrationState.isValid) {
        print('🔄 Auto-calibrating to 256 mdpl (fallback)...');
        await Future.delayed(Duration(seconds: 2)); // Wait for sensor readings
        await _barometerService.calibrateForBorobudur(
          knownAltitude: 256.0, // IDN Times source
          calibrationType: CalibrationType.auto,
        );
        print('✅ Auto-calibration complete (will be replaced if user manually calibrates)');
      } else {
        print('📂 Using existing calibration: ${calibrationState}');
      }

      await _levelDetectionService.startDetection();
      print('✅ Level detection started');

      _levelSubscription = _levelDetectionService.levelStream.listen((level) {
        if (mounted) {
          setState(() {
            _currentTempleLevel = level;
          });
          
          print('🏛️ Level detected: $level');

          if (isNavigating) {
            _speakInstruction('Anda sekarang di lantai $level');
          }

          // Update 3D extrusion and markers visibility based on level
          _update3DExtrusion();
          _updateMarkersVisibility();
          
          // NEW: Update 3D building visibility based on detected level
          _update3DBuildingVisibility(level);
        }
      });

      _barometerSubscription = _barometerService.barometerStream.listen((update) {
        if (mounted) {
          setState(() {
            _currentAltitude = update.relativeAltitude;
            _currentAbsoluteAltitude = update.altitude;
            _currentPressure = update.pressure;
          });
          
          // Debug logging for altitude detection
          print('📏 Altitude Update: ${update.relativeAltitude.toStringAsFixed(2)}m (relative) | ${update.altitude.toStringAsFixed(2)}m (absolute) | Pressure: ${update.pressure.toStringAsFixed(2)} hPa');
        }
      });

      print('✅ Barometer and level detection services initialized successfully');
      print('🎧 Stream listeners attached');
    } catch (e) {
      print('❌ Error initializing barometer services: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _isBarometerAvailable = false;
      });
    }
  }

  Future<void> _initializeLocationTracking() async {
    try {
      print('📍 Initializing location tracking...');
      
      _hasLocationPermission ??= await _navigationService.hasLocationPermission();
      print('Location permission status: $_hasLocationPermission');

      if (!_hasLocationPermission!) {
        debugPrint('❌ Location permission not granted, showing dialog');
        _showLocationPermissionDialog();
        return;
      }

      print('✅ Location permission granted');
      
      // Start location tracking
      print('Starting location tracking service...');
      await _navigationService.startLocationTracking();
      
      // Get current position immediately (don't wait for stream)
      print('📍 Getting current GPS position...');
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        );
        _currentPosition = position;
        print('✅ Got GPS position:');
        print('   Lat: ${_currentPosition?.latitude}');
        print('   Lon: ${_currentPosition?.longitude}');
        print('   Accuracy: ${_currentPosition?.accuracy}m');
      } catch (e) {
        print('⚠️ Error getting GPS position: $e');
        print('   Using test location as fallback');
        _currentPosition = _navigationService.getCurrentLocationForTesting();
        print('   Test location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      }

      // Subscribe to position stream
      _positionSubscription = _navigationService.positionStream?.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            
            // Check if at Borobudur
            _isAtBorobudur = LocationHelper.isAtBorobudur(
              position.latitude,
              position.longitude,
            );
          });
          
          print('📍 Position update: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m, atBorobudur: $_isAtBorobudur');
          _updateUserLocationOnMap(position);
          
          // Show smart calibration prompt if needed
          _checkAndShowCalibrationPrompt();
          
          // Check for multi-stage navigation stage switching
          if (_navigationStage == 1 && isNavigating) {
            _checkStageTransition(position);
          }
        }
      });
      
      print('Position stream subscription: ${_positionSubscription != null ? "Active" : "NULL"}');

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
      
      print('✅ Location tracking fully initialized');
    } catch (e) {
      print('❌ Error initializing location tracking: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Check if a point (lat, lon) is inside Borobudur temple complex
  /// The complex boundaries are approximate based on the temple area
  bool _isPointInsideBorobudurComplex(double lat, double lon) {
    // Borobudur temple complex approximate boundaries
    // These coordinates roughly define the area where vehicles cannot directly access
    const double minLat = -7.6095; // Southern boundary
    const double maxLat = -7.6070; // Northern boundary
    const double minLon = 110.2020; // Western boundary
    const double maxLon = 110.2045; // Eastern boundary
    
    final isInside = lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
    
    if (isInside) {
      print('📍 Point ($lat, $lon) is INSIDE Borobudur complex');
    } else {
      print('📍 Point ($lat, $lon) is OUTSIDE Borobudur complex');
    }
    
    return isInside;
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

  // Helper function to load image from assets
  Future<Uint8List?> _loadImageFromAsset(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error loading image from $assetPath: $e');
      return null;
    }
  }

  // Helper function to convert Material Icon to image bytes
  Future<Uint8List?> _iconToImage(IconData icon, {double size = 48, Color color = Colors.white}) async {
    try {
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          color: color,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset.zero);
      
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error converting icon to image: $e');
      return null;
    }
  }

  Future<void> _setupMarkersAndLayers() async {
    if (_mapboxMap == null) return;

    try {
      // Add Borobudur temple 3D layers with extrusion based on level
      await _addBorobudur3DLayers();
      
      // Enable 3D building visualization based on barometer
      await _enable3DBuildingVisualization();
      
      // Add edge lines (path network) - before markers so they appear below
      await _addEdgeLines();
      
      // Add point annotations for nodes and features
      await _addNodeMarkers();
      await _addFeatureMarkers();
      
      // Add external facilities markers (outside temple)
      await _addExternalFacilitiesMarkers();
      
      // Setup initial markers visibility based on current level
      await _updateMarkersVisibility();
      
    } catch (e) {
      print('Error setting up markers and layers: $e');
    }
  }

  // Switch to Current Location mode
  Future<void> _switchToCurrentLocationMode() async {
    if (_mapboxMap == null) return;
    
    try {
      // Get current user location
      final hasPermission = await _navigationService.hasLocationPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission required')),
        );
        setState(() {
          _mapCenterMode = MapCenterMode.borobudurLocation;
        });
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition();
      
      // Move camera to current location
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
          pitch: 45.0,
          bearing: 0.0,
        ),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mode: Current Location - Map mengikuti lokasi Anda'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error switching to current location mode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get current location')),
      );
      setState(() {
        _mapCenterMode = MapCenterMode.borobudurLocation;
      });
    }
  }

  // Switch to Borobudur mode
  Future<void> _switchToBorobudurMode() async {
    if (_mapboxMap == null) return;
    
    try {
      // Move camera to Borobudur
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(borobudurLon, borobudurLat)),
          zoom: cameraZoom,
          pitch: cameraPitch,
          bearing: cameraBearing,
        ),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mode: Borobudur - Map terpusat di Candi Borobudur'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error switching to Borobudur mode: $e');
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
          fillExtrusionOpacity: 0.0, // DISABLED - buildings invisible to match bolobudur-app
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

  /// Update 3D building visibility based on detected level from barometer
  /// Shows current level prominently, dims others for context
  Future<void> _update3DBuildingVisibility(int detectedLevel) async {
    if (_mapboxMap == null) return;

    try {
      final levels = _levelDetectionService.levelConfigs;
      
      print('🏗️ Updating 3D building visibility for level $detectedLevel');
      
      for (final levelConfig in levels) {
        final layerId = 'borobudur-3d-${levelConfig.level}';
        
        // Calculate opacity based on level relationship
        double opacity;
        if (levelConfig.level == detectedLevel) {
          // Current level: fully visible
          opacity = 0.9;
        } else if (levelConfig.level == detectedLevel - 1) {
          // Level below: semi-transparent for context
          opacity = 0.4;
        } else if (levelConfig.level == detectedLevel + 1) {
          // Level above: very transparent
          opacity = 0.2;
        } else {
          // Other levels: nearly invisible
          opacity = 0.1;
        }
        
        // Update layer opacity
        try {
          await _mapboxMap!.style.setStyleLayerProperty(
            layerId,
            'fill-extrusion-opacity',
            opacity,
          );
          
          print('  ✅ Level ${levelConfig.level} opacity: $opacity');
        } catch (e) {
          print('  ⚠️ Failed to update layer $layerId: $e');
        }
      }
      
      print('✅ 3D building visibility updated successfully');
    } catch (e) {
      print('❌ Error updating 3D building visibility: $e');
    }
  }

  /// Enable 3D buildings visualization with altitude-based opacity
  Future<void> _enable3DBuildingVisualization() async {
    if (_mapboxMap == null) return;

    try {
      print('🏗️ Enabling 3D building visualization...');
      
      // Update visibility for current level
      await _update3DBuildingVisibility(_currentTempleLevel);
      
      print('✅ 3D building visualization enabled');
    } catch (e) {
      print('❌ Error enabling 3D building visualization: $e');
    }
  }

  /// Disable 3D buildings (set all to invisible)
  Future<void> _disable3DBuildingVisualization() async {
    if (_mapboxMap == null) return;

    try {
      final levels = _levelDetectionService.levelConfigs;
      
      for (final levelConfig in levels) {
        final layerId = 'borobudur-3d-${levelConfig.level}';
        
        await _mapboxMap!.style.setStyleLayerProperty(
          layerId,
          'fill-extrusion-opacity',
          0.0,
        );
      }
      
      print('✅ 3D building visualization disabled');
    } catch (e) {
      print('❌ Error disabling 3D building visualization: $e');
    }
  }



  Future<void> _addNodeMarkers() async {
    if (_mapboxMap == null) return;

    try {
      final nodes = _navigationService.nodes.values.toList();
      
      // Group nodes by level - SHOW ALL NODES (no filter)
      final Map<int, List<TempleNode>> nodesByLevel = {};
      int skippedCount = 0;
      List<String> skippedNames = [];
      List<String> acceptedNames = [];
      
      for (final node in nodes) {
        final level = node.level;
        final nameUpper = node.name.toUpperCase();
        
        // FILTER: Only show TANGGA and numbered STUPA nodes (STUPA1, STUPA2, STUPA3)
        // Hide: generic nodes (LANTAI1_2, etc.) and DASAR_STUPA
        final hasTangga = nameUpper.contains('TANGGA');
        final hasDasarStupa = nameUpper.contains('DASAR_STUPA') || nameUpper.contains('DASAR STUPA');
        final hasNumberedStupa = nameUpper.contains('STUPA1') || 
                                  nameUpper.contains('STUPA2') || 
                                  nameUpper.contains('STUPA3');
        
        if (hasTangga || hasNumberedStupa) {
          nodesByLevel.putIfAbsent(level, () => []).add(node);
          if (acceptedNames.length < 10) {
            acceptedNames.add(node.name);
          }
        } else {
          skippedCount++;
          if (skippedNames.length < 10) {
            skippedNames.add(node.name);
          }
        }
      }
      
      int totalMarkers = 0;
      
      // Clear previous marker levels
      _levelsWithMarkers.clear();
      
      // DEBUG: Print total nodes and filtering results
      print('🔍 DEBUG: Total nodes loaded: ${nodes.length}');
      print('🔍 DEBUG: Filtered nodes by level: ${nodesByLevel.map((k, v) => MapEntry(k, v.length))}');
      int filteredCount = nodesByLevel.values.fold(0, (sum, list) => sum + list.length);
      print('🔍 DEBUG: Total markers (TANGGA + STUPA1/2/3 only): $filteredCount');
      print('🔍 DEBUG: Skipped $skippedCount nodes (including DASAR_STUPA)');
      print('🔍 DEBUG: Sample displayed nodes: ${acceptedNames.join(", ")}');
      print('🔍 DEBUG: Sample skipped nodes: ${skippedNames.join(", ")}');
      
      // Add nodes as GeoJSON sources with circle layers per level
      for (final level in nodesByLevel.keys) {
        final levelNodes = nodesByLevel[level]!;
        
        // Track this level has markers
        _levelsWithMarkers.add(level);
        
        print('🔍 DEBUG: Processing level $level with ${levelNodes.length} nodes');
        
        // Create GeoJSON features for this level (2D mode - no altitude)
        final features = levelNodes.map((node) {
          return '''
          {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [${node.longitude}, ${node.latitude}]
            },
            "properties": {
              "id": ${node.id},
              "name": "${node.name}",
              "type": "${node.type}",
              "level": ${node.level}
            }
          }
          ''';
        }).join(',');
        
        final geojson = '''
        {
          "type": "FeatureCollection",
          "features": [$features]
        }
        ''';
        
        // Add source
        final sourceId = 'nodes-level-$level';
        await _mapboxMap!.style.addSource(GeoJsonSource(
          id: sourceId,
          data: geojson,
        ));
        print('✅ Added source: $sourceId');
        
        // Load custom icons (only once per level iteration)
        if (level == nodesByLevel.keys.first) {
          try {
            print('🎨 Loading custom icons...');
            final gateIconData = await _loadImageFromAsset('assets/images/icon_gate.png');
            if (gateIconData != null) {
              try {
                await _mapboxMap!.style.addStyleImage('icon-gate', 1.0, MbxImage(width: 50, height: 50, data: gateIconData), false, [], [], null);
                print('✅ Loaded icon-gate (${gateIconData.length} bytes)');
              } catch (e) {
                print('⚠️ Icon-gate already exists or error: $e');
              }
            } else {
              print('❌ Failed to load icon-gate');
            }
            
            final stupaIconData = await _loadImageFromAsset('assets/images/icon_stupa.png');
            if (stupaIconData != null) {
              try {
                await _mapboxMap!.style.addStyleImage('icon-stupa', 1.0, MbxImage(width: 50, height: 50, data: stupaIconData), false, [], [], null);
                print('✅ Loaded icon-stupa (${stupaIconData.length} bytes)');
              } catch (e) {
                print('⚠️ Icon-stupa already exists or error: $e');
              }
            } else {
              print('❌ Failed to load icon-stupa');
            }
          } catch (e) {
            print('❌ Error loading icons: $e');
          }
        }
        
        // Add symbol layer with custom icons (matching bolobudur-app)
        final layerId = 'nodes-symbols-$level';
        
        // Determine dominant type for this level
        int stupaCount = levelNodes.where((n) => n.name.toUpperCase().contains('STUPA')).length;
        int tanggaCount = levelNodes.where((n) => n.name.toUpperCase().contains('TANGGA')).length;
        
        
        // Choose icon and styling based on dominant type
        String iconImage;
        int circleColor;
        int strokeColor;
        if (stupaCount > tanggaCount) {
          iconImage = 'icon-stupa';
          circleColor = 0xFFFF9800; // Vibrant orange for stupa
          strokeColor = 0xFFFFFFFF; // White border
          print('   🟠 Using STUPA icon with vibrant orange background');
        } else {
          iconImage = 'icon-gate';
          circleColor = 0xFF4CAF50; // Vibrant green for tangga
          strokeColor = 0xFFFFFFFF; // White border
          print('   🟢 Using GATE icon with vibrant green background');
        }
        
        // Add background circle layer with white border
        final circleLayerId = 'nodes-circles-$level';
        await _mapboxMap!.style.addLayer(CircleLayer(
          id: circleLayerId,
          sourceId: sourceId,
          circleRadius: 10.0, // Smaller for compact display
          circleColor: circleColor,
          circleOpacity: 1.0, // Full opacity for solid background
          circleStrokeWidth: 2.0, // White border
          circleStrokeColor: strokeColor,
          circleStrokeOpacity: 1.0,
          circlePitchAlignment: CirclePitchAlignment.VIEWPORT,
          circleSortKey: 998.0, // Below symbol layer
        ));
        
        // Add symbol layer with icon on top
        await _mapboxMap!.style.addLayer(SymbolLayer(
          id: layerId,
          sourceId: sourceId,
          iconImage: iconImage,
          iconSize: 0.3, // Smaller to create padding/margin with background
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ));
        
        String typeLabel = stupaCount > tanggaCount ? 'STUPA' : 'TANGGA';
        print('✅ Added enhanced layers: $circleLayerId + $layerId for ${levelNodes.length} markers');
        
        // DEBUG: Show sample node names to verify filtering
        if (levelNodes.isNotEmpty) {
          final sampleNames = levelNodes.take(3).map((n) => n.name).join(', ');
          print('   Sample names: $sampleNames');
        }
        
        totalMarkers += levelNodes.length;
      }
      
      print('Added $totalMarkers node markers across ${nodesByLevel.keys.length} levels');
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
      
      // Separate features by type
      final stupaFeatures = features.where((f) => f.type == 'stupa').toList();
      final otherFeatures = features.where((f) => f.type != 'stupa').toList();
      
      // Add stupa features (blue) with moderate altitude
      if (stupaFeatures.isNotEmpty) {
        final stupaGeoJson = {
          'type': 'FeatureCollection',
          'features': stupaFeatures.map((feature) => {
            'type': 'Feature',
            'id': feature.id,
            'geometry': {
              'type': 'Point',
              'coordinates': [feature.longitude, feature.latitude], // 2D coordinates
            },
            'properties': {
              'id': feature.id,
              'name': feature.name,
              'type': feature.type,
            },
          }).toList(),
        };
        
        await _mapboxMap!.style.addSource(GeoJsonSource(
          id: 'features-stupa-source',
          data: json.encode(stupaGeoJson),
        ));
        
        // Background circle for stupa features
        await _mapboxMap!.style.addLayer(CircleLayer(
          id: 'features-stupa-circles',
          sourceId: 'features-stupa-source',
          circleRadius: 10.0,
          circleColor: 0xFFFF9800, // Orange for stupas
          circleOpacity: 1.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          circleStrokeOpacity: 1.0,
          circlePitchAlignment: CirclePitchAlignment.VIEWPORT,
          circleSortKey: 998.0,
        ));
        
        // Load and add stupa icon
        try {
          final stupaIconData = await _iconToImage(Icons.account_balance, size: 24, color: Colors.white);
          if (stupaIconData != null) {
            try {
              await _mapboxMap!.style.addStyleImage('icon-feature-stupa', 1.0, MbxImage(width: 24, height: 24, data: stupaIconData), false, [], [], null);
            } catch (e) {
              // Icon already exists
            }
          }
        } catch (e) {
          print('Error loading stupa feature icon: $e');
        }
        
        // Add stupa icon symbol
        await _mapboxMap!.style.addLayer(SymbolLayer(
          id: 'features-stupa-symbols',
          sourceId: 'features-stupa-source',
          iconImage: 'icon-feature-stupa',
          iconSize: 0.5,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ));
      }
      
      // Add other features (purple) - 2D mode
      if (otherFeatures.isNotEmpty) {
        final otherGeoJson = {
          'type': 'FeatureCollection',
          'features': otherFeatures.map((feature) => {
            'type': 'Feature',
            'id': feature.id,
            'geometry': {
              'type': 'Point',
              'coordinates': [feature.longitude, feature.latitude], // 2D coordinates
            },
            'properties': {
              'id': feature.id,
              'name': feature.name,
              'type': feature.type,
            },
          }).toList(),
        };
        
        await _mapboxMap!.style.addSource(GeoJsonSource(
          id: 'features-other-source',
          data: json.encode(otherGeoJson),
        ));
        
        // Background circle for other features
        await _mapboxMap!.style.addLayer(CircleLayer(
          id: 'features-other-circles',
          sourceId: 'features-other-source',
          circleRadius: 10.0,
          circleColor: 0xFF9C27B0, // Purple for other features
          circleOpacity: 1.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFFFFFFFF, // White border
          circleStrokeOpacity: 1.0,
          circlePitchAlignment: CirclePitchAlignment.VIEWPORT,
          circleSortKey: 998.0,
        ));
        
        // Load and add location icon
        try {
          final locationIconData = await _iconToImage(Icons.place, size: 24, color: Colors.white);
          if (locationIconData != null) {
            try {
              await _mapboxMap!.style.addStyleImage('icon-feature-location', 1.0, MbxImage(width: 24, height: 24, data: locationIconData), false, [], [], null);
            } catch (e) {
              // Icon already exists
            }
          }
        } catch (e) {
          print('Error loading location feature icon: $e');
        }
        
        // Add location icon symbol
        await _mapboxMap!.style.addLayer(SymbolLayer(
          id: 'features-other-symbols',
          sourceId: 'features-other-source',
          iconImage: 'icon-feature-location',
          iconSize: 0.5,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ));
      }
      
      print('Added ${features.length} feature markers with emoji icons (${stupaFeatures.length} stupa, ${otherFeatures.length} other)');
    } catch (e) {
      print('Error adding feature markers: $e');
    }
  }

  Future<void> _addExternalFacilitiesMarkers() async {
    if (_mapboxMap == null) return;

    try {
      // Get facilities data
      final facilities = BorobudurFacilitiesData.getFacilities();
      
      // Group facilities by type for better organization
      final facilitiesByType = <String, List<TempleFeature>>{};
      for (final facility in facilities) {
        facilitiesByType.putIfAbsent(facility.type, () => []).add(facility);
      }
      
      print('🏢 Loading ${facilities.length} external facilities across ${facilitiesByType.keys.length} types');
      
      // Map facility types to Material Icons
      final Map<String, IconData> facilityIcons = {
        'museum': Icons.museum,
        'toilet': Icons.wc,
        'parking': Icons.local_parking,
        'restaurant': Icons.restaurant,
        'cafe': Icons.local_cafe,
        'shop': Icons.shopping_bag,
        'entrance': Icons.door_sliding,
        'ticket_booth': Icons.confirmation_number,
        'information': Icons.info,
        'medical': Icons.local_hospital,
        'prayer_room': Icons.mosque,
        'security': Icons.security,
        'atm': Icons.atm,
        'hotel': Icons.hotel,
      };
      
      // Load all facility icons
      for (final entry in facilityIcons.entries) {
        try {
          final iconData = await _iconToImage(entry.value, size: 24, color: Colors.white);
          if (iconData != null) {
            try {
              await _mapboxMap!.style.addStyleImage('icon-facility-${entry.key}', 1.0, MbxImage(width: 24, height: 24, data: iconData), false, [], [], null);
              print('✅ Loaded icon for ${entry.key}');
            } catch (e) {
              // Icon already exists
            }
          }
        } catch (e) {
          print('Error loading ${entry.key} icon: $e');
        }
      }
      
      // Create GeoJSON with icon property
      final facilitiesGeoJson = {
        'type': 'FeatureCollection',
        'features': facilities.map((facility) {
          final iconName = facilityIcons.containsKey(facility.type) ? 'icon-facility-${facility.type}' : 'icon-facility-information';
          return {
            'type': 'Feature',
            'id': facility.id,
            'geometry': {
              'type': 'Point',
              'coordinates': [facility.longitude, facility.latitude],
            },
            'properties': {
              'id': facility.id,
              'name': facility.name,
              'type': facility.type,
              'icon': iconName,
            },
          };
        }).toList(),
      };
      
      // Add source for facilities
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: 'external-facilities-source',
        data: json.encode(facilitiesGeoJson),
      ));
      
      // Add background circle layer
      await _mapboxMap!.style.addLayer(CircleLayer(
        id: 'external-facilities-circles',
        sourceId: 'external-facilities-source',
        circleRadius: 10.0,
        circleColor: 0xFF2196F3, // Blue for facilities
        circleOpacity: 1.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: 0xFFFFFFFF, // White border
        circleStrokeOpacity: 1.0,
        circlePitchAlignment: CirclePitchAlignment.VIEWPORT,
        circleSortKey: 997.0,
      ));
      
      // Add icon layer using property expression
      await _mapboxMap!.style.addLayer(SymbolLayer(
        id: 'external-facilities-symbols',
        sourceId: 'external-facilities-source',
        iconImage: '{icon}',
        iconSize: 0.5,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ));
      
      print('✅ Added ${facilities.length} external facility markers with Material Icons');
      
      // Log facilities by type
      facilitiesByType.forEach((type, list) {
        print('   - $type: ${list.length} locations');
      });
      
    } catch (e) {
      print('Error adding external facilities markers: $e');
    }
  }

  Future<void> _addEdgeLines() async {
    if (_mapboxMap == null) return;

    try {
      // Get edges from navigation service
      final edges = _navigationService.edges;
      
      if (edges.isEmpty) {
        print('No edges loaded from API');
        return;
      }

      // Create GeoJSON LineString features for all edges
      final edgeFeatures = edges.map((edge) {
        // Get source and target nodes
        final sourceNode = _navigationService.nodes[edge.sourceId];
        final targetNode = _navigationService.nodes[edge.targetId];
        
        if (sourceNode == null || targetNode == null) {
          return null;
        }

        return '''
        {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": [
              [${sourceNode.longitude}, ${sourceNode.latitude}],
              [${targetNode.longitude}, ${targetNode.latitude}]
            ]
          },
          "properties": {
            "id": ${edge.id},
            "source": ${edge.sourceId},
            "target": ${edge.targetId}
          }
        }
        ''';
      }).where((feature) => feature != null).join(',');

      final edgesGeoJson = '''
      {
        "type": "FeatureCollection",
        "features": [$edgeFeatures]
      }
      ''';

      // Add source for edges
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: 'temple-edges-source',
        data: edgesGeoJson,
      ));

      // Add line layer for edges (like bolobudur-app)
      await _mapboxMap!.style.addLayer(LineLayer(
        id: 'temple-edges-layer',
        sourceId: 'temple-edges-source',
        lineColor: 0xFFBDBDBD, // Light gray color
        lineWidth: 2.0,
        lineOpacity: 0.6,
      ));

      print('✅ Added ${edges.length} edge lines to map');
      
    } catch (e) {
      print('Error adding edge lines: $e');
    }
  }

  void _setupMapInteractions() {
    if (_mapboxMap == null) return;

    print('Map interactions setup completed');
  }

  // Handle map tap to detect marker clicks
  Future<void> _onMapTappedFromContext(MapContentGestureContext context) async {
    if (_mapboxMap == null) return;
    final point = context.point;
    final coordinates = point.coordinates;
    
    print('Map tapped at: ${coordinates.lat}, ${coordinates.lng}');
    
    // Handle custom location selection (tap anywhere on map)
    if (_isSelectingStartLocation) {
      setState(() {
        _customStartLocation = geo.Position(
          latitude: coordinates.lat.toDouble(),
          longitude: coordinates.lng.toDouble(),
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        _isSelectingStartLocation = false;
        _locationMode = LocationMode.customLocation;
      });
      
      await _addCustomLocationMarker(
        coordinates.lat.toDouble(),
        coordinates.lng.toDouble(),
      );
      
      _showMessage('Lokasi awal dipilih', AppColors.primary);
      return;
    }
    
    // Handle node selection (tap on node marker)
    if (_isSelectingNodeFromMap) {
      final screenCoordinate = await _mapboxMap!.pixelForCoordinate(point);
      
      try {
        final features = await _mapboxMap!.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
          RenderedQueryOptions(
            layerIds: [
              ..._levelsWithMarkers.map((level) => 'nodes-symbols-$level'),
            ],
          ),
        );
        
        if (features.isNotEmpty) {
          final feature = features.first;
          
          if (feature != null) {
            final featureData = feature.queriedFeature.feature;
            final properties = featureData['properties'];
            
            if (properties != null && properties is Map) {
              final nodeId = properties['id'];
              final node = _navigationService.nodes[nodeId];
              
              if (node != null) {
                setState(() {
                  _customStartLocation = geo.Position(
                    latitude: node.latitude,
                    longitude: node.longitude,
                    timestamp: DateTime.now(),
                    accuracy: 0,
                    altitude: 0,
                    heading: 0,
                    speed: 0,
                    speedAccuracy: 0,
                    altitudeAccuracy: 0,
                    headingAccuracy: 0,
                  );
                  _isSelectingNodeFromMap = false;
                  _locationMode = LocationMode.customLocation;
                });
                
                await _addCustomLocationMarker(node.latitude, node.longitude);
                _showMessage('Lokasi awal dipilih: ${node.name}', AppColors.primary);
                return;
              }
            }
          }
        }
        
        // If no node was tapped, show message
        _showMessage('Tap pada node (marker) untuk memilih lokasi awal', Colors.orange);
      } catch (e) {
        print('Error querying features for node selection: $e');
      }
      return;
    }
    
    // Normal tap handling (show node/feature info)
    await _handleFeatureTap(point);
  }

  // New method to handle normal feature taps
  Future<void> _handleFeatureTap(Point tappedPoint) async {
    if (_mapboxMap == null) return;

    // Query rendered features at tap location using screen coordinate
    try {
      // Convert the tapped geographical point to screen coordinate
      final screenCoord = await _mapboxMap!.pixelForCoordinate(tappedPoint);
      
      print('Screen coordinate: x=${screenCoord.x}, y=${screenCoord.y}');
      
      // Query features at the exact screen coordinate
      // Include all layers: node circles+symbols, feature circles+symbols, facility circles+symbols
      final layerIds = [
        ..._levelsWithMarkers.map((level) => 'nodes-circles-$level'),
        ..._levelsWithMarkers.map((level) => 'nodes-symbols-$level'),
        'features-stupa-circles',
        'features-stupa-symbols',
        'features-other-circles',
        'features-other-symbols',
        'external-facilities-circles',
        'external-facilities-symbols',
      ];
      print('Querying layers: $layerIds');
      
      final features = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoord),
        RenderedQueryOptions(
          layerIds: layerIds,
        ),
      );
      
      print('Found ${features.length} features at tap location');
      
      if (features.isNotEmpty) {
        // Get the first (topmost) feature
        final feature = features.first;
        
        if (feature != null) {
          final featureData = feature.queriedFeature.feature;
          final source = feature.queriedFeature.source;
          print('Feature data: $featureData');
          print('Source: $source');
          
          if (featureData['properties'] != null) {
            final properties = featureData['properties'] as Map;
            print('Properties: $properties');
            final id = properties['id'];
            final type = properties['type'];
            
            if (id != null) {
              // Check source or type to determine if it's a feature, node, or external facility
              print('Checking: source=$source, type=$type');
              
              // Check if it's an external facility
              if (source == 'external-facilities-source') {
                print('Determined as EXTERNAL FACILITY marker');
                // Find facility in dummy data
                final facilities = BorobudurFacilitiesData.getFacilities();
                final facility = facilities.firstWhere(
                  (f) => f.id == id,
                  orElse: () => TempleFeature(
                    id: id,
                    name: properties['name'] ?? 'Unknown Facility',
                    type: properties['type'] ?? 'facility',
                    latitude: 0,
                    longitude: 0,
                    description: properties['description'],
                  ),
                );
                print('Opening bottom sheet for facility: ${facility.name} (ID: $id)');
                _showFacilityInfoBottomSheet(facility);
                return;
              }
              
              print('Is feature source? ${source == 'features-stupa-source' || source == 'features-other-source'}');
              print('Type check: type != NODE? ${type != null && type != 'NODE'}');
              
              if (source == 'features-stupa-source' || source == 'features-other-source' || 
                  (type != null && type != 'NODE')) {
                // It's a feature marker
                print('Determined as FEATURE marker');
                try {
                  final templeFeature = _navigationService.features.firstWhere(
                    (f) => f.id == id,
                    orElse: () => throw Exception('Feature not found'),
                  );
                  print('Opening bottom sheet for feature: ${templeFeature.name} (ID: $id)');
                  _showFeatureInfoBottomSheet(templeFeature);
                  return;
                } catch (e) {
                  print('Feature not found in service for ID: $id, error: $e');
                }
              } else {
                // It's a node marker (type == 'NODE' or from node source)
                print('Determined as NODE marker');
                final node = _navigationService.nodes[id];
                if (node != null) {
                  print('Opening bottom sheet for node: ${node.name} (ID: $id)');
                  _showNodeInfoBottomSheet(node);
                  return;
                } else {
                  print('Node not found in service for ID: $id');
                }
              }
            } else {
              print('No ID in properties');
            }
          } else {
            print('No properties in feature');
          }
        }
      } else {
        print('No features found at tap location');
      }
    } catch (e) {
      print('Error querying features: $e');
    }
  }

  // Show bottom sheet with node info and navigation button
  void _showNodeInfoBottomSheet(TempleNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Node name
                  Text(
                    node.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Node details
                  _buildInfoRow(
                    Icons.layers,
                    'Level',
                    'Lantai ${node.level}',
                  ),
                  const SizedBox(height: 8),
                  
                  _buildInfoRow(
                    Icons.category,
                    'Type',
                    node.type,
                  ),
                  const SizedBox(height: 8),
                  
                  _buildInfoRow(
                    Icons.location_on,
                    'Coordinates',
                    '${node.latitude.toStringAsFixed(6)}, ${node.longitude.toStringAsFixed(6)}',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Navigation button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _startNavigationToNode(node);
                      },
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: const Text(
                        'Navigasi ke Sini',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // Show bottom sheet with feature info
  void _showFeatureInfoBottomSheet(dynamic feature) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Feature name
                  Text(
                    feature.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Feature info rows
                  _buildInfoRow(
                    Icons.category,
                    'Type',
                    feature.type,
                  ),
                  const SizedBox(height: 8),
                  
                  _buildInfoRow(
                    Icons.location_on,
                    'Coordinates',
                    '${feature.latitude.toStringAsFixed(6)}, ${feature.longitude.toStringAsFixed(6)}',
                  ),
                  
                  if (feature.description != null && feature.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.info_outline,
                      'Description',
                      feature.description,
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Navigation button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _startNavigationToFeature(feature);
                      },
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: const Text(
                        'Navigasi ke Sini',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show facility info bottom sheet (for external facilities like toilet, museum, etc)
  void _showFacilityInfoBottomSheet(TempleFeature facility) {
    final icon = BorobudurFacilitiesData.getIconForType(facility.type);
    final colorInt = BorobudurFacilitiesData.getColorForType(facility.type);
    final color = Color(colorInt);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Facility icon and name
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              facility.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                facility.type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Facility info
                  if (facility.description != null && facility.description!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              facility.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  _buildInfoRow(
                    Icons.location_on,
                    'Koordinat',
                    '${facility.latitude.toStringAsFixed(6)}, ${facility.longitude.toStringAsFixed(6)}',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Navigation button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _startNavigationToFeature(facility);
                      },
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: const Text(
                        'Navigasi ke Fasilitas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Start navigation to selected node
  void _startNavigationToNode(TempleNode node) {
    setState(() {
      destinationNode = node;
      destinationFeature = null;
      useCurrentLocation = true;
    });
    
    _showNavigationPreview();
  }

  // Start navigation to selected feature
  void _startNavigationToFeature(dynamic feature) {
    setState(() {
      destinationNode = null;
      destinationFeature = feature;
      useCurrentLocation = true;
    });
    
    _showNavigationPreview();
  }

  // Show navigation preview with distance, time, and route line
  Future<void> _showNavigationPreview() async {
    if (_mapboxMap == null) return;
    
    // Get current position based on mode
    geo.Position? currentPos;
    if (_locationMode == LocationMode.customLocation) {
      if (_customStartLocation == null) {
        _showMessage('Silakan pilih lokasi awal terlebih dahulu', Colors.orange);
        setState(() {
          _isSelectingStartLocation = true;
          _showLocationModePanel = false;
        });
        _showMessage('Tap pada peta untuk memilih lokasi awal', AppColors.primary);
        return;
      }
      currentPos = _customStartLocation;
      print('🗺️ Using CUSTOM start location: ${currentPos?.latitude}, ${currentPos?.longitude}');
    } else {
      currentPos = _currentPosition;
      print('🗺️ Using CURRENT GPS location: ${currentPos?.latitude}, ${currentPos?.longitude}');
      if (currentPos == null) {
        print('❌ Current position is NULL - GPS not ready');
        _showMessage('Menunggu sinyal GPS... Mohon tunggu sebentar', Colors.orange);
        
        // Try to wait a bit for GPS
        await Future.delayed(Duration(milliseconds: 500));
        currentPos = _currentPosition;
        
        if (currentPos == null) {
          _showMessage('Tidak dapat menemukan lokasi Anda. Pastikan GPS aktif.', Colors.red);
          return;
        }
      }
    }
    
    // Get destination coordinates
  double destLat, destLon;
  if (destinationNode != null) {
    destLat = destinationNode!.latitude;
    destLon = destinationNode!.longitude;
  } else if (destinationFeature != null) {
    destLat = destinationFeature!.latitude;
    destLon = destinationFeature!.longitude;
  } else {
    return;
  }
  
  if (currentPos == null) return;
  
  // Check if this is a multi-stage navigation scenario
  // (user outside temple, destination inside temple)
  final isUserOutside = !_isPointInsideBorobudurComplex(currentPos.latitude, currentPos.longitude);
  final isDestinationInside = _isPointInsideBorobudurComplex(destLat, destLon);
  final isDummyFacility = destinationFeature != null && destinationFeature!.id >= 101 && destinationFeature!.id <= 200;
  
  if (isUserOutside && isDestinationInside && !isDummyFacility) {
    // MULTI-STAGE NAVIGATION: Outside → Entrance → Inside
    print('🎯 MULTI-STAGE NAVIGATION DETECTED');
    print('   User is OUTSIDE temple, destination is INSIDE');
    print('   Stage 1: Navigate to Entrance Gate (ID: $ENTRANCE_GATE_ID)');
    print('   Stage 2: Navigate from $ENTRY_NODE_ID to final destination');
    
    // Save final destination
    _finalDestinationNode = destinationNode;
    _finalDestinationFeature = destinationFeature;
    _navigationStage = 1;
    
    // Get entrance gate feature
    final entranceGate = BorobudurFacilitiesData.getFacilities()
        .firstWhere((f) => f.id == ENTRANCE_GATE_ID);
    
    // Set entrance as current destination for Stage 1
    destinationFeature = entranceGate;
    destinationNode = null;
    destLat = entranceGate.latitude;
    destLon = entranceGate.longitude;
    
    print('   → Stage 1 destination set to: ${entranceGate.name}');
  } else {
    // Normal single-stage navigation
    _navigationStage = 0;
    _finalDestinationNode = null;
    _finalDestinationFeature = null;
  }
  
  // Try to get route data from Borobudur API ONLY if destination is inside Borobudur complex
  Map<String, dynamic>? routeData;
  
  // Check if destination is inside Borobudur complex
  final isDestinationInsideBorobudur = _isPointInsideBorobudurComplex(destLat, destLon);
  
  // isDummyFacility already declared above at line 2193
  
  if (isDestinationInsideBorobudur && !isDummyFacility) {
    // Destination is inside Borobudur AND not a dummy facility - try backend API
    if (destinationNode != null) {
      print('🎯 Destination NODE inside Borobudur: ${destinationNode!.name} (ID: ${destinationNode!.id})');
      print('   Fetching route from Borobudur Backend API...');
      routeData = await _fetchBorobudurRoute(
        currentPos.latitude,
        currentPos.longitude,
        destinationNode!.id,
      );
    } else if (destinationFeature != null) {
      print('🎯 Destination FEATURE inside Borobudur: ${destinationFeature!.name} (ID: ${destinationFeature!.id})');
      print('   Fetching route from Borobudur Backend API...');
      routeData = await _fetchBorobudurRoute(
        currentPos.latitude,
        currentPos.longitude,
        destinationFeature!.id,
      );
    }
  } else {
    // Destination is OUTSIDE Borobudur OR is a dummy facility - skip backend API, use Mapbox directly
    if (isDummyFacility) {
      print('🗺️ Destination is DUMMY FACILITY (ID: ${destinationFeature!.id})');
      print('   Skipping Backend API, using Mapbox Directions for dummy facilities');
    } else {
      print('🗺️ Destination is OUTSIDE Borobudur complex');
      print('   Using Mapbox Directions API for routing');
    }
  }
  
  double distance;
  int durationSeconds;
    
    // Use Borobudur API data if available, otherwise calculate
    if (routeData != null && routeData['properties'] != null) {
      final props = routeData['properties'];
      distance = (props['distance_m'] ?? 0).toDouble();
      durationSeconds = (props['duration_s'] ?? 0).toInt();
      print('Using Borobudur API metrics: ${distance}m, ${durationSeconds}s');
    } else {
      // Calculate straight-line distance (haversine formula)
      distance = _calculateDistance(
        currentPos.latitude,
        currentPos.longitude,
        destLat,
        destLon,
      );
      
      // Estimate walking time (average walking speed: 1.4 m/s or 5 km/h)
      final walkingSpeedMps = 1.4; // meters per second
      durationSeconds = (distance / walkingSpeedMps).round();
      print('Using calculated metrics: ${distance}m, ${durationSeconds}s');
    }
    
    setState(() {
      previewDistance = distance;
      previewDuration = durationSeconds;
      showNavigationPreview = true;
    });
    
    // Draw route line on map (pass targetNode if destination is a node, targetFeature if destination is a feature)
  await _drawRouteLine(
    currentPos.latitude,
    currentPos.longitude,
    destLat,
    destLon,
    targetNode: destinationNode,
    targetFeature: destinationFeature,
  );
  
  // If multi-stage navigation, also draw Stage 2 route preview
  if (_navigationStage == 1 && (_finalDestinationNode != null || _finalDestinationFeature != null)) {
    print('📍 Drawing Stage 2 route preview...');
    print('   Final destination: ${_finalDestinationNode?.name ?? _finalDestinationFeature?.name}');
    
    // Get entry node location
    final entryNode = _navigationService.nodes[ENTRY_NODE_ID];
    print('   Entry node ($ENTRY_NODE_ID): ${entryNode != null ? "FOUND" : "NOT FOUND"}');
    
    if (entryNode != null) {
      print('   Entry node location: (${entryNode.latitude}, ${entryNode.longitude})');
      
      // Get final destination coordinates
      double finalLat, finalLon;
      if (_finalDestinationNode != null) {
        finalLat = _finalDestinationNode!.latitude;
        finalLon = _finalDestinationNode!.longitude;
        print('   Final destination (Node): ($finalLat, $finalLon)');
      } else {
        finalLat = _finalDestinationFeature!.latitude;
        finalLon = _finalDestinationFeature!.longitude;
        print('   Final destination (Feature): ($finalLat, $finalLon)');
      }
      
      await _drawStage2RoutePreview(
        entryNode.latitude,
        entryNode.longitude,
        finalLat,
        finalLon,
        targetNode: _finalDestinationNode,
        targetFeature: _finalDestinationFeature,
      );
    } else {
      print('   ❌ Cannot draw Stage 2 route: Entry node not found');
    }
  }
  
  // Adjust camera to show entire route
  await _fitCameraToRoute(
    currentPos.latitude,
    currentPos.longitude,
    destLat,
    destLon,
  );
}

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // Find nearest node from a given position
  TempleNode? _findNearestNode(double lat, double lon, {int? preferredLevel}) {
    if (_navigationService.nodes.isEmpty) {
      print('No nodes available to find nearest');
      return null;
    }
    
    TempleNode? nearestNode;
    double minDistance = double.infinity;
    
    // First try: find nearest node from preferred level if specified
    if (preferredLevel != null) {
      for (final node in _navigationService.nodes.values) {
        if (node.level == preferredLevel) {
          final distance = _calculateDistance(lat, lon, node.latitude, node.longitude);
          if (distance < minDistance) {
            minDistance = distance;
            nearestNode = node;
          }
        }
      }
      
      if (nearestNode != null) {
        print('Nearest node (level $preferredLevel): ${nearestNode.name} (ID: ${nearestNode.id}) at ${minDistance.toStringAsFixed(2)}m away');
        return nearestNode;
      }
    }
    
    // Second try: find any nearest node
    minDistance = double.infinity;
    for (final node in _navigationService.nodes.values) {
      final distance = _calculateDistance(lat, lon, node.latitude, node.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        nearestNode = node;
      }
    }
    
    if (nearestNode != null) {
      print('Nearest node (any level): ${nearestNode.name} (ID: ${nearestNode.id}) at ${minDistance.toStringAsFixed(2)}m away');
    }
    
    return nearestNode;
  }

  // Find multiple nearest nodes for fallback attempts
  List<TempleNode> _findNearestNodes(double lat, double lon, {int count = 5, int? preferredLevel}) {
    if (_navigationService.nodes.isEmpty) {
      return [];
    }
    
    // Calculate distances for all nodes, excluding TANGGA nodes (stairs are often isolated)
    final nodesWithDistance = <MapEntry<TempleNode, double>>[];
    
    for (final node in _navigationService.nodes.values) {
      // Skip TANGGA nodes as they might be isolated from the main graph
      if (node.name.contains('TANGGA')) {
        continue;
      }
      
      final distance = _calculateDistance(lat, lon, node.latitude, node.longitude);
      nodesWithDistance.add(MapEntry(node, distance));
    }
    
    if (nodesWithDistance.isEmpty) {
      print('⚠️ No non-TANGGA nodes found, trying all nodes including TANGGA');
      // Fallback: include TANGGA nodes if no other nodes available
      for (final node in _navigationService.nodes.values) {
        final distance = _calculateDistance(lat, lon, node.latitude, node.longitude);
        nodesWithDistance.add(MapEntry(node, distance));
      }
    }
    
    // Sort by distance
    nodesWithDistance.sort((a, b) => a.value.compareTo(b.value));
    
    // Prefer nodes from the same level
    if (preferredLevel != null) {
      final sameLevelNodes = nodesWithDistance
          .where((entry) => entry.key.level == preferredLevel)
          .take(count)
          .toList();
      
      if (sameLevelNodes.isNotEmpty) {
        print('Found ${sameLevelNodes.length} nearest non-TANGGA nodes from level $preferredLevel');
        return sameLevelNodes.map((e) => e.key).toList();
      }
    }
    
    // Return closest nodes regardless of level
    print('Found ${nodesWithDistance.take(count).length} nearest non-TANGGA nodes');
    return nodesWithDistance.take(count).map((e) => e.key).toList();
  }

  // Fetch route from Borobudur Backend API (for on-temple navigation)
  // Now with smart snap-to-nearest-node feature
  Future<Map<String, dynamic>?> _fetchBorobudurRoute(
    double startLat, 
    double startLon, 
    int toNodeId,
  ) async {
    const baseUrl = 'https://borobudurbackend.context.my.id/v1/temples/navigation/route';
    const profile = 'walking';

    try {
      // Get destination node info
      final destinationNode = _navigationService.nodes[toNodeId];
      final destinationLevel = destinationNode?.level;
      
      print('=== Borobudur Route Request ===');
      print('From: ($startLat, $startLon)');
      print('To: Node $toNodeId${destinationNode != null ? ' (${destinationNode.name}, Level $destinationLevel)' : ''}');
      
      // Attempt 1: Try direct routing from position
      var url = Uri.parse('$baseUrl?fromLat=$startLat&fromLon=$startLon&toNodeId=$toNodeId&profile=$profile');
      print('\n--- Attempt 1: Direct routing ---');
      print('URL: $url');
      
      var response = await http.get(url);
      print('Status: ${response.statusCode}');
      print('Body: ${response.body.substring(0, math.min(200, response.body.length))}...');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          // Check if data contains error (no path found)
          if (data['data']['error'] != null) {
            print('❌ Borobudur API Error: ${data['data']['error']}');
            print('Will try nearest nodes or fallback to Mapbox');
          } else if (data['data']['features'] != null && 
              (data['data']['features'] as List).isNotEmpty) {
            print('✅ SUCCESS: Using Borobudur Backend API for routing!');
            final feature = data['data']['features'][0];
            if (feature['properties'] != null) {
              print('📊 Route metrics:');
              print('   Distance: ${feature['properties']['distance_m']} m');
              print('   Duration: ${feature['properties']['duration_s']} s');
            }
            return feature;
          }
        }
      }

      // Attempt 2-6: Try multiple nearest nodes
      print('\n--- Attempt 2-6: Routing via nearest nodes ---');
      final nearestNodes = _findNearestNodes(startLat, startLon, count: 5, preferredLevel: destinationLevel);
      
      if (nearestNodes.isEmpty) {
        print('❌ No nearest nodes found');
        return null;
      }
      
      print('Found ${nearestNodes.length} candidate nodes to try');
      
      for (int i = 0; i < nearestNodes.length; i++) {
        final node = nearestNodes[i];
        final distance = _calculateDistance(startLat, startLon, node.latitude, node.longitude);
        
        print('\n--- Attempt ${i + 2}: Via ${node.name} ---');
        print('Node: ID ${node.id}, Level ${node.level}, ${distance.toStringAsFixed(2)}m away');
        print('Coordinates: (${node.latitude}, ${node.longitude})');
        
        url = Uri.parse('$baseUrl?fromLat=${node.latitude}&fromLon=${node.longitude}&toNodeId=$toNodeId&profile=$profile');
        print('URL: $url');
        
        response = await http.get(url);
        print('Status: ${response.statusCode}');
        print('Body: ${response.body.substring(0, math.min(200, response.body.length))}...');

        if (response.statusCode == 200) {
          final snapData = json.decode(response.body);
          if (snapData['status'] == 'success' && 
              snapData['data'] != null &&
              snapData['data']['error'] == null &&
              snapData['data']['features'] != null &&
              (snapData['data']['features'] as List).isNotEmpty) {
            
            print('✅ Success! Route found via ${node.name}');
            final feature = snapData['data']['features'][0];
            
            // Add start segment: user position → nearest node
            final startSegmentDistance = distance;
            
            // Prepend coordinates from user position to nearest node
            final originalCoords = feature['geometry']['coordinates'] as List;
            final newCoords = [
              [startLon, startLat], // User position first
              ...originalCoords, // Then route from nearest node to destination
            ];
            
            // Update geometry with new coordinates
            feature['geometry']['coordinates'] = newCoords;
            
            // Update distance and duration
            if (feature['properties'] != null) {
              final originalDistance = (feature['properties']['distance_m'] ?? 0).toDouble();
              final totalDistance = originalDistance + startSegmentDistance;
              final originalDuration = (feature['properties']['duration_s'] ?? 0).toInt();
              final walkingSpeed = 1.4; // m/s
              final startSegmentDuration = (startSegmentDistance / walkingSpeed).round();
              final totalDuration = originalDuration + startSegmentDuration;
              
              feature['properties']['distance_m'] = totalDistance;
              feature['properties']['duration_s'] = totalDuration;
              feature['properties']['snapped_to_node'] = node.name;
              feature['properties']['snap_distance_m'] = startSegmentDistance;
              
              print('Total distance: ${totalDistance.toStringAsFixed(2)}m (snap: ${startSegmentDistance.toStringAsFixed(2)}m + route: ${originalDistance.toStringAsFixed(2)}m)');
              print('Total duration: ${totalDuration}s');
            }
            
            return feature;
          } else {
            print('❌ Error: ${snapData['data']?['error'] ?? 'No route found'}');
            // Continue to next node
          }
        }
      }

      print('\n❌ All ${nearestNodes.length + 1} attempts failed');
      return null;
    } catch (e) {
      print('💥 Exception: $e');
      return null;
    }
  }

  // Fetch route from Mapbox Directions API (for general navigation)
  Future<Map<String, dynamic>?> _fetchDirectionsRoute(
    double startLat, 
    double startLon, 
    double endLat, 
    double endLon
  ) async {
    try {
      // Mapbox Directions API endpoint for walking
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/walking/'
        '$startLon,$startLat;$endLon,$endLat'
        '?geometries=geojson'
        '&overview=full'
        '&steps=true'
        '&access_token=${MapConfig.mapboxAccessToken}'
      );
      
      print('Fetching route from Mapbox Directions API...');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          print('Mapbox route fetched successfully!');
          return data['routes'][0];
        }
      } else {
        print('Directions API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }
    return null;
  }

  // Draw route line on map with traffic styling
  Future<void> _drawRouteLine(
    double startLat, 
    double startLon, 
    double endLat, 
    double endLon, {
    TempleNode? targetNode,
    TempleFeature? targetFeature,
  }) async {
    if (_mapboxMap == null) return;
    
    try {
      // Remove existing route layer if any
      try {
        await _mapboxMap!.style.removeStyleLayer('route-layer');
        await _mapboxMap!.style.removeStyleLayer('route-layer-casing');
        await _mapboxMap!.style.removeStyleSource('route-source');
        // Also remove dashed segments if exists
        await _mapboxMap!.style.removeStyleLayer('dashed-segment-layer');
        await _mapboxMap!.style.removeStyleSource('dashed-segment-source');
        await _mapboxMap!.style.removeStyleLayer('start-dashed-segment-layer');
        await _mapboxMap!.style.removeStyleSource('start-dashed-segment-source');
      } catch (e) {
        // Layer doesn't exist, ignore
      }
      
      Map<String, dynamic>? route;
      String routeSource = 'unknown';
      
      // Check if destination is inside Borobudur complex
      final isDestinationInsideBorobudur = _isPointInsideBorobudurComplex(endLat, endLon);
      
      // Check if destination is a dummy facility (ID 101-200)
      final isDummyFacility = targetFeature != null && targetFeature.id >= 101 && targetFeature.id <= 200;
      
      // Try Borobudur Backend API ONLY if destination is inside Borobudur complex AND not a dummy facility
      if (isDestinationInsideBorobudur && !isDummyFacility) {
        if (targetNode != null) {
          print('🗺️ Destination NODE inside Borobudur: ${targetNode.name}');
          print('   Attempting to fetch route from Borobudur Backend API...');
          final borobudurRoute = await _fetchBorobudurRoute(startLat, startLon, targetNode.id);
          
          if (borobudurRoute != null && borobudurRoute['geometry'] != null) {
            route = borobudurRoute;
            routeSource = 'Borobudur Backend';
            
            // Extract distance and duration from Borobudur API response
            if (borobudurRoute['properties'] != null) {
              final props = borobudurRoute['properties'];
              if (props['distance_m'] != null) {
                print('Borobudur API distance: ${props['distance_m']} m');
              }
              if (props['duration_s'] != null) {
                print('Borobudur API duration: ${props['duration_s']} s');
              }
            }
          }
        } else if (targetFeature != null) {
          print('🗺️ Destination FEATURE inside Borobudur: ${targetFeature.name}');
          print('   Attempting to fetch route from Borobudur Backend API...');
          final borobudurRoute = await _fetchBorobudurRoute(startLat, startLon, targetFeature.id);
          
          if (borobudurRoute != null && borobudurRoute['geometry'] != null) {
            route = borobudurRoute;
            routeSource = 'Borobudur Backend';
            
            // Extract distance and duration from Borobudur API response
            if (borobudurRoute['properties'] != null) {
              final props = borobudurRoute['properties'];
              if (props['distance_m'] != null) {
                print('Borobudur API distance: ${props['distance_m']} m');
              }
              if (props['duration_s'] != null) {
                print('Borobudur API duration: ${props['duration_s']} s');
              }
            }
          }
        }
      } else {
        if (isDummyFacility) {
          print('🗺️ Destination is DUMMY FACILITY (ID: ${targetFeature!.id})');
          print('   Skipping Backend API, using Mapbox Directions');
        } else {
          print('🗺️ Destination is OUTSIDE Borobudur complex');
          print('   Skipping Borobudur Backend API, will use Mapbox Directions');
        }
      }
      
      // Fallback to Mapbox Directions API if Borobudur API fails or not a node/feature
      if (route == null) {
        print('Falling back to Mapbox Directions API...');
        route = await _fetchDirectionsRoute(startLat, startLon, endLat, endLon);
        if (route != null && route['geometry'] != null) {
          routeSource = 'Mapbox Directions';
        }
      }
      
      // Check if start and destination are inside Borobudur complex
      final isStartInsideBorobudur = _isPointInsideBorobudurComplex(startLat, startLon);
      // isDestinationInsideBorobudur already declared above at line 2568
      
      // Determine if we need hybrid routing
      // Hybrid routing is needed when using Mapbox (not Borobudur backend) and either start or end is inside complex
      final needsHybridRoute = routeSource == 'Mapbox Directions' && (isStartInsideBorobudur || isDestinationInsideBorobudur);
      
      Map<String, dynamic> routeGeoJson;
      Map<String, dynamic>? dashedSegmentGeoJson;
      Map<String, dynamic>? startDashedSegmentGeoJson;
      bool isStraightLineFallback = false;
      
      if (route != null && route['geometry'] != null) {
        if (needsHybridRoute) {
          // HYBRID ROUTE: May have dashed lines at start and/or end
          final routeCoords = route['geometry']['coordinates'] as List;
          final firstRoadPoint = routeCoords.first as List;
          final firstRoadLon = firstRoadPoint[0];
          final firstRoadLat = firstRoadPoint[1];
          final lastRoadPoint = routeCoords.last as List;
          final lastRoadLon = lastRoadPoint[0];
          final lastRoadLat = lastRoadPoint[1];
          
          print('🔀 Creating HYBRID route:');
          if (isStartInsideBorobudur) {
            print('   1. Dashed line from start location to road (walking path)');
          }
          print('   ${isStartInsideBorobudur ? '2' : '1'}. Solid blue line following road (Mapbox)');
          if (isDestinationInsideBorobudur) {
            print('   ${isStartInsideBorobudur ? '3' : '2'}. Dashed line from road end to destination (walking path)');
          }
          
          // Start dashed segment (if start is inside complex)
          if (isStartInsideBorobudur) {
            startDashedSegmentGeoJson = {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [startLon, startLat],           // From actual start location
                  [firstRoadLon, firstRoadLat],   // To beginning of road
                ],
              },
              'properties': {
                'route-color': '#FF6B6B', // Red color for off-road segment
                'route-source': 'Walking Path (No Vehicle Access)',
              },
            };
            print('   Start location: ($startLat, $startLon)');
            print('   Road begins at: ($firstRoadLat, $firstRoadLon)');
          }
          
          // Solid route from Mapbox (road)
          routeGeoJson = {
            'type': 'Feature',
            'geometry': route['geometry'],
            'properties': {
              'route-color': '#3366FF', // Blue color for road route
              'route-source': routeSource,
            },
          };
          
          // End dashed segment (if destination is inside complex)
          if (isDestinationInsideBorobudur) {
            dashedSegmentGeoJson = {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [lastRoadLon, lastRoadLat], // From end of road
                  [endLon, endLat],            // To actual destination
                ],
              },
              'properties': {
                'route-color': '#FF6B6B', // Red color for off-road segment
                'route-source': 'Walking Path (No Vehicle Access)',
              },
            };
            print('   Road ends at: ($lastRoadLat, $lastRoadLon)');
            print('   Destination: ($endLat, $endLon)');
          }
          
          // Show notification
          String message = '';
          if (isStartInsideBorobudur && isDestinationInsideBorobudur) {
            message = 'Start dan tujuan di dalam area candi. Ikuti garis putus-putus (jalan kaki) ke jalan, lalu ikuti jalan.';
          } else if (isStartInsideBorobudur) {
            message = 'Start di dalam area candi. Ikuti garis putus-putus (jalan kaki) ke jalan terlebih dahulu.';
          } else if (isDestinationInsideBorobudur) {
            message = 'Tujuan di dalam area candi. Ikuti jalan, lalu jalan kaki (garis putus-putus).';
          }
          
          if (message.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.directions_walk, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange[700],
                duration: Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(bottom: 100, left: 16, right: 16),
              ),
            );
          }
          
        } else {
          // Normal route - all solid line
          routeGeoJson = {
            'type': 'Feature',
            'geometry': route['geometry'],
            'properties': {
              'route-color': '#3366FF', // Blue color for route
              'route-source': routeSource,
            },
          };
          print('Using $routeSource route with ${route['geometry']['coordinates'].length} points');
        }
      } else {
        // Complete API failure - straight line fallback
        print('All APIs failed - falling back to dashed straight line route');
        isStraightLineFallback = true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tidak ada jalan ditemukan. Menampilkan garis lurus ke tujuan.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange[700],
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 100, left: 16, right: 16),
          ),
        );
        
        routeGeoJson = {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [startLon, startLat],
              [endLon, endLat],
            ],
          },
          'properties': {
            'route-color': '#FF6B6B', // Red color for fallback route
            'route-source': 'Straight Line (Fallback)',
          },
        };
      }
      
      // Add source
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: 'route-source',
        data: json.encode(routeGeoJson),
      ));
      
      // Add casing layer (black border) - only for real routes
      if (!isStraightLineFallback) {
        await _mapboxMap!.style.addLayer(LineLayer(
          id: 'route-layer-casing',
          sourceId: 'route-source',
          lineColor: Colors.black.value,
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            12.0, 8.0,
            14.0, 10.0,
            16.0, 12.0,
            18.0, 14.0,
            20.0, 16.0,
          ],
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ));
      }
      
      // Add main route layer with traffic-style colors or dashed line for fallback
      if (isStraightLineFallback) {
        // Dashed line for fallback route (no road found)
        await _mapboxMap!.style.addLayer(LineLayer(
          id: 'route-layer',
          sourceId: 'route-source',
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            12.0, 4.0,
            14.0, 5.0,
            16.0, 6.0,
            18.0, 7.0,
            20.0, 8.0,
          ],
          lineColor: 0xFFFF6B6B, // Red color for no-route fallback
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.8,
          lineDasharray: [2.0, 2.0], // Dashed pattern: 2px line, 2px gap
        ));
        print('Route line drawn as DASHED (no road found - straight line fallback)');
      } else {
        // Solid line for real routes from API
        await _mapboxMap!.style.addLayer(LineLayer(
          id: 'route-layer',
          sourceId: 'route-source',
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            12.0, 5.0,
            14.0, 6.0,
            16.0, 7.0,
            18.0, 8.0,
            20.0, 10.0,
          ],
          lineColorExpression: [
            'interpolate',
            ['linear'],
            ['zoom'],
            10.0, 'rgb(51, 102, 255)', // Blue at low zoom
            14.0, [
              'coalesce',
              ['get', 'route-color'],
              'rgb(51, 102, 255)'
            ],
          ],
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.9,
        ));
        print('Route line drawn successfully with solid line (real route from API)');
      }
      
      // Add dashed segments for hybrid route (walking paths)
      // End dashed segment (destination to road)
      if (dashedSegmentGeoJson != null) {
        await _mapboxMap!.style.addSource(GeoJsonSource(
          id: 'dashed-segment-source',
          data: json.encode(dashedSegmentGeoJson),
        ));
        
        await _mapboxMap!.style.addLayer(LineLayer(
          id: 'dashed-segment-layer',
          sourceId: 'dashed-segment-source',
          lineWidth: 6.0,
          lineColor: 0xFFFF6B6B, // Red color for walking path
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.8,
          lineDasharray: [2.0, 2.0], // Dashed pattern
        ));
        print('✅ End dashed segment drawn (walking path from road to destination)');
      }
      
      // Start dashed segment (start location to road)
      if (startDashedSegmentGeoJson != null) {
        await _mapboxMap!.style.addSource(GeoJsonSource(
          id: 'start-dashed-segment-source',
          data: json.encode(startDashedSegmentGeoJson),
        ));
        
        await _mapboxMap!.style.addLayer(LineLayer(
          id: 'start-dashed-segment-layer',
          sourceId: 'start-dashed-segment-source',
          lineWidth: 6.0,
          lineColor: 0xFFFF6B6B, // Red color for walking path
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.8,
          lineDasharray: [2.0, 2.0], // Dashed pattern
        ));
        print('✅ Start dashed segment drawn (walking path from start to road)');
      }
      
    } catch (e) {
      print('Error drawing route line: $e');
    }
  }

  // Draw Stage 2 route preview (entrance to final destination)
  Future<void> _drawStage2RoutePreview(
    double startLat,
    double startLon,
    double endLat,
    double endLon, {
    TempleNode? targetNode,
    TempleFeature? targetFeature,
  }) async {
    if (_mapboxMap == null) return;
    
    try {
      // Remove existing Stage 2 preview layers if any
      try {
        await _mapboxMap!.style.removeStyleLayer('stage2-route-layer');
        await _mapboxMap!.style.removeStyleLayer('stage2-route-layer-casing');
        await _mapboxMap!.style.removeStyleSource('stage2-route-source');
      } catch (e) {
        // Layer doesn't exist, ignore
      }
      
      Map<String, dynamic>? route;
      
      // Try to get route from backend API for Stage 2
      if (targetNode != null) {
        print('🗺️ Fetching Stage 2 route for NODE: ${targetNode.name} (ID: ${targetNode.id})');
        print('   From: ($startLat, $startLon) To: ($endLat, $endLon)');
        route = await _fetchBorobudurRoute(startLat, startLon, targetNode.id);
        print('   Route fetched: ${route != null ? "SUCCESS" : "NULL"}');
        if (route != null) {
          print('   Route has geometry: ${route['geometry'] != null}');
        }
      } else if (targetFeature != null) {
        print('🗺️ Fetching Stage 2 route for FEATURE: ${targetFeature.name} (ID: ${targetFeature.id})');
        print('   From: ($startLat, $startLon) To: ($endLat, $endLon)');
        route = await _fetchBorobudurRoute(startLat, startLon, targetFeature.id);
        print('   Route fetched: ${route != null ? "SUCCESS" : "NULL"}');
        if (route != null) {
          print('   Route has geometry: ${route['geometry'] != null}');
        }
      }
      
      if (route == null || route['geometry'] == null) {
        print('⚠️ No Stage 2 route from backend, skipping preview');
        print('   Route is null: ${route == null}');
        if (route != null) {
          print('   Geometry is null: ${route['geometry'] == null}');
          print('   Route data: $route');
        }
        return;
      }
      
      // Create GeoJSON for Stage 2 route
      final routeGeoJson = {
        'type': 'Feature',
        'geometry': route['geometry'],
        'properties': {
          'route-color': '#4CAF50', // Green color for Stage 2
          'route-source': 'Stage 2 Preview',
        },
      };
      
      // Add source
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: 'stage2-route-source',
        data: json.encode(routeGeoJson),
      ));
      
      // Add casing layer (black border)
      await _mapboxMap!.style.addLayer(LineLayer(
        id: 'stage2-route-layer-casing',
        sourceId: 'stage2-route-source',
        lineColor: Colors.black.value,
        lineWidth: 8.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ));
      
      // Add main route layer (green, semi-transparent)
      await _mapboxMap!.style.addLayer(LineLayer(
        id: 'stage2-route-layer',
        sourceId: 'stage2-route-source',
        lineColor: 0xFF4CAF50, // Green
        lineWidth: 6.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineOpacity: 0.7, // Semi-transparent to distinguish from Stage 1
      ));
      
      print('✅ Stage 2 route preview drawn (green line)');
      
    } catch (e) {
      print('Error drawing Stage 2 route preview: $e');
    }
  }

  // Fit camera to show entire route
  Future<void> _fitCameraToRoute(double startLat, double startLon, double endLat, double endLon) async {
    if (_mapboxMap == null) return;
    
    try {
      // Calculate bounds
      final minLat = math.min(startLat, endLat);
      final maxLat = math.max(startLat, endLat);
      final minLon = math.min(startLon, endLon);
      final maxLon = math.max(startLon, endLon);
      
      // Add padding
      final padding = 0.001; // ~111 meters
      
      // Calculate center
      final centerLat = (minLat + maxLat) / 2;
      final centerLon = (minLon + maxLon) / 2;
      
      // Calculate appropriate zoom level
      final latDiff = maxLat - minLat + (padding * 2);
      final lonDiff = maxLon - minLon + (padding * 2);
      final maxDiff = math.max(latDiff, lonDiff);
      
      double zoom = 18.0;
      if (maxDiff > 0.01) zoom = 15.0;
      else if (maxDiff > 0.005) zoom = 16.0;
      else if (maxDiff > 0.002) zoom = 17.0;
      
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(centerLon, centerLat)),
          zoom: zoom,
          pitch: 45.0,
          bearing: cameraBearing,
        ),
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );
    } catch (e) {
      print('Error fitting camera: $e');
    }
  }

  // Add marker for custom start location
  Future<void> _addCustomLocationMarker(double lat, double lon) async {
    if (_mapboxMap == null) return;
    
    try {
      // Remove existing custom location marker if any
      try {
        await _mapboxMap!.style.removeStyleLayer('custom-location-layer');
        await _mapboxMap!.style.removeStyleSource('custom-location-source');
      } catch (e) {
        // Layer doesn't exist, ignore
      }
      
      // Create GeoJSON point (2D mode - no altitude)
      final markerGeoJson = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [lon, lat], // 2D coordinates
        },
        'properties': {},
      };
      
      // Add source
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: 'custom-location-source',
        data: json.encode(markerGeoJson),
      ));
      
      // Add circle layer with improved styling
      await _mapboxMap!.style.addLayer(CircleLayer(
        id: 'custom-location-layer',
        sourceId: 'custom-location-source',
        circleRadius: 12.0, // Smaller radius
        circleColor: 0xFF4CAF50, // Vibrant green
        circleStrokeWidth: 3.0, // Thinner stroke
        circleStrokeColor: 0xFFFFFFFF, // White border
        circleOpacity: 0.9, // Slight transparency
        circlePitchAlignment: CirclePitchAlignment.VIEWPORT, // 2D mode
        circleSortKey: 1000.0, // Highest priority, above all other markers
      ));
      
      print('Custom location marker added at: $lat, $lon');
    } catch (e) {
      print('Error adding custom location marker: $e');
    }
  }

  // Cancel navigation preview
  void _cancelNavigationPreview() {
    setState(() {
      showNavigationPreview = false;
      destinationNode = null;
      destinationFeature = null;
      previewDistance = null;
      previewDuration = null;
    });
    
    // Remove route line
    _removeRouteLine();
  }

  // Remove route line from map
  Future<void> _removeRouteLine() async {
    if (_mapboxMap == null) return;
    
    try {
      await _mapboxMap!.style.removeStyleLayer('route-layer');
      await _mapboxMap!.style.removeStyleLayer('route-layer-casing');
      await _mapboxMap!.style.removeStyleSource('route-source');
      // Also remove dashed segment if exists
      await _mapboxMap!.style.removeStyleLayer('dashed-segment-layer');
      await _mapboxMap!.style.removeStyleSource('dashed-segment-source');
    } catch (e) {
      // Layer doesn't exist, ignore
    }
  }

  Future<void> _updateUserLocationOnMap(geo.Position position) async {
    if (_mapboxMap == null) return;

    try {
      // Update camera to follow user during navigation
      if (isNavigating) {
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(position.longitude, position.latitude)),
            zoom: 19.0, // Closer zoom for navigation
            bearing: position.heading, // Follow user's heading
            pitch: 60.0, // 3D perspective
          ),
          MapAnimationOptions(duration: 800, startDelay: 0),
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

  Future<void> _updateMarkersVisibility() async {
    if (_mapboxMap == null) return;

    try {
      // BOLOBUDUR-APP STYLE: Show all markers at full opacity at all times
      // No level-based filtering - all markers are always visible
      
      for (final level in _levelsWithMarkers) {
        final circleLayerId = 'nodes-circles-$level';
        
        try {
          // All markers always visible with full opacity
          await _mapboxMap!.style.setStyleLayerProperty(
            circleLayerId,
            'visibility',
            'visible',
          );
          
          await _mapboxMap!.style.setStyleLayerProperty(
            circleLayerId,
            'circle-opacity',
            1.0, // Full opacity for all markers
          );
        } catch (e) {
          // Layer might not exist yet
          debugPrint('Could not update markers for level $level: $e');
        }
      }
    } catch (e) {
      debugPrint('Error updating markers visibility: $e');
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.red),
            SizedBox(width: 8),
            Text('Izin Lokasi Diperlukan'),
          ],
        ),
        content: Text(
          'Aplikasi memerlukan akses lokasi untuk:\n'
          '• Menampilkan posisi Anda di peta\n'
          '• Memberikan navigasi real-time\n'
          '• Mendeteksi level/lantai Anda\n\n'
          'Silakan berikan izin akses lokasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Request permission
              final permission = await geo.Geolocator.requestPermission();
              print('Permission request result: $permission');
              
              if (permission == geo.LocationPermission.always || 
                  permission == geo.LocationPermission.whileInUse) {
                print('✅ Permission granted, initializing location tracking...');
                setState(() {
                  _hasLocationPermission = true;
                });
                await _initializeLocationTracking();
                _showMessage('Izin lokasi diberikan', AppColors.primary);
              } else {
                print('❌ Permission denied');
                _showMessage('Izin lokasi ditolak. Fitur navigasi tidak tersedia.', Colors.red);
              }
            },
            child: Text('Berikan Izin'),
          ),
        ],
      ),
    );
  }

  Future<void> _startNavigation() async {
    if (destinationNode == null && destinationFeature == null) {
      _showMessage('navigation_detail.select_destination'.tr(), Colors.orange);
      return;
    }

    print('🚀 Starting navigation...');
    print('Location mode: $_locationMode');
    print('Use current location: $useCurrentLocation');
    print('Current position: $_currentPosition');
    print('Custom start location: $_customStartLocation');

    if (useCurrentLocation) {
      if (_currentPosition == null) {
        print('❌ Current position is null!');
        print('Position subscription active: ${_positionSubscription != null}');
        print('Has location permission: $_hasLocationPermission');
        
        // Try to get current position immediately
        try {
          final position = await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          );
          setState(() {
            _currentPosition = position;
          });
          print('✅ Got current position: ${position.latitude}, ${position.longitude}');
        } catch (e) {
          print('❌ Failed to get current position: $e');
          _showMessage('Tidak dapat mendapatkan lokasi GPS. Pastikan GPS aktif.', Colors.red);
          return;
        }
      }
    } else {
      if (startNode == null && startFeature == null) {
        _showMessage('navigation_detail.select_destination'.tr(), Colors.orange);
        return;
      }
    }

    setState(() {
      showNavigationPreview = false; // Hide preview
      isNavigating = true;
    });

    // Move camera to starting location
    await _moveCameraToStartLocation();

    _speakInstruction('Navigasi dimulai');
  }

  // Move camera to starting location (custom or current)
  Future<void> _moveCameraToStartLocation() async {
    if (_mapboxMap == null) return;

    try {
      geo.Position? startPos;
      
      // Determine starting position based on location mode
      if (_locationMode == LocationMode.customLocation && _customStartLocation != null) {
        startPos = _customStartLocation;
      } else if (_currentPosition != null) {
        startPos = _currentPosition;
      }

      if (startPos != null) {
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(startPos.longitude, startPos.latitude)),
            zoom: cameraZoom,
            bearing: cameraBearing,
            pitch: cameraPitch,
          ),
          MapAnimationOptions(duration: 1500, startDelay: 0),
        );
        print('Camera moved to start location: ${startPos.latitude}, ${startPos.longitude}');
      }
    } catch (e) {
      print('Error moving camera to start location: $e');
    }
  }

  Future<void> _stopNavigation() async {
    _navigationService.stopNavigation();
    
    // Remove route line when stopping navigation
    await _removeRouteLine();
    
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

  Widget _buildNavigationPreviewPanel() {
    String destinationName = destinationNode?.name ?? destinationFeature?.name ?? 'Unknown';
    String distanceText = previewDistance != null 
        ? '${previewDistance!.toStringAsFixed(0)} m'
        : '-- m';
    String durationText = previewDuration != null
        ? _formatDuration(previewDuration!)
        : '-- min';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.route, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pratinjau Navigasi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Destination
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.flag, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destinationName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Distance and Time
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.straighten, color: Colors.blue, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jarak',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.access_time, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        durationText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Waktu',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Walking mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_walk, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Mode Jalan Kaki',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Buttons
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _startNavigation,
                  icon: const Icon(Icons.navigation, color: Colors.white),
                  label: const Text(
                    'Mulai Navigasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _cancelNavigationPreview,
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey[400]!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds detik';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).round();
      return '$minutes menit';
    } else {
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).round();
      return '$hours jam $minutes menit';
    }
  }

  Widget _buildLocationModePanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Pilih Lokasi Awal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _showLocationModePanel = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Current Location option
          InkWell(
            onTap: () {
              setState(() {
                _locationMode = LocationMode.currentLocation;
                _customStartLocation = null;
                _showLocationModePanel = false;
              });
              // Remove custom location marker
              try {
                _mapboxMap?.style.removeStyleLayer('custom-location-layer');
                _mapboxMap?.style.removeStyleSource('custom-location-source');
              } catch (e) {
                // Ignore
              }
              _showMessage('Mode: Lokasi Saat Ini', AppColors.primary);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _locationMode == LocationMode.currentLocation
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationMode == LocationMode.currentLocation
                      ? AppColors.primary
                      : Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    color: _locationMode == LocationMode.currentLocation
                        ? AppColors.primary
                        : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi Saat Ini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _locationMode == LocationMode.currentLocation
                                ? AppColors.primary
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gunakan GPS untuk lokasi real-time',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_locationMode == LocationMode.currentLocation)
                    Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Custom Location option
          InkWell(
            onTap: () {
              // Show options: tap on map or select from nodes
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Pilih Lokasi Awal'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.touch_app, color: Colors.orange),
                        title: Text('Tap pada Peta'),
                        subtitle: Text('Pilih lokasi bebas di peta'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _locationMode = LocationMode.customLocation;
                            _isSelectingStartLocation = true;
                            _showLocationModePanel = false;
                          });
                          _showMessage('Tap pada peta untuk memilih lokasi awal', AppColors.primary);
                        },
                      ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.location_on, color: Colors.blue),
                        title: Text('Pilih dari Node'),
                        subtitle: Text('Tap node di peta'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _locationMode = LocationMode.customLocation;
                            _isSelectingNodeFromMap = true;
                            _showLocationModePanel = false;
                          });
                          _showMessage('Tap pada node di peta untuk memilih lokasi awal', AppColors.primary);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Batal'),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _locationMode == LocationMode.customLocation
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationMode == LocationMode.customLocation
                      ? Colors.orange
                      : Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_location_alt,
                    color: _locationMode == LocationMode.customLocation
                        ? Colors.orange
                        : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _locationMode == LocationMode.customLocation
                                ? Colors.orange
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _customStartLocation != null
                              ? 'Lokasi dipilih: ${_customStartLocation!.latitude.toStringAsFixed(5)}, ${_customStartLocation!.longitude.toStringAsFixed(5)}'
                              : 'Pilih dari peta atau node',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_locationMode == LocationMode.customLocation)
                    Icon(Icons.check_circle, color: Colors.orange, size: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNodeSelectionDialog() {
    // Get all nodes and sort by name
    final nodes = _navigationService.nodes.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Node Awal'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              final node = nodes[index];
              return ListTile(
                leading: Icon(
                  node.name.contains('STUPA') ? Icons.account_balance : Icons.stairs,
                  color: node.name.contains('STUPA') ? Colors.orange : Colors.green,
                ),
                title: Text(node.name),
                subtitle: Text('Level ${node.level} • ${node.latitude.toStringAsFixed(5)}, ${node.longitude.toStringAsFixed(5)}'),
                onTap: () {
                  setState(() {
                    _locationMode = LocationMode.customLocation;
                    _customStartLocation = geo.Position(
                      latitude: node.latitude,
                      longitude: node.longitude,
                      timestamp: DateTime.now(),
                      accuracy: 0,
                      altitude: 0,
                      heading: 0,
                      speed: 0,
                      speedAccuracy: 0,
                      altitudeAccuracy: 0,
                      headingAccuracy: 0,
                    );
                    _showLocationModePanel = false;
                  });
                  
                  // Add marker for selected node
                  _addCustomLocationMarker(node.latitude, node.longitude);
                  
                  // Move camera to selected node
                  _mapboxMap?.flyTo(
                    CameraOptions(
                      center: Point(coordinates: Position(node.longitude, node.latitude)),
                      zoom: 18.0,
                    ),
                    MapAnimationOptions(duration: 1000),
                  );
                  
                  Navigator.pop(context);
                  _showMessage('Lokasi awal dipilih: ${node.name}', AppColors.primary);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
        ],
      ),
    );
  }

  void _showLevelFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Filter Levels'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show All option
                    CheckboxListTile(
                      title: Text('Show All Levels', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: _showAllLevels,
                      onChanged: (value) {
                        setDialogState(() {
                          _showAllLevels = value ?? true;
                          if (_showAllLevels) {
                            _selectedLevels.clear();
                          }
                        });
                      },
                    ),
                    Divider(),
                    // Individual level checkboxes (Levels 1-10)
                    ...List.generate(10, (index) {
                      final level = index + 1;
                      return CheckboxListTile(
                        title: Text('Level $level'),
                        value: _showAllLevels || _selectedLevels.contains(level),
                        enabled: !_showAllLevels,
                        onChanged: _showAllLevels ? null : (value) {
                          setDialogState(() {
                            if (value == true) {
                              _selectedLevels.add(level);
                            } else {
                              _selectedLevels.remove(level);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // State already updated via setDialogState
                    });
                    _applyLevelFilter();
                    Navigator.pop(context);
                  },
                  child: Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyLevelFilter() async {
    if (_mapboxMap == null) return;
    
    try {
      // Update visibility of marker layers based on selected levels
      for (final level in _levelsWithMarkers) {
        final circleLayerId = 'nodes-circles-$level';
        final symbolLayerId = 'nodes-symbols-$level';
        
        final shouldShow = _showAllLevels || _selectedLevels.contains(level);
        final visibility = shouldShow ? 'visible' : 'none';
        
        try {
          await _mapboxMap!.style.setStyleLayerProperty(
            circleLayerId,
            'visibility',
            visibility,
          );
          await _mapboxMap!.style.setStyleLayerProperty(
            symbolLayerId,
            'visibility',
            visibility,
          );
        } catch (e) {
          print('Could not update visibility for level $level: $e');
        }
      }
      
      print('✅ Applied level filter: ${_showAllLevels ? "All levels" : "Levels ${_selectedLevels.join(", ")}"}');
    } catch (e) {
      print('Error applying level filter: $e');
    }
  }

  /// Check if we should show calibration prompt
  void _checkAndShowCalibrationPrompt() {
    // Don't show if already shown this session
    if (_hasShownCalibrationPrompt) return;
    
    // Don't show if not at Borobudur
    if (!_isAtBorobudur) return;
    
    // Don't show if barometer not available
    if (!_isBarometerAvailable) return;
    
    // Check calibration state
    final calibrationState = _barometerService.calibrationState;
    
    // Show prompt if:
    // - No valid calibration, OR
    // - Only auto-calibration (not manual)
    if (!calibrationState.isValid || calibrationState.type == CalibrationType.auto) {
      _hasShownCalibrationPrompt = true;
      
      // Delay to avoid showing immediately on screen load
      Future.delayed(Duration(seconds: 2), () {
        if (mounted && _isAtBorobudur) {
          _showSmartCalibrationPrompt();
        }
      });
    }
  }

  /// Show smart calibration prompt dialog
  void _showSmartCalibrationPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.gps_fixed, color: AppColors.primary, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kalibrasi Barometer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anda berada di Candi Borobudur.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                'Kalibrasi sekarang untuk akurasi level detection terbaik?',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pastikan Anda di lantai dasar untuk hasil optimal',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showMessage('Menggunakan auto-kalibrasi (256 mdpl)', Colors.grey);
              },
              child: Text('Nanti', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Manual calibration at current location
                await _barometerService.calibrateForBorobudur(
                  knownAltitude: 256.0,
                  calibrationType: CalibrationType.manual,
                );
                
                _showMessage('✅ Kalibrasi berhasil! Level detection siap.', AppColors.primary);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Kalibrasi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Check if user has arrived at entrance gate and should switch to Stage 2
  void _checkStageTransition(geo.Position position) async {
    if (_navigationStage != 1) return;
    
    // Get entrance gate location
    final entranceGate = BorobudurFacilitiesData.getFacilities()
        .firstWhere((f) => f.id == ENTRANCE_GATE_ID);
    
    // Calculate distance to entrance gate
    final distance = _calculateDistance(
      position.latitude,
      position.longitude,
      entranceGate.latitude,
      entranceGate.longitude,
    );
    
    // If within 15 meters of entrance gate, switch to Stage 2
    if (distance <= 15.0) {
      print('🎯 STAGE TRANSITION: User arrived at entrance gate!');
      print('   Distance to entrance: ${distance.toStringAsFixed(1)}m');
      print('   Switching to Stage 2: Entry node → Final destination');
      
      // Stop current navigation
      await _stopNavigation();
      
      // Get entry node
      final entryNode = _navigationService.nodes[ENTRY_NODE_ID];
      if (entryNode == null) {
        print('❌ Entry node $ENTRY_NODE_ID not found!');
        _showMessage('Error: Entry point not found', Colors.red);
        return;
      }
      
      // Set up Stage 2 navigation
      setState(() {
        _navigationStage = 2;
        startNode = entryNode;
        destinationNode = _finalDestinationNode;
        destinationFeature = _finalDestinationFeature;
        useCurrentLocation = false; // Use entry node as start
      });
      
      // Show message
      _showMessage(
        'Memasuki area candi. Navigasi dilanjutkan ke ${_finalDestinationNode?.name ?? _finalDestinationFeature?.name}',
        AppColors.primary,
      );
      
      // Show navigation preview for Stage 2
      await _showNavigationPreview();
      
      print('✅ Stage 2 navigation preview ready');
    }
  }

  void _calibrateBarometer() {
    if (!_isBarometerAvailable) {
      _showMessage('Barometer not available', Colors.red);
      return;
    }

    final TextEditingController altitudeController = TextEditingController(text: '265');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.speed, color: Colors.deepOrange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Calibrate Barometer',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current altitude: ${(_currentAltitude < 0 ? 0 : _currentAltitude).toStringAsFixed(1)}m (relatif) / ${_currentAbsoluteAltitude.toStringAsFixed(0)}m mdpl',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                SizedBox(height: 20),
                Text(
                  'Choose calibration method:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 16),
                
                // Auto Borobudur option with editable altitude
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.temple_buddhist, color: AppColors.primary, size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto Borobudur',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Kalibrasi untuk Candi Borobudur. Masukkan ketinggian rata-rata Borobudur (mdpl).',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Ketinggian relatif akan disesuaikan berdasarkan nilai ini.',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: altitudeController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Altitude (mdpl)',
                                hintText: '265',
                                suffixText: 'm',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final altitudeText = altitudeController.text.trim();
                              final altitude = double.tryParse(altitudeText);
                              
                              if (altitude == null || altitude <= 0) {
                                _showMessage('Please enter a valid altitude', Colors.red);
                                return;
                              }
                              
                              _barometerService.calibrateForBorobudur(knownAltitude: altitude);
                              _showMessage('Barometer calibrated for ${altitude.toStringAsFixed(0)}m mdpl', AppColors.primary);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            child: Text('Set'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Current location option
                InkWell(
                  onTap: () {
                    _barometerService.calibrateHere();
                    _showMessage('Barometer calibrated at current location', AppColors.primary);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.my_location, color: Colors.green, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Calibrate at your current location',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
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
          // Single menu button for all options
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.black),
            tooltip: 'Menu',
            onSelected: (value) {
              switch (value) {
                case 'map_center':
                  setState(() {
                    if (_mapCenterMode == MapCenterMode.borobudurLocation) {
                      _mapCenterMode = MapCenterMode.currentLocation;
                      _switchToCurrentLocationMode();
                    } else {
                      _mapCenterMode = MapCenterMode.borobudurLocation;
                      _switchToBorobudurMode();
                    }
                  });
                  break;
                case 'location_mode':
                  setState(() {
                    _showLocationModePanel = !_showLocationModePanel;
                  });
                  break;
                case 'level_config':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LevelConfigScreen(),
                    ),
                  );
                  break;
                case 'level_filter':
                  _showLevelFilterDialog();
                  break;
                case 'calibrate_barometer':
                  _calibrateBarometer();
                  break;
              }
            },
            itemBuilder: (context) => [
              // Map Center Mode
              PopupMenuItem(
                value: 'map_center',
                child: ListTile(
                  leading: Icon(
                    _mapCenterMode == MapCenterMode.borobudurLocation 
                        ? Icons.temple_buddhist 
                        : Icons.location_on,
                    color: _mapCenterMode == MapCenterMode.borobudurLocation 
                        ? AppColors.primary 
                        : Colors.green,
                  ),
                  title: Text('Map Center'),
                  subtitle: Text(
                    _mapCenterMode == MapCenterMode.borobudurLocation 
                        ? 'Borobudur' 
                        : 'Current Location'
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              
              // Location Mode
              PopupMenuItem(
                value: 'location_mode',
                child: ListTile(
                  leading: Icon(
                    _locationMode == LocationMode.currentLocation 
                        ? Icons.my_location 
                        : Icons.edit_location_alt,
                    color: _locationMode == LocationMode.customLocation 
                        ? Colors.orange 
                        : AppColors.primary,
                  ),
                  title: Text('Location Mode'),
                  subtitle: Text(
                    _locationMode == LocationMode.currentLocation 
                        ? 'Current Location' 
                        : 'Custom Location'
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              
              // Level Configuration (only if barometer available)
              if (_isBarometerAvailable)
                PopupMenuItem(
                  value: 'level_config',
                  child: ListTile(
                    leading: Icon(Icons.tune, color: AppColors.accent),
                    title: Text('Level Settings'),
                    subtitle: Text('Configure altitude levels'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              
              // Level Filter
              PopupMenuItem(
                value: 'level_filter',
                child: ListTile(
                  leading: Icon(Icons.filter_list, color: AppColors.primary),
                  title: Text('Filter Levels'),
                  subtitle: Text(
                    _showAllLevels 
                        ? 'Showing all levels' 
                        : '${_selectedLevels.length} level(s) selected'
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              
              // Calibrate Barometer (only if barometer available)
              if (_isBarometerAvailable)
                PopupMenuItem(
                  value: 'calibrate_barometer',
                  child: ListTile(
                    leading: Icon(Icons.speed, color: Colors.deepOrange),
                    title: Text('Calibrate Barometer'),
                    subtitle: Text('Set reference altitude'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
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
            key: _mapKey,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(borobudurLon, borobudurLat)),
              zoom: cameraZoom,
              bearing: cameraBearing,
              pitch: cameraPitch,
            ),
            styleUri: MapboxStyles.STANDARD,
            textureView: true,
            onMapCreated: _onMapCreated,
            onTapListener: (MapContentGestureContext context) {
              print('Map tap listener triggered at ${context.point.coordinates}');
              _onMapTappedFromContext(context);
            },
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.layers, color: AppColors.primary, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      'Level $_currentTempleLevel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Relatif: ',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                        Text(
                          '${(_currentAltitude < 0 ? 0 : _currentAltitude).toStringAsFixed(1)}m',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        Text(
                          ' (${_currentAbsoluteAltitude.toStringAsFixed(0)}m mdpl)',
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pressure: ',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                        Text(
                          '${_currentPressure.toStringAsFixed(1)} hPa',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Location mode panel
          if (_showLocationModePanel && !isNavigating)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: _buildLocationModePanel(),
            ),
          
          // Selection mode indicator
          if (_isSelectingStartLocation)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap pada peta untuk memilih lokasi awal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSelectingStartLocation = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Node selection mode indicator
          if (_isSelectingNodeFromMap)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap pada node (marker) untuk memilih lokasi awal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSelectingNodeFromMap = false;
                        });
                      },
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

          // Navigation Preview
          if (showNavigationPreview && !isNavigating)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildNavigationPreviewPanel(),
            ),

          // Quick Re-calibrate Button (only at Borobudur)
          if (_isAtBorobudur && _isBarometerAvailable)
            Positioned(
              bottom: showNavigationPreview || (destinationNode != null || destinationFeature != null) ? 100 : 24,
              right: 16,
              child: FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Kalibrasi Ulang?'),
                        content: Text('Kalibrasi barometer di lokasi ini sebagai lantai dasar (0m)?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Batal'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              
                              await _barometerService.calibrateForBorobudur(
                                knownAltitude: 256.0,
                                calibrationType: CalibrationType.manual,
                              );
                              
                              _showMessage('✅ Kalibrasi berhasil!', AppColors.primary);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: Text('Kalibrasi'),
                          ),
                        ],
                      );
                    },
                  );
                },
                backgroundColor: AppColors.primary,
                child: Icon(Icons.gps_fixed, color: Colors.white),
                tooltip: 'Kalibrasi Ulang',
              ),
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
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Multi-stage indicator (if applicable)
          if (_navigationStage > 0) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    _navigationStage == 1 
                        ? 'Tahap 1/2: Menuju Pintu Masuk'
                        : 'Tahap 2/2: Menuju ${_finalDestinationNode?.name ?? _finalDestinationFeature?.name}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
          
          // Navigation instruction
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
