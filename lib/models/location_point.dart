class LocationPoint {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String type; // 'FOUNDATION' or 'GATE'
  final String description;
  final int level; // Level lantai (1-9, dengan 1 = bawah, 9 = puncak)
  final int foundationIndex; // Index urutan fondasi dalam level
  final String direction; // 'NORTH', 'EAST', 'SOUTH', 'WEST' untuk gerbang

  LocationPoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.description = '',
    this.level = 3,
    this.foundationIndex = 0,
    this.direction = '',
  });

  // Helper untuk mendapatkan elevasi 3D berdasarkan level (level 1 = paling bawah)
  double get elevationHeight => (level - 1) * 12.0;
  
  // Helper untuk mendapatkan ukuran sisi persegi berdasarkan level
  double get sideLength {
    switch (level) {
      case 1: return 160.0; // Level bawah: sisi terbesar
      case 2: return 140.0;
      case 3: return 120.0;
      case 4: return 100.0;
      case 5: return 80.0;
      case 6: return 60.0;
      case 7: return 40.0;
      case 8: return 30.0;
      case 9: return 10.0;  // Puncak: stupa utama
      default: return 120.0;
    }
  }

  // Helper untuk mendapatkan posisi pada sisi persegi
  Map<String, dynamic> get squarePosition {
    if (foundationIndex == 0 || type == 'STUPA') {
      // Center position for stupa or special cases
      return {'side': 0, 'position': 0.0, 'x': 0.0, 'y': 0.0};
    }
    
    if (type == 'GATE') {
      // Special handling for gates - position them outside perimeter of each side
      final halfSide = sideLength / 2;
      final gateOffset = 5.0; // Same offset as in data generation
      
      switch (direction) {
        case 'SOUTH':
          return {'side': 0, 'position': 0.0, 'x': 0.0, 'y': -(halfSide + gateOffset)};
        case 'EAST':
          return {'side': 1, 'position': 0.0, 'x': halfSide + gateOffset, 'y': 0.0};
        case 'NORTH':
          return {'side': 2, 'position': 0.0, 'x': 0.0, 'y': halfSide + gateOffset};
        case 'WEST':
          return {'side': 3, 'position': 0.0, 'x': -(halfSide + gateOffset), 'y': 0.0};
        default:
          return {'side': 0, 'position': 0.0, 'x': 0.0, 'y': 0.0};
      }
    }
    
    final totalFoundations = _getFoundationCountForLevel(level);
    final pointsPerSide = totalFoundations ~/ 4;
    final sideIndex = (foundationIndex - 1) ~/ pointsPerSide; // 0=bawah, 1=kanan, 2=atas, 3=kiri
    final posInSide = (foundationIndex - 1) % pointsPerSide;
    final halfSide = sideLength / 2;
    
    double x, y;
    
    switch (sideIndex) {
      case 0: // Sisi bawah (dari kiri ke kanan)
        x = -halfSide + (posInSide * sideLength / (pointsPerSide - 1));
        y = -halfSide;
        break;
      case 1: // Sisi kanan (dari bawah ke atas)
        x = halfSide;
        y = -halfSide + (posInSide * sideLength / (pointsPerSide - 1));
        break;
      case 2: // Sisi atas (dari kanan ke kiri)
        x = halfSide - (posInSide * sideLength / (pointsPerSide - 1));
        y = halfSide;
        break;
      case 3: // Sisi kiri (dari atas ke bawah)
        x = -halfSide;
        y = halfSide - (posInSide * sideLength / (pointsPerSide - 1));
        break;
      default:
        x = 0;
        y = 0;
    }
    
    return {
      'side': sideIndex,
      'position': posInSide.toDouble(),
      'x': x,
      'y': y,
    };
  }

  // Helper untuk menentukan jumlah fondasi per level
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
      case 9: return 1;  // Puncak: stupa utama
      default: return 28;
    }
  }
}