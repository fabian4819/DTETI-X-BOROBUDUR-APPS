import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import '../../models/temple_node.dart';
import '../../services/temple_navigation_service.dart';
import '../../services/barometer_service.dart';
import '../../services/level_detection_service.dart';
import '../../utils/app_colors.dart';
import '../../config/map_config.dart';
import 'level_config_screen.dart';

// Enum for location mode
enum LocationMode {
  currentLocation,
  customLocation,
}

class Mapbox3DNavigationScreen extends StatefulWidget {
  const Mapbox3DNavigationScreen({Key? key}) : super(key: key);

  @override
  State<Mapbox3DNavigationScreen> createState() => _Mapbox3DNavigationScreenState();
}

class _Mapbox3DNavigationScreenState extends State<Mapbox3DNavigationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Global key for MapWidget to prevent recreate error
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
  geo.Position? _customStartLocation;
  bool _isSelectingStartLocation = false;
  bool _showLocationModePanel = false;

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

  // Track which levels have markers
  final Set<int> _levelsWithMarkers = {};

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

          // Update 3D extrusion and markers visibility based on level
          _update3DExtrusion();
          _updateMarkersVisibility();
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
      
      // Setup initial markers visibility based on current level
      await _updateMarkersVisibility();
      
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
          fillExtrusionOpacity: 0.0, // DISABLED - buildings invisible for testing
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
      
      // Group nodes by level for better organization
      final nodesByLevel = <int, List<TempleNode>>{};
      for (final node in nodes) {
        // Filter: Only show nodes with "STUPA" or "TANGGA" in name
        final nodeName = node.name.toUpperCase();
        if (nodeName.contains('STUPA') || nodeName.contains('TANGGA')) {
          nodesByLevel.putIfAbsent(node.level, () => []).add(node);
        }
      }
      
      int totalMarkers = 0;
      
      // Clear previous marker levels
      _levelsWithMarkers.clear();
      
      // DEBUG: Print total nodes and grouping
      print('🔍 DEBUG: Total nodes loaded: ${nodes.length}');
      print('🔍 DEBUG: Nodes by level: ${nodesByLevel.map((k, v) => MapEntry(k, v.length))}');
      
      // Add nodes as GeoJSON sources with circle layers per level
      for (final level in nodesByLevel.keys) {
        final levelNodes = nodesByLevel[level]!;
        
        // Track this level has markers
        _levelsWithMarkers.add(level);
        
        print('🔍 DEBUG: Processing level $level with ${levelNodes.length} nodes');
        
        // Create GeoJSON features for this level (2D mode - no altitude)
        final features = levelNodes.map((node) {
          final color = _getNodeColor(node);
          
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
              "level": ${node.level},
              "color": "${color.value}"
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
        
        // Add circle layer for 2D markers with VIEWPORT alignment
        final layerId = 'nodes-circles-$level';
        await _mapboxMap!.style.addLayer(CircleLayer(
          id: layerId,
          sourceId: sourceId,
          circleRadius: 14.0, // Large for visibility
          circleColor: Colors.green.value,
          circleStrokeWidth: 5.0, // Thick stroke
          circleStrokeColor: Colors.white.value,
          circleOpacity: 1.0, // Full opacity
          circlePitchAlignment: CirclePitchAlignment.VIEWPORT, // 2D mode
          // Ensure circles are always on top
          circleSortKey: 999.0, // Highest priority
        ));
        print('✅ Added layer: $layerId for ${levelNodes.length} markers');
        
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
        
        await _mapboxMap!.style.addLayer(CircleLayer(
          id: 'features-stupa-circles',
          sourceId: 'features-stupa-source',
          circleRadius: 18.0, // Largest for stupa visibility
          circleColor: Colors.blue.value,
          circleStrokeWidth: 6.0, // Thickest stroke
          circleStrokeColor: Colors.white.value,
          circleOpacity: 1.0, // Full opacity
          circlePitchAlignment: CirclePitchAlignment.VIEWPORT, // 2D mode
          circleSortKey: 999.0, // Always on top
        ));
      }
      
      // Add other features (orange) - 2D mode
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
        
        await _mapboxMap!.style.addLayer(CircleLayer(
          id: 'features-other-circles',
          sourceId: 'features-other-source',
          circleRadius: 16.0, // Large for feature visibility
          circleColor: Colors.orange.value,
          circleStrokeWidth: 6.0, // Thick stroke
          circleStrokeColor: Colors.white.value,
          circleOpacity: 1.0, // Full opacity
          circlePitchAlignment: CirclePitchAlignment.VIEWPORT, // 2D mode
          circleSortKey: 999.0, // Always on top
        ));
      }
      
      print('Added ${features.length} feature markers as layers (${stupaFeatures.length} stupa, ${otherFeatures.length} other)');
    } catch (e) {
      print('Error adding feature markers: $e');
    }
  }

  void _setupMapInteractions() {
    if (_mapboxMap == null) return;

    print('Map interactions setup completed');
  }

  // Handle map tap to detect marker clicks
  void _onMapTappedFromContext(MapContentGestureContext context) async {
    if (_mapboxMap == null) return;
    
    final tappedPoint = context.point;
    print('Map tapped at point: ${tappedPoint.coordinates}');
    
    // If selecting custom start location, handle that first
    if (_isSelectingStartLocation) {
      setState(() {
        _customStartLocation = geo.Position(
          latitude: tappedPoint.coordinates.lat.toDouble(),
          longitude: tappedPoint.coordinates.lng.toDouble(),
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        _isSelectingStartLocation = false;
      });
      
      // Add marker for custom location
      await _addCustomLocationMarker(
        tappedPoint.coordinates.lat.toDouble(),
        tappedPoint.coordinates.lng.toDouble(),
      );
      
      _showMessage('Lokasi awal dipilih', AppColors.primary);
      return;
    }
    
    // Query rendered features at tap location using screen coordinate
    try {
      // Convert the tapped geographical point to screen coordinate
      final screenCoord = await _mapboxMap!.pixelForCoordinate(tappedPoint);
      
      print('Screen coordinate: x=${screenCoord.x}, y=${screenCoord.y}');
      
      // Query features at the exact screen coordinate
      // Include both node layers and feature layers
      final layerIds = [
        ..._levelsWithMarkers.map((level) => 'nodes-circles-$level'),
        'features-stupa-circles',
        'features-other-circles',
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
              // Check source or type to determine if it's a feature or node
              print('Checking: source=$source, type=$type');
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
    } else {
      currentPos = _currentPosition;
      if (currentPos == null) {
        _showMessage('Tidak dapat menemukan lokasi Anda', Colors.orange);
        return;
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
    
    // Try to get route data from Borobudur API if destination is a node
    Map<String, dynamic>? routeData;
    if (destinationNode != null) {
      routeData = await _fetchBorobudurRoute(
        currentPos.latitude,
        currentPos.longitude,
        destinationNode!.id,
      );
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
    
    // Draw route line on map (pass targetNode if destination is a node)
    await _drawRouteLine(
      currentPos.latitude,
      currentPos.longitude,
      destLat,
      destLon,
      targetNode: destinationNode,
    );
    
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
      final isDestinationTangga = destinationNode?.name.contains('TANGGA') ?? false;
      
      print('=== Borobudur Route Request ===');
      print('From: ($startLat, $startLon)');
      print('To: Node $toNodeId${destinationNode != null ? ' (${destinationNode.name}, Level $destinationLevel${isDestinationTangga ? ', TANGGA node' : ''})' : ''}');
      
      // If destination is TANGGA (isolated), skip snap-to-nearest and go straight to Mapbox
      if (isDestinationTangga) {
        print('⚠️ Destination is TANGGA node (likely isolated from graph)');
        print('Skipping Borobudur API and using Mapbox Directions instead');
        return null;
      }

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
            print('❌ Error: ${data['data']['error']}');
          } else if (data['data']['features'] != null && 
              (data['data']['features'] as List).isNotEmpty) {
            print('✅ Direct route successful!');
            final feature = data['data']['features'][0];
            if (feature['properties'] != null) {
              print('Distance: ${feature['properties']['distance_m']} m');
              print('Duration: ${feature['properties']['duration_s']} s');
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
  }) async {
    if (_mapboxMap == null) return;
    
    try {
      // Remove existing route layer if any
      try {
        await _mapboxMap!.style.removeStyleLayer('route-layer');
        await _mapboxMap!.style.removeStyleLayer('route-layer-casing');
        await _mapboxMap!.style.removeStyleSource('route-source');
      } catch (e) {
        // Layer doesn't exist, ignore
      }
      
      Map<String, dynamic>? route;
      String routeSource = 'unknown';
      
      // Try Borobudur Backend API first if destination is a Node
      if (targetNode != null) {
        print('Attempting to fetch route from Borobudur Backend (on-temple navigation)...');
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
      }
      
      // Fallback to Mapbox Directions API if Borobudur API fails or not a node
      if (route == null) {
        print('Falling back to Mapbox Directions API...');
        route = await _fetchDirectionsRoute(startLat, startLon, endLat, endLon);
        if (route != null && route['geometry'] != null) {
          routeSource = 'Mapbox Directions';
        }
      }
      
      Map<String, dynamic> routeGeoJson;
      
      if (route != null && route['geometry'] != null) {
        // Use real route from API
        routeGeoJson = {
          'type': 'Feature',
          'geometry': route['geometry'],
          'properties': {
            'route-color': '#3366FF', // Blue color for route
            'route-source': routeSource,
          },
        };
        print('Using $routeSource route with ${route['geometry']['coordinates'].length} points');
      } else {
        // Fallback to straight line if all APIs fail
        print('All APIs failed - falling back to straight line route');
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
            'route-color': '#3366FF',
            'route-source': 'Straight Line (Fallback)',
          },
        };
      }
      
      // Add source
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: 'route-source',
        data: json.encode(routeGeoJson),
      ));
      
      // Add casing layer (black border)
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
      
      // Add main route layer with traffic-style colors
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
      
      print('Route line drawn successfully with traffic styling');
    } catch (e) {
      print('Error drawing route line: $e');
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
      
      // Add circle layer (2D mode - VIEWPORT alignment)
      await _mapboxMap!.style.addLayer(CircleLayer(
        id: 'custom-location-layer',
        sourceId: 'custom-location-source',
        circleRadius: 20.0, // Largest for custom location marker
        circleColor: Colors.green.value,
        circleStrokeWidth: 7.0, // Thickest stroke for emphasis
        circleStrokeColor: Colors.white.value,
        circleOpacity: 1.0, // Full opacity
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
    } catch (e) {
      // Layer doesn't exist, ignore
    }
  }

  Future<void> _updateUserLocationOnMap(geo.Position position) async {
    if (_mapboxMap == null) return;

    try {
      // Update camera to follow user ONLY if using current location mode
      // If using custom location mode, don't auto-follow GPS
      if (isNavigating && _locationMode == LocationMode.currentLocation) {
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

  Future<void> _updateMarkersVisibility() async {
    if (_mapboxMap == null) return;

    try {
      // Show only markers for current level and adjacent levels
      // This makes the view cleaner in 3D mode
      
      // Only update levels that have markers
      for (final level in _levelsWithMarkers) {
        final layerId = 'nodes-circles-$level';
        
        // Show current level with full opacity, adjacent levels with reduced opacity
        final levelDiff = (level - _currentTempleLevel).abs();
        String visibility = 'visible';
        double opacity = 0.9;
        
        if (levelDiff == 0) {
          // Current level - full visibility
          opacity = 1.0;
        } else if (levelDiff == 1) {
          // Adjacent level - reduced opacity
          opacity = 0.4;
        } else {
          // Far levels - hide to reduce clutter
          visibility = 'none';
        }
        
        try {
          await _mapboxMap!.style.setStyleLayerProperty(
            layerId,
            'visibility',
            visibility,
          );
          
          if (visibility == 'visible') {
            await _mapboxMap!.style.setStyleLayerProperty(
              layerId,
              'circle-opacity',
              opacity,
            );
          }
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

  void _stopNavigation() {
    _navigationService.stopNavigation();
    
    // Remove route line when stopping navigation
    _removeRouteLine();
    
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
              setState(() {
                _locationMode = LocationMode.customLocation;
                _isSelectingStartLocation = true;
                _showLocationModePanel = false;
              });
              _showMessage('Tap pada peta untuk memilih lokasi awal', Colors.orange);
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
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi Custom',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _locationMode == LocationMode.customLocation
                                ? Colors.orange
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _customStartLocation != null
                              ? 'Lokasi dipilih: ${_customStartLocation!.latitude.toStringAsFixed(6)}, ${_customStartLocation!.longitude.toStringAsFixed(6)}'
                              : 'Tap peta untuk pilih lokasi (untuk testing)',
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
          // Location mode toggle
          IconButton(
            icon: Icon(
              _locationMode == LocationMode.currentLocation 
                  ? Icons.my_location 
                  : Icons.edit_location_alt,
              color: _locationMode == LocationMode.customLocation 
                  ? Colors.orange 
                  : AppColors.primary,
            ),
            onPressed: () {
              setState(() {
                _showLocationModePanel = !_showLocationModePanel;
              });
            },
            tooltip: 'Pilih Mode Lokasi',
          ),
          
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
