import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/app_colors.dart';

class FacilitiesScreen extends StatelessWidget {
  const FacilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final facilities = [
      {
        'name': 'facilities_detail.toilet'.tr(),
        'icon': Icons.wc,
        'color': AppColors.primary,
        'description': 'facilities_detail.toilet_desc'.tr(),
        'locations': ['Pintu Masuk Utama', 'Area Parkir', 'Museum', 'Rest Area']
      },
      {
        'name': 'facilities_detail.mushola'.tr(),
        'icon': Icons.mosque,
        'color': AppColors.success,
        'description': 'facilities_detail.mushola_desc'.tr(),
        'locations': ['Dekat Pintu Masuk', 'Area Parkir Timur']
      },
      {
        'name': 'facilities_detail.canteen'.tr(),
        'icon': Icons.restaurant,
        'color': AppColors.warning,
        'description': 'facilities_detail.canteen_desc'.tr(),
        'locations': ['Food Court Utama', 'Warung Tradisional', 'Cafe Museum']
      },
      {
        'name': 'facilities_detail.souvenir'.tr(),
        'icon': Icons.shopping_bag,
        'color': AppColors.accent,
        'description': 'facilities_detail.souvenir_desc'.tr(),
        'locations': ['Toko Utama', 'Stan Kerajinan', 'Museum Gift Shop']
      },
      {
        'name': 'facilities_detail.parking'.tr(),
        'icon': Icons.local_parking,
        'color': AppColors.secondary,
        'description': 'facilities_detail.parking_desc'.tr(),
        'locations': ['Parkir Mobil', 'Parkir Motor', 'Parkir Bus']
      },
      {
        'name': 'facilities_detail.atm'.tr(),
        'icon': Icons.atm,
        'color': AppColors.error,
        'description': 'facilities_detail.atm_desc'.tr(),
        'locations': ['ATM BCA', 'ATM Mandiri', 'ATM BRI']
      },
      {
        'name': 'facilities_detail.clinic'.tr(),
        'icon': Icons.local_hospital,
        'color': AppColors.primary,
        'description': 'facilities_detail.clinic_desc'.tr(),
        'locations': ['Pos Kesehatan Utama', 'Mobile Clinic']
      },
      {
        'name': 'facilities_detail.wifi'.tr(),
        'icon': Icons.wifi,
        'color': AppColors.success,
        'description': 'facilities_detail.wifi_desc'.tr(),
        'locations': ['Seluruh Area Candi', 'Museum', 'Rest Area']
      },
      {
        'name': 'facilities_detail.info_center'.tr(),
        'icon': Icons.info,
        'color': AppColors.warning,
        'description': 'facilities_detail.info_center_desc'.tr(),
        'locations': ['Pintu Masuk Utama', 'Counter Tiket']
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'facilities_detail.facilities_title'.tr(),
          style: const TextStyle(
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
                  Text(
                    'facilities_detail.header_title'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'facilities_detail.header_subtitle'.tr(),
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
                      Text(
                        'facilities_detail.important_info'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${'facilities_detail.info_hours'.tr()}\n'
                    '${'facilities_detail.info_free'.tr()}\n'
                    '${'facilities_detail.info_wifi'.tr()}\n'
                    '${'facilities_detail.info_help'.tr()}\n'
                    '${'facilities_detail.info_environment'.tr()}',
                    style: const TextStyle(
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
                            'facilities_detail.location_label'.tr(),
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