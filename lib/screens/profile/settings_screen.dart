import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _voiceGuidanceEnabled = true;
  String _selectedLanguage = 'Indonesia';
  String _selectedTheme = 'Sistem';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
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
            // General Settings
            const Text(
              'Umum',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Container(
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
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications,
                    title: 'Notifikasi',
                    subtitle: 'Terima notifikasi acara dan berita',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      _showMessage('Pengaturan notifikasi ${value ? 'diaktifkan' : 'dimatikan'}');
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.location_on,
                    title: 'Layanan Lokasi',
                    subtitle: 'Izinkan akses lokasi untuk navigasi',
                    value: _locationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _locationEnabled = value;
                      });
                      _showMessage('Layanan lokasi ${value ? 'diaktifkan' : 'dimatikan'}');
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.volume_up,
                    title: 'Panduan Suara',
                    subtitle: 'Aktifkan panduan suara saat navigasi',
                    value: _voiceGuidanceEnabled,
                    onChanged: (value) {
                      setState(() {
                        _voiceGuidanceEnabled = value;
                      });
                      _showMessage('Panduan suara ${value ? 'diaktifkan' : 'dimatikan'}');
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Appearance Settings
            const Text(
              'Tampilan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Container(
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
                children: [
                  _buildSelectionTile(
                    icon: Icons.language,
                    title: 'Bahasa',
                    subtitle: _selectedLanguage,
                    onTap: () => _showLanguageDialog(),
                  ),
                  _buildDivider(),
                  _buildSelectionTile(
                    icon: Icons.palette,
                    title: 'Tema',
                    subtitle: _selectedTheme,
                    onTap: () => _showThemeDialog(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Privacy & Security
            const Text(
              'Privasi & Keamanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Container(
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
                children: [
                  _buildActionTile(
                    icon: Icons.lock,
                    title: 'Ubah Password',
                    subtitle: 'Perbarui password akun Anda',
                    onTap: () => _showMessage('Fitur ubah password akan segera hadir!'),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.security,
                    title: 'Verifikasi Dua Langkah',
                    subtitle: 'Tingkatkan keamanan akun',
                    onTap: () => _showMessage('Fitur 2FA akan segera hadir!'),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.delete_forever,
                    title: 'Hapus Data',
                    subtitle: 'Hapus semua data lokal',
                    onTap: () => _showDeleteDataDialog(),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // About
            const Text(
              'Tentang',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Container(
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
                children: [
                  _buildActionTile(
                    icon: Icons.info,
                    title: 'Tentang Aplikasi',
                    subtitle: 'Versi 1.0.0',
                    onTap: () => _showAboutDialog(),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.help,
                    title: 'Bantuan & FAQ',
                    subtitle: 'Dapatkan bantuan penggunaan aplikasi',
                    onTap: () => _showMessage('Fitur bantuan akan segera hadir!'),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.feedback,
                    title: 'Kirim Feedback',
                    subtitle: 'Bantu kami meningkatkan aplikasi',
                    onTap: () => _showMessage('Fitur feedback akan segera hadir!'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
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
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
  
  Widget _buildSelectionTile({
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
          color: AppColors.primary.withValues(alpha: 0.1),
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
  
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (isDestructive ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? AppColors.error : AppColors.darkGray,
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
      color: AppColors.lightGray.withValues(alpha: 0.5),
      height: 1,
      indent: 72,
    );
  }
  
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Bahasa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Indonesia'),
              value: 'Indonesia',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.pop(context);
                _showMessage('Bahasa diubah ke Indonesia');
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'English',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.pop(context);
                _showMessage('Language changed to English');
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Terang'),
              value: 'Terang',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value!;
                });
                Navigator.pop(context);
                _showMessage('Tema diubah ke Terang');
              },
            ),
            RadioListTile<String>(
              title: const Text('Gelap'),
              value: 'Gelap',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value!;
                });
                Navigator.pop(context);
                _showMessage('Tema diubah ke Gelap');
              },
            ),
            RadioListTile<String>(
              title: const Text('Sistem'),
              value: 'Sistem',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value!;
                });
                Navigator.pop(context);
                _showMessage('Tema mengikuti sistem');
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus semua data lokal? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage('Data lokal berhasil dihapus');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
  
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang Wonderful Borobudur'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wonderful Borobudur v1.0.0',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Aplikasi panduan wisata resmi untuk menjelajahi keajaiban Candi Borobudur dan sekitarnya.',
            ),
            SizedBox(height: 16),
            Text(
              'Dikembangkan oleh:\nTim DTETI x Borobudur',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mediumGray,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
  
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}