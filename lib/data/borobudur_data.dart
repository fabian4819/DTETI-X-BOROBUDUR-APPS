import '../models/location_point.dart';
import 'dart:math' as math;

// Konstanta untuk area Borobudur
class BorobudurArea {
  static const double centerLat = -7.60794;
  static const double centerLon = 110.20386;
  static const double maxDistance = 150.0; // meter
}

// Dummy location untuk testing (dekat dengan area Borobudur)
final LocationPoint dummyUserLocation = LocationPoint(
  id: 'USER_DUMMY',
  name: 'Lokasi Testing',
  latitude: -7.60790,
  longitude: 110.20350,
  type: 'USER_LOCATION',
  description: 'Lokasi dummy untuk testing navigasi',
  level: 1,
  foundationIndex: 0,
);

// Helper function untuk generate koordinat dalam bentuk persegi
LocationPoint _generateFoundationPoint({
  required String id,
  required String name,
  required int level,
  required int index,
  required int totalPoints,
}) {
  final centerLat = BorobudurArea.centerLat;
  final centerLon = BorobudurArea.centerLon;
  
  // Ukuran sisi persegi dalam meter berdasarkan level
  final sideLength = _getSideLengthForLevel(level);
  final halfSide = sideLength / 2;
  
  // Hitung fondasi per sisi (totalPoints harus dibagi 4)
  final pointsPerSide = totalPoints ~/ 4;
  final sideIndex = index ~/ pointsPerSide; // 0=bawah, 1=kanan, 2=atas, 3=kiri
  final posInSide = index % pointsPerSide;
  
  double latOffset, lonOffset;
  
  switch (sideIndex) {
    case 0: // Sisi bawah (dari kiri ke kanan)
      latOffset = -halfSide / 111000;
      lonOffset = (-halfSide + (posInSide * sideLength / (pointsPerSide - 1))) / (111000 * math.cos(centerLat * math.pi / 180));
      break;
    case 1: // Sisi kanan (dari bawah ke atas)
      latOffset = (-halfSide + (posInSide * sideLength / (pointsPerSide - 1))) / 111000;
      lonOffset = halfSide / (111000 * math.cos(centerLat * math.pi / 180));
      break;
    case 2: // Sisi atas (dari kanan ke kiri)
      latOffset = halfSide / 111000;
      lonOffset = (halfSide - (posInSide * sideLength / (pointsPerSide - 1))) / (111000 * math.cos(centerLat * math.pi / 180));
      break;
    case 3: // Sisi kiri (dari atas ke bawah)
      latOffset = (halfSide - (posInSide * sideLength / (pointsPerSide - 1))) / 111000;
      lonOffset = -halfSide / (111000 * math.cos(centerLat * math.pi / 180));
      break;
    default:
      latOffset = 0;
      lonOffset = 0;
  }
  
  return LocationPoint(
    id: id,
    name: name,
    latitude: centerLat + latOffset,
    longitude: centerLon + lonOffset,
    type: 'FOUNDATION',
    level: level,
    foundationIndex: index + 1,
    description: 'Fondasi level $level - Sisi ${_getSideName(sideIndex)}',
  );
}

String _getSideName(int sideIndex) {
  switch (sideIndex) {
    case 0: return 'Selatan';
    case 1: return 'Timur';
    case 2: return 'Utara';
    case 3: return 'Barat';
    default: return 'Unknown';
  }
}

double _getSideLengthForLevel(int level) {
  switch (level) {
    case 1: return 160.0; // Level bawah: sisi terbesar
    case 2: return 140.0;
    case 3: return 120.0; // Level data asli
    case 4: return 100.0;
    case 5: return 80.0;
    case 6: return 60.0;
    case 7: return 40.0;
    case 8: return 30.0;
    case 9: return 10.0;  // Puncak: stupa utama
    default: return 120.0;
  }
}


