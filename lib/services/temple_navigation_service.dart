import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/temple_node.dart';
import '../models/api_models.dart';
import '../data/borobudur_data.dart';
import 'api_service.dart';

class TempleNavigationService {
  static final TempleNavigationService _instance = TempleNavigationService._internal();
  factory TempleNavigationService() => _instance;
  TempleNavigationService._internal();

  final ApiService _apiService = ApiService();
  
  StreamController<Position>? _positionStreamController;
  StreamController<NavigationUpdate>? _navigationUpdateController;
  
  Position? _currentPosition;
  List<RouteWaypoint> _currentPath = [];
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  TempleNode? _destination;
  
  // Direct API graph data - no conversion to LocationPoint
  Map<int, TempleNode> _nodes = {}; // node ID -> TempleNode
  Map<int, List<int>> _adjacencyList = {}; // node ID -> connected node IDs
  List<TempleEdge> _edges = [];
  List<TempleFeature> _features = [];
  
  // Loading states
  bool _isLoadingGraph = false;
  bool _isLoadingFeatures = false;

  // Getters
  Stream<Position>? get positionStream => _positionStreamController?.stream;
  Stream<NavigationUpdate>? get navigationUpdateStream => _navigationUpdateController?.stream;
  
  bool get isNavigating => _isNavigating;
  Position? get currentPosition => _currentPosition;
  List<RouteWaypoint> get currentPath => _currentPath;
  int get currentStepIndex => _currentStepIndex;
  bool get isLoadingGraph => _isLoadingGraph;
  bool get isLoadingFeatures => _isLoadingFeatures;
  
  // API data access
  Map<int, TempleNode> get nodes => Map.unmodifiable(_nodes);
  List<TempleEdge> get edges => List.unmodifiable(_edges);
  List<TempleFeature> get features => List.unmodifiable(_features);

  void initialize() {
    _positionStreamController = StreamController<Position>.broadcast();
    _navigationUpdateController = StreamController<NavigationUpdate>.broadcast();
    _loadTempleData();
  }

  // Load temple data from API
  Future<void> _loadTempleData() async {
    _isLoadingGraph = true;
    _isLoadingFeatures = true;
    
    try {
      // Load graph data (nodes and edges)
      final graphResponse = await _apiService.getTempleGraphCached();
      if (graphResponse != null && graphResponse.code == 200) {
        await _parseTempleGraph(graphResponse.data);
      }
      
      // Load features data (stupas, etc.)
      await _loadTempleFeatures();
      
    } catch (e) {
      debugPrint('Failed to load temple data from API: $e');
    } finally {
      _isLoadingGraph = false;
      _isLoadingFeatures = false;
    }
  }

  // Parse temple graph data directly from API
  Future<void> _parseTempleGraph(GraphData graphData) async {
    final newNodes = <int, TempleNode>{};
    final newAdjacencyList = <int, List<int>>{};
    final newEdges = <TempleEdge>[];

    // Clear existing data
    _nodes.clear();
    _adjacencyList.clear();
    _edges.clear();

    // Parse nodes (Points)
    for (final feature in graphData.features) {
      if (feature.geometry.isPoint && feature.properties.id != null) {
        final node = TempleNode.fromApiFeature(feature);
        newNodes[node.id] = node;
      }
    }

    // Parse edges (LineStrings)
    for (final feature in graphData.features) {
      if (feature.geometry.isLineString && 
          feature.properties.source != null && 
          feature.properties.target != null) {
        final edge = TempleEdge.fromApiFeature(feature);
        newEdges.add(edge);
        
        // Build adjacency list
        newAdjacencyList.putIfAbsent(edge.sourceId, () => []).add(edge.targetId);
        newAdjacencyList.putIfAbsent(edge.targetId, () => []).add(edge.sourceId);
      }
    }

    // Use parsed data
    _nodes = newNodes;
    _adjacencyList = newAdjacencyList;
    _edges = newEdges;
  }

  // Load temple features
  Future<void> _loadTempleFeatures() async {
    try {
      // Load all features
      final allFeatures = await getTempleFeatures();
      _features = allFeatures;
      
      debugPrint('Loaded ${_features.length} temple features');
      
    } catch (e) {
      debugPrint('Failed to load temple features: $e');
    }
  }

