import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_point.dart';
import '../models/api_models.dart';
import '../data/borobudur_data.dart';
import 'api_service.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final ApiService _apiService = ApiService();
  
  StreamController<Position>? _positionStreamController;
  StreamController<NavigationUpdate>? _navigationUpdateController;
  
  Position? _currentPosition;
  List<LocationPoint> _currentPath = [];
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  LocationPoint? _destination;
  
  // Graph data from API
  Map<String, List<String>> _adjacencyList = {};
  Map<String, LocationPoint> _locationMap = {};
  final Map<int, LocationPoint> _apiNodeMap = {}; // Maps API node IDs to LocationPoints
  final List<LocationPoint> _allFeatures = []; // All temple features
  
  // Loading states
  bool _isLoadingGraph = false;
  bool _isLoadingFeatures = false;

  Stream<Position>? get positionStream => _positionStreamController?.stream;
  Stream<NavigationUpdate>? get navigationUpdateStream => _navigationUpdateController?.stream;
  
  bool get isNavigating => _isNavigating;
  Position? get currentPosition => _currentPosition;
  List<LocationPoint> get currentPath => _currentPath;
  int get currentStepIndex => _currentStepIndex;
  
  // Expose loading states
  bool get isLoadingGraph => _isLoadingGraph;
  bool get isLoadingFeatures => _isLoadingFeatures;
  
  // Expose features data
  List<LocationPoint> get allFeatures => List.unmodifiable(_allFeatures);
  List<LocationPoint> get allNodes => List.unmodifiable(_locationMap.values);

  void initialize() {
    // Initialize streams first
    _positionStreamController = StreamController<Position>.broadcast();
    _navigationUpdateController = StreamController<NavigationUpdate>.broadcast();
    
    // Load temple graph and features from API
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

  // Parse temple graph data from API
  Future<void> _parseTempleGraph(GraphData graphData) async {
    final newLocationMap = <String, LocationPoint>{};
    final newAdjacencyList = <String, List<String>>{};
    final nodeIdMap = <int, LocationPoint>{}; // API node ID to LocationPoint

    // Clear existing data to use only API data
    _locationMap.clear();
    _adjacencyList.clear();
    _apiNodeMap.clear();

    // Parse nodes (Points)
    for (final feature in graphData.features) {
      if (feature.geometry.isPoint && feature.properties.id != null) {
        final coordinates = feature.geometry.pointCoordinates!;
        final nodeId = feature.properties.id!;
        final name = feature.properties.name ?? 'Unknown Node';
        
        final locationPoint = LocationPoint(
          id: 'API_NODE_$nodeId',
          name: name,
          latitude: coordinates[1], // API returns [lon, lat]
          longitude: coordinates[0],
          type: _determineNodeType(name),
          description: name,
          level: _extractLevelFromName(name),
        );

        newLocationMap[locationPoint.id] = locationPoint;
        nodeIdMap[nodeId] = locationPoint;
        _apiNodeMap[nodeId] = locationPoint;
      }
    }

    // Parse edges (LineStrings)
    for (final feature in graphData.features) {
      if (feature.geometry.isLineString && 
          feature.properties.source != null && 
          feature.properties.target != null) {
        final sourceId = feature.properties.source!;
        final targetId = feature.properties.target!;
        
        final sourceNode = nodeIdMap[sourceId];
        final targetNode = nodeIdMap[targetId];
        
        if (sourceNode != null && targetNode != null) {
          // Add bidirectional connection
          newAdjacencyList.putIfAbsent(sourceNode.id, () => []).add(targetNode.id);
          newAdjacencyList.putIfAbsent(targetNode.id, () => []).add(sourceNode.id);
        }
      }
    }

    // Use only API data
    _locationMap = newLocationMap;
    _adjacencyList = newAdjacencyList;
  }

  // Load all temple features (stupas, etc.)
  Future<void> _loadTempleFeatures() async {
    try {
      // Load different types of features
      final allFeatures = <LocationPoint>[];
      
      // Load stupas
      final stupas = await getTempleFeatures(type: 'stupa', limit: 100);
      allFeatures.addAll(stupas);
      
      // Load other features if needed
      final otherFeatures = await getTempleFeatures(limit: 200);
      for (final feature in otherFeatures) {
        if (!allFeatures.any((existing) => existing.id == feature.id)) {
          allFeatures.add(feature);
        }
      }
      
      _allFeatures.clear();
      _allFeatures.addAll(allFeatures);
      
    } catch (e) {
      debugPrint('Failed to load temple features: $e');
    }
  }

  String _determineNodeType(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('stupa')) return 'STUPA';
    if (nameLower.contains('lantai')) return 'FOUNDATION';
    if (nameLower.contains('tangga')) return 'GATE';
    return 'NODE';
  }

  int _extractLevelFromName(String name) {
    final levelMatch = RegExp(r'LANTAI(\d+)').firstMatch(name.toUpperCase());
    if (levelMatch != null) {
      return int.tryParse(levelMatch.group(1) ?? '1') ?? 1;
    }
    if (name.toUpperCase().contains('STUPA')) return 9;
    return 1;
  }

  void dispose() {
    _positionStreamController?.close();
    _navigationUpdateController?.close();
    _apiService.dispose();
  }

  // Local graph building is no longer needed - using API graph only

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

  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> startLocationTracking() async {
    if (!await requestLocationPermission()) {
      throw Exception('Location permission not granted');
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _currentPosition = position;
        _positionStreamController?.add(position);
        
        if (_isNavigating) {
          _updateNavigation(position);
        }
      },
    );

    // Get initial position
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      _positionStreamController?.add(_currentPosition!);
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
        currentStep: nextStep,
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

  String _getDirectionInstruction(int stepIndex) {
    if (stepIndex >= _currentPath.length - 1) {
      return 'Lanjutkan menuju ${_currentPath[stepIndex].name}';
    }

    if (stepIndex == 0) {
      return 'Mulai dari ${_currentPath[stepIndex].name}';
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

    return '$direction menuju ${next.name}';
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

  Future<NavigationResult> startNavigation(LocationPoint start, LocationPoint destination) async {
    // First try API-based routing if we have API nodes
    List<LocationPoint> path = [];
    
    // Try to find corresponding API nodes for start and destination
    final startApiNode = _findClosestApiNode(start);
    final destApiNode = _findClosestApiNode(destination);
    
    if (startApiNode != null && destApiNode != null) {
      path = await _getApiRoute(
        fromLat: start.latitude,
        fromLon: start.longitude,
        toNodeId: _getApiNodeId(destApiNode),
      );
    }
    
    // Fallback to local pathfinding if API route fails or unavailable
    if (path.isEmpty) {
      path = _findPathDijkstra(start, destination);
    }
    
    if (path.isEmpty) {
      return NavigationResult(success: false, message: 'Rute tidak ditemukan');
    }

    _currentPath = path;
    _destination = destination;
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
  }

  // Get route from API
  Future<List<LocationPoint>> _getApiRoute({
    double? fromLat,
    double? fromLon,
    int? fromNodeId,
    double? toLat,
    double? toLon,
    int? toNodeId,
    String profile = 'walking',
  }) async {
    try {
      final routeResponse = await _apiService.getNavigationRoute(
        fromLat: fromLat,
        fromLon: fromLon,
        fromNodeId: fromNodeId,
        toLat: toLat,
        toLon: toLon,
        toNodeId: toNodeId,
        profile: profile,
      );
      
      if (routeResponse != null && routeResponse.code == 200) {
        return _parseNavigationRoute(routeResponse.data);
      }
    } catch (e) {
      debugPrint('Failed to get API route: $e');
    }
    
    return [];
  }

  List<LocationPoint> _parseNavigationRoute(RouteData routeData) {
    final waypoints = <LocationPoint>[];

    for (final feature in routeData.features) {
      if (feature.geometry.isLineString) {
        final coordinates = feature.geometry.lineCoordinates!;
        
        // Convert LineString coordinates to waypoints
        for (int i = 0; i < coordinates.length; i++) {
          final coord = coordinates[i];
          waypoints.add(LocationPoint(
            id: 'ROUTE_WAYPOINT_$i',
            name: 'Route Point ${i + 1}',
            latitude: coord[1],
            longitude: coord[0],
            type: 'WAYPOINT',
            description: 'Navigation waypoint',
          ));
        }
      }
    }

    return waypoints;
  }

  LocationPoint? _findClosestApiNode(LocationPoint point) {
    LocationPoint? closest;
    double minDistance = double.infinity;

    for (final apiNode in _apiNodeMap.values) {
      final distance = _calculateDistance(
        point.latitude, point.longitude,
        apiNode.latitude, apiNode.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closest = apiNode;
      }
    }

    // Only return if within reasonable distance (50 meters)
    return (minDistance < 50.0) ? closest : null;
  }

  int? _getApiNodeId(LocationPoint apiNode) {
    // Extract API node ID from the location point ID
    final match = RegExp(r'API_NODE_(\d+)').firstMatch(apiNode.id);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  void stopNavigation() {
    _isNavigating = false;
    _currentPath.clear();
    _currentStepIndex = 0;
    _destination = null;
    resetDummySimulation();
  }

  List<LocationPoint> _findPathDijkstra(LocationPoint start, LocationPoint end) {
    var distances = <String, double>{};
    var previous = <String, String>{};
    var pq = PriorityQueue<MapEntry<String, double>>((a, b) => a.value.compareTo(b.value));

    for (var locId in _locationMap.keys) {
      distances[locId] = double.infinity;
    }
    distances[start.id] = 0;
    pq.add(MapEntry(start.id, 0));

    while (pq.isNotEmpty) {
      var currentId = pq.removeFirst().key;

      if (currentId == end.id) {
        List<LocationPoint> path = [];
        var tempId = end.id;
        while (previous.containsKey(tempId)) {
          path.insert(0, _locationMap[tempId]!);
          tempId = previous[tempId]!;
        }
        path.insert(0, start);
        return path;
      }

      if (_adjacencyList[currentId] == null) continue;

      for (var neighborId in _adjacencyList[currentId]!) {
        var startNode = _locationMap[currentId]!;
        var endNode = _locationMap[neighborId]!;
        var distance = _calculateDistance(startNode.latitude, startNode.longitude, endNode.latitude, endNode.longitude);
        var newDist = distances[currentId]! + distance;

        if (newDist < distances[neighborId]!) {
          distances[neighborId] = newDist;
          previous[neighborId] = currentId;
          pq.add(MapEntry(neighborId, newDist));
        }
      }
    }
    return [];
  }

  double _calculateTotalDistance(List<LocationPoint> path) {
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

  LocationPoint? findNearestLocation(double lat, double lon, {double maxDistance = 50}) {
    LocationPoint? nearest;
    double minDistance = maxDistance;

    // Check both local and API locations
    for (final location in _locationMap.values) {
      final distance = _calculateDistance(lat, lon, location.latitude, location.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = location;
      }
    }

    return nearest;
  }

  // Get nearest features from API
  Future<List<LocationPoint>> getNearestFeatures({
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

  // Get temple features with pagination
  Future<List<LocationPoint>> getTempleFeatures({
    String? type,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final featuresResponse = await _apiService.getTempleFeatures(
        type: type,
        page: page,
        limit: limit,
      );
      
      if (featuresResponse != null && featuresResponse.code == 200) {
        return _parseTempleFeatures(featuresResponse.data);
      }
    } catch (e) {
      debugPrint('Failed to get temple features: $e');
    }
    
    return [];
  }

  List<LocationPoint> _parseTempleFeatures(FeaturesData data) {
    final locationPoints = <LocationPoint>[];

    for (final feature in data.features) {
      if (feature.geometry.isPoint && feature.properties.id != null) {
        final coordinates = feature.geometry.pointCoordinates!;
        final locationPoint = LocationPoint(
          id: 'FEATURE_${feature.properties.id}',
          name: feature.properties.name ?? 'Unknown Feature',
          latitude: coordinates[1],
          longitude: coordinates[0],
          type: (feature.properties.type ?? 'FEATURE').toUpperCase(),
          description: feature.properties.description ?? '',
        );
        locationPoints.add(locationPoint);
      }
    }

    return locationPoints;
  }

  // Get features by type from loaded data
  List<LocationPoint> getFeaturesByType(String type) {
    return _allFeatures.where((feature) => 
        feature.type.toLowerCase() == type.toLowerCase()).toList();
  }

  // Get all available feature types
  Set<String> getAvailableFeatureTypes() {
    return _allFeatures.map((feature) => feature.type).toSet();
  }

  // Find nearby features from loaded data
  List<LocationPoint> findNearbyFeaturesLocal({
    required double lat,
    required double lon,
    double maxDistance = 200.0,
    int limit = 10,
    String? type,
  }) {
    var features = _allFeatures.where((feature) {
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

  bool isInBorobudurArea(double lat, double lon) {
    final distance = _calculateDistance(
      lat, lon, 
      BorobudurArea.centerLat, BorobudurArea.centerLon
    );
    return distance <= BorobudurArea.maxDistance;
  }

  Position getCurrentLocationForTesting() {
    // Menggunakan lokasi dummy untuk testing
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
}

class NavigationResult {
  final bool success;
  final String message;
  final List<LocationPoint>? path;
  final double? totalDistance;
  final int? estimatedTime;

  NavigationResult({
    required this.success,
    required this.message,
    this.path,
    this.totalDistance,
    this.estimatedTime,
  });
}

class NavigationUpdate {
  final LocationPoint currentStep;
  final double distanceToNextStep;
  final String instruction;
  final double remainingDistance;
  final int estimatedTime;
  final int stepIndex;
  final int totalSteps;
  final bool hasArrived;

  NavigationUpdate({
    required this.currentStep,
    required this.distanceToNextStep,
    required this.instruction,
    required this.remainingDistance,
    required this.estimatedTime,
    required this.stepIndex,
    required this.totalSteps,
    this.hasArrived = false,
  });
}