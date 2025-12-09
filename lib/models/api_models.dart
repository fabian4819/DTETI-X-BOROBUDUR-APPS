class GraphResponse {
  final String status;
  final String message;
  final GraphData data;
  final int code;

  GraphResponse({
    required this.status,
    required this.message,
    required this.data,
    required this.code,
  });

  factory GraphResponse.fromJson(Map<String, dynamic> json) {
    return GraphResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: GraphData.fromJson(json['data'] ?? {}),
      code: json['code'] ?? 200,
    );
  }
}

class GraphData {
  final String type;
  final List<GraphFeature> features;

  GraphData({
    required this.type,
    required this.features,
  });

  factory GraphData.fromJson(Map<String, dynamic> json) {
    return GraphData(
      type: json['type'] ?? 'FeatureCollection',
      features: (json['features'] as List<dynamic>? ?? [])
          .map((feature) => GraphFeature.fromJson(feature))
          .toList(),
    );
  }
}

class GraphFeature {
  final String type;
  final GraphGeometry geometry;
  final GraphProperties properties;

  GraphFeature({
    required this.type,
    required this.geometry,
    required this.properties,
  });

  factory GraphFeature.fromJson(Map<String, dynamic> json) {
    return GraphFeature(
      type: json['type'] ?? 'Feature',
      geometry: GraphGeometry.fromJson(json['geometry'] ?? {}),
      properties: GraphProperties.fromJson(json['properties'] ?? {}),
    );
  }
}

class GraphGeometry {
  final String type;
  final dynamic coordinates; // Can be List<double> for Point or List<List<double>> for LineString

  GraphGeometry({
    required this.type,
    required this.coordinates,
  });

  factory GraphGeometry.fromJson(Map<String, dynamic> json) {
    return GraphGeometry(
      type: json['type'] ?? 'Point',
      coordinates: json['coordinates'],
    );
  }

  bool get isPoint => type == 'Point';
  bool get isLineString => type == 'LineString';

  List<double>? get pointCoordinates => isPoint ? List<double>.from(coordinates) : null;
  List<List<double>>? get lineCoordinates => isLineString 
      ? (coordinates as List).map<List<double>>((coord) => List<double>.from(coord)).toList()
      : null;
}

class GraphProperties {
  final int? id;
  final String? name;
  final String? type;
  final String? description;
  final String? imageUrl;
  final double? rating;
  final int? source;
  final int? target;
  final double? cost;
  final double? reverseCost;
  final double? distanceM;
  final double? altitude;

  GraphProperties({
    this.id,
    this.name,
    this.type,
    this.description,
    this.imageUrl,
    this.rating,
    this.source,
    this.target,
    this.cost,
    this.reverseCost,
    this.distanceM,
    this.altitude,
  });

  factory GraphProperties.fromJson(Map<String, dynamic> json) {
    return GraphProperties(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      imageUrl: json['image_url'],
      rating: json['rating']?.toDouble(),
      source: json['source'],
      target: json['target'],
      cost: json['cost']?.toDouble(),
      reverseCost: json['reverse_cost']?.toDouble(),
      distanceM: json['distance_m']?.toDouble(),
      altitude: json['altitude_m']?.toDouble() ?? json['altitude']?.toDouble(), // Support both altitude_m and altitude
    );
  }
}

class FeaturesResponse {
  final String status;
  final String message;
  final FeaturesData data;
  final int code;

  FeaturesResponse({
    required this.status,
    required this.message,
    required this.data,
    required this.code,
  });

  factory FeaturesResponse.fromJson(Map<String, dynamic> json) {
    return FeaturesResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: FeaturesData.fromJson(json['data'] ?? {}),
      code: json['code'] ?? 200,
    );
  }
}

class FeaturesData {
  final String type;
  final List<GraphFeature> features;
  final Pagination? pagination;

  FeaturesData({
    required this.type,
    required this.features,
    this.pagination,
  });

  factory FeaturesData.fromJson(Map<String, dynamic> json) {
    return FeaturesData(
      type: json['type'] ?? 'FeatureCollection',
      features: (json['features'] as List<dynamic>? ?? [])
          .map((feature) => GraphFeature.fromJson(feature))
          .toList(),
      pagination: json['pagination'] != null 
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class Pagination {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final bool hasNextPage;
  final bool hasPreviousPage;

  Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      totalItems: json['totalItems'] ?? 0,
      itemsPerPage: json['itemsPerPage'] ?? 10,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPreviousPage: json['hasPreviousPage'] ?? false,
    );
  }
}

class RouteResponse {
  final String status;
  final String message;
  final RouteData data;
  final int code;

  RouteResponse({
    required this.status,
    required this.message,
    required this.data,
    required this.code,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    return RouteResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: RouteData.fromJson(json['data'] ?? {}),
      code: json['code'] ?? 200,
    );
  }
}

class RouteData {
  final String type;
  final List<RouteFeature> features;
  final String? error;

  RouteData({
    required this.type,
    required this.features,
    this.error,
  });

  factory RouteData.fromJson(Map<String, dynamic> json) {
    // Check if this is an error response
    if (json['error'] != null) {
      return RouteData(
        type: json['type'] ?? 'FeatureCollection',
        features: [],
        error: json['error'] as String?,
      );
    }

    return RouteData(
      type: json['type'] ?? 'FeatureCollection',
      features: (json['features'] as List<dynamic>? ?? [])
          .map((feature) => RouteFeature.fromJson(feature))
          .toList(),
    );
  }
}

class RouteFeature {
  final String type;
  final GraphGeometry geometry;
  final RouteProperties properties;

  RouteFeature({
    required this.type,
    required this.geometry,
    required this.properties,
  });

  factory RouteFeature.fromJson(Map<String, dynamic> json) {
    return RouteFeature(
      type: json['type'] ?? 'Feature',
      geometry: GraphGeometry.fromJson(json['geometry'] ?? {}),
      properties: RouteProperties.fromJson(json['properties'] ?? {}),
    );
  }
}

class RouteProperties {
  final double distanceM;
  final String profile;

  RouteProperties({
    required this.distanceM,
    required this.profile,
  });

  factory RouteProperties.fromJson(Map<String, dynamic> json) {
    return RouteProperties(
      distanceM: (json['distance_m'] ?? 0.0).toDouble(),
      profile: json['profile'] ?? 'walking',
    );
  }
}