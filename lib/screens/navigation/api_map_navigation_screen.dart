import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/temple_node.dart';
import '../../services/temple_navigation_service.dart';
import '../../utils/app_colors.dart';
import '../../config/map_config.dart';

class ApiMapNavigationScreen extends StatefulWidget {
  const ApiMapNavigationScreen({super.key});

  @override
  State<ApiMapNavigationScreen> createState() => _ApiMapNavigationScreenState();
}

class _ApiMapNavigationScreenState extends State<ApiMapNavigationScreen> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final TempleNavigationService _navigationService = TempleNavigationService();
  final FlutterTts _flutterTts = FlutterTts();
  
  // Navigation states
  TempleNode? selectedNode;
  TempleFeature? selectedFeature;
  TempleNode? destinationNode;
  TempleFeature? destinationFeature;
  
  // Start location options
  TempleNode? startNode;
  TempleFeature? startFeature;
  bool useCurrentLocation = true; // true = GPS, false = custom location
  
  bool isNavigating = false;
  
  // Voice guidance
  bool _isVoiceEnabled = true;
  String _lastSpokenInstruction = '';
  
  // Map data
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  List<RouteWaypoint> _currentRoute = [];
  String searchQuery = '';
  
  // Current position
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<NavigationUpdate>? _navigationSubscription;
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Map settings - default to Satellite for better Borobudur visualization
  String _currentTileLayer = MapConfig.isMapTilerConfigured ? 'MapTiler Satellite' : MapConfig.availableLayers.first;
  static const double _initialZoom = MapConfig.defaultZoom;
  
  // Borobudur center coordinates
  static const LatLng _borobudurCenter = LatLng(-7.607874, 110.203751);
  
  // UI states
  bool _showLoadingOverlay = false;
  NavigationUpdate? _currentNavigationUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationService.initialize();
    _initializeAnimations();
    _initializeVoiceGuidance();
    _initializeLocationTracking();
    _setupInitialMarkersAndPolylines();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Check permission when user returns to app (from settings)
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermissionStatus();
    }
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
  
  Future<void> _checkLocationPermissionStatus() async {
    final hasPermission = await _navigationService.requestLocationPermission();
    if (hasPermission && useCurrentLocation && mounted) {
      // Re-initialize location tracking if permission was just granted
      _initializeLocationTracking();
    }
  }

  void _initializeVoiceGuidance() async {
    try {
      await _flutterTts.setLanguage("id-ID"); // Indonesian language
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(0.8);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('Voice guidance initialization failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _navigationSubscription?.cancel();
    _pulseController.dispose();
    _flutterTts.stop();
    _navigationService.dispose();
    super.dispose();
  }
  
  Future<void> _speakInstruction(String instruction) async {
    if (_isVoiceEnabled && instruction != _lastSpokenInstruction) {
      try {
        await _flutterTts.speak(instruction);
        _lastSpokenInstruction = instruction;
      } catch (e) {
        debugPrint('Voice guidance error: $e');
      }
    }
  }

  Future<void> _initializeLocationTracking() async {
    try {
      // Get initial position
      _currentPosition = _navigationService.getCurrentLocationForTesting();
      
      await _navigationService.startLocationTracking();
      
      _positionSubscription = _navigationService.positionStream?.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _setupMarkers();
          });
        }
      });

      _navigationSubscription = _navigationService.navigationUpdateStream?.listen((update) {
        if (mounted) {
          setState(() {
            _currentNavigationUpdate = update;
          });
          
          // Voice guidance for navigation instructions
          if (update.instruction.isNotEmpty) {
            _speakInstruction(update.instruction);
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize location tracking: $e');
      _showLocationPermissionDialog();
    }
  }
  
  void _setupInitialMarkersAndPolylines() {
    // Wait a bit for API data to load
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_navigationService.isLoadingGraph && !_navigationService.isLoadingFeatures) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _setupMarkers();
            _setupPolylines();
          });
        }
      } else if (timer.tick > 30) { // Timeout after 30 seconds
        timer.cancel();
      }
    });
  }
  
  void _setupMarkers() {
    _markers.clear();
    
    // Add temple node markers from API
    for (final node in _navigationService.nodes.values) {
      final isSelected = selectedNode?.id == node.id;
      final isDestination = destinationNode?.id == node.id;
      final isStart = startNode?.id == node.id;
      
      Color markerColor = _getNodeMarkerColor(node, isSelected, isDestination, isStart);
      double markerSize = (isDestination || isStart) ? 50 : 35;
      
      _markers.add(
        Marker(
          point: LatLng(node.latitude, node.longitude),
          width: markerSize,
          height: markerSize,
          child: GestureDetector(
            onTap: () => _onNodeMarkerTapped(node),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getNodeIcon(node.type, name: node.name),
                    color: Colors.white,
                    size: (isDestination || isStart) ? 20 : 16,
                  ),
                ),
                // Add start indicator
                if (isStart && !useCurrentLocation)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                // Add destination indicator
                if (isDestination)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Add temple feature markers from API
    for (final feature in _navigationService.features) {
      final isSelected = selectedFeature?.id == feature.id;
      final isDestination = destinationFeature?.id == feature.id;
      final isStart = startFeature?.id == feature.id;
      
      Color markerColor = _getFeatureMarkerColor(feature, isSelected, isDestination, isStart);
      double markerSize = (isDestination || isStart) ? 50 : 35;
      
      _markers.add(
        Marker(
          point: LatLng(feature.latitude, feature.longitude),
          width: markerSize,
          height: markerSize,
          child: GestureDetector(
            onTap: () => _onFeatureMarkerTapped(feature),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getFeatureIcon(feature.type),
                    color: Colors.white,
                    size: (isDestination || isStart) ? 20 : 16,
                  ),
                ),
                // Add start indicator
                if (isStart && !useCurrentLocation)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                // Add destination indicator
                if (isDestination)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
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
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }
  
  void _setupPolylines() {
    _polylines.clear();
    
    // Add temple edges as polylines from API
    for (final edge in _navigationService.edges) {
      final sourceNode = _navigationService.nodes[edge.sourceId];
      final targetNode = _navigationService.nodes[edge.targetId];
      
      if (sourceNode != null && targetNode != null) {
        _polylines.add(
          Polyline(
            points: [
              LatLng(sourceNode.latitude, sourceNode.longitude),
              LatLng(targetNode.latitude, targetNode.longitude),
            ],
            color: Colors.grey.withValues(alpha: 0.6),
            strokeWidth: 2.0,
          ),
        );
      }
    }
    
    // Add navigation route if active
    if (_currentRoute.isNotEmpty) {
      final routePoints = _currentRoute.map((waypoint) => 
          LatLng(waypoint.latitude, waypoint.longitude)).toList();
      
      _polylines.add(
        Polyline(
          points: routePoints,
          color: AppColors.primary,
          strokeWidth: 4.0,
        ),
      );
    }
  }
  
  void _onNodeMarkerTapped(TempleNode node) {
    setState(() {
      selectedNode = node;
      selectedFeature = null;
    });
    
    _showNodeBottomSheet(node);
  }
  
  void _onFeatureMarkerTapped(TempleFeature feature) {
    setState(() {
      selectedFeature = feature;
      selectedNode = null;
    });
    
    _showFeatureBottomSheet(feature);
  }
  
  Color _getNodeMarkerColor(TempleNode node, bool isSelected, bool isDestination, bool isStart) {
    if (isDestination) return Colors.red;
    if (isStart && !useCurrentLocation) return Colors.blue;
    if (isSelected) return AppColors.primary;
    
    // Check name for tangga (stairs) - name contains "tangga"
    if (node.name.toLowerCase().contains('tangga')) {
      return Colors.green; // Same as gate
    }
    
    switch (node.type.toUpperCase()) {
      case 'STUPA':
        return Colors.orange;
      case 'FOUNDATION':
        return Colors.brown;
      case 'GATE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  Color _getFeatureMarkerColor(TempleFeature feature, bool isSelected, bool isDestination, bool isStart) {
    if (isDestination) return Colors.red;
    if (isStart && !useCurrentLocation) return Colors.blue;
    if (isSelected) return AppColors.primary;
    
    switch (feature.type.toUpperCase()) {
      case 'STUPA':
        return Colors.orange;
      default:
        return AppColors.accent;
    }
  }
  
  IconData _getNodeIcon(String type, {String? name}) {
    // Check name for tangga (stairs) - name contains "tangga"
    if (name != null && name.toLowerCase().contains('tangga')) {
      return Icons.stairs; // Different icon for stairs
    }
    
    switch (type.toUpperCase()) {
      case 'STUPA':
        return Icons.account_balance;
      case 'FOUNDATION':
        return Icons.foundation;
      case 'GATE':
        return Icons.door_front_door;
      default:
        return Icons.place;
    }
  }
  
  IconData _getFeatureIcon(String type) {
    switch (type.toUpperCase()) {
      case 'STUPA':
        return Icons.temple_buddhist;
      default:
        return Icons.star;
    }
  }
  
  String _getTileTemplate() {
    return MapConfig.getTileUrl(_currentTileLayer);
  }
  
  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    // Hide any open bottom sheets
    Navigator.of(context).pop();
  }
  
  Future<void> _startNavigation() async {
    // Check destination
    if (destinationNode == null && destinationFeature == null) {
      _showMessage('Pilih tujuan terlebih dahulu', Colors.orange);
      return;
    }

    // Check start location based on mode
    if (useCurrentLocation) {
      if (_currentPosition == null) {
        _showMessage('Lokasi GPS tidak tersedia', Colors.red);
        return;
      }
    } else {
      if (startNode == null && startFeature == null) {
        _showMessage('Pilih lokasi awal terlebih dahulu', Colors.orange);
        return;
      }
    }

    // Show route preview modal first
    _showRoutePreviewModal();
  }
  
  Future<void> _showRoutePreviewModal() async {
    setState(() {
      _showLoadingOverlay = true;
    });

    try {
      // Calculate route first to get preview data
      NavigationResult previewResult;
      
      if (useCurrentLocation) {
        previewResult = await _navigationService.startNavigation(
          fromLat: _currentPosition!.latitude,
          fromLon: _currentPosition!.longitude,
          toNode: destinationNode,
          toFeature: destinationFeature,
        );
      } else {
        if (startNode != null) {
          previewResult = await _navigationService.startNavigation(
            fromNode: startNode,
            toNode: destinationNode,
            toFeature: destinationFeature,
          );
        } else {
          previewResult = await _navigationService.startNavigation(
            fromLat: startFeature!.latitude,
            fromLon: startFeature!.longitude,
            toNode: destinationNode,
            toFeature: destinationFeature,
          );
        }
      }

      setState(() {
        _showLoadingOverlay = false;
      });

      if (previewResult.success) {
        // Show the beautiful preview modal
        _showRoutePreviewDialog(previewResult);
      } else {
        _showMessage(previewResult.message, Colors.red);
      }
    } catch (e) {
      setState(() {
        _showLoadingOverlay = false;
      });
      _showMessage('Gagal menghitung rute: $e', Colors.red);
    }
  }
  
  void _stopNavigation() {
    _navigationService.stopNavigation();
    setState(() {
      isNavigating = false;
      _currentRoute.clear();
      _currentNavigationUpdate = null;
      _lastSpokenInstruction = ''; // Reset voice guidance
      _setupPolylines(); // Remove route polylines
    });
    _speakInstruction('Navigasi dihentikan.');
  }
  
  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _showRoutePreviewDialog(NavigationResult result) {
    final distance = result.totalDistance?.toStringAsFixed(0) ?? '0';
    final timeMinutes = ((result.estimatedTime ?? 0) / 60).ceil();
    final timeText = timeMinutes < 1 ? '< 1 menit' : '$timeMinutes menit';
    
    String startLocationName = '';
    String destinationName = '';
    
    if (useCurrentLocation) {
      startLocationName = 'Lokasi Anda Saat Ini';
    } else {
      startLocationName = startNode?.name ?? startFeature?.name ?? 'Lokasi Kustom';
    }
    
    destinationName = destinationNode?.name ?? destinationFeature?.name ?? 'Tujuan';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400, 
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.route,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Preview Rute Navigasi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content - wrapped in Expanded and SingleChildScrollView to prevent overflow
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route info cards
                      _buildRouteInfoCard(
                        icon: Icons.my_location,
                        iconColor: Colors.green,
                        title: 'Dari',
                        subtitle: startLocationName,
                      ),
                      const SizedBox(height: 16),
                      
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                color: AppColors.accent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Rute Terpendek',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      _buildRouteInfoCard(
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                        title: 'Ke',
                        subtitle: destinationName,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Distance and time stats
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.accent.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                icon: Icons.straighten,
                                label: 'Jarak',
                                value: '${distance}m',
                                color: AppColors.primary,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                icon: Icons.access_time,
                                label: 'Estimasi Waktu',
                                value: timeText,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Route preview minimap (simplified)
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              // Background pattern
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey.withValues(alpha: 0.1),
                                      Colors.grey.withValues(alpha: 0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                              
                              // Route visualization (simplified)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Start point
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green.withValues(alpha: 0.3),
                                                  blurRadius: 6,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.my_location,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Start',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      // Route line
                                      Expanded(
                                        child: Container(
                                          height: 3,
                                          margin: const EdgeInsets.symmetric(horizontal: 16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.green, AppColors.primary, Colors.red],
                                            ),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      
                                      // End point
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.red.withValues(alpha: 0.3),
                                                  blurRadius: 6,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Tujuan',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Overlay text
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Preview Rute',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _confirmStartNavigation(result);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.navigation, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Mulai Navigasi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRouteInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Future<void> _confirmStartNavigation(NavigationResult result) async {
    setState(() {
      isNavigating = true;
      _currentRoute = result.path ?? [];
      _setupPolylines();
    });
    
    _showMessage(
      'Navigasi dimulai! Jarak: ${(result.totalDistance ?? 0).toStringAsFixed(0)}m',
      Colors.green,
    );
    
    // Start simulation for testing
    _navigationService.startDummyNavigationSimulation();
    
    // Speak initial instruction
    if (_isVoiceEnabled) {
      await _speakInstruction('Navigasi dimulai. Ikuti petunjuk arah.');
    }
  }
  
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Izin Lokasi Diperlukan'),
        content: const Text(
          'Aplikasi memerlukan izin lokasi untuk:\n'
          '• Menampilkan posisi Anda di peta\n'
          '• Navigasi dari lokasi saat ini\n'
          '• Memberikan petunjuk arah yang akurat\n\n'
          'Apakah Anda ingin memberikan izin lokasi?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showMessage('Izin lokasi ditolak. Gunakan mode lokasi kustom.', Colors.orange);
            },
            child: const Text('Tolak'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Try to request permission again
              final hasPermission = await _navigationService.requestLocationPermission();
              if (hasPermission) {
                _showMessage('Izin lokasi diberikan!', Colors.green);
                _initializeLocationTracking();
              } else {
                // Show settings dialog for permanently denied permission
                _showSettingsDialog();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Izinkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Buka Pengaturan Aplikasi'),
        content: const Text(
          'Izin lokasi diperlukan untuk navigasi. Aplikasi akan membuka Pengaturan untuk mengizinkan akses lokasi.\n\n'
          'Langkah:\n'
          '1. Pilih "Permissions" atau "Izin"\n'
          '2. Pilih "Location" atau "Lokasi"\n'
          '3. Pilih "Allow all the time" atau "Izinkan selalu"\n'
          '4. Kembali ke aplikasi'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showMessage('Gunakan mode lokasi kustom untuk navigasi.', Colors.orange);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final opened = await _navigationService.openLocationSettings();
              if (opened) {
                _showMessage('Pengaturan dibuka. Aktifkan izin lokasi lalu kembali ke aplikasi.', Colors.blue);
              } else {
                _showMessage('Tidak dapat membuka pengaturan. Cari "Borobudur Explorer" di Pengaturan sistem.', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Buka Pengaturan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _showNodeBottomSheet(TempleNode node) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              node.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Type: ${node.type}'),
            Text('Level: ${node.level}'),
            if (node.description != null) Text('Description: ${node.description}'),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!useCurrentLocation)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          startNode = node;
                          startFeature = null;
                        });
                        Navigator.of(context).pop();
                        _setupMarkers();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text('Set sebagai Start'),
                    ),
                  ),
                if (!useCurrentLocation) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        destinationNode = node;
                        destinationFeature = null;
                      });
                      Navigator.of(context).pop();
                      _setupMarkers();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Set sebagai Tujuan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showFeatureBottomSheet(TempleFeature feature) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              feature.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Type: ${feature.type}'),
            Text('Level: ${feature.level}'),
            if (feature.description != null) Text('Description: ${feature.description}'),
            if (feature.distanceM != null) Text('Distance: ${feature.distanceM!.toStringAsFixed(0)}m'),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!useCurrentLocation)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          startFeature = feature;
                          startNode = null;
                        });
                        Navigator.of(context).pop();
                        _setupMarkers();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text('Set sebagai Start'),
                    ),
                  ),
                if (!useCurrentLocation) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        destinationFeature = feature;
                        destinationNode = null;
                      });
                      Navigator.of(context).pop();
                      _setupMarkers();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Set sebagai Tujuan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          useCurrentLocation ? 'Peta Navigasi Borobudur' : 'Navigasi - Mode Kustom',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          // Voice guidance toggle
          IconButton(
            icon: Icon(
              _isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: _isVoiceEnabled ? AppColors.primary : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isVoiceEnabled = !_isVoiceEnabled;
              });
              if (_isVoiceEnabled) {
                _speakInstruction('Panduan suara diaktifkan.');
              } else {
                _flutterTts.stop();
              }
            },
            tooltip: _isVoiceEnabled ? 'Matikan Suara' : 'Hidupkan Suara',
          ),
          // Start location mode toggle
          PopupMenuButton<bool>(
            icon: Icon(
              useCurrentLocation ? Icons.my_location : Icons.place,
              color: useCurrentLocation ? Colors.blue : Colors.orange,
            ),
            onSelected: (mode) {
              setState(() {
                useCurrentLocation = mode;
                if (useCurrentLocation) {
                  // Clear custom start location when switching to current location
                  startNode = null;
                  startFeature = null;
                }
                _setupMarkers();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.my_location, color: useCurrentLocation ? Colors.blue : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Lokasi Saat Ini'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.place, color: !useCurrentLocation ? Colors.orange : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Lokasi Kustom'),
                  ],
                ),
              ),
            ],
          ),
          // Layer selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers),
            onSelected: (layer) {
              setState(() {
                _currentTileLayer = layer;
              });
            },
            itemBuilder: (context) => MapConfig.availableLayers.map((layer) => 
              PopupMenuItem(
                value: layer, 
                child: Text(layer == 'OpenStreetMap' && MapConfig.availableLayers.length == 1 
                    ? 'OpenStreetMap (Configure MapTiler for better maps)'
                    : layer
                )
              )
            ).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Loading indicators
          if (_navigationService.isLoadingGraph || _navigationService.isLoadingFeatures)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _navigationService.isLoadingGraph
                        ? 'Memuat peta candi...'
                        : 'Memuat fitur candi...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          
          // Map
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
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
                    userAgentPackageName: MapConfig.userAgent,
                    maxNativeZoom: 19,
                  ),
                  PolylineLayer(polylines: _polylines),
                  MarkerLayer(markers: _markers),
                ],
              ),
            ),
          ),
          
          // Navigation panel (when navigating)
          if (isNavigating && _currentNavigationUpdate != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sedang Bernavigasi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_currentNavigationUpdate!.stepIndex + 1}/${_currentNavigationUpdate!.totalSteps}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _stopNavigation,
                          ),
                        ],
                      ),
                    ),
                    // Navigation info
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            _currentNavigationUpdate!.instruction,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${_currentNavigationUpdate!.remainingDistance.toStringAsFixed(0)}m',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const Text(
                                    'Jarak',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${_currentNavigationUpdate!.estimatedTime}s',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const Text(
                                    'Waktu',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Bottom control panel
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Start location info
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          useCurrentLocation ? Icons.my_location : Icons.play_arrow,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            useCurrentLocation 
                                ? 'Start: Lokasi Saat Ini (GPS)'
                                : 'Start: ${startNode?.name ?? startFeature?.name ?? "Belum dipilih"}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Destination info
                  if (destinationNode != null || destinationFeature != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tujuan: ${destinationNode?.name ?? destinationFeature?.name}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isNavigating ? _stopNavigation : _startNavigation,
                          icon: Icon(isNavigating ? Icons.stop : Icons.navigation),
                          label: Text(isNavigating ? 'Stop Navigasi' : 'Mulai Navigasi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isNavigating ? Colors.red : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Loading overlay
          if (_showLoadingOverlay)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}