// Generate gerbang untuk setiap level di tengah setiap sisi persegi
List<LocationPoint> _generateGatesForLevel(int level) {
  final gates = <LocationPoint>[];
  final directions = ['SOUTH', 'EAST', 'NORTH', 'WEST']; // Sesuai urutan sisi
  final directionNames = ['Selatan', 'Timur', 'Utara', 'Barat'];
  
  final centerLat = BorobudurArea.centerLat;
  final centerLon = BorobudurArea.centerLon;
  final sideLength = _getSideLengthForLevel(level);
  final halfSide = sideLength / 2;
  
  // Offset gerbang sedikit keluar dari perimeter untuk visibility
  final gateOffset = 5.0; // 5 meter keluar dari sisi
  
  for (int i = 0; i < 4; i++) {
    double latOffset, lonOffset;
    
    switch (i) {
      case 0: // Gerbang Selatan (tengah sisi bawah)
        latOffset = -(halfSide + gateOffset) / 111000;
        lonOffset = 0;
        break;
      case 1: // Gerbang Timur (tengah sisi kanan)
        latOffset = 0;
        lonOffset = (halfSide + gateOffset) / (111000 * math.cos(centerLat * math.pi / 180));
        break;
      case 2: // Gerbang Utara (tengah sisi atas)
        latOffset = (halfSide + gateOffset) / 111000;
        lonOffset = 0;
        break;
      case 3: // Gerbang Barat (tengah sisi kiri)
        latOffset = 0;
        lonOffset = -(halfSide + gateOffset) / (111000 * math.cos(centerLat * math.pi / 180));
        break;
      default:
        latOffset = 0;
        lonOffset = 0;
    }
    
    final gate = LocationPoint(
      id: 'GATE_L${level}_${directions[i]}',
      name: 'Gerbang ${directionNames[i]} L$level',
      latitude: centerLat + latOffset,
      longitude: centerLon + lonOffset,
      type: 'GATE',
      level: level,
      direction: directions[i],
      description: 'Akses ${directionNames[i].toLowerCase()} level $level',
    );
    gates.add(gate);
  }
  
  return gates;
}

// Generate semua titik untuk Borobudur
List<LocationPoint> _generateAllBorobudurPoints() {
  final allPoints = <LocationPoint>[];
  
  // Generate fondasi untuk setiap level
  for (int level = 1; level <= 8; level++) {
    final foundationCount = _getFoundationCountForLevel(level);
    
    for (int i = 0; i < foundationCount; i++) {
      final foundation = _generateFoundationPoint(
        id: 'F${level}_${i + 1}',
        name: 'Fondasi L$level-${i + 1}',
        level: level,
        index: i,
        totalPoints: foundationCount,
      );
      allPoints.add(foundation);
    }
    
    // Generate gerbang untuk level ini (semua level punya gerbang)
    allPoints.addAll(_generateGatesForLevel(level));
  }
  
  // Tambahkan stupa utama di puncak
  allPoints.add(LocationPoint(
    id: 'STUPA_MAIN',
    name: 'Stupa Utama',
    latitude: BorobudurArea.centerLat,
    longitude: BorobudurArea.centerLon,
    type: 'STUPA',
    level: 9,
    foundationIndex: 0, // Center point, tidak mengikuti sistem fondasi
    description: 'Stupa utama di puncak Borobudur',
  ));
  
  return allPoints;
}

int _getFoundationCountForLevel(int level) {
  switch (level) {
    case 1: return 36; // Level bawah: 9 fondasi per sisi persegi (4x9=36)
    case 2: return 32; // 8 fondasi per sisi (4x8=32)
    case 3: return 28; // 7 fondasi per sisi (4x7=28)
    case 4: return 24; // 6 fondasi per sisi (4x6=24)
    case 5: return 20; // 5 fondasi per sisi (4x5=20)
    case 6: return 16; // 4 fondasi per sisi (4x4=16)
    case 7: return 12; // 3 fondasi per sisi (4x3=12)
    case 8: return 8;  // 2 fondasi per sisi (4x2=8)
    default: return 28;
  }
}

// Daftar semua titik lokasi di Borobudur
final List<LocationPoint> borobudurLocations = _generateAllBorobudurPoints();

// Helper functions
List<LocationPoint> getFoundationsForLevel(int level) {
  return borobudurLocations
      .where((loc) => loc.type == 'FOUNDATION' && loc.level == level)
      .toList()
    ..sort((a, b) => a.foundationIndex.compareTo(b.foundationIndex));
}

List<LocationPoint> getFoundationsInOrder() {
  final foundations = borobudurLocations
      .where((loc) => loc.type == 'FOUNDATION')
      .toList();
  foundations.sort((a, b) {
    final levelCompare = a.level.compareTo(b.level);
    if (levelCompare != 0) return levelCompare;
    return a.foundationIndex.compareTo(b.foundationIndex);
  });
  return foundations;
}

List<LocationPoint> getGatesForLevel(int level) {
  return borobudurLocations
      .where((loc) => loc.type == 'GATE' && loc.level == level)
      .toList();
}

List<LocationPoint> getGates() {
  return borobudurLocations.where((loc) => loc.type == 'GATE').toList();
}

List<LocationPoint> getAllPointsForLevel(int level) {
  return borobudurLocations.where((loc) => loc.level == level).toList();
}

// Mendapatkan level yang tersedia
List<int> getAvailableLevels() {
  return [1, 2, 3, 4, 5, 6, 7, 8, 9];
}