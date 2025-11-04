import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'app_language';

  // Singleton pattern
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  // Available languages
  static const Locale indonesian = Locale('id');
  static const Locale english = Locale('en');

  // Get current language from SharedPreferences
  Future<Locale> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);

    if (languageCode == 'en') {
      return english;
    }
    return indonesian; // Default to Indonesian
  }

  // Save language preference
  Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  // Change app language
  Future<void> changeLanguage(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    await saveLanguage(locale.languageCode);
  }

  // Get language name for display
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'id':
        return 'Indonesia';
      default:
        return 'Indonesia';
    }
  }

  // Get language flag emoji
  String getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇬🇧';
      case 'id':
        return '🇮🇩';
      default:
        return '🇮🇩';
    }
  }

  // Get TTS language code for voice guidance
  String getTTSLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'en-US';
      case 'id':
        return 'id-ID';
      default:
        return 'id-ID';
    }
  }
}
