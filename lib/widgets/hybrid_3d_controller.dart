import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/temple_node.dart';
// TempleFeature is already imported with temple_node.dart
import '../services/level_detection_service.dart';
import '../utils/app_colors.dart';
// Temporarily disable complex 3D widgets due to API compatibility issues
// import 'mapbox_3d_map_widget.dart';
// import 'enhanced_3d_map_widget.dart';

/// Visualization Mode Enum
enum VisualizationMode {
  map2D,          // Traditional 2D flat map
  // Temporarily disabled due to API compatibility issues
  // mapbox3D,       // Mapbox 3D terrain and buildings
  // enhanced3D,     // Enhanced 3D with temple layers
}

/// Hybrid 3D Controller
///
/// Manages seamless transitions between different visualization modes:
/// - 2D Map with markers (existing flutter_map)
/// - Mapbox 3D terrain with temple extrusions
/// - Detailed 3D temple models with interactive exploration
/// - Smooth animations and state management
/// - Integration with barometer level detection
class Hybrid3DController extends StatefulWidget {
  final List<TempleNode> templeNodes;
  final List<TempleFeature> templeFeatures;
  final int currentLevel;
  final List<TempleLevelConfig> levelConfigs;
  final Function(LatLng)? onMapTap;
  final Function(int)? onLevelSelected;
  final MapController? mapController;

  const Hybrid3DController({
    super.key,
    required this.templeNodes,
    required this.templeFeatures,
    required this.currentLevel,
    required this.levelConfigs,
    this.onMapTap,
    this.onLevelSelected,
    this.mapController,
  });

  @override
  State<Hybrid3DController> createState() => _Hybrid3DControllerState();
}

