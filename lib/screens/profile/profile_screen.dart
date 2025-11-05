import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../auth_wrapper.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_manager.dart';
import 'visit_history_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('profile.my_profile'.tr()),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.mediumGray,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: AuthManager.instance,
                    builder: (context, child) {
                      final user = AuthManager.instance.currentUser;
                      return Column(
                        children: [
                          Text(
                            user?.name ?? 'common.loading'.tr(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.mediumGray,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('12', 'profile_detail.visits'.tr()),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.lightGray,
                      ),
                      _buildStatItem('5', 'profile_detail.favorites'.tr()),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.lightGray,
                      ),
                      _buildStatItem('8', 'profile_detail.reviews'.tr()),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Menu items
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  _buildMenuItem(
                    icon: Icons.history,
                    title: 'profile_detail.visit_history_title'.tr(),
                    subtitle: 'profile_detail.visit_history_subtitle'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VisitHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.favorite,
                    title: 'profile_detail.favorite_places_title'.tr(),
                    subtitle: 'profile_detail.favorite_places_subtitle'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoritesScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.rate_review,
                    title: 'profile_detail.review_rating'.tr(),
                    subtitle: 'profile_detail.review_subtitle'.tr(),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('profile_detail.feature_coming_soon'.tr().replaceAll('{}', 'review')),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.download,
                    title: 'profile_detail.downloads'.tr(),
                    subtitle: 'profile_detail.downloads_subtitle'.tr(),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('profile_detail.no_downloads'.tr()),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Settings section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  _buildMenuItem(
                    icon: Icons.notifications,
                    title: 'profile_detail.notifications_title'.tr(),
                    subtitle: 'profile_detail.notifications_subtitle'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.language,
                    title: 'profile_detail.language_title'.tr(),
                    subtitle: 'profile_detail.language_current'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.privacy_tip,
                    title: 'profile_detail.privacy_title'.tr(),
                    subtitle: 'profile_detail.privacy_subtitle'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.help,
                    title: 'profile_detail.help_title'.tr(),
                    subtitle: 'profile_detail.help_subtitle'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Logout button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('profile.logout_account'.tr()),
                      content: Text('profile.logout_confirm'.tr()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('common.cancel'.tr()),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            // Close dialog immediately
                            Navigator.pop(context);
                            
                            // Show loading state in parent widget
                            setState(() {
                              _isLoggingOut = true;
                            });
                            
                            try {
                              await AuthManager.instance.logout();
                              
                              if (mounted) {
                                // Navigate to AuthWrapper
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => const AuthWrapper(),
                                  ),
                                  (route) => false,
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isLoggingOut = false;
                                });
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          child: Text(
                            'auth.logout'.tr(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'profile.logout_account'.tr(),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            Text(
              '${'common.version'.tr()} 1.0.0',
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

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkGray,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.mediumGray,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.mediumGray,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: AppColors.lightGray.withOpacity(0.5),
      height: 1,
      indent: 72,
    );
  }
}