  // Get temple features - returns TempleFeature directly
  Future<List<TempleFeature>> getTempleFeatures() async {
    try {
      final featuresResponse = await _apiService.getTempleFeatures();
      
      if (featuresResponse != null && featuresResponse.code == 200) {
        return _parseTempleFeatures(featuresResponse.data);
      }
    } catch (e) {
      debugPrint('Failed to get temple features: $e');
    }
    
    return [];
  }

  List<TempleFeature> _parseTempleFeatures(FeaturesData data) {
    final features = <TempleFeature>[];

    for (final feature in data.features) {
      if (feature.geometry.isPoint && feature.properties.id != null) {
        features.add(TempleFeature.fromApiFeature(feature));
      }
    }

    return features;
  }

  // Get nearest features using API
  Future<List<TempleFeature>> getNearestFeatures({
    required double lat,
    required double lon,
    double radius = 200.0,
    int limit = 10,
    String? type,
  }) async {
    try {
      final featuresResponse = await _apiService.getNearestFeatures(
        lat: lat,
        lon: lon,
        radius: radius,
        limit: limit,
        type: type,
      );
      
      if (featuresResponse != null && featuresResponse.code == 200) {
        return _parseTempleFeatures(featuresResponse.data);
      }
    } catch (e) {
      debugPrint('Failed to get nearest features: $e');
    }
    
    return [];
  }

  // Find nearby features from loaded data
  List<TempleFeature> findNearbyFeaturesLocal({
    required double lat,
    required double lon,
    double maxDistance = 200.0,
    int limit = 10,
    String? type,
  }) {
    var features = _features.where((feature) {
      if (type != null && feature.type.toLowerCase() != type.toLowerCase()) {
        return false;
      }
      final distance = _calculateDistance(lat, lon, feature.latitude, feature.longitude);
      return distance <= maxDistance;
    }).toList();

    // Sort by distance
    features.sort((a, b) {
      final distanceA = _calculateDistance(lat, lon, a.latitude, a.longitude);
      final distanceB = _calculateDistance(lat, lon, b.latitude, b.longitude);
      return distanceA.compareTo(distanceB);
    });

    return features.take(limit).toList();
  }

  // Get features by type
  List<TempleFeature> getFeaturesByType(String type) {
    return _features.where((feature) => 
        feature.type.toLowerCase() == type.toLowerCase()).toList();
  }

  // Get all available feature types
  Set<String> getAvailableFeatureTypes() {
    return _features.map((feature) => feature.type).toSet();
  }

  // Get all available levels from nodes
  Set<int> getAvailableLevels() {
    final levels = <int>{};
    levels.addAll(_nodes.values.map((node) => node.level));
    levels.addAll(_features.map((feature) => feature.level));
    return levels;
  }

  // Get nodes by level
  List<TempleNode> getNodesByLevel(int level) {
    return _nodes.values.where((node) => node.level == level).toList();
  }

  // Get features by level
  List<TempleFeature> getFeaturesByLevel(int level) {
    return _features.where((feature) => feature.level == level).toList();
  }

