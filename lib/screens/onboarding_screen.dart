import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:easy_localization/easy_localization.dart';
import 'auth_wrapper.dart';
import '../utils/app_colors.dart';
import '../services/language_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final LanguageService _languageService = LanguageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Set the background image
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/images/borobudur-onboarding.png',
            ), // Use AssetImage for local assets
            fit: BoxFit.cover, // Cover the entire screen
          ),
        ),
        child: Column(
          children: [
            // Language selector at the top
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildLanguageButton('id', '🇮🇩'),
                    const SizedBox(width: 12),
                    _buildLanguageButton('en', '🇬🇧'),
                  ],
                ),
              ),
            ),
            // Spacer to push content to the bottom
            const Expanded(
              flex: 3,
              child: SizedBox.shrink(), // Empty space
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    30,
                    30,
                    30,
                    30 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'onboarding.title'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'onboarding.subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF475569),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Save language choice before proceeding
                            await _languageService.saveLanguage(
                              context.locale.languageCode,
                            );
                            if (!mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AuthWrapper(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.primary.withOpacity(0.4),
                          ),
                          child: Text(
                            'onboarding.start_button'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageButton(String languageCode, String flag) {
    final isSelected = context.locale.languageCode == languageCode;

    return GestureDetector(
      onTap: () async {
        final locale = Locale(languageCode);
        await _languageService.changeLanguage(context, locale);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Text(
              _languageService.getLanguageName(languageCode),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
