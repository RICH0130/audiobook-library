import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _kApiKey = 'claude_api_key';
  static const _kRate = 'speech_rate';
  static const _kPitch = 'speech_pitch';
  static const _kLang = 'speech_lang';
  static const _kFont = 'font_size';
  static const _kShowKeywords = 'show_keywords';

  late SharedPreferences _prefs;

  String apiKey = '';
  double speechRate = 0.5; // flutter_tts range 0.0 - 1.0
  double pitch = 1.0;
  String language = 'zh-TW';
  double fontSize = 18;
  bool showKeywords = true;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    apiKey = _prefs.getString(_kApiKey) ?? '';
    speechRate = _prefs.getDouble(_kRate) ?? 0.5;
    pitch = _prefs.getDouble(_kPitch) ?? 1.0;
    language = _prefs.getString(_kLang) ?? 'zh-TW';
    fontSize = _prefs.getDouble(_kFont) ?? 18;
    showKeywords = _prefs.getBool(_kShowKeywords) ?? true;
  }

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  Future<void> setApiKey(String v) async {
    apiKey = v.trim();
    await _prefs.setString(_kApiKey, apiKey);
    notifyListeners();
  }

  Future<void> setSpeechRate(double v) async {
    speechRate = v;
    await _prefs.setDouble(_kRate, v);
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    pitch = v;
    await _prefs.setDouble(_kPitch, v);
    notifyListeners();
  }

  Future<void> setLanguage(String v) async {
    language = v;
    await _prefs.setString(_kLang, v);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    fontSize = v;
    await _prefs.setDouble(_kFont, v);
    notifyListeners();
  }

  Future<void> setShowKeywords(bool v) async {
    showKeywords = v;
    await _prefs.setBool(_kShowKeywords, v);
    notifyListeners();
  }
}
