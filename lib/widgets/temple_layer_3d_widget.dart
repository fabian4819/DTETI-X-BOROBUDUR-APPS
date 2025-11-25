import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/level_detection_service.dart';
import '../models/temple_node.dart';
import '../utils/app_colors.dart';

/// 3D Temple Layering Widget
///
/// Displays all temple levels simultaneously with current level highlighting
/// based on barometer readings. Shows level separation through visual effects
/// like opacity, size, and elevation-based positioning.
class TempleLayer3DWidget extends StatefulWidget {
  final List<Marker> markers;
  final int currentLevel;
  final List<TempleLevelConfig> levelConfigs;
  final Function(int)? onLevelSelected;
  final bool showAllLevels;
  final MapController mapController;

  const TempleLayer3DWidget({
    super.key,
    required this.markers,
    required this.currentLevel,
    required this.levelConfigs,
    this.onLevelSelected,
    this.showAllLevels = true,
    required this.mapController,
  });

  @override
  State<TempleLayer3DWidget> createState() => _TempleLayer3DWidgetState();
}

class _TempleLayer3DWidgetState extends State<TempleLayer3DWidget>
    with TickerProviderStateMixin {

  late AnimationController _levelController;
  late Animation<double> _levelAnimation;
  int _highlightedLevel = 1;

  @override
  void initState() {
    super.initState();
    _highlightedLevel = widget.currentLevel;

    _levelController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _levelAnimation = CurvedAnimation(
      parent: _levelController,
      curve: Curves.easeInOut,
    );

    _levelController.forward();
  }

  @override
  void didUpdateWidget(TempleLayer3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentLevel != widget.currentLevel) {
      _highlightedLevel = widget.currentLevel;
      _levelController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _levelController.dispose();
    super.dispose();
  }

  /// Get level configuration for a given level
  TempleLevelConfig? _getLevelConfig(int level) {
    try {
      return widget.levelConfigs.firstWhere((config) => config.level == level);
    } catch (e) {
      return null;
    }
  }

  /// Filter markers by temple level
  List<Marker> _getMarkersForLevel(int level) {
    return widget.markers.where((marker) {
      // Try to extract level from marker widget or data
      // This is a simplified approach - in a real implementation,
      // you'd pass the level information with each marker
      return true; // For now, return all markers
    }).toList();
  }

  /// Calculate visual properties for a marker based on its level
  Marker _transformMarkerForLevel(Marker originalMarker, int markerLevel) {
    final isCurrentLevel = markerLevel == _highlightedLevel;
    final levelConfig = _getLevelConfig(markerLevel);

    // Calculate opacity based on level relationship to current level
    double opacity = 0.3; // Default for non-current levels
    double scale = 0.8;   // Default size reduction

    if (isCurrentLevel) {
      opacity = 1.0;
      scale = 1.2;
    } else {
      // Calculate distance from current level for gradual opacity
      final levelDistance = (markerLevel - _highlightedLevel).abs();
      opacity = (0.6 / (levelDistance + 1)).clamp(0.2, 0.8);
      scale = (1.0 / (levelDistance * 0.2 + 1)).clamp(0.6, 1.0);
    }

    // Animate the opacity
    opacity = opacity * _levelAnimation.value;

    return Marker(
      point: originalMarker.point,
      width: originalMarker.width! * scale,
      height: originalMarker.height! * scale,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(originalMarker.width! / 2),
            border: Border.all(
              color: isCurrentLevel
                  ? levelConfig?.color ?? AppColors.primary
                  : Colors.white,
              width: isCurrentLevel ? 3 : 1,
            ),
            boxShadow: isCurrentLevel ? [
              BoxShadow(
                color: (levelConfig?.color ?? AppColors.primary).withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: originalMarker.child,
        ),
      ),
    );
  }

  /// Build level selector widget
  Widget _buildLevelSelector() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.layers,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Lantai',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Level buttons
            ...widget.levelConfigs.map((config) => _buildLevelButton(config)),
          ],
        ),
      ),
    );
  }

  /// Build individual level button
  Widget _buildLevelButton(TempleLevelConfig config) {
    final isCurrentLevel = config.level == _highlightedLevel;

    return InkWell(
      onTap: () {
        setState(() {
          _highlightedLevel = config.level;
        });
        _levelController.forward(from: 0);
        widget.onLevelSelected?.call(config.level);
      },
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrentLevel ? config.color.withOpacity(0.2) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isCurrentLevel ? config.color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          children: [
            Text(
              '${config.level}',
              style: TextStyle(
                fontWeight: isCurrentLevel ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                color: isCurrentLevel ? config.color : Colors.black87,
              ),
            ),
            if (isCurrentLevel)
              Container(
                width: 20,
                height: 3,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: config.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build current level indicator
  Widget _buildCurrentLevelIndicator() {
    final currentConfig = _getLevelConfig(_highlightedLevel);

    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          border: Border.all(
            color: currentConfig?.color ?? AppColors.primary,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: currentConfig?.color ?? AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lantai $_highlightedLevel',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  currentConfig?.name ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build 3D elevation effect
  Widget _build3DEffect() {
    return AnimatedBuilder(
      animation: _levelAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _TempleLevelPainter(
            levelConfigs: widget.levelConfigs,
            currentLevel: _highlightedLevel,
            animation: _levelAnimation.value,
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Transform markers for 3D effect
    final transformedMarkers = widget.markers.map((marker) {
      // In a real implementation, you'd extract the level from the marker's data
      final markerLevel = 1; // Placeholder
      return _transformMarkerForLevel(marker, markerLevel);
    }).toList();

    return Stack(
      children: [
        // 3D effect overlay
        _build3DEffect(),

        // Marker layer with 3D transformations
        MarkerLayer(markers: transformedMarkers),

        // Level selector
        if (widget.showAllLevels) _buildLevelSelector(),

        // Current level indicator
        _buildCurrentLevelIndicator(),
      ],
    );
  }
}

/// Custom painter for 3D temple level visualization
class _TempleLevelPainter extends CustomPainter {
  final List<TempleLevelConfig> levelConfigs;
  final int currentLevel;
  final double animation;

  _TempleLevelPainter({
    required this.levelConfigs,
    required this.currentLevel,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw subtle level separation lines
    final paint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final config in levelConfigs) {
      final isCurrentLevel = config.level == currentLevel;

      // Set color and opacity based on current level
      paint.color = config.color.withOpacity(
        isCurrentLevel ? 0.3 * animation : 0.1,
      );

      // Draw horizontal lines to represent level separation
      final y = size.height * (1.0 - (config.level / 10.0));

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TempleLevelPainter oldDelegate) {
    return oldDelegate.currentLevel != currentLevel ||
           oldDelegate.animation != animation;
  }
}

/// 3D Temple Layer Button for toggling 3D view
class TempleLayer3DButton extends StatelessWidget {
  final bool is3DMode;
  final VoidCallback onPressed;

  const TempleLayer3DButton({
    super.key,
    required this.is3DMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      onPressed: onPressed,
      backgroundColor: is3DMode ? AppColors.primary : Colors.white,
      child: Icon(
        Icons.view_in_ar,
        color: is3DMode ? Colors.white : AppColors.primary,
        size: 20,
      ),
    );
  }
}

/// Level information widget
class LevelInfoWidget extends StatelessWidget {
  final TempleLevelConfig config;
  final bool isActive;

  const LevelInfoWidget({
    super.key,
    required this.config,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? config.color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? config.color : Colors.grey.withOpacity(0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: config.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Lantai ${config.level}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? config.color : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            config.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${config.minAltitude.toStringAsFixed(1)}-${config.maxAltitude.toStringAsFixed(1)}m',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          if (config.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              config.description,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}