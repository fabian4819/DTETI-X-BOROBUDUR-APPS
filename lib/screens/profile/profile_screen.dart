import 'package:flutter/material.dart';
import '../auth_wrapper.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_manager.dart';

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
        title: const Text('Profilku'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {},
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
                            user?.name ?? 'Loading...',
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
                      _buildStatItem('12', 'Kunjungan'),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.lightGray,
                      ),
                      _buildStatItem('5', 'Favorit'),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.lightGray,
                      ),
                      _buildStatItem('8', 'Review'),
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
                    title: 'Riwayat Kunjungan',
                    subtitle: 'Lihat tempat yang pernah dikunjungi',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.favorite,
                    title: 'Tempat Favorit',
                    subtitle: 'Daftar tempat yang disimpan',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.rate_review,
                    title: 'Review & Rating',
                    subtitle: 'Ulasan yang pernah diberikan',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.download,
                    title: 'Unduhan',
                    subtitle: 'File dan konten yang diunduh',
                    onTap: () {},
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
                    title: 'Notifikasi',
                    subtitle: 'Atur preferensi notifikasi',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.language,
                    title: 'Bahasa',
                    subtitle: 'Indonesia',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.privacy_tip,
                    title: 'Privasi & Keamanan',
                    subtitle: 'Kelola data dan keamanan akun',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.help,
                    title: 'Bantuan & Dukungan',
                    subtitle: 'FAQ dan hubungi support',
                    onTap: () {},
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
                      title: const Text('Keluar dari Akun'),
                      content: const Text('Apakah Anda yakin ingin keluar?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
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
                          child: const Text(
                            'Keluar',
                            style: TextStyle(color: Colors.white),
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
                child: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              'Versi 1.0.0',
              style: TextStyle(
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