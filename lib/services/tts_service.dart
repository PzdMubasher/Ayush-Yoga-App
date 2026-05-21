import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  String _currentLanguage = 'en';

  Future<void> init() async {
    // Load persisted language preference
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('selected_language') ?? 'en';
    await _applyLanguage();
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _applyLanguage();
  }

  Future<void> _applyLanguage() async {
    if (_currentLanguage == 'hi') {
      await _flutterTts.setLanguage('hi-IN');
    } else if (_currentLanguage == 'te') {
      await _flutterTts.setLanguage('te-IN');
    } else {
      await _flutterTts.setLanguage('en-US');
    }
  }

  Future<void> speak(String text) async {
    // Re-confirm language before every speak to prevent TTS engine resets
    await _applyLanguage();
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
