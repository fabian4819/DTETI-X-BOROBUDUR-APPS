import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../../models/location_point.dart';
import '../../data/borobudur_data.dart';
import '../../services/navigation_service.dart';
import '../../services/voice_guidance_service.dart';
import '../../services/custom_marker_service.dart';
import '../../utils/app_colors.dart';
import 'temple_navigation_screen.dart';

class EnhancedNavigationScreen extends StatefulWidget {
  const EnhancedNavigationScreen({super.key});

  @override
  State<EnhancedNavigationScreen> createState() => _EnhancedNavigationScreenState();
}

class _EnhancedNavigationScreenState extends State<EnhancedNavigationScreen> 
    with TickerProviderStateMixin {
  final NavigationService _navigationService = NavigationService();
  final VoiceGuidanceService _voiceService = VoiceGuidanceService();
  final CustomMarkerService _markerService = CustomMarkerService();
  
  // Google Maps Controller
  GoogleMapController? _mapController;
  
  // Current view mode
  ViewMode _currentViewMode = ViewMode.satellite;
  
  // Navigation states
  LocationPoint? selectedLocation;
  LocationPoint? destinationLocation;
  LocationPoint? startLocation;
  bool isNavigating = false;
  bool useCustomStartLocation = false;
  bool _isVoiceEnabled = true;
  
  // Map data
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String searchQuery = '';
  List<LocationPoint> filteredLocations = [];
  
  // Streaming data
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<NavigationUpdate>? _navigationSubscription;
  Position? _currentPosition;
  NavigationUpdate? _currentNavigationUpdate;
  
  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Camera constants for Borobudur
  static const CameraPosition _borobudurLocation = CameraPosition(
    target: LatLng(-7.6079, 110.2038), // Borobudur coordinates
    zoom: 18.0,
    tilt: 45.0,
  );
  
  @override
  void initState() {
    super.initState();
    filteredLocations = borobudurLocations;
    _navigationService.initialize();
    _initializeAnimations();
    _initializeVoiceGuidance();
    _initializeLocationTracking();
    _setupMarkers();
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
      _currentPosition = _navigationService.getCurrentLocationForTesting();
      
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _currentPosition = _navigationService.getCurrentLocationForTesting();
          });
          _updateCurrentLocationMarker();
        } else {
          timer.cancel();
        }
      });

      _navigationSubscription = _navigationService.navigationUpdateStream?.listen((update) {
        setState(() {
          _currentNavigationUpdate = update;
        });
        
        if (_isVoiceEnabled && update.instruction.isNotEmpty) {
          _voiceService.speakNavigationInstruction(update.instruction);
        }
        
        if (update.hasArrived) {
          _stopNavigation();
          _showArrivalDialog();
        }
      });
    } catch (e) {
      _showLocationPermissionDialog();
    }
  }
  
  
  Future<void> _setupMarkers() async {
    _markers.clear();
    
    for (final location in borobudurLocations) {
      final isSelected = selectedLocation?.id == location.id;
      final isDestination = destinationLocation?.id == location.id;
      final isStart = startLocation?.id == location.id;
      
      final customIcon = await _markerService.getCustomMarker(
        location,
        isSelected: isSelected,
        isDestination: isDestination,
        isStart: isStart,
      );
      
      final marker = Marker(
        markerId: MarkerId(location.id),
        position: LatLng(location.latitude, location.longitude),
        icon: customIcon,
        infoWindow: InfoWindow(
          title: location.name,
          snippet: '${location.description} • Level ${location.level}',
          onTap: () => _onMarkerTapped(location),
        ),
        onTap: () => _onMarkerTapped(location),
      );
      _markers.add(marker);
    }
    
    await _updateCurrentLocationMarker();
    if (mounted) setState(() {});
  }
  
  Future<void> _updateCurrentLocationMarker() async {
    if (_currentPosition == null) return;
    
    _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
    
    final customIcon = await _markerService.getCurrentLocationMarker();
    
    final currentMarker = Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      icon: customIcon,
      infoWindow: const InfoWindow(
        title: 'Lokasi Anda',
        snippet: 'Posisi saat ini',
      ),
    );
    
    _markers.add(currentMarker);
  }
  
  
  void _onMarkerTapped(LocationPoint location) {
    setState(() {
      selectedLocation = location;
      if (!useCustomStartLocation) {
        destinationLocation = location;
      }
    });
    
    _setupMarkers(); // Refresh markers with new selection
    _showLocationBottomSheet(location);
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
                          _getIconForType(location.type),
                          color: _getColorForType(location.type),
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
                            label: const Text('Set as Tujuan'),
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
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (useCustomStartLocation)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow, size: 20),
                              label: const Text('Set as Start'),
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
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (destinationLocation != null && destinationLocation!.id == location.id)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.navigation, size: 20),
                          label: const Text('Mulai Navigasi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _startNavigation();
                          },
                        ),
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
  
  Future<void> _startNavigation() async {
    if (destinationLocation == null) return;

    LocationPoint? actualStartLocation;

    if (useCustomStartLocation && startLocation != null) {
      actualStartLocation = startLocation;
    } else {
      _currentPosition ??= _navigationService.getCurrentLocationForTesting();
      
      if (!_navigationService.isInBorobudurArea(_currentPosition!.latitude, _currentPosition!.longitude)) {
        _showOutOfAreaWarning();
        return;
      }

      actualStartLocation = _navigationService.findNearestLocation(
        _currentPosition!.latitude, 
        _currentPosition!.longitude,
        maxDistance: 50,
      );
    }

    if (actualStartLocation == null) {
      _showSnackBar('Tidak dapat menemukan titik awal yang valid', Colors.orange);
      return;
    }

    try {
      final result = await _navigationService.startNavigation(actualStartLocation, destinationLocation!);
      
      if (result.success) {
        setState(() {
          isNavigating = true;
        });
        
        _updateNavigationPolyline();
        _showNavigationStartDialog(result, actualStartLocation);
        _navigationService.startDummyNavigationSimulation();
        
        if (_isVoiceEnabled) {
          await _voiceService.announceNavigationStart(
            destinationLocation!.name, 
            result.estimatedTime!.toInt()
          );
        }
      } else {
        _showSnackBar(result.message, Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error memulai navigasi', Colors.red);
    }
  }
  
  void _updateNavigationPolyline() {
    _polylines.clear();
    
    if (_navigationService.currentPath.length > 1) {
      final pathPoints = _navigationService.currentPath
          .map((location) => LatLng(location.latitude, location.longitude))
          .toList();
      
      final polyline = Polyline(
        polylineId: const PolylineId('navigation_route'),
        points: pathPoints,
        color: AppColors.primary,
        width: 5,
        patterns: [PatternItem.dash(10), PatternItem.gap(5)],
      );
      
      _polylines.add(polyline);
    }
    
    setState(() {});
  }
  
  void _stopNavigation() {
    _navigationService.stopNavigation();
    setState(() {
      isNavigating = false;
      _polylines.clear();
    });
    
    if (_isVoiceEnabled) {
      _voiceService.speak('Navigasi dihentikan');
    }
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
  
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _navigationSubscription?.cancel();
    _pulseController.dispose();
    _navigationService.dispose();
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
          'Enhanced Navigation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          // View Mode Toggle
          PopupMenuButton<ViewMode>(
            icon: Icon(
              _currentViewMode == ViewMode.satellite 
                  ? Icons.satellite_alt 
                  : _currentViewMode == ViewMode.terrain
                      ? Icons.terrain
                      : Icons.map,
              color: Colors.black,
            ),
            onSelected: (mode) {
              setState(() {
                _currentViewMode = mode;
              });
              _updateMapType();
            },
            itemBuilder: (context) => ViewMode.values
                .map((mode) => PopupMenuItem(
                      value: mode,
                      child: Row(
                        children: [
                          Icon(_getViewModeIcon(mode)),
                          const SizedBox(width: 8),
                          Text(_getViewModeLabel(mode)),
                        ],
                      ),
                    ))
                .toList(),
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
          // 3D View Toggle
          IconButton(
            icon: const Icon(Icons.view_in_ar, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TempleNavigationScreen()),
              );
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
          // Real-time Navigation Panel
          if (isNavigating && _currentNavigationUpdate != null)
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildNavigationPanel(),
            ),
          
          // Google Maps View
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
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: _borobudurLocation,
                  mapType: _getMapType(),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  onTap: _onMapTapped,
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
  
  Widget _buildNavigationPanel() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: const Icon(Icons.navigation, color: Colors.white, size: 24),
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
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getDirectionIcon(_currentNavigationUpdate!.instruction),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentNavigationUpdate!.instruction,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Menuju ${_currentNavigationUpdate!.currentStep.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavInfo(
                    Icons.straighten,
                    '${_currentNavigationUpdate!.distanceToNextStep.toStringAsFixed(0)}m',
                    'Jarak',
                  ),
                  _buildNavInfo(
                    Icons.schedule,
                    '${(_currentNavigationUpdate!.estimatedTime / 60).ceil()} min',
                    'Waktu',
                  ),
                  _buildNavInfo(
                    Icons.location_on,
                    '${_currentNavigationUpdate!.stepIndex + 1}/${_currentNavigationUpdate!.totalSteps}',
                    'Progress',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Navigation Setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
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
                Icon(_getIconForType(destinationLocation!.type), color: AppColors.accent),
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
                    label: const Text('Navigate'),
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
  
  Widget _buildNavInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMapType();
  }
  
  void _onMapTapped(LatLng position) {
    // Find nearest location point to tap
    LocationPoint? nearestLocation;
    double minDistance = double.infinity;
    
    for (final location in borobudurLocations) {
      final distance = _calculateDistance(
        position.latitude, 
        position.longitude, 
        location.latitude, 
        location.longitude
      );
      
      if (distance < minDistance && distance < 0.01) { // 10m threshold
        minDistance = distance;
        nearestLocation = location;
      }
    }
    
    if (nearestLocation != null) {
      _onMarkerTapped(nearestLocation);
    }
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  void _updateMapType() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _borobudurLocation.target,
          zoom: _borobudurLocation.zoom,
          tilt: _borobudurLocation.tilt,
        ),
      ),
    );
  }
  
  MapType _getMapType() {
    switch (_currentViewMode) {
      case ViewMode.satellite:
        return MapType.satellite;
      case ViewMode.terrain:
        return MapType.terrain;
      case ViewMode.normal:
        return MapType.normal;
      case ViewMode.hybrid:
        return MapType.hybrid;
    }
  }
  
  IconData _getViewModeIcon(ViewMode mode) {
    switch (mode) {
      case ViewMode.satellite:
        return Icons.satellite_alt;
      case ViewMode.terrain:
        return Icons.terrain;
      case ViewMode.normal:
        return Icons.map;
      case ViewMode.hybrid:
        return Icons.layers;
    }
  }
  
  String _getViewModeLabel(ViewMode mode) {
    switch (mode) {
      case ViewMode.satellite:
        return 'Satellite';
      case ViewMode.terrain:
        return 'Terrain';
      case ViewMode.normal:
        return 'Normal';
      case ViewMode.hybrid:
        return 'Hybrid';
    }
  }
  
  // Helper functions from original screen
  IconData _getDirectionIcon(String instruction) {
    if (instruction.contains('kanan')) return Icons.turn_right;
    if (instruction.contains('kiri')) return Icons.turn_left;
    if (instruction.contains('Lurus')) return Icons.straight;
    if (instruction.contains('Putar balik')) return Icons.u_turn_left;
    if (instruction.contains('Mulai')) return Icons.play_arrow;
    return Icons.navigation;
  }
  
  IconData _getIconForType(String type) {
    switch (type) {
      case 'FOUNDATION': return Icons.circle;
      case 'GATE': return Icons.door_front_door;
      case 'STUPA': return Icons.account_balance;
      default: return Icons.location_on;
    }
  }
  
  Color _getColorForType(String type) {
    switch (type) {
      case 'FOUNDATION': return Colors.brown;
      case 'GATE': return AppColors.primary;
      case 'STUPA': return AppColors.accent;
      default: return AppColors.secondary;
    }
  }
  
  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppColors.accent, size: 28),
            const SizedBox(width: 12),
            const Text('Selamat!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Anda telah tiba di ${destinationLocation?.name ?? "tujuan"}!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
  
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Izin Lokasi'),
          ],
        ),
        content: const Text(
          'Aplikasi memerlukan akses lokasi untuk memberikan navigasi real-time.',
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
  
  void _showOutOfAreaWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Di Luar Jangkauan'),
          ],
        ),
        content: const Text(
          'Anda berada di luar area Candi Borobudur. '
          'Navigasi hanya tersedia di dalam kompleks candi.',
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
  
  void _showNavigationStartDialog(NavigationResult result, LocationPoint startLocation) {
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
            Text('Dari: ${startLocation.name}'),
            Text('Ke: ${destinationLocation!.name}'),
            const SizedBox(height: 8),
            Text('Jarak: ${result.totalDistance!.toStringAsFixed(0)}m'),
            Text('Estimasi: ~${(result.estimatedTime! / 60).ceil()} menit'),
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
}

enum ViewMode {
  satellite,
  terrain,
  normal,
  hybrid,
}