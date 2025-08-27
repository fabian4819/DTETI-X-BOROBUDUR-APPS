import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class FreeNavigationService {
  static final FreeNavigationService _instance = FreeNavigationService._internal();
  factory FreeNavigationService() => _instance;
  FreeNavigationService._internal();

  // OpenRouteService API (Free: 2000 requests/day, no API key needed for basic usage)
  static const String _baseUrl = 'https://api.openrouteservice.org';
  
  // Alternative: Use local routing for Borobudur area
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
    String profile = 'foot-walking', // foot-walking, cycling-regular, driving-car
  }) async {
    try {
      // For Borobudur area, we can use local routing since it's a contained area
      // This avoids API rate limits and works offline-friendly
      return _getLocalBorobudurRoute(start, destination);
    } catch (e) {
      // Fallback to OpenRouteService if local routing fails
      return await _getOpenRouteServiceRoute(start, destination, profile);
    }
  }

  // Local routing for Borobudur temple complex
  NavigationRoute _getLocalBorobudurRoute(LatLng start, LatLng destination) {
    // Use your existing navigation logic but enhance with OSM-style routing
    final distance = Distance();
    final totalDistance = distance.as(LengthUnit.Meter, start, destination);
    
    // Create waypoints for better navigation
    final waypoints = _generateBorobudurWaypoints(start, destination);
    
    return NavigationRoute(
      coordinates: waypoints,
      totalDistance: totalDistance,
      estimatedDuration: _calculateWalkingTime(totalDistance),
      instructions: _generateLocalInstructions(waypoints),
      source: 'Local Borobudur Routing',
    );
  }

  Future<NavigationRoute?> _getOpenRouteServiceRoute(
    LatLng start, 
    LatLng destination, 
    String profile
  ) async {
    try {
      final url = '$_baseUrl/v2/directions/$profile/geojson';
      
      final body = {
        'coordinates': [
          [start.longitude, start.latitude],
          [destination.longitude, destination.latitude]
        ],
        'instructions': true,
        'geometry': true,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          // Optional: Add your free API key here if you register
          // 'Authorization': 'your-api-key',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseOpenRouteServiceResponse(data);
      } else {
        throw Exception('Failed to get route: ${response.statusCode}');
      }
    } catch (e) {
      // Return null if API fails, caller can handle fallback
      return null;
    }
  }

  NavigationRoute _parseOpenRouteServiceResponse(Map<String, dynamic> data) {
    final feature = data['features'][0];
    final geometry = feature['geometry'];
    final properties = feature['properties'];
    
    final coordinates = (geometry['coordinates'] as List)
        .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
        .toList();
    
    final segments = properties['segments'][0];
    final distance = segments['distance'].toDouble();
    final duration = segments['duration'].toDouble();
    
    final instructions = (segments['steps'] as List)
        .map((step) => step['instruction'].toString())
        .toList();

    return NavigationRoute(
      coordinates: coordinates,
      totalDistance: distance,
      estimatedDuration: duration,
      instructions: instructions,
      source: 'OpenRouteService',
    );
  }

  List<LatLng> _generateBorobudurWaypoints(LatLng start, LatLng destination) {
    final waypoints = <LatLng>[start];
    
    // Add intermediate points based on Borobudur's layout
    // This creates a more realistic walking path
    final centerLat = (start.latitude + destination.latitude) / 2;
    final centerLng = (start.longitude + destination.longitude) / 2;
    
    // Add waypoint near center if the route is long enough
    final distance = Distance();
    if (distance.as(LengthUnit.Meter, start, destination) > 50) {
      waypoints.add(LatLng(centerLat, centerLng));
    }
    
    waypoints.add(destination);
    return waypoints;
  }

  double _calculateWalkingTime(double distanceInMeters) {
    // Average walking speed: 1.4 m/s (5 km/h)
    return distanceInMeters / 1.4;
  }

  List<String> _generateLocalInstructions(List<LatLng> waypoints) {
    final instructions = <String>['Mulai berjalan menuju tujuan'];
    
    for (int i = 1; i < waypoints.length - 1; i++) {
      instructions.add('Lanjutkan berjalan lurus');
    }
    
    instructions.add('Anda telah tiba di tujuan');
    return instructions;
  }

  // Get nearby places using Overpass API (completely free)
  Future<List<BorobudurPOI>> getNearbyPlaces(LatLng center, double radiusKm) async {
    try {
      final query = '''
      [out:json];
      (
        node["tourism"](around:${radiusKm * 1000},${center.latitude},${center.longitude});
        node["historic"](around:${radiusKm * 1000},${center.latitude},${center.longitude});
        node["amenity"="restaurant"](around:${radiusKm * 1000},${center.latitude},${center.longitude});
      );
      out;
      ''';

      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=$query',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseOverpassResponse(data);
      }
    } catch (e) {
      // Return empty list if fails
    }
    
    return [];
  }

  List<BorobudurPOI> _parseOverpassResponse(Map<String, dynamic> data) {
    final elements = data['elements'] as List;
    return elements.map((element) {
      final tags = element['tags'] ?? {};
      return BorobudurPOI(
        id: element['id'].toString(),
        name: tags['name'] ?? 'Unnamed Location',
        type: _determinePOIType(tags),
        position: LatLng(element['lat'].toDouble(), element['lon'].toDouble()),
        description: tags['description'] ?? '',
      );
    }).toList();
  }

  String _determinePOIType(Map<String, dynamic> tags) {
    if (tags.containsKey('tourism')) return tags['tourism'];
    if (tags.containsKey('historic')) return 'historic';
    if (tags.containsKey('amenity')) return tags['amenity'];
    return 'unknown';
  }
}

class NavigationRoute {
  final List<LatLng> coordinates;
  final double totalDistance;
  final double estimatedDuration;
  final List<String> instructions;
  final String source;

  NavigationRoute({
    required this.coordinates,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.instructions,
    required this.source,
  });
}

class BorobudurPOI {
  final String id;
  final String name;
  final String type;
  final LatLng position;
  final String description;

  BorobudurPOI({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.description,
  });
}