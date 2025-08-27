import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../models/location_point.dart';
import '../../data/borobudur_data.dart';
import '../../services/free_navigation_service.dart';
import '../../services/voice_guidance_service.dart';
import '../../utils/app_colors.dart';

class FreeNavigationScreen extends StatefulWidget {
  const FreeNavigationScreen({super.key});

  @override
  State<FreeNavigationScreen> createState() => _FreeNavigationScreenState();
}

class _FreeNavigationScreenState extends State<FreeNavigationScreen> 
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final FreeNavigationService _navigationService = FreeNavigationService();
  final VoiceGuidanceService _voiceService = VoiceGuidanceService();
  
  // Navigation states
  LocationPoint? selectedLocation;
  LocationPoint? destinationLocation;
  LocationPoint? startLocation;
  bool isNavigating = false;
  bool useCustomStartLocation = false;
  bool _isVoiceEnabled = true;
  
  // Map data
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  NavigationRoute? _currentRoute;
  String searchQuery = '';
  List<LocationPoint> filteredLocations = [];
  
  // Current position
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Map settings
  String _currentTileLayer = 'OpenStreetMap';
  static const double _initialZoom = 18.0;
  static const LatLng _borobudurCenter = LatLng(-7.6079, 110.2038);
  
  @override
  void initState() {
    super.initState();
    filteredLocations = borobudurLocations;
    _initializeAnimations();
    _initializeVoiceGuidance();
    _initializeLocationTracking();
    _setupMarkers();
    
    // Center map on Borobudur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_borobudurCenter, _initialZoom);
    });
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  Future<void> _initializeVoiceGuidance() async {
    await _voiceService.initialize();
  }
  
  Future<void> _initializeLocationTracking() async {
    try {
      // Use dummy location for testing
      _currentPosition = Position(
        latitude: -7.6079,
        longitude: 110.2038,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      
      Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          setState(() {
            _setupMarkers();
          });
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      _showLocationPermissionDialog();
    }
  }
  
  void _setupMarkers() {
    _markers.clear();
    
    // Add location markers
    for (final location in borobudurLocations) {
      final isSelected = selectedLocation?.id == location.id;
      final isDestination = destinationLocation?.id == location.id;
      final isStart = startLocation?.id == location.id;
      
      Color markerColor = _getMarkerColor(location, isSelected, isDestination, isStart);
      
      _markers.add(
        Marker(
          point: LatLng(location.latitude, location.longitude),
          width: isDestination || isStart ? 60 : 40,
          height: isDestination || isStart ? 60 : 40,
          child: GestureDetector(
            onTap: () => _onMarkerTapped(location),
            child: Container(
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(76),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getLocationIcon(location),
                color: Colors.white,
                size: isDestination || isStart ? 24 : 18,
              ),
            ),
          ),
        ),
      );
    }
    
    // Add current location marker
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 40,
          height: 40,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }
  
  void _onMarkerTapped(LocationPoint location) {
    setState(() {
      selectedLocation = location;
      if (!useCustomStartLocation) {
        destinationLocation = location;
      }
    });
    
    _setupMarkers();
    _showLocationBottomSheet(location);
  }
  
  Future<void> _startNavigation() async {
    if (destinationLocation == null) return;

    LatLng startPos;
    if (useCustomStartLocation && startLocation != null) {
      startPos = LatLng(startLocation!.latitude, startLocation!.longitude);
    } else if (_currentPosition != null) {
      startPos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      _showSnackBar('Cannot determine start location', Colors.red);
      return;
    }

    final destPos = LatLng(destinationLocation!.latitude, destinationLocation!.longitude);
    
    setState(() {
      isNavigating = true;
    });

    try {
      final route = await _navigationService.getRoute(
        start: startPos,
        destination: destPos,
        profile: 'foot-walking',
      );

      if (route != null) {
        _currentRoute = route;
        _updateRoutePolyline();
        
        if (_isVoiceEnabled) {
          await _voiceService.announceNavigationStart(
            destinationLocation!.name,
            route.estimatedDuration.toInt(),
          );
        }
        
        _showNavigationDialog(route);
      } else {
        _showSnackBar('Could not calculate route', Colors.red);
        setState(() {
          isNavigating = false;
        });
      }
    } catch (e) {
      _showSnackBar('Navigation error: $e', Colors.red);
      setState(() {
        isNavigating = false;
      });
    }
  }
  
  void _updateRoutePolyline() {
    if (_currentRoute == null) return;
    
    _polylines.clear();
    _polylines.add(
      Polyline(
        points: _currentRoute!.coordinates,
        color: AppColors.primary,
        strokeWidth: 4.0,
      ),
    );
    
    setState(() {});
  }
  
  void _stopNavigation() {
    setState(() {
      isNavigating = false;
      _currentRoute = null;
      _polylines.clear();
    });
    
    if (_isVoiceEnabled) {
      _voiceService.speak('Navigasi dihentikan');
    }
  }
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _pulseController.dispose();
    _voiceService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Navigasi Borobudur',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          // Map Layer Toggle
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers, color: Colors.black),
            onSelected: (layer) {
              setState(() {
                _currentTileLayer = layer;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'OpenStreetMap',
                child: Text('OpenStreetMap'),
              ),
              const PopupMenuItem(
                value: 'Satellite',
                child: Text('Satellite (Esri)'),
              ),
              const PopupMenuItem(
                value: 'Terrain',
                child: Text('Terrain'),
              ),
            ],
          ),
          // Voice Toggle
          IconButton(
            icon: Icon(
              _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: _isVoiceEnabled ? AppColors.primary : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isVoiceEnabled = !_isVoiceEnabled;
                _voiceService.setEnabled(_isVoiceEnabled);
              });
            },
          ),
          if (isNavigating)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              onPressed: _stopNavigation,
            ),
        ],
      ),
      body: Column(
        children: [
          // Navigation Info Panel
          if (isNavigating && _currentRoute != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 24,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Navigasi Aktif',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _stopNavigation,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavInfo(
                        Icons.straighten,
                        '${_currentRoute!.totalDistance.toStringAsFixed(0)}m',
                        'Distance',
                      ),
                      _buildNavInfo(
                        Icons.schedule,
                        '${(_currentRoute!.estimatedDuration / 60).ceil()} min',
                        'Time',
                      ),
                      _buildNavInfo(
                        Icons.source,
                        _currentRoute!.source,
                        'Source',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _borobudurCenter,
                    initialZoom: _initialZoom,
                    minZoom: 10.0,
                    maxZoom: 20.0,
                    onTap: _onMapTapped,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _getTileTemplate(),
                      userAgentPackageName: 'com.example.borobudur_app',
                      maxNativeZoom: 19,
                    ),
                    PolylineLayer(polylines: _polylines),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom Control Panel
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildControlPanel(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white.withAlpha(204)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(204),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Setup Navigasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 16),
        
        // Custom start toggle
        SwitchListTile(
          title: const Text('Custom Start Location'),
          subtitle: Text(startLocation?.name ?? 'Use current location'),
          value: useCustomStartLocation,
          activeColor: AppColors.primary,
          onChanged: (value) {
            setState(() {
              useCustomStartLocation = value;
              if (!value) startLocation = null;
            });
          },
        ),
        
        if (destinationLocation != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(_getLocationIcon(destinationLocation!), color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destinationLocation!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Level ${destinationLocation!.level}',
                        style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
                      ),
                    ],
                  ),
                ),
                if (!isNavigating)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _startNavigation,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  String _getTileTemplate() {
    switch (_currentTileLayer) {
      case 'Satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'Terrain':
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
      default: // OpenStreetMap
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }
  
  void _onMapTapped(TapPosition tapPosition, LatLng position) {
    // Find nearest location
    LocationPoint? nearest;
    double minDistance = double.infinity;
    
    for (final location in borobudurLocations) {
      final distance = Distance().as(
        LengthUnit.Meter,
        LatLng(location.latitude, location.longitude),
        position,
      );
      
      if (distance < minDistance && distance < 50) {
        minDistance = distance;
        nearest = location;
      }
    }
    
    if (nearest != null) {
      _onMarkerTapped(nearest);
    }
  }
  
  Color _getMarkerColor(LocationPoint location, bool isSelected, bool isDestination, bool isStart) {
    if (isDestination) return AppColors.accent;
    if (isStart) return Colors.green;
    if (isSelected) return AppColors.primary;
    
    switch (location.type) {
      case 'FOUNDATION':
        return Colors.brown;
      case 'GATE':
        return Colors.blue;
      case 'STUPA':
        return AppColors.accent;
      default:
        return AppColors.secondary;
    }
  }
  
  IconData _getLocationIcon(LocationPoint location) {
    switch (location.type) {
      case 'FOUNDATION': return Icons.circle;
      case 'GATE': return Icons.door_front_door;
      case 'STUPA': return Icons.account_balance;
      default: return Icons.location_on;
    }
  }
  
  void _showLocationBottomSheet(LocationPoint location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getLocationIcon(location),
                          color: _getMarkerColor(location, false, false, false),
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Level ${location.level} • ${location.type}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      location.description.isNotEmpty 
                          ? location.description
                          : 'Titik bersejarah di Candi Borobudur',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.flag, size: 20),
                            label: const Text('Set Destination'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                destinationLocation = location;
                              });
                              Navigator.pop(context);
                              _setupMarkers();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (useCustomStartLocation)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow, size: 20),
                              label: const Text('Set Start'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                setState(() {
                                  startLocation = location;
                                });
                                Navigator.pop(context);
                                _setupMarkers();
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showNavigationDialog(NavigationRoute route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.navigation, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            const Text('Navigasi Dimulai'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ke: ${destinationLocation!.name}'),
            const SizedBox(height: 8),
            Text('Jarak: ${route.totalDistance.toStringAsFixed(0)}m'),
            Text('Waktu: ~${(route.estimatedDuration / 60).ceil()} menit'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopNavigation();
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mulai'),
          ),
        ],
      ),
    );
  }
  
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Location Access'),
          ],
        ),
        content: const Text(
          'This app needs location access for navigation. Using test location for demo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }
}