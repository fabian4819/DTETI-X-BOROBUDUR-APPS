import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../models/category.dart';

class BorobudurpediaCategoriesScreen extends StatelessWidget {
  const BorobudurpediaCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      Category(name: 'Alat', count: 156, icon: '🔧'),
      Category(name: 'Arsitektur', count: 80, icon: '🏛️'),
      Category(name: 'Bahan', count: 80, icon: '🧱'),
      Category(name: 'Budha', count: 51, icon: '🧘'),
      Category(name: 'Fauna', count: 7, icon: '🐘'),
      Category(name: 'Flora', count: 39, icon: '🌿'),
      Category(name: 'Kawasan', count: 72, icon: '🗺️'),
      Category(name: 'Pelestarian', count: 113, icon: '🛡️'),
      Category(name: 'Regulasi', count: 28, icon: '📋'),
      Category(name: 'Stakeholder', count: 6, icon: '👥'),
      Category(name: 'Tokoh', count: 26, icon: '👤'),
      Category(name: 'Lain-lain', count: 60, icon: '📚'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ensiklopedia'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selamat Datang,',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            const Text(
              'Apa yang ingin kamu pelajari?',
              style: TextStyle(fontSize: 16, color: AppColors.mediumGray),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lihat apa yang ada di sekitar kamu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGray,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true, // penting!
              physics: const NeverScrollableScrollPhysics(), // penting!
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryCard(category);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ganti Expanded menjadi SizedBox
          SizedBox(
            height: 70, // atur tinggi sesuai kebutuhan
            width: double.infinity,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
          ),
          // Ganti Expanded menjadi Flexible atau hapus saja
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                Text(
                  '${category.count} Ensiklopedia',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Pelajari',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
