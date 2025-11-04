import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/app_colors.dart';
import '../../services/language_service.dart';
import '../../services/voice_guidance_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LanguageService _languageService = LanguageService();
  final VoiceGuidanceService _voiceGuidanceService = VoiceGuidanceService();

  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _voiceGuidanceEnabled = true;
  String _selectedLanguage = 'Indonesia';
  String _selectedTheme = 'Sistem';

  @override
  void initState() {
    super.initState();
    // Set initial language from current locale
    _selectedLanguage = _languageService.getLanguageName(context.locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('settings.title'.tr()),
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
            Text(
              'settings.general'.tr(),
              style: const TextStyle(
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
                    title: 'settings.notifications'.tr(),
                    subtitle: 'settings.notifications_subtitle'.tr(),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      _showMessage(value ? 'settings.notifications_enabled'.tr() : 'settings.notifications_disabled'.tr());
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.location_on,
                    title: 'settings.location_services'.tr(),
                    subtitle: 'settings.location_subtitle'.tr(),
                    value: _locationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _locationEnabled = value;
                      });
                      _showMessage(value ? 'settings.location_enabled'.tr() : 'settings.location_disabled'.tr());
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.volume_up,
                    title: 'settings.voice_guidance'.tr(),
                    subtitle: 'settings.voice_subtitle'.tr(),
                    value: _voiceGuidanceEnabled,
                    onChanged: (value) {
                      setState(() {
                        _voiceGuidanceEnabled = value;
                      });
                      _showMessage(value ? 'settings.voice_enabled'.tr() : 'settings.voice_disabled'.tr());
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Appearance Settings
            Text(
              'settings.appearance'.tr(),
              style: const TextStyle(
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
                    title: 'settings.language'.tr(),
                    subtitle: _selectedLanguage,
                    onTap: () => _showLanguageDialog(),
                  ),
                  _buildDivider(),
                  _buildSelectionTile(
                    icon: Icons.palette,
                    title: 'settings.theme'.tr(),
                    subtitle: _selectedTheme,
                    onTap: () => _showThemeDialog(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Privacy & Security
            Text(
              'settings.privacy'.tr(),
              style: const TextStyle(
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
                    title: 'settings.change_password'.tr(),
                    subtitle: 'settings.change_password_subtitle'.tr(),
                    onTap: () => _showMessage('settings.coming_soon'.tr().replaceAll('{}', 'settings.change_password'.tr())),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.security,
                    title: 'settings.two_factor'.tr(),
                    subtitle: 'settings.two_factor_subtitle'.tr(),
                    onTap: () => _showMessage('settings.coming_soon'.tr().replaceAll('{}', '2FA')),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.delete_forever,
                    title: 'settings.delete_data'.tr(),
                    subtitle: 'settings.delete_data_subtitle'.tr(),
                    onTap: () => _showDeleteDataDialog(),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // About
            Text(
              'settings.about'.tr(),
              style: const TextStyle(
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
                    title: 'settings.about_app'.tr(),
                    subtitle: '${'settings.version'.tr()} 1.0.0',
                    onTap: () => _showAboutDialog(),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.help,
                    title: 'settings.help_faq'.tr(),
                    subtitle: 'settings.help_subtitle'.tr(),
                    onTap: () => _showMessage('settings.coming_soon'.tr().replaceAll('{}', 'settings.help_faq'.tr())),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.feedback,
                    title: 'settings.send_feedback'.tr(),
                    subtitle: 'settings.feedback_subtitle'.tr(),
                    onTap: () => _showMessage('settings.coming_soon'.tr().replaceAll('{}', 'settings.send_feedback'.tr())),
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
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.language'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Row(
                children: [
                  Text(_languageService.getLanguageFlag('id')),
                  const SizedBox(width: 8),
                  const Text('Indonesia'),
                ],
              ),
              value: 'Indonesia',
              groupValue: _selectedLanguage,
              onChanged: (value) async {
                // Change app language
                await _languageService.changeLanguage(context, LanguageService.indonesian);
                // Change voice guidance language
                await _voiceGuidanceService.changeLanguage('id');
                setState(() {
                  _selectedLanguage = value!;
                });
                if (!mounted) return;
                Navigator.pop(dialogContext);
                _showMessage('Bahasa diubah ke Indonesia');
              },
            ),
            RadioListTile<String>(
              title: Row(
                children: [
                  Text(_languageService.getLanguageFlag('en')),
                  const SizedBox(width: 8),
                  const Text('English'),
                ],
              ),
              value: 'English',
              groupValue: _selectedLanguage,
              onChanged: (value) async {
                // Change app language
                await _languageService.changeLanguage(context, LanguageService.english);
                // Change voice guidance language
                await _voiceGuidanceService.changeLanguage('en');
                setState(() {
                  _selectedLanguage = value!;
                });
                if (!mounted) return;
                Navigator.pop(dialogContext);
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
        title: Text('settings.select_theme'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text('settings.theme_light'.tr()),
              value: 'settings.theme_light'.tr(),
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value!;
                });
                Navigator.pop(context);
                _showMessage('settings.theme_changed'.tr().replaceAll('{}', 'settings.theme_light'.tr()));
              },
            ),
            RadioListTile<String>(
              title: Text('settings.theme_dark'.tr()),
              value: 'settings.theme_dark'.tr(),
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value!;
                });
                Navigator.pop(context);
                _showMessage('settings.theme_changed'.tr().replaceAll('{}', 'settings.theme_dark'.tr()));
              },
            ),
            RadioListTile<String>(
              title: Text('settings.theme_system'.tr()),
              value: 'settings.theme_system'.tr(),
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() {
                  _selectedTheme = value!;
                });
                Navigator.pop(context);
                _showMessage('settings.theme_changed'.tr().replaceAll('{}', 'settings.theme_system'.tr()));
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
        title: Text('settings.delete_data'.tr()),
        content: Text('settings.delete_data_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage('settings.data_deleted'.tr());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('common.delete'.tr()),
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