  // Start navigation using API route calculation
  Future<NavigationResult> startNavigation({
    double? fromLat,
    double? fromLon,
    TempleNode? fromNode,
    TempleNode? toNode,
    TempleFeature? toFeature,
  }) async {
    try {
      // Get route from API
      List<RouteWaypoint> path = [];
      
      if (fromLat != null && fromLon != null) {
        // Use coordinates as start point
        if (toNode != null) {
          path = await _getApiRoute(
            fromLat: fromLat,
            fromLon: fromLon,
            toNodeId: toNode.id,
          );
        } else if (toFeature != null) {
          path = await _getApiRoute(
            fromLat: fromLat,
            fromLon: fromLon,
            toLat: toFeature.latitude,
            toLon: toFeature.longitude,
          );
        }
      } else if (fromNode != null) {
        // Use node as start point
        if (toNode != null) {
          path = await _getApiRoute(
            fromNodeId: fromNode.id,
            toNodeId: toNode.id,
          );
        } else if (toFeature != null) {
          path = await _getApiRoute(
            fromNodeId: fromNode.id,
            toLat: toFeature.latitude,
            toLon: toFeature.longitude,
          );
        }
      }
      
      if (path.isEmpty) {
        String errorMsg = 'Rute tidak ditemukan';
        if (fromLat != null && fromLon != null) {
          final nearestNode = _findNearestNodeId(fromLat, fromLon);
          if (nearestNode == null) {
            errorMsg = 'Lokasi awal terlalu jauh dari node terdekat (>50m)';
          }
        }
        if (toNode == null && toFeature != null) {
          final nearestDestNode = _findNearestNodeId(toFeature.latitude, toFeature.longitude);
          if (nearestDestNode == null) {
            errorMsg = 'Lokasi tujuan terlalu jauh dari node terdekat (>50m)';
          }
        }
        debugPrint('Route calculation failed: $errorMsg');
        return NavigationResult(success: false, message: errorMsg);
      }

      _currentPath = path;
      _destination = toNode;
      _currentStepIndex = 0;
      _isNavigating = true;

      final totalDistance = _calculateTotalDistance(path);
      final estimatedTime = (totalDistance / 1.4).ceil(); // 1.4 m/s walking speed

      return NavigationResult(
        success: true,
        path: path,
        totalDistance: totalDistance,
        estimatedTime: estimatedTime,
        message: 'Navigasi dimulai',
      );
      
    } catch (e) {
      debugPrint('Failed to start navigation: $e');
      return NavigationResult(success: false, message: 'Gagal memulai navigasi: $e');
    }
  }

  // Get route from API with fallback logic
  Future<List<RouteWaypoint>> _getApiRoute({
    double? fromLat,
    double? fromLon,
    int? fromNodeId,
    double? toLat,
    double? toLon,
    int? toNodeId,
    String profile = 'walking',
  }) async {
    try {
      // If using coordinates, try to find nearest node first
      int? nearestFromNodeId = fromNodeId;
      int? nearestToNodeId = toNodeId;
      
      if (fromLat != null && fromLon != null && fromNodeId == null) {
        nearestFromNodeId = _findNearestNodeId(fromLat, fromLon);
        debugPrint('Found nearest start node: $nearestFromNodeId for coordinates ($fromLat, $fromLon)');
      }
      
      if (toLat != null && toLon != null && toNodeId == null) {
        nearestToNodeId = _findNearestNodeId(toLat, toLon);
        debugPrint('Found nearest destination node: $nearestToNodeId for coordinates ($toLat, $toLon)');
      } else if (toNodeId != null) {
        nearestToNodeId = toNodeId;
        debugPrint('Using provided destination node ID: $toNodeId');
      }
      
      // Convert node IDs to coordinates if needed
      double? actualFromLat = fromLat;
      double? actualFromLon = fromLon;
      double? actualToLat = toLat;  
      double? actualToLon = toLon;
      
      if (nearestFromNodeId != null && fromLat == null) {
        final fromNode = _nodes[nearestFromNodeId];
        if (fromNode != null) {
          actualFromLat = fromNode.latitude;
          actualFromLon = fromNode.longitude;
          debugPrint('Using start node coordinates: ${fromNode.name} (${fromNode.latitude}, ${fromNode.longitude})');
        }
      }
      
      if (nearestToNodeId != null && toLat == null) {
        final toNodeObj = _nodes[nearestToNodeId];
        if (toNodeObj != null) {
          actualToLat = toNodeObj.latitude;
          actualToLon = toNodeObj.longitude;
          debugPrint('Using destination node coordinates: ${toNodeObj.name} (${toNodeObj.latitude}, ${toNodeObj.longitude})');
        }
      }
      
      // API call - try multiple routing approaches for cross-floor navigation
      RouteResponse? routeResponse;
      
      // Method 1: Try fromLat/fromLon + toNodeId (most reliable for same floor)
      if (actualFromLat != null && actualFromLon != null && nearestToNodeId != null) {
        debugPrint('Method 1 - fromLat/fromLon + toNodeId: ($actualFromLat, $actualFromLon) -> node $nearestToNodeId');
        try {
          routeResponse = await _apiService.getNavigationRoute(
            fromLat: actualFromLat,
            fromLon: actualFromLon,
            toNodeId: nearestToNodeId,
            profile: profile,
          );
          if (routeResponse != null && routeResponse.code == 200) {
            debugPrint('Method 1 successful!');
          }
        } catch (e) {
          debugPrint('Method 1 failed: $e');
        }
      }
      
      // Method 2: Try coordinate-to-coordinate (better for cross-floor)
      if ((routeResponse == null || routeResponse.code != 200) && 
          actualFromLat != null && actualFromLon != null && 
          actualToLat != null && actualToLon != null) {
        debugPrint('Method 2 - coordinates: ($actualFromLat, $actualFromLon) -> ($actualToLat, $actualToLon)');
        try {
          routeResponse = await _apiService.getNavigationRoute(
            fromLat: actualFromLat,
            fromLon: actualFromLon,
            toLat: actualToLat,
            toLon: actualToLon,
            profile: profile,
          );
          if (routeResponse != null && routeResponse.code == 200) {
            debugPrint('Method 2 successful!');
          }
        } catch (e) {
          debugPrint('Method 2 failed: $e');
        }
      }
      
      // Method 3: Try finding alternative nearby nodes if cross-floor fails
      if ((routeResponse == null || routeResponse.code != 200) && 
          actualFromLat != null && actualFromLon != null && actualToLat != null && actualToLon != null) {
        debugPrint('Method 3 - trying alternative nodes for cross-floor navigation');
        final alternativeToNodes = _findAlternativeNodes(actualToLat, actualToLon);
        
        for (final altNodeId in alternativeToNodes) {
          try {
            debugPrint('Trying alternative destination node: $altNodeId');
            routeResponse = await _apiService.getNavigationRoute(
              fromLat: actualFromLat,
              fromLon: actualFromLon,
              toNodeId: altNodeId,
              profile: profile,
            );
            if (routeResponse != null && routeResponse.code == 200) {
              debugPrint('Method 3 successful with node $altNodeId!');
              break;
            }
          } catch (e) {
            debugPrint('Alternative node $altNodeId failed: $e');
          }
        }
      }
      
      if (routeResponse != null && routeResponse.code == 200) {
        return _parseNavigationRoute(routeResponse.data);
      }
    } catch (e) {
      debugPrint('Failed to get API route: $e');
    }
    
    return [];
  }
  
