/// Direct representation of temple nodes from API
class TempleNode {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final String? description;
  final double? altitude; // Altitude in meters above sea level

  TempleNode({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.description,
    this.altitude,
  });

  factory TempleNode.fromGraphFeature(dynamic feature) {
    final geometry = feature['geometry'];
    final properties = feature['properties'];
    final coordinates = geometry['coordinates'] as List;

    // Handle 2D [lon, lat] or 3D [lon, lat, altitude] coordinates
    double? altitude;
    if (coordinates.length >= 3) {
      altitude = (coordinates[2] as num).toDouble();
    }

    return TempleNode(
      id: properties['id'] as int,
      name: properties['name'] as String,
      latitude: coordinates[1].toDouble(), // API returns [lon, lat]
      longitude: coordinates[0].toDouble(),
      type: _determineNodeType(properties['name'] as String),
      description: properties['name'] as String,
      altitude: altitude ?? properties['altitude']?.toDouble(),
    );
  }

  factory TempleNode.fromApiFeature(dynamic feature) {
    final geometry = feature.geometry;
    final properties = feature.properties;
    final coordinates = geometry.pointCoordinates!;

    // Handle 2D [lon, lat] or 3D [lon, lat, altitude] coordinates
    double? altitude;
    if (coordinates.length >= 3) {
      altitude = coordinates[2];
    }

    return TempleNode(
      id: properties.id!,
      name: properties.name ?? 'Unknown Node',
      latitude: coordinates[1],
      longitude: coordinates[0],
      type: properties.type ?? 'NODE',
      description: properties.description ?? properties.name,
      altitude: altitude ?? properties.altitude?.toDouble(),
    );
  }

  static String _determineNodeType(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('stupa')) return 'STUPA';
    if (nameLower.contains('lantai')) return 'FOUNDATION';
    if (nameLower.contains('tangga')) return 'GATE';
    return 'NODE';
  }

  int get level {
    // Try to extract level from name first
    final levelMatch = RegExp(r'LANTAI(\d+)').firstMatch(name.toUpperCase());
    if (levelMatch != null) {
      return int.tryParse(levelMatch.group(1) ?? '1') ?? 1;
    }

    // Check for stupa levels - USER DEFINED MAPPING
    final nameUpper = name.toUpperCase();
    
    // DASAR_STUPA = Level 5
    if (nameUpper.contains('DASAR_STUPA') || nameUpper.contains('DASAR STUPA')) {
      return 5;
    }
    
    // STUPA1 = Level 6
    if (nameUpper.contains('STUPA1')) {
      return 6;
    }
    
    // STUPA2 = Level 7
    if (nameUpper.contains('STUPA2')) {
      return 7;
    }
    
    // STUPA3 = Level 8
    if (nameUpper.contains('STUPA3')) {
      return 8;
    }
    
    // Generic STUPA (fallback) - use altitude if available
    if (nameUpper.contains('STUPA')) {
      if (altitude != null) {
        return _calculateLevelFromAltitude(altitude!);
      }
      return 6; // Default to level 6 for generic stupa
    }

    // Use altitude if available for precise level detection
    if (altitude != null) {
      return _calculateLevelFromAltitude(altitude!);
    }

    return 1; // Default to ground level
  }

  /// Calculate temple level from altitude (rough approximation for Borobudur)
  int _calculateLevelFromAltitude(double altitude) {
    // Borobudur temple approximate level heights
    if (altitude < 15.0) return 1;  // Ground level
    if (altitude < 25.0) return 2;
    if (altitude < 35.0) return 3;
    if (altitude < 45.0) return 4;
    if (altitude < 55.0) return 5;
    if (altitude < 65.0) return 6;
    if (altitude < 75.0) return 7;
    if (altitude < 85.0) return 8;
    return 9; // Top level
  }

  /// Get estimated elevation from temple level
  double? get estimatedElevation {
    switch (level) {
      case 1: return 7.5;   // Average of 0-15m
      case 2: return 20.0;  // Average of 15-25m
      case 3: return 30.0;  // Average of 25-35m
      case 4: return 40.0;  // Average of 35-45m
      case 5: return 50.0;  // Average of 45-55m
      case 6: return 60.0;  // Average of 55-65m
      case 7: return 70.0;  // Average of 65-75m
      case 8: return 80.0;  // Average of 75-85m
      case 9: return 92.5;  // Average of 85-100m
      default: return null;
    }
  }

  @override
  String toString() => 'TempleNode(id: $id, name: $name, type: $type, level: $level, altitude: ${altitude?.toStringAsFixed(1) ?? 'null'})';
}

/// Direct representation of temple edges from API
class TempleEdge {
  final int id;
  final int sourceId;
  final int targetId;
  final double cost;
  final double reverseCost;

  TempleEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.cost,
    required this.reverseCost,
  });

  factory TempleEdge.fromGraphFeature(dynamic feature) {
    final properties = feature['properties'];
    
    return TempleEdge(
      id: properties['id'] as int,
      sourceId: properties['source'] as int,
      targetId: properties['target'] as int,
      cost: (properties['cost'] as num).toDouble(),
      reverseCost: (properties['reverse_cost'] as num).toDouble(),
    );
  }

  factory TempleEdge.fromApiFeature(dynamic feature) {
    final properties = feature.properties;
    
    return TempleEdge(
      id: properties.id!,
      sourceId: properties.source!,
      targetId: properties.target!,
      cost: properties.cost ?? 1.0,
      reverseCost: properties.reverseCost ?? 1.0,
    );
  }

  @override
  String toString() => 'TempleEdge(id: $id, source: $sourceId, target: $targetId, cost: $cost)';
}

/// Temple feature (stupa, etc.) from API
class TempleFeature {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final String? description;
  final String? imageUrl;
  final double? rating;
  final double? distanceM;
  final double? altitude; // Altitude in meters above sea level

  TempleFeature({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.description,
    this.imageUrl,
    this.rating,
    this.distanceM,
    this.altitude,
  });

  factory TempleFeature.fromApiFeature(dynamic feature) {
    final geometry = feature.geometry;
    final properties = feature.properties;
    final coordinates = geometry.pointCoordinates!;

    // Handle 2D [lon, lat] or 3D [lon, lat, altitude] coordinates
    double? altitude;
    if (coordinates.length >= 3) {
      altitude = coordinates[2];
    }

    return TempleFeature(
      id: properties.id!,
      name: properties.name ?? 'Unknown Feature',
      latitude: coordinates[1],
      longitude: coordinates[0],
      type: properties.type ?? 'FEATURE',
      description: properties.description,
      imageUrl: properties.imageUrl,
      rating: properties.rating,
      distanceM: properties.distanceM,
      altitude: altitude ?? properties.altitude?.toDouble(),
    );
  }

  int get level {
    // Try to extract level from name first
    final levelMatch = RegExp(r'LANTAI(\d+)').firstMatch(name.toUpperCase());
    if (levelMatch != null) {
      return int.tryParse(levelMatch.group(1) ?? '1') ?? 1;
    }

    // Check for stupa (typically on upper levels)
    if (name.toUpperCase().contains('STUPA')) {
      // Use altitude if available for more precise level detection
      if (altitude != null) {
        return _calculateLevelFromAltitude(altitude!);
      }
      return 9; // Default to top level for stupas
    }

    // Use altitude if available for precise level detection
    if (altitude != null) {
      return _calculateLevelFromAltitude(altitude!);
    }

    return 1; // Default to ground level
  }

  /// Calculate temple level from altitude (rough approximation for Borobudur)
  int _calculateLevelFromAltitude(double altitude) {
    // Borobudur temple approximate level heights
    if (altitude < 15.0) return 1;  // Ground level
    if (altitude < 25.0) return 2;
    if (altitude < 35.0) return 3;
    if (altitude < 45.0) return 4;
    if (altitude < 55.0) return 5;
    if (altitude < 65.0) return 6;
    if (altitude < 75.0) return 7;
    if (altitude < 85.0) return 8;
    return 9; // Top level
  }

  /// Get estimated elevation from temple level
  double? get estimatedElevation {
    switch (level) {
      case 1: return 7.5;   // Average of 0-15m
      case 2: return 20.0;  // Average of 15-25m
      case 3: return 30.0;  // Average of 25-35m
      case 4: return 40.0;  // Average of 35-45m
      case 5: return 50.0;  // Average of 45-55m
      case 6: return 60.0;  // Average of 55-65m
      case 7: return 70.0;  // Average of 65-75m
      case 8: return 80.0;  // Average of 75-85m
      case 9: return 92.5;  // Average of 85-100m
      default: return null;
    }
  }

  @override
  String toString() => 'TempleFeature(id: $id, name: $name, type: $type, level: $level, altitude: ${altitude?.toStringAsFixed(1) ?? 'null'})';
}

/// Navigation route waypoint from API
class RouteWaypoint {
  final double latitude;
  final double longitude;
  final int index;

  RouteWaypoint({
    required this.latitude,
    required this.longitude,
    required this.index,
  });

  @override
  String toString() => 'RouteWaypoint(index: $index, lat: $latitude, lon: $longitude)';
}

/// Navigation update information
class NavigationUpdate {
  final TempleNode? currentStep;
  final double distanceToNextStep;
  final String instruction;
  final double remainingDistance;
  final int estimatedTime;
  final int stepIndex;
  final int totalSteps;
  final bool hasArrived;

  NavigationUpdate({
    this.currentStep,
    required this.distanceToNextStep,
    required this.instruction,
    required this.remainingDistance,
    required this.estimatedTime,
    required this.stepIndex,
    required this.totalSteps,
    this.hasArrived = false,
  });
}

/// Navigation result
class NavigationResult {
  final bool success;
  final String message;
  final List<RouteWaypoint>? path;
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