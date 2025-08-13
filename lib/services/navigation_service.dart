import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_point.dart';
import '../data/borobudur_data.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  StreamController<Position>? _positionStreamController;
  StreamController<NavigationUpdate>? _navigationUpdateController;
  
  Position? _currentPosition;
  List<LocationPoint> _currentPath = [];
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  LocationPoint? _destination;
  
  // Graph untuk pathfinding
  late Map<String, List<String>> _adjacencyList;
  late Map<String, LocationPoint> _locationMap;

  Stream<Position>? get positionStream => _positionStreamController?.stream;
  Stream<NavigationUpdate>? get navigationUpdateStream => _navigationUpdateController?.stream;
  
  bool get isNavigating => _isNavigating;
  Position? get currentPosition => _currentPosition;
  List<LocationPoint> get currentPath => _currentPath;
  int get currentStepIndex => _currentStepIndex;

  void initialize() {
    _locationMap = {for (var loc in borobudurLocations) loc.id: loc};
    _adjacencyList = _buildGraph();
    _positionStreamController = StreamController<Position>.broadcast();
    _navigationUpdateController = StreamController<NavigationUpdate>.broadcast();
  }

  void dispose() {
    _positionStreamController?.close();
    _navigationUpdateController?.close();
  }

  Map<String, List<String>> _buildGraph() {
    final Map<String, List<String>> graph = {};
    final foundations = getFoundationsInOrder(); // Menggunakan helper function yang sudah diurutkan
    final gates = getGates();

    // 1. Connect foundations in sequential square order (straight lines, not circular)
    // Group foundations by level first
    final foundationsByLevel = <int, List<LocationPoint>>{};
    for (final foundation in foundations) {
      foundationsByLevel.putIfAbsent(foundation.level, () => []).add(foundation);
    }
    
    // Connect foundations within each level in square pattern
    for (final levelFoundations in foundationsByLevel.values) {
      levelFoundations.sort((a, b) => a.foundationIndex.compareTo(b.foundationIndex));
      
      for (int i = 0; i < levelFoundations.length; i++) {
        final current = levelFoundations[i];
        final next = levelFoundations[(i + 1) % levelFoundations.length];
        
        // Connect current to next (square perimeter path)
        graph.putIfAbsent(current.id, () => []).add(next.id);
        graph.putIfAbsent(next.id, () => []).add(current.id);
      }
    }

    // 2. Connect foundations to nearest gates (untuk akses ke level lain)
    for (final foundation in foundations) {
      LocationPoint? closestGate;
      double minDistance = double.infinity;

      for (final gate in gates) {
        final distance = _calculateDistance(foundation.latitude, foundation.longitude, gate.latitude, gate.longitude);
        if (distance < minDistance && distance < 30) { // Hanya jika dalam radius 30m
          minDistance = distance;
          closestGate = gate;
        }
      }

      if (closestGate != null) {
        graph.putIfAbsent(foundation.id, () => []).add(closestGate.id);
        graph.putIfAbsent(closestGate.id, () => []).add(foundation.id);
      }
    }

    // 3. Connect gates to each other (untuk perpindahan antar gerbang)
    for (final gate1 in gates) {
      for (final gate2 in gates) {
        if (gate1.id != gate2.id) {
          graph.putIfAbsent(gate1.id, () => []).add(gate2.id);
        }
      }
    }

    return graph;
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
      print('Error getting initial position: $e');
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
    final path = _findPathDijkstra(start, destination);
    
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

    for (final location in borobudurLocations) {
      final distance = _calculateDistance(lat, lon, location.latitude, location.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = location;
      }
    }

    return nearest;
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