  // Find nearest node ID to given coordinates
  int? _findNearestNodeId(double lat, double lon) {
    if (_nodes.isEmpty) {
      debugPrint('Warning: No nodes loaded yet, cannot find nearest node');
      return null;
    }
    
    double minDistance = double.infinity;
    int? nearestNodeId;
    
    for (final node in _nodes.values) {
      final distance = _calculateDistance(lat, lon, node.latitude, node.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        nearestNodeId = node.id;
      }
    }
    
    // Only return if within reasonable distance (200 meters for cross-floor flexibility)
    debugPrint('Nearest node distance: ${minDistance.toStringAsFixed(1)}m (node ID: $nearestNodeId)');
    return minDistance <= 200.0 ? nearestNodeId : null;
  }
  
  // Find multiple alternative nodes for better cross-floor routing
  List<int> _findAlternativeNodes(double lat, double lon) {
    if (_nodes.isEmpty) return [];
    
    final nodeDistances = <MapEntry<int, double>>[];
    
    for (final node in _nodes.values) {
      final distance = _calculateDistance(lat, lon, node.latitude, node.longitude);
      if (distance <= 300.0) { // Wider range for alternatives
        nodeDistances.add(MapEntry(node.id, distance));
      }
    }
    
    // Sort by distance and return top 5 closest nodes
    nodeDistances.sort((a, b) => a.value.compareTo(b.value));
    final alternatives = nodeDistances.take(5).map((entry) => entry.key).toList();
    
    debugPrint('Found ${alternatives.length} alternative nodes: $alternatives');
    return alternatives;
  }

  List<RouteWaypoint> _parseNavigationRoute(RouteData routeData) {
    // Check if the route data contains an error
    if (routeData.error != null) {
      debugPrint('Route API returned error: ${routeData.error}');
      return []; // Return empty list for error
    }

    final waypoints = <RouteWaypoint>[];

    for (final feature in routeData.features) {
      if (feature.geometry.isLineString) {
        final coordinates = feature.geometry.lineCoordinates!;

        // Convert LineString coordinates to waypoints
        for (int i = 0; i < coordinates.length; i++) {
          final coord = coordinates[i];
          waypoints.add(RouteWaypoint(
            latitude: coord[1],
            longitude: coord[0],
            index: i,
          ));
        }
      }
    }

    return waypoints;
  }

