import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('profile.favorite_places'.tr()),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('profile_detail.edit_coming_soon'.tr()),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: AppColors.error,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'favorites_detail.total_favorites'.tr(args: ['5']),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGray,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'favorites_detail.saved_places'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            Text(
              'favorites_detail.favorite_list'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Favorites grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _getFavorites().length,
              itemBuilder: (context, index) {
                final favorite = _getFavorites()[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image placeholder
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: favorite['gradient'],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(
                                  favorite['icon'],
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('favorites_detail.removed_from_favorites'.tr(args: [favorite['name']])),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.favorite,
                                      color: AppColors.error,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Info
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  favorite['name'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkGray,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  favorite['description'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mediumGray,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 12,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      favorite['rating'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darkGray,
                                      ),
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
              },
            ),
          ],
        ),
      ),
    );
  }
  
  List<Map<String, dynamic>> _getFavorites() {
    return [
      {
        'name': 'Candi Borobudur',
        'description': 'favorites_detail.temple_main'.tr(),
        'rating': '4.8',
        'icon': Icons.temple_buddhist,
        'gradient': const LinearGradient(
          colors: [Color(0xFF6B73FF), Color(0xFF000DFF)],
        ),
      },
      {
        'name': 'Museum Borobudur',
        'description': 'favorites_detail.museum'.tr(),
        'rating': '4.5',
        'icon': Icons.museum,
        'gradient': const LinearGradient(
          colors: [Color(0xFFFFCE00), Color(0xFFFE4B36)],
        ),
      },
      {
        'name': 'Taman Lumbini',
        'description': 'favorites_detail.lumbini_park'.tr(),
        'rating': '4.6',
        'icon': Icons.park,
        'gradient': const LinearGradient(
          colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
        ),
      },
      {
        'name': 'Candi Mendut',
        'description': 'favorites_detail.mendut_temple'.tr(),
        'rating': '4.4',
        'icon': Icons.account_balance,
        'gradient': const LinearGradient(
          colors: [Color(0xFFFC466B), Color(0xFF3F5EFB)],
        ),
      },
      {
        'name': 'Candi Pawon',
        'description': 'favorites_detail.pawon_temple'.tr(),
        'rating': '4.2',
        'icon': Icons.foundation,
        'gradient': const LinearGradient(
          colors: [Color(0xFFFEA116), Color(0xFFFF6B35)],
        ),
      },
    ];
  }
}