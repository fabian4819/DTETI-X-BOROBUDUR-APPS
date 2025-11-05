import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'borobudurpedia_categories_screen.dart';
import 'article_details_screen.dart';
import '../../utils/app_colors.dart';

class BorobudurpediaMainScreen extends StatelessWidget {
  const BorobudurpediaMainScreen({super.key});

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: SingleChildScrollView( // Tambahkan ini
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'borobudurpedia.title'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'borobudurpedia.title'.tr(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'borobudurpedia_detail.subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // decoration: BoxDecoration(
                    //   color: Colors.white,
                    //   borderRadius: BorderRadius.circular(25),
                    // ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'borobudurpedia.search_placeholder'.tr(),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: AppColors.mediumGray),
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _buildStatItem('0', 'borobudurpedia_detail.stats_encyclopedia'.tr())),
                  Expanded(child: _buildStatItem('0', 'borobudurpedia_detail.stats_ebook'.tr())),
                  Expanded(child: _buildStatItem('0', 'borobudurpedia_detail.stats_video'.tr())),
                  Expanded(child: _buildStatItem('0', 'borobudurpedia_detail.stats_gallery'.tr())),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Popular Categories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'borobudurpedia_detail.popular_categories'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BorobudurpediaCategoriesScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Lihat semua',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'borobudurpedia_detail.categories_subtitle'.tr(),
                    style: TextStyle(
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCategoryCard(context, 'borobudurpedia_detail.category_alat'.tr(), 'borobudurpedia_detail.encyclopedia_count'.tr(args: ['155'])),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCategoryCard(context, 'borobudurpedia_detail.category_bahan'.tr(), 'borobudurpedia_detail.encyclopedia_count'.tr(args: ['87'])),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCategoryCard(context, 'borobudurpedia_detail.category_buddha'.tr(), 'borobudurpedia_detail.encyclopedia_count'.tr(args: ['87'])),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Popular Links
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'borobudurpedia_detail.popular_link'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                  Text(
                    'borobudurpedia_detail.popular_link_subtitle'.tr(),
                    style: TextStyle(
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPopularLinkItem(
                    context,
                    'borobudurpedia_detail.encyclopedia_title'.tr(),
                    'borobudurpedia_detail.encyclopedia_desc'.tr(),
                  ),
                  const SizedBox(height: 12),
                  _buildPopularLinkItem(
                    context,
                    'borobudurpedia_detail.sikawa_title'.tr(),
                    'borobudurpedia_detail.sikawa_desc'.tr(),
                  ),
                ],
              ),
            ),
           ],
        ),
      ),
    ),
  );
}

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, String subtitle) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailsScreen(
              title: _getSampleArticleTitle(title),
              category: title,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.lightGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.mediumGray,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPopularLinkItem(BuildContext context, String title, String description) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailsScreen(
              title: _getSampleArticleTitle(title),
              category: 'Lain-lain',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGray),
        ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.mediumGray,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                    height: 1.3,
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

  String _getSampleArticleTitle(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'alat':
        return 'Alat-alat Tradisional Pembangun Borobudur';
      case 'arsitektur':
        return 'Keajaiban Arsitektur Candi Borobudur';
      case 'bahan':
        return 'Batu Andesit: Material Utama Borobudur';
      case 'budha':
      case 'buddha':
        return 'Relief Buddha dalam Candi Borobudur';
      case 'ensiklopedia':
        return 'Ensiklopedia Lengkap Candi Borobudur';
      case 'sikawa':
        return 'Sistem Informasi Kawasan Borobudur';
      default:
        return 'Keajaiban Warisan Dunia Borobudur';
    }
  }
}