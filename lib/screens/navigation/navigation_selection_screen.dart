import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import 'api_map_navigation_screen.dart';
import 'enhanced_navigation_screen.dart';
import 'free_navigation_screen.dart';

class NavigationSelectionScreen extends StatelessWidget {
  const NavigationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Choose Navigation Mode',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select your preferred navigation experience:',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.mediumGray,
              ),
            ),
            const SizedBox(height: 24),
            
            // FREE Navigation Option (Recommended)
            _buildNavigationCard(
              context: context,
              title: 'FREE Navigation',
              subtitle: 'OpenStreetMap • Completely Free',
              description: 'Uses OpenStreetMap tiles and OpenRouteService for completely free navigation with no API costs. Perfect for budget-conscious projects.',
              icon: Icons.map,
              color: Colors.green,
              isRecommended: true,
              features: [
                '✓ No API costs',
                '✓ OpenStreetMap data',
                '✓ Multiple map styles',
                '✓ Voice guidance',
                '✓ 2000 routes/day free'
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FreeNavigationScreen()),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Google Maps Navigation
            _buildNavigationCard(
              context: context,
              title: 'Google Maps Navigation',
              subtitle: 'Professional • API Required',
              description: 'Premium Google Maps experience with satellite imagery, but requires API key and has usage costs after free tier.',
              icon: Icons.satellite_alt,
              color: Colors.blue,
              features: [
                '✓ High-quality satellite imagery',
                '✓ Street view integration',
                '✓ Professional markers',
                '✓ Voice guidance',
                '⚠ Requires API key & billing'
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EnhancedNavigationScreen()),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 3D Custom Navigation
            _buildNavigationCard(
              context: context,
              title: '3D Temple Visualization',
              subtitle: 'Original • Offline',
              description: 'Your original custom 3D visualization of Borobudur temple. Works completely offline with no external dependencies.',
              icon: Icons.view_in_ar,
              color: AppColors.accent,
              features: [
                '✓ Completely offline',
                '✓ Custom 3D temple view',
                '✓ Interactive levels',
                '✓ No external APIs',
                '✓ Cultural heritage focus'
              ],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ApiMapNavigationScreen()),
              ),
            ),
            
            const Spacer(),
            
            // Bottom info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Navigation Comparison',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For production apps, we recommend starting with FREE Navigation to avoid API costs, then upgrading to Google Maps if you need premium features.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> features,
    required VoidCallback onTap,
    bool isRecommended = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isRecommended 
              ? Border.all(color: Colors.green, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isRecommended) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'RECOMMENDED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.mediumGray,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: features.map((feature) => Text(
                  feature,
                  style: TextStyle(
                    fontSize: 12,
                    color: feature.startsWith('⚠') 
                        ? Colors.orange 
                        : Colors.grey[600],
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}