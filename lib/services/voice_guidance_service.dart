import 'package:flutter_tts/flutter_tts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'language_service.dart';

class VoiceGuidanceService {
  static final VoiceGuidanceService _instance = VoiceGuidanceService._internal();
  factory VoiceGuidanceService() => _instance;
  VoiceGuidanceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final LanguageService _languageService = LanguageService();
  bool _isInitialized = false;
  bool _isEnabled = true;
  String _currentLanguage = 'id-ID';

  bool get isEnabled => _isEnabled;

  Future<void> initialize({String? languageCode}) async {
    if (_isInitialized) return;

    // Use provided language code or default to Indonesian
    final ttsLanguage = languageCode != null
        ? _languageService.getTTSLanguageCode(languageCode)
        : 'id-ID';

    try {
      await _flutterTts.setLanguage(ttsLanguage);
      await _flutterTts.setSpeechRate(0.7);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _currentLanguage = ttsLanguage;
      _isInitialized = true;
    } catch (e) {
      // Fallback to English if requested language not available
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.8);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _currentLanguage = 'en-US';
      _isInitialized = true;
    }
  }

  // Change TTS language dynamically
  Future<void> changeLanguage(String languageCode) async {
    final ttsLanguage = _languageService.getTTSLanguageCode(languageCode);
    if (_currentLanguage == ttsLanguage) return;

    try {
      await _flutterTts.setLanguage(ttsLanguage);
      _currentLanguage = ttsLanguage;
    } catch (e) {
      // Keep current language if change fails
    }
  }

  Future<void> speak(String text) async {
    if (!_isEnabled || !_isInitialized) return;
    
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      // Log error in production with proper logging framework
      // Log error silently for production
    }
  }

  Future<void> speakNavigationInstruction(String instruction) async {
    if (!_isEnabled) return;
    
    // Enhanced instruction with context
    String enhancedInstruction = _enhanceInstruction(instruction);
    await speak(enhancedInstruction);
  }

  String _enhanceInstruction(String instruction) {
    // Add contextual information to make instructions clearer
    // Check for localized keywords in both languages
    final navigationStarted = 'navigation_screen.navigation_started'.tr();
    final arrived = 'navigation_screen.arrived'.tr();
    final turnRight = 'navigation_screen.turn_right'.tr();
    final turnLeft = 'navigation_screen.turn_left'.tr();
    final goStraight = 'navigation_screen.go_straight'.tr();

    if (instruction.contains(navigationStarted) ||
        instruction.toLowerCase().contains('start') ||
        instruction.toLowerCase().contains('mulai')) {
      return '$navigationStarted. $instruction';
    } else if (instruction.contains(arrived) ||
               instruction.toLowerCase().contains('arriv') ||
               instruction.toLowerCase().contains('tiba')) {
      return '$instruction';
    } else if (instruction.contains(turnRight) || instruction.contains(turnLeft)) {
      return '$instruction';
    } else if (instruction.contains(goStraight)) {
      return '$instruction';
    }

    return instruction;
  }

  Future<void> announceArrival(String destinationName) async {
    await speak('${' navigation_screen.arrived'.tr()} $destinationName');
  }

  Future<void> announceNavigationStart(String destinationName, int estimatedTime) async {
    final minutes = (estimatedTime / 60).ceil();
    final startText = 'navigation_screen.starting_to'.tr();
    await speak('$startText $destinationName');
  }

  Future<void> announceDistanceToDestination(double distance) async {
    if (distance < 10) {
      await speak('navigation_screen.very_close'.tr());
    } else if (distance < 50) {
      final text = 'navigation_screen.destination_ahead'.tr();
      await speak(text.replaceAll('{}', distance.round().toString()));
    } else if (distance < 100) {
      await speak('navigation_screen.very_close'.tr());
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void dispose() {
    _flutterTts.stop();
  }
}