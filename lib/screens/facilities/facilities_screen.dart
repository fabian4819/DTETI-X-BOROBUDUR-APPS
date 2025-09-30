import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class FacilitiesScreen extends StatelessWidget {
  const FacilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final facilities = [
      {
        'name': 'Toilet',
        'icon': Icons.wc,
        'color': AppColors.primary,
        'description': 'Fasilitas toilet tersedia di berbagai lokasi',
        'locations': ['Pintu Masuk Utama', 'Area Parkir', 'Museum', 'Rest Area']
      },
      {
        'name': 'Mushola',
        'icon': Icons.mosque,
        'color': AppColors.success,
        'description': 'Tempat ibadah untuk pengunjung muslim',
        'locations': ['Dekat Pintu Masuk', 'Area Parkir Timur']
      },
      {
        'name': 'Kantin',
        'icon': Icons.restaurant,
        'color': AppColors.warning,
        'description': 'Tempat makan dan minum',
        'locations': ['Food Court Utama', 'Warung Tradisional', 'Cafe Museum']
      },
      {
        'name': 'Souvenir Shop',
        'icon': Icons.shopping_bag,
        'color': AppColors.accent,
        'description': 'Toko oleh-oleh dan cinderamata',
        'locations': ['Toko Utama', 'Stan Kerajinan', 'Museum Gift Shop']
      },
      {
        'name': 'Parkir',
        'icon': Icons.local_parking,
        'color': AppColors.secondary,
        'description': 'Area parkir kendaraan',
        'locations': ['Parkir Mobil', 'Parkir Motor', 'Parkir Bus']
      },
      {
        'name': 'ATM',
        'icon': Icons.atm,
        'color': AppColors.error,
        'description': 'Mesin ATM untuk kebutuhan finansial',
        'locations': ['ATM BCA', 'ATM Mandiri', 'ATM BRI']
      },
      {
        'name': 'Klinik Kesehatan',
        'icon': Icons.local_hospital,
        'color': AppColors.primary,
        'description': 'Fasilitas kesehatan dan P3K',
        'locations': ['Pos Kesehatan Utama', 'Mobile Clinic']
      },
      {
        'name': 'Wifi Gratis',
        'icon': Icons.wifi,
        'color': AppColors.success,
        'description': 'Akses internet gratis untuk pengunjung',
        'locations': ['Seluruh Area Candi', 'Museum', 'Rest Area']
      },
      {
        'name': 'Information Center',
        'icon': Icons.info,
        'color': AppColors.warning,
        'description': 'Pusat informasi dan bantuan pengunjung',
        'locations': ['Pintu Masuk Utama', 'Counter Tiket']
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Fasilitas Borobudur',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.location_city,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fasilitas Lengkap untuk Kenyamanan Anda',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nikmati berbagai fasilitas modern yang tersedia di kawasan Candi Borobudur',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Facilities grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: facilities.length,
              itemBuilder: (context, index) {
                final facility = facilities[index];
                return _buildFacilityCard(facility);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Additional info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Informasi Penting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Semua fasilitas buka dari jam 06:00 - 17:00 WIB\n'
                    '• Fasilitas toilet dan mushola tersedia gratis\n'
                    '• Wifi gratis dengan SSID: Borobudur_Free_WiFi\n'
                    '• Untuk bantuan, hubungi Information Center\n'
                    '• Harap menjaga kebersihan dan kelestarian lingkungan',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon header
          Container(
            height: 70,
            width: double.infinity,
            decoration: BoxDecoration(
              color: (facility['color'] as Color).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Icon(
                facility['icon'] as IconData,
                size: 36,
                color: facility['color'] as Color,
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility['name'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      facility['description'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGray,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (facility['locations'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lokasi:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: facility['color'] as Color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (facility['locations'] as List<String>).take(2).join(', '),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.mediumGray,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}