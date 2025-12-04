import '../models/temple_node.dart';

/// Data dummy untuk fasilitas di area Borobudur (luar candi)
/// Koordinat berdasarkan lokasi real di sekitar Candi Borobudur
class BorobudurFacilitiesData {
  static List<TempleFeature> getFacilities() {
    return [
      // Entrance & Ticketing
      TempleFeature(
        id: 101,
        name: 'Pintu Masuk Utama',
        type: 'entrance',
        latitude: -7.6091,
        longitude: 110.2037,
        description: 'Pintu masuk utama kompleks Candi Borobudur',
      ),
      TempleFeature(
        id: 102,
        name: 'Loket Tiket',
        type: 'ticket_booth',
        latitude: -7.6093,
        longitude: 110.2038,
        description: 'Tempat pembelian tiket masuk',
      ),

      // Toilets
      TempleFeature(
        id: 103,
        name: 'Toilet Area Utara',
        type: 'toilet',
        latitude: -7.6070,
        longitude: 110.2035,
        description: 'Fasilitas toilet di area utara',
      ),
      TempleFeature(
        id: 104,
        name: 'Toilet Area Selatan',
        type: 'toilet',
        latitude: -7.6095,
        longitude: 110.2040,
        description: 'Fasilitas toilet di area selatan',
      ),
      TempleFeature(
        id: 105,
        name: 'Toilet Dekat Parkir',
        type: 'toilet',
        latitude: -7.6098,
        longitude: 110.2033,
        description: 'Fasilitas toilet dekat area parkir',
      ),

      // Museums
      TempleFeature(
        id: 106,
        name: 'Museum Karmawibhangga',
        type: 'museum',
        latitude: -7.6085,
        longitude: 110.2025,
        description: 'Museum yang menyimpan foto-foto relief Karmawibhangga',
      ),
      TempleFeature(
        id: 107,
        name: 'Museum Samudraraksa',
        type: 'museum',
        latitude: -7.6100,
        longitude: 110.2028,
        description: 'Museum kapal Samudraraksa yang berlayar ke Afrika',
      ),

      // Auditorium & Theater
      TempleFeature(
        id: 108,
        name: 'Auditorium Borobudur',
        type: 'auditorium',
        latitude: -7.6088,
        longitude: 110.2020,
        description: 'Auditorium untuk pertunjukan dan presentasi',
      ),
      TempleFeature(
        id: 109,
        name: 'Manohara Theater',
        type: 'theater',
        latitude: -7.6095,
        longitude: 110.2018,
        description: 'Theater multimedia tentang sejarah Borobudur',
      ),

      // Restaurants & Cafes
      TempleFeature(
        id: 110,
        name: 'Resto Patio',
        type: 'restaurant',
        latitude: -7.6092,
        longitude: 110.2042,
        description: 'Restoran dengan pemandangan candi',
      ),
      TempleFeature(
        id: 111,
        name: 'Cafe Gowes',
        type: 'cafe',
        latitude: -7.6096,
        longitude: 110.2044,
        description: 'Kafe dengan menu ringan dan minuman',
      ),
      TempleFeature(
        id: 112,
        name: 'Food Court',
        type: 'food_court',
        latitude: -7.6097,
        longitude: 110.2036,
        description: 'Area food court dengan berbagai pilihan makanan',
      ),

      // Souvenir Shops
      TempleFeature(
        id: 113,
        name: 'Toko Souvenir Utama',
        type: 'shop',
        latitude: -7.6094,
        longitude: 110.2039,
        description: 'Toko souvenir dan oleh-oleh khas Borobudur',
      ),
      TempleFeature(
        id: 114,
        name: 'Galeri Kerajinan',
        type: 'shop',
        latitude: -7.6090,
        longitude: 110.2046,
        description: 'Galeri kerajinan lokal dan seni',
      ),

      // Parking Areas
      TempleFeature(
        id: 115,
        name: 'Parkir Bus',
        type: 'parking',
        latitude: -7.6102,
        longitude: 110.2032,
        description: 'Area parkir khusus bus wisata',
      ),
      TempleFeature(
        id: 116,
        name: 'Parkir Mobil',
        type: 'parking',
        latitude: -7.6100,
        longitude: 110.2036,
        description: 'Area parkir kendaraan mobil',
      ),
      TempleFeature(
        id: 117,
        name: 'Parkir Motor',
        type: 'parking',
        latitude: -7.6099,
        longitude: 110.2038,
        description: 'Area parkir sepeda motor',
      ),

      // Prayer Rooms
      TempleFeature(
        id: 118,
        name: 'Mushola Al-Hikmah',
        type: 'prayer_room',
        latitude: -7.6093,
        longitude: 110.2034,
        description: 'Mushola untuk ibadah umat muslim',
      ),

      // Information Centers
      TempleFeature(
        id: 119,
        name: 'Pusat Informasi Wisata',
        type: 'information',
        latitude: -7.6092,
        longitude: 110.2037,
        description: 'Pusat informasi dan panduan wisata',
      ),
      TempleFeature(
        id: 120,
        name: 'Tourist Guide Post',
        type: 'information',
        latitude: -7.6087,
        longitude: 110.2041,
        description: 'Pos pemandu wisata',
      ),

      // Medical & Safety
      TempleFeature(
        id: 121,
        name: 'Klinik Kesehatan',
        type: 'medical',
        latitude: -7.6089,
        longitude: 110.2032,
        description: 'Klinik kesehatan dan P3K',
      ),
      TempleFeature(
        id: 122,
        name: 'Pos Keamanan',
        type: 'security',
        latitude: -7.6091,
        longitude: 110.2041,
        description: 'Pos keamanan dan petugas',
      ),

      // Recreation Areas
      TempleFeature(
        id: 123,
        name: 'Taman Lumbini',
        type: 'park',
        latitude: -7.6105,
        longitude: 110.2025,
        description: 'Taman dengan berbagai stupa mini',
      ),
      TempleFeature(
        id: 124,
        name: 'Area Foto Spot',
        type: 'photo_spot',
        latitude: -7.6082,
        longitude: 110.2043,
        description: 'Lokasi foto dengan pemandangan terbaik',
      ),

      // Hotels Nearby
      TempleFeature(
        id: 125,
        name: 'Manohara Hotel',
        type: 'hotel',
        latitude: -7.6095,
        longitude: 110.2050,
        description: 'Hotel terdekat dengan akses sunrise',
      ),

      // Additional Services
      TempleFeature(
        id: 126,
        name: 'ATM Center',
        type: 'atm',
        latitude: -7.6094,
        longitude: 110.2035,
        description: 'Anjungan tunai mandiri',
      ),
      TempleFeature(
        id: 127,
        name: 'Bike Rental',
        type: 'rental',
        latitude: -7.6096,
        longitude: 110.2041,
        description: 'Rental sepeda untuk berkeliling area',
      ),
    ];
  }

