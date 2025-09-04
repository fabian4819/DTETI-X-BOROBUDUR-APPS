/// Direct representation of temple nodes from API
class TempleNode {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final String? description;

  TempleNode({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.description,
  });

  factory TempleNode.fromGraphFeature(dynamic feature) {
    final geometry = feature['geometry'];
    final properties = feature['properties'];
    final coordinates = geometry['coordinates'] as List;
    
    return TempleNode(
      id: properties['id'] as int,
      name: properties['name'] as String,
      latitude: coordinates[1].toDouble(), // API returns [lon, lat]
      longitude: coordinates[0].toDouble(),
      type: _determineNodeType(properties['name'] as String),
      description: properties['name'] as String,
    );
  }

  factory TempleNode.fromApiFeature(dynamic feature) {
    final geometry = feature.geometry;
    final properties = feature.properties;
    final coordinates = geometry.pointCoordinates!;
    
    return TempleNode(
      id: properties.id!,
      name: properties.name ?? 'Unknown Node',
      latitude: coordinates[1],
      longitude: coordinates[0],
      type: properties.type ?? 'NODE',
      description: properties.description ?? properties.name,
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
    final levelMatch = RegExp(r'LANTAI(\d+)').firstMatch(name.toUpperCase());
    if (levelMatch != null) {
      return int.tryParse(levelMatch.group(1) ?? '1') ?? 1;
    }
    if (name.toUpperCase().contains('STUPA')) return 9;
    return 1;
  }

  @override
  String toString() => 'TempleNode(id: $id, name: $name, type: $type)';
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
  });

  factory TempleFeature.fromApiFeature(dynamic feature) {
    final geometry = feature.geometry;
    final properties = feature.properties;
    final coordinates = geometry.pointCoordinates!;
    
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
    );
  }

  int get level {
    final levelMatch = RegExp(r'LANTAI(\d+)').firstMatch(name.toUpperCase());
    if (levelMatch != null) {
      return int.tryParse(levelMatch.group(1) ?? '1') ?? 1;
    }
    if (name.toUpperCase().contains('STUPA')) return 9;
    return 1;
  }

  @override
  String toString() => 'TempleFeature(id: $id, name: $name, type: $type)';
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