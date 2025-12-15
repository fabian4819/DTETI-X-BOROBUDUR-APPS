import 'dart:math';

/// Helper class for location-based operations
class LocationHelper {
  // Borobudur Temple coordinates
  static const double BOROBUDUR_LATITUDE = -7.6079;
  static const double BOROBUDUR_LONGITUDE = 110.2038;
  static const double BOROBUDUR_RADIUS_METERS = 200.0; // Detection radius
  
  /// Check if given coordinates are within Borobudur complex
  /// Returns true if within 200m radius of Borobudur center
  static bool isAtBorobudur(double latitude, double longitude) {
    final distance = calculateDistance(
      latitude,
      longitude,
      BOROBUDUR_LATITUDE,
      BOROBUDUR_LONGITUDE,
    );
    return distance <= BOROBUDUR_RADIUS_METERS;
  }
  
  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