  /// Get icon for facility type
  static String getIconForType(String type) {
    switch (type) {
      case 'entrance':
        return '🚪';
      case 'ticket_booth':
        return '🎫';
      case 'toilet':
        return '🚻';
      case 'museum':
        return '🏛️';
      case 'auditorium':
      case 'theater':
        return '🎭';
      case 'restaurant':
        return '🍽️';
      case 'cafe':
        return '☕';
      case 'food_court':
        return '🍔';
      case 'shop':
        return '🛍️';
      case 'parking':
        return '🅿️';
      case 'prayer_room':
        return '🕌';
      case 'information':
        return 'ℹ️';
      case 'medical':
        return '🏥';
      case 'security':
        return '👮';
      case 'park':
        return '🌳';
      case 'photo_spot':
        return '📷';
      case 'hotel':
        return '🏨';
      case 'atm':
        return '💳';
      case 'rental':
        return '🚲';
      default:
        return '📍';
    }
  }

  /// Get color for facility type
  static int getColorForType(String type) {
    switch (type) {
      case 'entrance':
      case 'ticket_booth':
        return 0xFF4CAF50; // Green
      case 'toilet':
        return 0xFF2196F3; // Blue
      case 'museum':
      case 'auditorium':
      case 'theater':
        return 0xFF9C27B0; // Purple
      case 'restaurant':
      case 'cafe':
      case 'food_court':
        return 0xFFFF9800; // Orange
      case 'shop':
        return 0xFFE91E63; // Pink
      case 'parking':
        return 0xFF607D8B; // Blue Grey
      case 'prayer_room':
        return 0xFF00BCD4; // Cyan
      case 'information':
        return 0xFF03A9F4; // Light Blue
      case 'medical':
        return 0xFFF44336; // Red
      case 'security':
        return 0xFF3F51B5; // Indigo
      case 'park':
      case 'photo_spot':
        return 0xFF8BC34A; // Light Green
      case 'hotel':
        return 0xFF795548; // Brown
      case 'atm':
        return 0xFFFFEB3B; // Yellow
      case 'rental':
        return 0xFF00BCD4; // Cyan
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}
