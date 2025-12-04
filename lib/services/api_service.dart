import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/api_models.dart';

class ApiService {
  static const String _baseUrl = 'https://borobudurbackend.context.my.id';
  static const Duration _timeout = Duration(seconds: 30);

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  // Create HTTP client that allows self-signed certificates for development
  http.Client _createHttpClient() {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      debugPrint('SSL Certificate warning for $host:$port - accepting for development');
      return true; // Accept all certificates for development
    };
    return IOClient(httpClient);
  }

  // Graph endpoint - get nodes and edges for temple mapping
  Future<GraphResponse?> getTempleGraph() async {
    final uri = Uri.parse('$_baseUrl/v1/temples/graph');

    debugPrint('Fetching temple graph from: $uri');
    final client = _createHttpClient();
    try {
      final response = await client
          .get(uri, headers: _getHeaders())
          .timeout(_timeout);
      
      debugPrint('Graph API response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return GraphResponse.fromJson(jsonData);
      } else {
        debugPrint('Graph API error body: ${response.body}');
        throw ApiException('Failed to fetch temple graph: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw ApiException('Network error: $e');
    } finally {
      client.close();
    }
  }

  // Features endpoint - get temple features
  Future<FeaturesResponse?> getTempleFeatures() async {
    final uri = Uri.parse('$_baseUrl/v1/temples/features');

    debugPrint('Fetching temple features from: $uri');
    final client = _createHttpClient();
    try {
      final response = await client
          .get(uri, headers: _getHeaders())
          .timeout(_timeout);

      debugPrint('Features API response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return FeaturesResponse.fromJson(jsonData);
      } else {
        debugPrint('Features API error body: ${response.body}');
        throw ApiException('Failed to fetch temple features: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Network error: $e');
    } finally {
      client.close();
    }
  }

  // Nearest features endpoint - get features near current location
  Future<FeaturesResponse?> getNearestFeatures({
    required double lat,
    required double lon,
    double radius = 200.0,
    int limit = 10,
    String? type,
  }) async {
    final queryParams = {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radius': radius.toString(),
      'limit': limit.toString(),
    };
    
    if (type != null) {
      queryParams['type'] = type;
    }

    final uri = Uri.parse('$_baseUrl/v1/temples/features/nearest').replace(
      queryParameters: queryParams,
    );

    final client = _createHttpClient();
    try {
      final response = await client
          .get(uri, headers: _getHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return FeaturesResponse.fromJson(jsonData);
      } else {
        throw ApiException('Failed to fetch nearest features: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Network error: $e');
    } finally {
      client.close();
    }
  }

  // Route endpoint - get navigation route between two points
  Future<RouteResponse?> getNavigationRoute({
    double? fromLat,
    double? fromLon,
    int? fromNodeId,
    double? toLat,
    double? toLon,
    int? toNodeId,
    String profile = 'walking',
  }) async {
    final queryParams = <String, String>{
      'profile': profile,
    };

    // Add source parameters
      if (fromLat != null && fromLon != null) {
        queryParams['fromLat'] = fromLat.toString();
        queryParams['fromLon'] = fromLon.toString();
      } else if (fromNodeId != null) {
        queryParams['fromNodeId'] = fromNodeId.toString();
      } else {
        throw ApiException('Either fromLat/fromLon or fromNodeId must be provided');
      }

      // Add destination parameters
      if (toLat != null && toLon != null) {
        queryParams['toLat'] = toLat.toString();
        queryParams['toLon'] = toLon.toString();
      } else if (toNodeId != null) {
        queryParams['toNodeId'] = toNodeId.toString();
      } else {
        throw ApiException('Either toLat/toLon or toNodeId must be provided');
      }

      final uri = Uri.parse('$_baseUrl/v1/temples/navigation/route').replace(
        queryParameters: queryParams,
      );

      debugPrint('Route API URL: $uri');
      debugPrint('Route API params: $queryParams');

      final client = _createHttpClient();
      try {
        final response = await client
            .get(uri, headers: _getHeaders())
            .timeout(_timeout);

        debugPrint('Route API response: ${response.statusCode}');
        debugPrint('Route API body: ${response.body}');

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          return RouteResponse.fromJson(jsonData);
        } else {
          throw ApiException('Failed to get navigation route: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        throw ApiException('Network error: $e');
      } finally {
        client.close();
      }
  }

  // Helper method to get standard headers
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // Cache management for offline capabilities
  final Map<String, CacheEntry> _cache = {};

  Future<T?> _getCachedOrFetch<T>(
    String cacheKey,
    Future<T?> Function() fetchFunction, {
    Duration cacheDuration = const Duration(minutes: 30),
  }) async {
    // Check cache first
    final cached = _cache[cacheKey];
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) < cacheDuration) {
      return cached.data as T?;
    }

    // Fetch new data
    try {
      final result = await fetchFunction();
      if (result != null) {
        _cache[cacheKey] = CacheEntry(data: result, timestamp: DateTime.now());
      }
      return result;
    } catch (e) {
      // Return cached data if available, even if expired
      if (cached != null) {
        return cached.data as T?;
      }
      rethrow;
    }
  }

  // Cached version of graph fetch
  Future<GraphResponse?> getTempleGraphCached() {
    const cacheKey = 'temple_graph';
    return _getCachedOrFetch(
      cacheKey,
      () => getTempleGraph(),
      cacheDuration: const Duration(hours: 1),
    );
  }

  // Clean up resources
  void dispose() {
    // No client to close since we use http directly
    _cache.clear();
  }

  // Clear cache manually
  void clearCache() {
    _cache.clear();
  }

  // Check if we have cached data for offline use
  bool hasCachedGraph() {
    return _cache.keys.any((key) => key.startsWith('graph_'));
  }
}

class CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  CacheEntry({required this.data, required this.timestamp});
}

class ApiException implements Exception {
  final String message;
  
  ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}