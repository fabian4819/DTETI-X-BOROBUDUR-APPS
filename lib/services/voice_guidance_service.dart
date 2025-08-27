import 'package:flutter_tts/flutter_tts.dart';

class VoiceGuidanceService {
  static final VoiceGuidanceService _instance = VoiceGuidanceService._internal();
  factory VoiceGuidanceService() => _instance;
  VoiceGuidanceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isEnabled = true;

  bool get isEnabled => _isEnabled;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _flutterTts.setLanguage('id-ID');
      await _flutterTts.setSpeechRate(0.7);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      // Fallback to English if Indonesian not available
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.8);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
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
    if (instruction.contains('Mulai')) {
      return 'Navigasi dimulai. $instruction';
    } else if (instruction.contains('Tiba')) {
      return 'Anda telah $instruction. Navigasi selesai.';
    } else if (instruction.contains('kanan') || instruction.contains('kiri')) {
      return 'Dalam 50 meter, $instruction';
    } else if (instruction.contains('Lurus')) {
      return '$instruction terus';
    }
    
    return instruction;
  }

  Future<void> announceArrival(String destinationName) async {
    await speak('Selamat! Anda telah tiba di $destinationName');
  }

  Future<void> announceNavigationStart(String destinationName, int estimatedTime) async {
    final minutes = (estimatedTime / 60).ceil();
    await speak('Memulai navigasi menuju $destinationName. Estimasi waktu $minutes menit');
  }

  Future<void> announceDistanceToDestination(double distance) async {
    if (distance < 10) {
      await speak('Anda sudah sangat dekat dengan tujuan');
    } else if (distance < 50) {
      await speak('Tujuan berada ${distance.round()} meter di depan');
    } else if (distance < 100) {
      await speak('Tujuan berada kurang dari 100 meter');
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