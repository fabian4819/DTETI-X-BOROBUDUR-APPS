class MapConfig {
  // MapTiler API Configuration
  // Get your free API key from: https://maptiler.com/
  // Free tier includes: 100,000 map loads per month
  // Sign up at https://cloud.maptiler.com/account/
  
  static const String mapTilerApiKey = 'jc4j4uffD0fuzidaTZUi';
  
  // MapTiler OMT (OpenMapTiles) templates - supports 3D buildings and floor layers
  static const Map<String, String> tileTemplates = {
    'MapTiler OMT Basic': 'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}.png?key=$mapTilerApiKey',
    'MapTiler OMT Streets': 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$mapTilerApiKey',
    'MapTiler 3D Buildings': 'https://api.maptiler.com/maps/3d/{z}/{x}/{y}.png?key=$mapTilerApiKey',
    'MapTiler Satellite': 'https://api.maptiler.com/maps/hybrid/{z}/{x}/{y}.jpg?key=$mapTilerApiKey',
    'OpenStreetMap': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  };
  
  // Vector tile template for 3D building data
  static String get vectorTileUrl => 'https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key=$mapTilerApiKey';
  
  // Map settings
  static const double defaultZoom = 18.0;
  static const double minZoom = 10.0;
  static const double maxZoom = 20.0;
  
  // User agent for tile requests
  static const String userAgent = 'com.example.borobudur_app';
  
  // Check if MapTiler API key is configured
  static bool get isMapTilerConfigured => 
      mapTilerApiKey.isNotEmpty && mapTilerApiKey != 'your_maptiler_api_key_here';
  
  // Get tile URL for a layer
  static String getTileUrl(String layerName) {
    if (!isMapTilerConfigured && layerName.startsWith('MapTiler')) {
      // Fallback to OpenStreetMap if MapTiler not configured
      return tileTemplates['OpenStreetMap'] ?? '';
    }
    return tileTemplates[layerName] ?? tileTemplates['OpenStreetMap'] ?? '';
  }
  
  // Get available layers (hide MapTiler options if not configured)
  static List<String> get availableLayers {
    if (isMapTilerConfigured) {
      return tileTemplates.keys.toList();
    } else {
      return ['OpenStreetMap'];
    }
  }
}