  void stopNavigation() {
    _isNavigating = false;
    _currentPath.clear();
    _currentStepIndex = 0;
    _destination = null;
    resetDummySimulation();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    double dLat = (lat2 - lat1) * (math.pi / 180);
    double dLon = (lon2 - lon1) * (math.pi / 180);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _calculateTotalDistance(List<RouteWaypoint> path) {
    double total = 0;
    for (int i = 0; i < path.length - 1; i++) {
      total += _calculateDistance(
        path[i].latitude,
        path[i].longitude,
        path[i + 1].latitude,
        path[i + 1].longitude,
      );
    }
    return total;
  }

  /// Check if location permission is granted without requesting it
  Future<bool> hasLocationPermission() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return false;
      }

      // Use geolocator's checkPermission for better iOS support
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Current geolocator permission status: $permission');
      
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
      
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  Future<bool> requestLocationPermission() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        // Try to open location settings
        try {
          bool opened = await Geolocator.openLocationSettings();
          debugPrint('Location settings opened: $opened');
        } catch (e) {
          debugPrint('Could not open location settings: $e');
        }
        return false;
      }

      // Check current permission status using geolocator
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Current location permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        // Request permission
        debugPrint('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('Permission request result: $permission');
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied - user needs to enable in settings');
        return false;
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        debugPrint('Location permission granted successfully');
        // Test if we can actually get location
        try {
          Position testPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 10),
          );
          debugPrint('Location test successful: ${testPosition.latitude}, ${testPosition.longitude}');
          debugPrint('Location accuracy: ${testPosition.accuracy}m');
          return true;
        } catch (e) {
          debugPrint('Location test failed (permission granted but no location): $e');
          // Still return true if permission is granted, location might be available later
          return true;
        }
      }
      
      debugPrint('Location permission denied');
      return false;
      
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }
  
  Future<bool> openLocationSettings() async {
    try {
      bool opened = await openAppSettings();
      debugPrint('App settings opened: $opened');
      return opened;
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  Future<void> startLocationTracking() async {
    // Check if permission is already granted first
    if (!await hasLocationPermission()) {
      // Only request if not already granted
      if (!await requestLocationPermission()) {
        throw Exception('Location permission not granted');
      }
    }

    // iOS-specific location settings for better GPS accuracy
    final LocationSettings locationSettings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.otherNavigation,
      distanceFilter: 2,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _currentPosition = position;
        // Check if controller is still open before adding
        if (_positionStreamController != null && !_positionStreamController!.isClosed) {
          _positionStreamController!.add(position);
        }
        
        if (_isNavigating) {
          _updateNavigation(position);
        }
      },
    );

    // Get initial position
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      if (_positionStreamController != null && !_positionStreamController!.isClosed) {
        _positionStreamController!.add(_currentPosition!);
      }
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }
  }

  void _updateNavigation(Position currentPos) {
    if (_currentPath.isEmpty || _destination == null) return;

    final currentStep = _currentPath[_currentStepIndex];
    final distanceToStep = _calculateDistance(
      currentPos.latitude,
      currentPos.longitude,
      currentStep.latitude,
      currentStep.longitude,
    );

    // If close to current step (within 5 meters), move to next step
    if (distanceToStep < 5.0 && _currentStepIndex < _currentPath.length - 1) {
      _currentStepIndex++;
      final nextStep = _currentPath[_currentStepIndex];
      final direction = _getDirectionInstruction(_currentStepIndex);
      
      _navigationUpdateController?.add(NavigationUpdate(
        currentStep: _destination,
        distanceToNextStep: _calculateDistance(
          currentPos.latitude,
          currentPos.longitude,
          nextStep.latitude,
          nextStep.longitude,
        ),
        instruction: direction,
        remainingDistance: _calculateRemainingDistance(currentPos),
        estimatedTime: _calculateEstimatedTime(currentPos),
        stepIndex: _currentStepIndex,
        totalSteps: _currentPath.length,
      ));
    }

    // Check if reached destination
    if (_destination != null) {
      final distanceToDestination = _calculateDistance(
        currentPos.latitude,
        currentPos.longitude,
        _destination!.latitude,
        _destination!.longitude,
      );

      if (distanceToDestination < 5.0) {
        stopNavigation();
        _navigationUpdateController?.add(NavigationUpdate(
          currentStep: _destination!,
          distanceToNextStep: 0,
          instruction: 'Anda telah sampai di tujuan!',
          remainingDistance: 0,
          estimatedTime: 0,
          stepIndex: _currentPath.length - 1,
          totalSteps: _currentPath.length,
          hasArrived: true,
        ));
      }
    }
  }

  String _getDirectionInstruction(int stepIndex) {
    if (stepIndex >= _currentPath.length - 1) {
      return 'Lanjutkan menuju tujuan';
    }

    if (stepIndex == 0) {
      return 'Mulai navigasi';
    }

    final prev = _currentPath[stepIndex - 1];
    final current = _currentPath[stepIndex];
    final next = _currentPath[stepIndex + 1];

    final bearing1 = _calculateBearing(prev.latitude, prev.longitude, current.latitude, current.longitude);
    final bearing2 = _calculateBearing(current.latitude, current.longitude, next.latitude, next.longitude);
    final angleDiff = (bearing2 - bearing1 + 360) % 360;

    String direction;
    if (angleDiff > 340 || angleDiff < 20) {
      direction = 'Lurus';
    } else if (angleDiff >= 20 && angleDiff < 160) {
      direction = 'Belok kanan';
    } else if (angleDiff >= 200 && angleDiff <= 340) {
      direction = 'Belok kiri';
    } else {
      direction = 'Putar balik';
    }

    return '$direction menuju tujuan';
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    double dLon = (lon2 - lon1) * (math.pi / 180);
    lat1 = lat1 * (math.pi / 180);
    lat2 = lat2 * (math.pi / 180);

    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360;
  }

  double _calculateRemainingDistance(Position currentPos) {
    if (_currentPath.isEmpty) return 0;

    double totalDistance = _calculateDistance(
      currentPos.latitude,
      currentPos.longitude,
      _currentPath[_currentStepIndex].latitude,
      _currentPath[_currentStepIndex].longitude,
    );

    for (int i = _currentStepIndex; i < _currentPath.length - 1; i++) {
      totalDistance += _calculateDistance(
        _currentPath[i].latitude,
        _currentPath[i].longitude,
        _currentPath[i + 1].latitude,
        _currentPath[i + 1].longitude,
      );
    }

    return totalDistance;
  }

  int _calculateEstimatedTime(Position currentPos) {
    final distance = _calculateRemainingDistance(currentPos);
    const double walkingSpeed = 1.4; // m/s
    return (distance / walkingSpeed).ceil();
  }

  bool isInBorobudurArea(double lat, double lon) {
    final distance = _calculateDistance(
      lat, lon, 
      BorobudurArea.centerLat, BorobudurArea.centerLon
    );
    return distance <= BorobudurArea.maxDistance;
  }

  Position getCurrentLocationForTesting() {
    // Use dummy location for testing
    return Position(
      latitude: dummyUserLocation.latitude,
      longitude: dummyUserLocation.longitude,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  // Dummy position simulation for step-by-step testing
  int _dummyStepIndex = 0;
  
  void startDummyNavigationSimulation() {
    if (!_isNavigating || _currentPath.isEmpty) return;
    
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isNavigating || _dummyStepIndex >= _currentPath.length) {
        timer.cancel();
        return;
      }
      
      final currentStep = _currentPath[_dummyStepIndex];
      final dummyPosition = Position(
        latitude: currentStep.latitude,
        longitude: currentStep.longitude,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 1.4, // Walking speed
        speedAccuracy: 0.0,
      );
      
      _currentPosition = dummyPosition;
      _positionStreamController?.add(dummyPosition);
      _updateNavigation(dummyPosition);
      
      _dummyStepIndex++;
    });
  }
  
  void resetDummySimulation() {
    _dummyStepIndex = 0;
  }

  void dispose() {
    _positionStreamController?.close();
    _navigationUpdateController?.close();
    _apiService.dispose();
  }
}