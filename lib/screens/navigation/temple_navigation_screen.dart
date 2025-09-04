import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../models/temple_node.dart';
import '../../services/temple_navigation_service.dart';
import '../../utils/app_colors.dart';

class TempleNavigationScreen extends StatefulWidget {
  const TempleNavigationScreen({super.key});

  @override
  State<TempleNavigationScreen> createState() => _TempleNavigationScreenState();
}

class _TempleNavigationScreenState extends State<TempleNavigationScreen> with TickerProviderStateMixin {
  final TempleNavigationService _navigationService = TempleNavigationService();
  
  TempleNode? selectedNode;
  TempleFeature? selectedFeature;
  TempleNode? destinationNode;
  TempleFeature? destinationFeature;
  bool isNavigating = false;
  String searchQuery = '';
  int currentViewLevel = 1;
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<NavigationUpdate>? _navigationSubscription;
  Position? _currentPosition;
  NavigationUpdate? _currentNavigationUpdate;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Future: View controls for 3D implementation could be added here

  @override
  void initState() {
    super.initState();
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
      
      await _navigationService.startLocationTracking();
      
      _positionSubscription = _navigationService.positionStream?.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });

      _navigationSubscription = _navigationService.navigationUpdateStream?.listen((update) {
        if (mounted) {
          setState(() {
            _currentNavigationUpdate = update;
          });
        }
      });
    } catch (e) {
      debugPrint('Failed to initialize location tracking: $e');
    }
  }

  void _onLocationSelected(dynamic location) {
    setState(() {
      if (location is TempleNode) {
        selectedNode = location;
        selectedFeature = null;
      } else if (location is TempleFeature) {
        selectedFeature = location;
        selectedNode = null;
      }
    });
  }

  void _onDestinationSelected(dynamic destination) {
    setState(() {
      if (destination is TempleNode) {
        destinationNode = destination;
        destinationFeature = null;
      } else if (destination is TempleFeature) {
        destinationFeature = destination;
        destinationNode = null;
      }
    });
  }

  Future<void> _startNavigation() async {
    if (_currentPosition == null) {
      _showMessage('Lokasi GPS tidak tersedia', Colors.red);
      return;
    }

    if (destinationNode == null && destinationFeature == null) {
      _showMessage('Pilih tujuan terlebih dahulu', Colors.orange);
      return;
    }

    try {
      final result = await _navigationService.startNavigation(
        fromLat: _currentPosition!.latitude,
        fromLon: _currentPosition!.longitude,
        toNode: destinationNode,
        toFeature: destinationFeature,
      );

      if (result.success) {
        setState(() {
          isNavigating = true;
        });
        _showMessage('Navigasi dimulai', Colors.green);
      } else {
        _showMessage(result.message, Colors.red);
      }
    } catch (e) {
      _showMessage('Gagal memulai navigasi: $e', Colors.red);
    }
  }

  void _stopNavigation() {
    _navigationService.stopNavigation();
    setState(() {
      isNavigating = false;
      _currentNavigationUpdate = null;
    });
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

  List<TempleNode> _getFilteredNodes() {
    final nodes = _navigationService.getNodesByLevel(currentViewLevel);
    if (searchQuery.isEmpty) return nodes;
    
    return nodes.where((node) =>
        node.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
  }

  List<TempleFeature> _getFilteredFeatures() {
    final features = _navigationService.getFeaturesByLevel(currentViewLevel);
    if (searchQuery.isEmpty) return features;
    
    return features.where((feature) =>
        feature.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Navigasi Candi Borobudur',
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
            itemBuilder: (context) {
              final availableLevels = _navigationService.getAvailableLevels().toList()..sort();
              return availableLevels.map((level) {
                return PopupMenuItem(
                  value: level,
                  child: Text('Level $level'),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
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

          // Navigation panel (when navigating)
          if (isNavigating && _currentNavigationUpdate != null)
            Container(
              width: double.infinity,
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

          // Search bar
          Container(
            margin: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari lokasi...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Location lists
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primary,
                    tabs: [
                      Tab(text: 'Nodes (${_getFilteredNodes().length})'),
                      Tab(text: 'Features (${_getFilteredFeatures().length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildNodesList(),
                        _buildFeaturesList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Selected items info
                if (selectedNode != null || selectedFeature != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dipilih: ${selectedNode?.name ?? selectedFeature?.name}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (destinationNode != null || destinationFeature != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.green),
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
                        label: Text(isNavigating ? 'Stop' : 'Navigasi'),
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
        ],
      ),
    );
  }

  Widget _buildNodesList() {
    final nodes = _getFilteredNodes();
    
    if (nodes.isEmpty) {
      return const Center(
        child: Text('Tidak ada node di level ini'),
      );
    }

    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        final isSelected = selectedNode?.id == node.id;
        final isDestination = destinationNode?.id == node.id;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getNodeColor(node.type),
              child: Icon(
                _getNodeIcon(node.type),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(node.name),
            subtitle: Text('${node.type} • Level ${node.level}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Icon(Icons.location_on, color: Colors.blue),
                if (isDestination)
                  const Icon(Icons.flag, color: Colors.green),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'select') {
                      _onLocationSelected(node);
                    } else if (value == 'destination') {
                      _onDestinationSelected(node);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'select', child: Text('Pilih Lokasi')),
                    const PopupMenuItem(value: 'destination', child: Text('Set Tujuan')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturesList() {
    final features = _getFilteredFeatures();
    
    if (features.isEmpty) {
      return const Center(
        child: Text('Tidak ada fitur di level ini'),
      );
    }

    return ListView.builder(
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        final isSelected = selectedFeature?.id == feature.id;
        final isDestination = destinationFeature?.id == feature.id;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getFeatureColor(feature.type),
              child: Icon(
                _getFeatureIcon(feature.type),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(feature.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${feature.type} • Level ${feature.level}'),
                if (feature.distanceM != null)
                  Text('${feature.distanceM!.toStringAsFixed(0)}m dari Anda'),
              ],
            ),
            isThreeLine: feature.distanceM != null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Icon(Icons.location_on, color: Colors.blue),
                if (isDestination)
                  const Icon(Icons.flag, color: Colors.green),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'select') {
                      _onLocationSelected(feature);
                    } else if (value == 'destination') {
                      _onDestinationSelected(feature);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'select', child: Text('Pilih Lokasi')),
                    const PopupMenuItem(value: 'destination', child: Text('Set Tujuan')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getNodeColor(String type) {
    switch (type.toUpperCase()) {
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

  IconData _getNodeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'STUPA':
        return Icons.account_balance;
      case 'FOUNDATION':
        return Icons.foundation;
      case 'GATE':
        return Icons.door_front_door;
      default:
        return Icons.circle;
    }
  }

  Color _getFeatureColor(String type) {
    switch (type.toUpperCase()) {
      case 'STUPA':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  IconData _getFeatureIcon(String type) {
    switch (type.toUpperCase()) {
      case 'STUPA':
        return Icons.temple_buddhist;
      default:
        return Icons.place;
    }
  }
}