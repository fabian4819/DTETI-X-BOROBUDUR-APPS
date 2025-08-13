import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../../models/location_point.dart';
import '../../data/borobudur_data.dart';
import '../../services/navigation_service.dart';
import '../../utils/app_colors.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with TickerProviderStateMixin {
  final NavigationService _navigationService = NavigationService();
  
  LocationPoint? selectedLocation;
  LocationPoint? destinationLocation;
  LocationPoint? startLocation; // Pilihan titik awal
  bool isNavigating = false;
  bool useCustomStartLocation = false; // Toggle untuk menggunakan lokasi kustom
  String searchQuery = '';
  List<LocationPoint> filteredLocations = [];
  int currentViewLevel = 3; // Level yang sedang dilihat
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<NavigationUpdate>? _navigationSubscription;
  Position? _currentPosition;
  NavigationUpdate? _currentNavigationUpdate;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 3D View Controls
  double _zoom = 1.0;
  double _rotationY = 0.0; // Rotasi horizontal
  double _rotationX = -0.3; // Rotasi vertikal (sedikit dari atas)
  Offset _panOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    filteredLocations = borobudurLocations;
    _navigationService.initialize();
    _initializeAnimations();
    _initializeLocationTracking();
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

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _navigationSubscription?.cancel();
    _pulseController.dispose();
    _navigationService.dispose();
    super.dispose();
  }

  Future<void> _initializeLocationTracking() async {
    try {
      _currentPosition = _navigationService.getCurrentLocationForTesting();
      
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _currentPosition = _navigationService.getCurrentLocationForTesting();
          });
        } else {
          timer.cancel();
        }
      });

      _navigationSubscription = _navigationService.navigationUpdateStream?.listen((update) {
        setState(() {
          _currentNavigationUpdate = update;
        });
        
        if (update.hasArrived) {
          _stopNavigation();
          _showArrivalDialog();
        }
      });
    } catch (e) {
      _showLocationPermissionDialog();
    }
  }

  void _stopNavigation() {
    _navigationService.stopNavigation();
    setState(() {
      isNavigating = false;
    });
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
          'Aplikasi memerlukan akses lokasi untuk memberikan navigasi real-time. '
          'Untuk testing, kami menggunakan lokasi dummy di area Borobudur.',
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

  // Helper untuk icon arah berdasarkan instruksi
  IconData _getDirectionIcon(String instruction) {
    if (instruction.contains('kanan')) return Icons.turn_right;
    if (instruction.contains('kiri')) return Icons.turn_left;
    if (instruction.contains('Lurus')) return Icons.straight;
    if (instruction.contains('Putar balik')) return Icons.u_turn_left;
    if (instruction.contains('Mulai')) return Icons.play_arrow;
    return Icons.navigation;
  }

  // Helper untuk info navigasi
  Widget _buildNavInfo(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
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

  void _searchLocations(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredLocations = borobudurLocations;
      } else {
        filteredLocations = borobudurLocations
            .where((location) =>
                location.name.toLowerCase().contains(query.toLowerCase()) ||
                location.id.toLowerCase().contains(query.toLowerCase()) ||
                location.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }
  
  Future<void> _startNavigation() async {
    if (destinationLocation == null) return;

    LocationPoint? actualStartLocation;

    if (useCustomStartLocation && startLocation != null) {
      // Gunakan titik awal yang dipilih
      actualStartLocation = startLocation;
    } else {
      // Gunakan lokasi saat ini (mode dummy untuk testing)
      _currentPosition ??= _navigationService.getCurrentLocationForTesting();

      if (!_navigationService.isInBorobudurArea(_currentPosition!.latitude, _currentPosition!.longitude)) {
        _showOutOfAreaWarning();
        return;
      }

      actualStartLocation = _navigationService.findNearestLocation(
        _currentPosition!.latitude, 
        _currentPosition!.longitude,
        maxDistance: 50, // Increased for dummy testing
      );
    }

    if (actualStartLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat menemukan titik awal yang valid'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final result = await _navigationService.startNavigation(actualStartLocation, destinationLocation!);
      
      if (result.success) {
        setState(() {
          isNavigating = true;
        });
        
        _showNavigationStartDialog(result, actualStartLocation);
        
        // Start dummy simulation for testing
        _navigationService.startDummyNavigationSimulation();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error memulai navigasi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(Icons.my_location, 'Dari', startLocation.name),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_on, 'Ke', destinationLocation!.name),
              const Divider(height: 24),
              _buildInfoRow(Icons.straighten, 'Jarak', '${result.totalDistance!.toStringAsFixed(0)}m'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.schedule, 'Waktu', '~${(result.estimatedTime! / 60).ceil()} menit'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ikuti petunjuk arah yang akan muncul di layar. Tetap berada di jalur yang telah ditentukan.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopNavigation();
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.navigation),
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            label: const Text('Mulai'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.secondary))),
      ],
    );
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
          // Level selector
          PopupMenuButton<int>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'L$currentViewLevel',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            onSelected: (level) {
              setState(() {
                currentViewLevel = level;
              });
            },
            itemBuilder: (context) => getAvailableLevels()
                .map((level) => PopupMenuItem(
                      value: level,
                      child: Text('Level $level${level == 9 ? " (Puncak)" : ""}'),
                    ))
                .toList(),
          ),
          if (isNavigating)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              tooltip: 'Stop Navigasi',
              onPressed: _stopNavigation,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Reset View',
            onPressed: () {
              setState(() {
                selectedLocation = null;
                destinationLocation = null;
                _zoom = 1.0;
                _rotationY = 0.0;
                _rotationX = -0.3;
                _panOffset = Offset.zero;
              });
              _stopNavigation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Realtime Navigation Panel (Google Maps style)
          if (isNavigating && _currentNavigationUpdate != null)
            Flexible(
              flex: 0,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              child: Column(
                children: [
                  // Header navigasi
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
                  
                  // Step-by-step instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Instruksi utama
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
                                      fontSize: 14,
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
                        
                        // Progress dan info
                        Row(
                          children: [
                            _buildNavInfo(
                              Icons.straighten,
                              '${_currentNavigationUpdate!.distanceToNextStep.toStringAsFixed(0)}m',
                              'Jarak ke langkah berikutnya',
                            ),
                            const SizedBox(width: 8),
                            _buildNavInfo(
                              Icons.schedule,
                              '${(_currentNavigationUpdate!.estimatedTime / 60).ceil()} min',
                              'Estimasi waktu',
                            ),
                            const SizedBox(width: 8),
                            _buildNavInfo(
                              Icons.location_on,
                              '${_currentNavigationUpdate!.stepIndex + 1}/${_currentNavigationUpdate!.totalSteps}',
                              'Langkah',
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Progress bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${((_currentNavigationUpdate!.stepIndex / _currentNavigationUpdate!.totalSteps) * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _currentNavigationUpdate!.stepIndex / _currentNavigationUpdate!.totalSteps,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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

          // 3D Interactive Map
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                child: Stack(
                  children: [
                    // Main 3D View
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapDown: (details) {
                            _selectLocationOnMap(details.localPosition, constraints.biggest);
                          },
                          onScaleStart: (details) {
                            // Initialize scale gesture
                          },
                          onScaleUpdate: (details) {
                            setState(() {
                              _zoom = (_zoom * details.scale).clamp(0.5, 3.0);
                              _rotationY += details.rotation;
                              _panOffset += details.focalPointDelta;
                            });
                          },
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: Size.infinite,
                                painter: Borobudur3DMapPainter(
                                  locations: borobudurLocations,
                                  selectedLocation: selectedLocation,
                                  destinationLocation: destinationLocation,
                                  navigationPath: _navigationService.currentPath,
                                  currentPosition: _currentPosition,
                                  isNavigating: isNavigating,
                                  pulseValue: _pulseController.value,
                                  currentViewLevel: currentViewLevel,
                                  zoom: _zoom,
                                  rotationY: _rotationY,
                                  rotationX: _rotationX,
                                  panOffset: _panOffset,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    
                    // Controls overlay
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        children: [
                          // Zoom controls
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(229),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.zoom_in),
                                  onPressed: () {
                                    setState(() {
                                      _zoom = (_zoom * 1.2).clamp(0.5, 3.0);
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.zoom_out),
                                  onPressed: () {
                                    setState(() {
                                      _zoom = (_zoom / 1.2).clamp(0.5, 3.0);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Rotation controls
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(229),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_up),
                                  onPressed: () {
                                    setState(() {
                                      _rotationX = (_rotationX - 0.1).clamp(-1.5, 0.5);
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  onPressed: () {
                                    setState(() {
                                      _rotationX = (_rotationX + 0.1).clamp(-1.5, 0.5);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Info overlay
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(178),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level $currentViewLevel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap: Select • Drag: Pan • Pinch: Zoom',
                              style: TextStyle(
                                color: Colors.white.withAlpha(204),
                                fontSize: 12,
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
          ),

          // Destination Selection
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
            child: Column(
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
                    // Filter by level
                    DropdownButton<int>(
                      value: currentViewLevel,
                      items: getAvailableLevels()
                          .map((level) => DropdownMenuItem(
                                value: level,
                                child: Text('L$level'),
                              ))
                          .toList(),
                      onChanged: (level) {
                        if (level != null) {
                          setState(() {
                            currentViewLevel = level;
                            // Filter locations by level
                            filteredLocations = borobudurLocations
                                .where((loc) => loc.level == level)
                                .toList();
                          });
                        }
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Toggle custom start location
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray.withAlpha(127),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.my_location, color: AppColors.mediumGray),
                      const SizedBox(width: 8),
                      const Text('Gunakan titik awal kustom'),
                      const Spacer(),
                      Switch(
                        value: useCustomStartLocation,
                        onChanged: (value) {
                          setState(() {
                            useCustomStartLocation = value;
                            if (!value) startLocation = null;
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                
                if (useCustomStartLocation) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withAlpha(127)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            startLocation?.name ?? 'Pilih titik awal dari daftar',
                            style: TextStyle(
                              fontWeight: startLocation != null ? FontWeight.bold : FontWeight.normal,
                              color: startLocation != null ? AppColors.accent : Colors.grey[600],
                            ),
                          ),
                        ),
                        if (startLocation != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                startLocation = null;
                              });
                            },
                            color: Colors.grey[600],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  onChanged: _searchLocations,
                  decoration: InputDecoration(
                    hintText: 'Cari fondasi atau gerbang...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.mediumGray),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                ),
                const SizedBox(height: 16),
                if (destinationLocation != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getIconForType(destinationLocation!.type),
                          color: AppColors.accent,
                        ),
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
                                destinationLocation!.description.isNotEmpty
                                    ? destinationLocation!.description
                                    : 'Level ${destinationLocation!.level}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mediumGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isNavigating)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.navigation, size: 18),
                            onPressed: _startNavigation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            label: const Text('Navigasi'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Location List
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: ListView.builder(
                itemCount: filteredLocations.length,
                itemBuilder: (context, index) {
                  final location = filteredLocations[index];
                  final isSelected = selectedLocation?.id == location.id;
                  final isDestination = destinationLocation?.id == location.id;
                  final isStartLocation = startLocation?.id == location.id;

                  Color borderColor = AppColors.lightGray;
                  Color backgroundColor = Colors.white;
                  
                  if (isDestination) {
                    borderColor = AppColors.accent;
                    backgroundColor = AppColors.accent.withAlpha(51);
                  } else if (isStartLocation) {
                    borderColor = Colors.green;
                    backgroundColor = Colors.green.withAlpha(51);
                  } else if (isSelected) {
                    backgroundColor = AppColors.primary.withAlpha(51);
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: isDestination || isStartLocation ? 2 : 1),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getColorForType(location.type),
                        child: Icon(
                          _getIconForType(location.type),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              location.name,
                              style: TextStyle(
                                fontWeight: isDestination || isStartLocation ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isDestination)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TUJUAN',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          if (isStartLocation)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'START',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${location.description} • Level ${location.level}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: AppColors.mediumGray),
                        onSelected: (action) {
                          setState(() {
                            selectedLocation = location;
                            if (action == 'destination') {
                              destinationLocation = location;
                            } else if (action == 'start') {
                              startLocation = location;
                              useCustomStartLocation = true;
                            }
                            currentViewLevel = location.level;
                          });
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'destination',
                            child: Row(
                              children: [
                                Icon(Icons.flag, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Set as Tujuan'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'start',
                            child: Row(
                              children: [
                                Icon(Icons.play_arrow, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Set as Titik Awal'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          selectedLocation = location;
                          if (!useCustomStartLocation) {
                            destinationLocation = location;
                          }
                          currentViewLevel = location.level;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
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

  void _selectLocationOnMap(Offset tapPosition, Size mapSize) {
    LocationPoint? tappedLocation;
    double minDistance = 30;

    // Filter locations by current view level
    final levelLocations = borobudurLocations
        .where((loc) => loc.level == currentViewLevel)
        .toList();

    for (final location in levelLocations) {
      final pixelPos = _calculateLocationScreenPosition(location, mapSize);
      final distance = (tapPosition - pixelPos).distance;

      if (distance < minDistance) {
        minDistance = distance;
        tappedLocation = location;
      }
    }
    
    if (tappedLocation != null) {
      setState(() {
        selectedLocation = tappedLocation;
        destinationLocation = tappedLocation;
      });
    }
  }

  // Helper function to calculate screen position of a location
  Offset _calculateLocationScreenPosition(LocationPoint location, Size mapSize) {
    final centerX = mapSize.width / 2 + _panOffset.dx;
    final centerY = mapSize.height / 2 + _panOffset.dy;
    
    // Use square position from LocationPoint
    final squarePos = location.squarePosition;
    double localX = squarePos['x'] as double;
    double localY = squarePos['y'] as double;
    
    // Apply rotation
    final cosRotY = math.cos(_rotationY);
    final sinRotY = math.sin(_rotationY);
    final rotatedX = localX * cosRotY - localY * sinRotY;
    final rotatedY = localX * sinRotY + localY * cosRotY;
    
    // Apply zoom and 3D isometric projection
    final x = centerX + rotatedX * _zoom;
    final y = centerY + rotatedY * _zoom * math.cos(_rotationX) - (location.elevationHeight * _zoom * 0.5);
    
    return Offset(x, y);
  }

}

class Borobudur3DMapPainter extends CustomPainter {
  final List<LocationPoint> locations;
  final LocationPoint? selectedLocation;
  final LocationPoint? destinationLocation;
  final List<LocationPoint> navigationPath;
  final Position? currentPosition;
  final bool isNavigating;
  final double pulseValue;
  final int currentViewLevel;
  final double zoom;
  final double rotationY;
  final double rotationX;
  final Offset panOffset;

  Borobudur3DMapPainter({
    required this.locations,
    this.selectedLocation,
    this.destinationLocation,
    this.navigationPath = const [],
    this.currentPosition,
    this.isNavigating = false,
    this.pulseValue = 0,
    this.currentViewLevel = 3,
    this.zoom = 1.0,
    this.rotationY = 0.0,
    this.rotationX = -0.3,
    this.panOffset = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFE3F2FD),
          const Color(0xFFBBDEFB),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw foundation connections for current level
    _drawFoundationConnections(canvas, size);
    
    // Draw navigation path
    if (isNavigating && navigationPath.length > 1) {
      _drawNavigationPath(canvas, size);
    }
    
    // Draw 3D square pyramid structure
    _draw3DSquarePyramid(canvas, size);
    
    // Draw square frames for foundations
    _drawSquareFrames(canvas, size);
    
    // Draw locations for current level
    _drawLocations3D(canvas, size);
    
    // Draw current position
    if (currentPosition != null) {
      _drawCurrentPosition(canvas, size);
    }
  }


  void _drawFoundationConnections(Canvas canvas, Size size) {
    final foundations = getFoundationsForLevel(currentViewLevel);
    if (foundations.length < 2) return;

    final connectionPaint = Paint()
      ..color = AppColors.mediumGray.withAlpha(127)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    bool isFirst = true;
    
    for (final foundation in foundations) {
      final pos = _get3DPosition(foundation, size);
      if (isFirst) {
        path.moveTo(pos.dx, pos.dy);
        isFirst = false;
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }
    
    // Close the circular path
    if (foundations.isNotEmpty) {
      final firstPos = _get3DPosition(foundations.first, size);
      path.lineTo(firstPos.dx, firstPos.dy);
    }
    
    canvas.drawPath(path, connectionPaint);
  }

  void _drawNavigationPath(Canvas canvas, Size size) {
    if (navigationPath.length < 2) return;
    
    final pathPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final firstPos = _get3DPosition(navigationPath.first, size);
    path.moveTo(firstPos.dx, firstPos.dy);

    for (int i = 1; i < navigationPath.length; i++) {
      final pos = _get3DPosition(navigationPath[i], size);
      path.lineTo(pos.dx, pos.dy);
    }
    
    canvas.drawPath(path, pathPaint);
  }

  void _drawLocations3D(Canvas canvas, Size size) {
    // Filter locations by current view level
    final levelLocations = locations
        .where((loc) => loc.level == currentViewLevel)
        .toList();
    
    // Draw shadows first
    for (final location in levelLocations) {
      final position = _get3DPosition(location, size);
      final radius = _getLocationRadius(location);
      
      final shadowPaint = Paint()
        ..color = Colors.black.withAlpha(51)
        ..style = PaintingStyle.fill;
      
      if (location.type == 'STUPA') {
        // Draw stupa as circle
        canvas.drawCircle(
          Offset(position.dx + 2, position.dy + 2), 
          radius + 2, 
          shadowPaint
        );
      } else {
        // Draw foundation and gates as squares
        final shadowRect = Rect.fromCenter(
          center: Offset(position.dx + 2, position.dy + 2),
          width: (radius * 2) + 4,
          height: (radius * 2) + 4,
        );
        canvas.drawRect(shadowRect, shadowPaint);
      }
    }
    
    // Draw locations
    for (final location in levelLocations) {
      final position = _get3DPosition(location, size);
      final isSelected = selectedLocation?.id == location.id;
      final isDestination = destinationLocation?.id == location.id;
      final isOnPath = navigationPath.any((p) => p.id == location.id);
      final radius = _getLocationRadius(location);
      
      final markerPaint = Paint()
        ..color = _getLocationColor(location, isSelected, isDestination, isOnPath)
        ..style = PaintingStyle.fill;
      
      final borderPaint = Paint()
        ..color = _getLocationColor(location, isSelected, isDestination, isOnPath).withAlpha(204)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      if (location.type == 'STUPA') {
        // Draw stupa as circle
        canvas.drawCircle(position, radius, markerPaint);
        canvas.drawCircle(position, radius, borderPaint);
      } else {
        // Draw foundation and gates as squares
        final rect = Rect.fromCenter(
          center: position,
          width: radius * 2,
          height: radius * 2,
        );
        canvas.drawRect(rect, markerPaint);
        canvas.drawRect(rect, borderPaint);
      }
      
      // Highlight for selected/destination
      if (isSelected || isDestination) {
        final highlightPaint = Paint()
          ..color = isDestination ? AppColors.accent.withAlpha(102) : AppColors.primary.withAlpha(102)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        
        if (location.type == 'STUPA') {
          canvas.drawCircle(position, radius + 6, highlightPaint);
        } else {
          final highlightRect = Rect.fromCenter(
            center: position,
            width: (radius * 2) + 12,
            height: (radius * 2) + 12,
          );
          canvas.drawRect(highlightRect, highlightPaint);
        }
      }
      
      // Icon
      _drawLocationIcon(canvas, location, position);
      
      // Label for selected
      if (isSelected || isDestination) {
        _drawLabel(canvas, location.name, position);
      }
    }
  }

  void _draw3DSquarePyramid(Canvas canvas, Size size) {
    final centerX = size.width / 2 + panOffset.dx;
    final centerY = size.height / 2 + panOffset.dy;
    
    // Draw all levels as 3D square pyramid with better 3D effect
    final pyramidPaint = Paint()
      ..color = const Color(0xFF8B4513).withAlpha(153) // Dark brown outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final facePaint = Paint()
      ..color = const Color(0xFFD2B48C).withAlpha(76) // Tan face color
      ..style = PaintingStyle.fill;
      
    final sideFacePaint = Paint()
      ..color = const Color(0xFFA0522D).withAlpha(102) // Darker sienna for depth
      ..style = PaintingStyle.fill;
    
    // Draw from bottom to top
    for (int level = 1; level <= 8; level++) {
      final sideLength = _getSideLengthForLevel(level);
      final halfSide = sideLength / 2;
      final elevation = (level - 1) * 12.0;
      
      // Calculate 4 corners of the square
      final corners = [
        {'x': -halfSide, 'y': -halfSide}, // Bottom-left
        {'x': halfSide, 'y': -halfSide},  // Bottom-right
        {'x': halfSide, 'y': halfSide},   // Top-right
        {'x': -halfSide, 'y': halfSide},  // Top-left
      ];
      
      final cornerPositions = <Offset>[];
      
      for (final corner in corners) {
        final localX = corner['x'] as double;
        final localY = corner['y'] as double;
        
        // Apply rotation
        final cosRotY = math.cos(rotationY);
        final sinRotY = math.sin(rotationY);
        final rotatedX = localX * cosRotY - localY * sinRotY;
        final rotatedY = localX * sinRotY + localY * cosRotY;
        
        // Apply zoom and 3D projection
        final x = centerX + rotatedX * zoom;
        final y = centerY + rotatedY * zoom * math.cos(rotationX) - (elevation * zoom * 0.5);
        
        cornerPositions.add(Offset(x, y));
      }
      
      // Draw top face (square outline for this level)
      final topPath = Path()
        ..moveTo(cornerPositions[0].dx, cornerPositions[0].dy)
        ..lineTo(cornerPositions[1].dx, cornerPositions[1].dy)
        ..lineTo(cornerPositions[2].dx, cornerPositions[2].dy)
        ..lineTo(cornerPositions[3].dx, cornerPositions[3].dy)
        ..close();
      
      canvas.drawPath(topPath, facePaint);
      canvas.drawPath(topPath, pyramidPaint);
      
      // Draw visible side faces for 3D effect
      if (level > 1) {
        final prevSideLength = _getSideLengthForLevel(level - 1);
        final prevHalfSide = prevSideLength / 2;
        final prevElevation = (level - 2) * 12.0;
        
        final prevCorners = [
          {'x': -prevHalfSide, 'y': -prevHalfSide},
          {'x': prevHalfSide, 'y': -prevHalfSide},
          {'x': prevHalfSide, 'y': prevHalfSide},
          {'x': -prevHalfSide, 'y': prevHalfSide},
        ];
        
        final prevCornerPositions = <Offset>[];
        
        for (final corner in prevCorners) {
          final localX = corner['x'] as double;
          final localY = corner['y'] as double;
          
          final cosRotY = math.cos(rotationY);
          final sinRotY = math.sin(rotationY);
          final rotatedX = localX * cosRotY - localY * sinRotY;
          final rotatedY = localX * sinRotY + localY * cosRotY;
          
          final x = centerX + rotatedX * zoom;
          final y = centerY + rotatedY * zoom * math.cos(rotationX) - (prevElevation * zoom * 0.5);
          
          prevCornerPositions.add(Offset(x, y));
        }
        
        // Draw visible side faces (front and right sides based on rotation)
        final frontFacePath = Path()
          ..moveTo(prevCornerPositions[0].dx, prevCornerPositions[0].dy)
          ..lineTo(prevCornerPositions[1].dx, prevCornerPositions[1].dy)
          ..lineTo(cornerPositions[1].dx, cornerPositions[1].dy)
          ..lineTo(cornerPositions[0].dx, cornerPositions[0].dy)
          ..close();
        
        final rightFacePath = Path()
          ..moveTo(prevCornerPositions[1].dx, prevCornerPositions[1].dy)
          ..lineTo(prevCornerPositions[2].dx, prevCornerPositions[2].dy)
          ..lineTo(cornerPositions[2].dx, cornerPositions[2].dy)
          ..lineTo(cornerPositions[1].dx, cornerPositions[1].dy)
          ..close();
        
        canvas.drawPath(frontFacePath, sideFacePaint);
        canvas.drawPath(frontFacePath, pyramidPaint);
        canvas.drawPath(rightFacePath, sideFacePaint);
        canvas.drawPath(rightFacePath, pyramidPaint);
      }
      
      // Draw vertical edges to next level (if not top level)
      if (level < 8) {
        final nextSideLength = _getSideLengthForLevel(level + 1);
        final nextHalfSide = nextSideLength / 2;
        final nextElevation = level * 12.0;
        
        final nextCorners = [
          {'x': -nextHalfSide, 'y': -nextHalfSide},
          {'x': nextHalfSide, 'y': -nextHalfSide},
          {'x': nextHalfSide, 'y': nextHalfSide},
          {'x': -nextHalfSide, 'y': nextHalfSide},
        ];
        
        final nextCornerPositions = <Offset>[];
        
        for (final corner in nextCorners) {
          final localX = corner['x'] as double;
          final localY = corner['y'] as double;
          
          final cosRotY = math.cos(rotationY);
          final sinRotY = math.sin(rotationY);
          final rotatedX = localX * cosRotY - localY * sinRotY;
          final rotatedY = localX * sinRotY + localY * cosRotY;
          
          final x = centerX + rotatedX * zoom;
          final y = centerY + rotatedY * zoom * math.cos(rotationX) - (nextElevation * zoom * 0.5);
          
          nextCornerPositions.add(Offset(x, y));
        }
        
        // Draw vertical edges connecting this level to next level
        for (int i = 0; i < 4; i++) {
          canvas.drawLine(cornerPositions[i], nextCornerPositions[i], pyramidPaint);
        }
      }
    }
  }
  
  double _getSideLengthForLevel(int level) {
    switch (level) {
      case 1: return 160.0;
      case 2: return 140.0;
      case 3: return 120.0;
      case 4: return 100.0;
      case 5: return 80.0;
      case 6: return 60.0;
      case 7: return 40.0;
      case 8: return 30.0;
      case 9: return 10.0;
      default: return 120.0;
    }
  }

  void _drawSquareFrames(Canvas canvas, Size size) {
    // Draw square frames for the current level
    final levelLocations = locations
        .where((loc) => loc.level == currentViewLevel && loc.type == 'FOUNDATION')
        .toList();
    
    if (levelLocations.isEmpty) return;
    
    // Group foundations by side
    final foundationsBySide = <int, List<LocationPoint>>{};
    for (final location in levelLocations) {
      final squarePos = location.squarePosition;
      final side = squarePos['side'] as int;
      foundationsBySide.putIfAbsent(side, () => []).add(location);
    }
    
    // Draw lines connecting foundations on each side
    final framePaint = Paint()
      ..color = Colors.grey.withAlpha(127)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    for (final side in foundationsBySide.keys) {
      final sideFoundations = foundationsBySide[side]!;
      if (sideFoundations.length < 2) continue;
      
      // Sort foundations by position on their side
      sideFoundations.sort((a, b) {
        final posA = a.squarePosition['position'] as double;
        final posB = b.squarePosition['position'] as double;
        return posA.compareTo(posB);
      });
      
      // Draw line connecting all foundations on this side
      for (int i = 0; i < sideFoundations.length - 1; i++) {
        final start = _get3DPosition(sideFoundations[i], size);
        final end = _get3DPosition(sideFoundations[i + 1], size);
        canvas.drawLine(start, end, framePaint);
      }
    }
    
    // Connect corners to complete the square
    if (foundationsBySide.length == 4) {
      for (int side = 0; side < 4; side++) {
        final currentSide = foundationsBySide[side];
        final nextSide = foundationsBySide[(side + 1) % 4];
        
        if (currentSide != null && currentSide.isNotEmpty && 
            nextSide != null && nextSide.isNotEmpty) {
          final lastOfCurrent = currentSide.last;
          final firstOfNext = nextSide.first;
          
          final start = _get3DPosition(lastOfCurrent, size);
          final end = _get3DPosition(firstOfNext, size);
          canvas.drawLine(start, end, framePaint);
        }
      }
    }
  }

  void _drawCurrentPosition(Canvas canvas, Size size) {
    if (currentPosition == null) return;
    
    // Convert current position to map coordinates
    final deltaLat = (currentPosition!.latitude - BorobudurArea.centerLat) * 111000;
    final deltaLon = (currentPosition!.longitude - BorobudurArea.centerLon) * 111000;
    
    final centerX = size.width / 2 + panOffset.dx;
    final centerY = size.height / 2 + panOffset.dy;
    
    final distance = math.sqrt(deltaLat * deltaLat + deltaLon * deltaLon);
    final angle = math.atan2(deltaLon, deltaLat) + rotationY;
    
    final x = centerX + distance * zoom * math.cos(angle);
    final y = centerY + distance * zoom * math.sin(angle) * math.cos(rotationX);
    
    final position = Offset(x, y);
    
    // Pulse effect
    final pulseRadius = 12 + (pulseValue * 4);
    
    // Outer pulse
    final pulsePaint = Paint()
      ..color = Colors.blue.withAlpha(102)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, pulseRadius, pulsePaint);
    
    // Inner circle
    final positionPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 6, positionPaint);
    
    // White center dot
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 3, centerPaint);
  }

  Offset _get3DPosition(LocationPoint location, Size size) {
    final centerX = size.width / 2 + panOffset.dx;
    final centerY = size.height / 2 + panOffset.dy;
    
    // Use square position from LocationPoint
    final squarePos = location.squarePosition;
    double localX = squarePos['x'] as double;
    double localY = squarePos['y'] as double;
    
    // Apply rotation
    final cosRotY = math.cos(rotationY);
    final sinRotY = math.sin(rotationY);
    final rotatedX = localX * cosRotY - localY * sinRotY;
    final rotatedY = localX * sinRotY + localY * cosRotY;
    
    // Apply zoom and 3D isometric projection
    final x = centerX + rotatedX * zoom;
    final y = centerY + rotatedY * zoom * math.cos(rotationX) - (location.elevationHeight * zoom * 0.5);
    
    return Offset(x, y);
  }


  double _getLocationRadius(LocationPoint location) {
    switch (location.type) {
      case 'FOUNDATION': return 6.0;
      case 'GATE': return 12.0; // Bigger for better visibility
      case 'STUPA': return 14.0;
      default: return 8.0;
    }
  }

  Color _getLocationColor(LocationPoint location, bool isSelected, bool isDestination, bool isOnPath) {
    if (isDestination) return AppColors.accent;
    if (isSelected) return AppColors.primary;
    if (isOnPath && isNavigating) return AppColors.primary.withAlpha(204);
    
    switch (location.type) {
      case 'FOUNDATION': 
        return Colors.brown;
      case 'GATE':
        // Different colors for different gate directions
        switch (location.direction) {
          case 'SOUTH': return Colors.red;      // Selatan = Merah
          case 'EAST': return Colors.orange;    // Timur = Orange 
          case 'NORTH': return Colors.blue;     // Utara = Biru
          case 'WEST': return Colors.green;     // Barat = Hijau
          default: return AppColors.primary;
        }
      case 'STUPA': 
        return AppColors.accent;
      default: 
        return AppColors.secondary;
    }
  }

  void _drawLocationIcon(Canvas canvas, LocationPoint location, Offset position) {
    String iconText;
    double fontSize;
    
    switch (location.type) {
      case 'FOUNDATION':
        iconText = '●';
        fontSize = 10;
        break;
      case 'GATE':
        // Different icons for different directions
        switch (location.direction) {
          case 'SOUTH': iconText = '▼'; break; // Panah bawah
          case 'EAST': iconText = '▶'; break;  // Panah kanan
          case 'NORTH': iconText = '▲'; break; // Panah atas
          case 'WEST': iconText = '◀'; break;  // Panah kiri
          default: iconText = '■'; break;
        }
        fontSize = 12;
        break;
      case 'STUPA':
        iconText = '▲';
        fontSize = 14;
        break;
      default:
        iconText = '●';
        fontSize = 10;
    }
    
    final iconPainter = TextPainter(
      text: TextSpan(
        text: iconText,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        position.dx - iconPainter.width / 2,
        position.dy - iconPainter.height / 2,
      ),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset position) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black54,
            offset: Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout(minWidth: 0, maxWidth: 120);
    final offset = Offset(position.dx - textPainter.width / 2, position.dy - 30);
    
    // Background
    final bgPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.dx - 4, offset.dy - 2, textPainter.width + 8, textPainter.height + 4),
        const Radius.circular(4),
      ),
      bgPaint,
    );
    
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant Borobudur3DMapPainter oldDelegate) {
    return oldDelegate.selectedLocation != selectedLocation ||
           oldDelegate.destinationLocation != destinationLocation ||
           oldDelegate.navigationPath != navigationPath ||
           oldDelegate.currentPosition != currentPosition ||
           oldDelegate.isNavigating != isNavigating ||
           oldDelegate.pulseValue != pulseValue ||
           oldDelegate.currentViewLevel != currentViewLevel ||
           oldDelegate.zoom != zoom ||
           oldDelegate.rotationY != rotationY ||
           oldDelegate.rotationX != rotationX ||
           oldDelegate.panOffset != panOffset;
  }
}