class _Hybrid3DControllerState extends State<Hybrid3DController>
    with TickerProviderStateMixin {

  VisualizationMode _currentMode = VisualizationMode.map2D;
  bool _isTransitioning = false;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Slide from right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Switch to a specific visualization mode with animation
  Future<void> _switchToMode(VisualizationMode newMode) async {
    if (_isTransitioning || newMode == _currentMode) {
      return;
    }

    setState(() {
      _isTransitioning = true;
    });

    // Determine animation direction
    final direction = _getAnimationDirection(_currentMode, newMode);

    // Prepare animation
    if (direction == AnimationDirection.fade) {
      await _fadeController.reverse();
    } else {
      await _slideController.reverse();
    }

    // Switch mode
    setState(() {
      _currentMode = newMode;
    });

    // Animate in new mode
    if (direction == AnimationDirection.fade) {
      await _fadeController.forward();
    } else {
      await _slideController.forward();
    }

    setState(() {
      _isTransitioning = false;
    });
  }

  AnimationDirection _getAnimationDirection(VisualizationMode from, VisualizationMode to) {
    // Simplified animation direction since only map2D is available
    return AnimationDirection.fade; // Default fade
  }

  /// Handle level change from barometer or user selection
  void _onLevelChanged(int newLevel) {
    widget.onLevelSelected?.call(newLevel);

    // Update current visualization if needed
    switch (_currentMode) {
      // Temporarily disabled 3D modes
      // case VisualizationMode.mapbox3D:
      //   // Mapbox will auto-update through widget rebuild
      //   break;
      // case VisualizationMode.enhanced3D:
      //   // Enhanced3DMapWidget handles level changes internally
      //   break;
      case VisualizationMode.map2D:
      default:
        // 2D map updates through existing system
        break;
    }
  }

  /// Handle map tap events
  void _onMapTap(LatLng location) {
    widget.onMapTap?.call(location);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main visualization content
        _buildCurrentVisualization(),

        // Transition overlay
        if (_isTransitioning)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),

        // Mode selector controls
        _buildModeControls(),

        // Current mode indicator
        _buildModeIndicator(),
      ],
    );
  }

  Widget _buildCurrentVisualization() {
    switch (_currentMode) {
      // Temporarily disabled mapbox3D case
      // case VisualizationMode.mapbox3D:
      //   return AnimatedBuilder(
      //     animation: _fadeAnimation,
      //     builder: (context, child) {
      //       return Opacity(
      //         opacity: _fadeAnimation.value,
      //         child: Mapbox3DMapWidget(
      //           templeNodes: widget.templeNodes,
      //           templeFeatures: widget.templeFeatures,
      //           currentLevel: widget.currentLevel,
      //           levelConfigs: widget.levelConfigs,
      //           onLevelSelected: _onLevelChanged,
      //           onMapTap: _onMapTap,
      //         ),
      //       );
      //     },
      //   );

      // Temporarily disabled 3D modes
      // case VisualizationMode.enhanced3D:
      //   return AnimatedBuilder(
      //     animation: _fadeAnimation,
      //     builder: (context, child) {
      //       return Opacity(
      //         opacity: _fadeAnimation.value,
      //         child: Enhanced3DMapWidget(
      //           templeNodes: widget.templeNodes,
      //           templeFeatures: widget.templeFeatures,
      //           currentLevel: widget.currentLevel,
      //           levelConfigs: widget.levelConfigs,
      //           onLevelSelected: _onLevelChanged,
      //           onMapTap: _onMapTap,
      //         ),
      //       );
      //     },
      //   );

      case VisualizationMode.map2D:
      default:
        return AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: GestureDetector(
                onTap: () {
                  // Simple tap handler for the map
                  _onMapTap(const LatLng(-7.607874, 110.203751));
                },
                child: FlutterMap(
                  mapController: widget.mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(-7.607874, 110.203751), // Borobudur center
                    initialZoom: 16.0,
                    minZoom: 10.0,
                    maxZoom: 20.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'borobudur_app',
                      maxNativeZoom: 19,
                    ),
                    // Add existing markers and polylines here
                  ],
                ),
              ),
            );
          },
        );
    }
  }

  Widget _buildModeControls() {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          // Mode selector buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton(
                  icon: Icons.map,
                  label: '2D',
                  mode: VisualizationMode.map2D,
                  tooltip: 'Traditional 2D Map View',
                ),
                // Temporarily disabled 3D modes due to API compatibility
                // _buildModeButton(
                //   icon: Icons.view_in_ar,
                //   label: '3D',
                //   mode: VisualizationMode.mapbox3D,
                //   tooltip: '3D Terrain and Buildings',
                // ),
                // _buildModeButton(
                //   icon: Icons.view_in_ar,
                //   label: '3D+',
                //   mode: VisualizationMode.enhanced3D,
                //   tooltip: 'Enhanced 3D Temple View',
                // ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Camera controls for 3D modes - temporarily disabled
          // if (_currentMode != VisualizationMode.map2D)
          //   Container(
          //     decoration: BoxDecoration(
          //       color: Colors.white,
          //       borderRadius: BorderRadius.circular(12),
          //       boxShadow: [
          //         BoxShadow(
          //           color: Colors.black.withOpacity(0.2),
          //           blurRadius: 8,
          //           offset: const Offset(0, 2),
          //         ),
          //       ],
          //     ),
          //     child: Column(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         _buildCameraControl(
          //           icon: Icons.tune,
          //           tooltip: 'Adjust 3D Perspective',
          //           onPressed: _adjust3DPerspective,
          //         ),
          //         _buildCameraControl(
          //           icon: Icons.center_focus_strong,
          //           tooltip: 'Reset Camera',
          //           onPressed: _resetCamera,
          //         ),
          //       ],
          //     ),
          //   ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required VisualizationMode mode,
    required String tooltip,
  }) {
    final isActive = _currentMode == mode;

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : AppColors.primary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(icon, color: AppColors.primary, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _buildModeIndicator() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getModeIcon(),
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              _getModeLabel(),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModeIcon() {
    switch (_currentMode) {
      case VisualizationMode.map2D:
        return Icons.map;
      // Temporarily disabled 3D modes
      // case VisualizationMode.mapbox3D:
      //   return Icons.view_in_ar;
      // case VisualizationMode.enhanced3D:
      //   return Icons.view_in_ar;
      default:
        return Icons.map;
    }
  }

  String _getModeLabel() {
    switch (_currentMode) {
      case VisualizationMode.map2D:
        return '2D Map';
      // Temporarily disabled 3D modes
      // case VisualizationMode.mapbox3D:
      //   return '3D Map';
      // case VisualizationMode.enhanced3D:
      //   return '3D Enhanced';
      default:
        return '2D Map';
    }
  }

  Future<void> _adjust3DPerspective() async {
    // Show dialog for adjusting 3D perspective
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('3D Perspective Controls'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('3D functionality temporarily disabled'),
            const SizedBox(height: 8),
            const Text('Use 2D map mode for now'),
            const SizedBox(height: 16),
            // Temporarily disabled 3D controls
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     ElevatedButton(
            //       onPressed: () {
            //         Navigator.of(context).pop();
            //         _increase3DPerspective();
            //       },
            //       child: const Text('More 3D'),
            //     ),
            //     ElevatedButton(
            //       onPressed: () {
            //         Navigator.of(context).pop();
            //         _decrease3DPerspective();
            //       },
            //       child: const Text('Less 3D'),
            //     ),
            //   ],
            // ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Temporarily disabled 3D perspective methods
// Future<void> _increase3DPerspective() async {
//   // Increase 3D perspective for Mapbox 3D
//   if (_currentMode == VisualizationMode.mapbox3D) {
//     // This would call the Mapbox3DMapWidget's increasePerspective method
//     // Implementation depends on the exact Mapbox Maps Flutter SDK API
//   }
// }
//
// Future<void> _decrease3DPerspective() async {
//   // Decrease 3D perspective for Mapbox 3D
//   if (_currentMode == VisualizationMode.mapbox3D) {
//     // This would call the Mapbox3DMapWidget's decreasePerspective method
//   }
// }

  Future<void> _resetCamera() async {
    // Reset camera to default position for current mode
    switch (_currentMode) {
      // Temporarily disabled 3D modes
      // case VisualizationMode.mapbox3D:
      //   // Reset Mapbox 3D camera
      //   break;
      // case VisualizationMode.enhanced3D:
      //   // Enhanced3DMapWidget handles camera reset internally
      //   break;
      case VisualizationMode.map2D:
      default:
        // Reset 2D map camera
        if (widget.mapController != null) {
          widget.mapController!.move(
            const LatLng(-7.607874, 110.203751),
            16.0,
          );
        }
        break;
    }
  }

  /// Public method to programmatically switch visualization modes
  Future<void> switchToMode(VisualizationMode mode) async {
    await _switchToMode(mode);
  }

  /// Get current visualization mode
  VisualizationMode get currentMode => _currentMode;

  /// Check if currently transitioning between modes
  bool get isTransitioning => _isTransitioning;
}

enum AnimationDirection {
  fade,
  slide,
}