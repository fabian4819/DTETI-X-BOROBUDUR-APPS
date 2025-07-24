import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../utils/app_colors.dart';

// Model untuk lokasi
class LocationPoint {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type; // 'JALAN' atau 'FOUNDATION'
  final String description;

  LocationPoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.description = '',
  });
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  LocationPoint? selectedLocation;
  LocationPoint? startLocation;
  LocationPoint? endLocation;
  bool showRoute = false;
  String searchQuery = '';
  List<LocationPoint> filteredLocations = [];

  // Data koordinat Candi Borobudur
  final List<LocationPoint> borobudurLocations = [
    LocationPoint(
      id: 'JALAN_1',
      name: 'Jalan Masuk Utama',
      latitude: -7.60794,
      longitude: 110.20352,
      type: 'JALAN',
    ),
    LocationPoint(
      id: 'F1',
      name: 'Fondasi F1',
      latitude: -7.60804,
      longitude: 110.20347,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F2',
      name: 'Fondasi F2',
      latitude: -7.60795,
      longitude: 110.20349,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F3',
      name: 'Fondasi F3',
      latitude: -7.60774,
      longitude: 110.20356,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F4',
      name: 'Fondasi F4',
      latitude: -7.60786,
      longitude: 110.20357,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F5',
      name: 'Fondasi F5',
      latitude: -7.60764,
      longitude: 110.20349,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F6',
      name: 'Fondasi F6',
      latitude: -7.60762,
      longitude: 110.20363,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F7',
      name: 'Fondasi F7',
      latitude: -7.60760,
      longitude: 110.20363,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F8',
      name: 'Fondasi F8',
      latitude: -7.60759,
      longitude: 110.20380,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F9',
      name: 'Fondasi F9',
      latitude: -7.60759,
      longitude: 110.20378,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'JALAN_2',
      name: 'Jalan Tengah',
      latitude: -7.60761,
      longitude: 110.20381,
      type: 'JALAN',
    ),
    LocationPoint(
      id: 'F10',
      name: 'Fondasi F10',
      latitude: -7.60758,
      longitude: 110.20389,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F11',
      name: 'Fondasi F11',
      latitude: -7.60762,
      longitude: 110.20390,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F12',
      name: 'Fondasi F12',
      latitude: -7.60763,
      longitude: 110.20400,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F13',
      name: 'Fondasi F13',
      latitude: -7.60760,
      longitude: 110.20407,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F14',
      name: 'Fondasi F14',
      latitude: -7.60764,
      longitude: 110.20408,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F15',
      name: 'Fondasi F15',
      latitude: -7.60771,
      longitude: 110.20416,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F16',
      name: 'Fondasi F16',
      latitude: -7.60772,
      longitude: 110.20418,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F17',
      name: 'Fondasi F17',
      latitude: -7.60805,
      longitude: 110.20401,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F18',
      name: 'Fondasi F18',
      latitude: -7.60793,
      longitude: 110.20421,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'JALAN_3',
      name: 'Jalan Keliling',
      latitude: -7.60796,
      longitude: 110.20420,
      type: 'JALAN',
    ),
    LocationPoint(
      id: 'F19',
      name: 'Fondasi F19',
      latitude: -7.60804,
      longitude: 110.20421,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F20',
      name: 'Fondasi F20',
      latitude: -7.60803,
      longitude: 110.20415,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F21',
      name: 'Fondasi F21',
      latitude: -7.60819,
      longitude: 110.20420,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F22',
      name: 'Fondasi F22',
      latitude: -7.60821,
      longitude: 110.20417,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F23',
      name: 'Fondasi F23',
      latitude: -7.60830,
      longitude: 110.20417,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F24',
      name: 'Fondasi F24',
      latitude: -7.60829,
      longitude: 110.20406,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F25',
      name: 'Fondasi F25',
      latitude: -7.60834,
      longitude: 110.20406,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F26',
      name: 'Fondasi F26',
      latitude: -7.60831,
      longitude: 110.20390,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F27',
      name: 'Fondasi F27',
      latitude: -7.60834,
      longitude: 110.20389,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'JALAN_4',
      name: 'Jalan Selatan',
      latitude: -7.60832,
      longitude: 110.20382,
      type: 'JALAN',
    ),
    LocationPoint(
      id: 'F28',
      name: 'Fondasi F28',
      latitude: -7.60832,
      longitude: 110.20378,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F29',
      name: 'Fondasi F29',
      latitude: -7.60829,
      longitude: 110.20381,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F30',
      name: 'Fondasi F30',
      latitude: -7.60832,
      longitude: 110.20364,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F31',
      name: 'Fondasi F31',
      latitude: -7.60827,
      longitude: 110.20362,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F32',
      name: 'Fondasi F32',
      latitude: -7.60830,
      longitude: 110.20350,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F33',
      name: 'Fondasi F33',
      latitude: -7.60821,
      longitude: 110.20343,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F34',
      name: 'Fondasi F34',
      latitude: -7.60818,
      longitude: 110.20346,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F35',
      name: 'Fondasi F35',
      latitude: -7.60795,
      longitude: 110.20348,
      type: 'FOUNDATION',
    ),
    LocationPoint(
      id: 'F36',
      name: 'Fondasi F36',
      latitude: -7.60801,
      longitude: 110.20343,
      type: 'FOUNDATION',
    ),
  ];

  @override
  void initState() {
    super.initState();
    filteredLocations = borobudurLocations;
  }

  // Hitung jarak antara dua koordinat (dalam meter)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meter
    double dLat = (lat2 - lat1) * (math.pi / 180);
    double dLon = (lon2 - lon1) * (math.pi / 180);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Konversi koordinat ke posisi pixel pada layar
  Offset coordinateToPixel(double lat, double lon, Size mapSize) {
    // Batas koordinat Borobudur
    const double minLat = -7.60840;
    const double maxLat = -7.60750;
    const double minLon = 110.20340;
    const double maxLon = 110.20430;

    double x = ((lon - minLon) / (maxLon - minLon)) * mapSize.width;
    double y = ((maxLat - lat) / (maxLat - minLat)) * mapSize.height;

    return Offset(x, y);
  }

  void _searchLocations(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredLocations = borobudurLocations;
      } else {
        filteredLocations =
            borobudurLocations
                .where(
                  (location) =>
                      location.name.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      location.id.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  void _startNavigation() {
    if (startLocation != null && endLocation != null) {
      setState(() {
        showRoute = true;
      });

      double distance = calculateDistance(
        startLocation!.latitude,
        startLocation!.longitude,
        endLocation!.latitude,
        endLocation!.longitude,
      );

      _showNavigationDialog(distance);
    }
  }

  void _showNavigationDialog(double distance) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Navigasi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dari: ${startLocation!.name}'),
                Text('Ke: ${endLocation!.name}'),
                const SizedBox(height: 10),
                Text('Jarak: ${distance.toStringAsFixed(0)} meter'),
                Text(
                  'Estimasi waktu: ${(distance / 1.4).toStringAsFixed(0)} detik',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Implementasi navigasi turn-by-turn bisa ditambahkan di sini
                },
                child: const Text('Mulai Navigasi'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Navigasi'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            // color: Colors.green.shade50,
            child: TextField(
              onChanged: _searchLocations,
              decoration: InputDecoration(
                hintText: 'Cari lokasi...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Navigation Controls
          if (showRoute || startLocation != null || endLocation != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dari: ${startLocation?.name ?? "Pilih lokasi awal"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            startLocation = null;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ke: ${endLocation?.name ?? "Pilih tujuan"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            endLocation = null;
                          });
                        },
                      ),
                    ],
                  ),
                  if (startLocation != null && endLocation != null)
                    ElevatedButton(
                      onPressed: _startNavigation,
                      child: const Text('Mulai Navigasi'),
                    ),
                ],
              ),
            ),

          // Map Area
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  painter: BorobudurMapPainter(
                    locations: borobudurLocations,
                    selectedLocation: selectedLocation,
                    startLocation: startLocation,
                    endLocation: endLocation,
                    showRoute: showRoute,
                  ),
                  child: GestureDetector(
                    onTapDown: (details) {
                      final RenderBox renderBox =
                          context.findRenderObject() as RenderBox;
                      final localPosition = renderBox.globalToLocal(
                        details.globalPosition,
                      );
                      _selectLocationAtPosition(localPosition);
                    },
                    child: Container(),
                  ),
                ),
              ),
            ),
          ),

          // Location List
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lokasi (${filteredLocations.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredLocations.length,
                      itemBuilder: (context, index) {
                        final location = filteredLocations[index];
                        final isSelected = selectedLocation?.id == location.id;
                        final isStart = startLocation?.id == location.id;
                        final isEnd = endLocation?.id == location.id;

                        return Card(
                          color:
                              isSelected
                                  ? Colors.blue.shade100
                                  : isStart
                                  ? Colors.green.shade100
                                  : isEnd
                                  ? Colors.red.shade100
                                  : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  location.type == 'JALAN'
                                      ? Colors.blue
                                      : Colors.orange,
                              child: Icon(
                                location.type == 'JALAN'
                                    ? Icons
                                        .route // Ganti dari Icons.road
                                    : Icons.location_on,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(location.name),
                            subtitle: Text(
                              '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'start':
                                    setState(() {
                                      startLocation = location;
                                    });
                                    break;
                                  case 'end':
                                    setState(() {
                                      endLocation = location;
                                    });
                                    break;
                                  case 'select':
                                    setState(() {
                                      selectedLocation = location;
                                    });
                                    break;
                                }
                              },
                              itemBuilder:
                                  (context) => [
                                    const PopupMenuItem(
                                      value: 'select',
                                      child: Text('Pilih Lokasi'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'start',
                                      child: Text('Set sebagai Awal'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'end',
                                      child: Text('Set sebagai Tujuan'),
                                    ),
                                  ],
                            ),
                            onTap: () {
                              setState(() {
                                selectedLocation = location;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectLocationAtPosition(Offset position) {
    // Implementasi untuk memilih lokasi berdasarkan posisi tap
    // Bisa ditambahkan logika untuk mendeteksi tap pada marker
  }
}

class BorobudurMapPainter extends CustomPainter {
  final List<LocationPoint> locations;
  final LocationPoint? selectedLocation;
  final LocationPoint? startLocation;
  final LocationPoint? endLocation;
  final bool showRoute;

  BorobudurMapPainter({
    required this.locations,
    this.selectedLocation,
    this.startLocation,
    this.endLocation,
    this.showRoute = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final backgroundPaint = Paint()..color = Colors.green.shade50;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Grid lines
    final gridPaint =
        Paint()
          ..color = Colors.grey.shade300
          ..strokeWidth = 0.5;

    for (int i = 0; i <= 10; i++) {
      double x = (size.width / 10) * i;
      double y = (size.height / 10) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Route line
    if (showRoute && startLocation != null && endLocation != null) {
      final routePaint =
          Paint()
            ..color = Colors.blue
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke;

      final startPos = _coordinateToPixel(
        startLocation!.latitude,
        startLocation!.longitude,
        size,
      );
      final endPos = _coordinateToPixel(
        endLocation!.latitude,
        endLocation!.longitude,
        size,
      );

      canvas.drawLine(startPos, endPos, routePaint);
    }

    // Draw locations
    for (final location in locations) {
      final position = _coordinateToPixel(
        location.latitude,
        location.longitude,
        size,
      );

      // Marker circle
      final markerPaint =
          Paint()
            ..color = _getLocationColor(location)
            ..style = PaintingStyle.fill;

      canvas.drawCircle(position, 6, markerPaint);

      // Border
      final borderPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;

      canvas.drawCircle(position, 6, borderPaint);

      // Label
      if (selectedLocation?.id == location.id) {
        _drawLabel(canvas, location.name, position, size);
      }
    }
  }

  Color _getLocationColor(LocationPoint location) {
    if (startLocation?.id == location.id) return Colors.green;
    if (endLocation?.id == location.id) return Colors.red;
    if (selectedLocation?.id == location.id) return Colors.blue;
    return location.type == 'JALAN'
        ? Colors.blue.shade600
        : Colors.orange.shade600;
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final labelRect = Rect.fromLTWH(
      position.dx - textPainter.width / 2,
      position.dy - 20,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    final labelPaint = Paint()..color = Colors.white.withOpacity(0.9);

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      labelPaint,
    );

    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - 18),
    );
  }

  Offset _coordinateToPixel(double lat, double lon, Size mapSize) {
    const double minLat = -7.60840;
    const double maxLat = -7.60750;
    const double minLon = 110.20340;
    const double maxLon = 110.20430;

    double x = ((lon - minLon) / (maxLon - minLon)) * mapSize.width;
    double y = ((maxLat - lat) / (maxLat - minLat)) * mapSize.height;

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
