import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snellum/translations/bn_translations.dart';
import 'package:snellum/translations/fa_translations.dart';
import 'package:snellum/translations/he_translations.dart';
import 'package:snellum/translations/id_translations.dart';
import 'package:snellum/translations/ms_translations.dart';
import 'package:snellum/translations/ro_translations.dart';
import 'package:snellum/translations/th_translations.dart';
import 'package:snellum/translations/uk_translations.dart';
import 'package:snellum/translations/vi_translations.dart';
import '../translations/en_translations.dart';
import '../translations/sw_translations.dart';
import '../translations/es_translations.dart';
import '../translations/fr_translations.dart';
import '../translations/de_translations.dart';
import '../translations/pt_translations.dart';
import '../translations/ar_translations.dart';
import '../translations/hi_translations.dart';
import '../translations/it_translations.dart';
import '../translations/ja_translations.dart';
import '../translations/ko_translations.dart';
import '../translations/zh_translations.dart';
import '../translations/ru_translations.dart';
import '../translations/tr_translations.dart';
import '../translations/nl_translations.dart';
import '../translations/pl_translations.dart';

class LanguageProvider with ChangeNotifier {
  static const String _languageKey = 'app_language_code';

  // Default to English (US)
  String _currentLanguageCode = 'en';
  String _currentLanguageName = 'English (US)';

  final List<Map<String, String>> _supportedLanguages = [
    {'code': 'en', 'name': 'English (US)'},
    {'code': 'sw', 'name': 'Kiswahili'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'pt', 'name': 'Português'},
    {'code': 'it', 'name': 'Italiano'},
    {'code': 'ar', 'name': 'العربية'},
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'zh', 'name': '中文'},
    {'code': 'ja', 'name': '日本語'},
    {'code': 'ko', 'name': '한국어'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'tr', 'name': 'Turkish'},
    {'code': 'nl', 'name': 'Dutch'},
    {'code': 'pl', 'name': 'Polish'},
    {'code': 'vi', 'name': 'Vietnamese'},
    {'code': 'th', 'name': 'Thai'},
    {'code': 'id', 'name': 'Indonesian'},
    {'code': 'ms', 'name': 'Malay'},
    {'code': 'fa', 'name': 'Farsi'},
    {'code': 'he', 'name': 'Hebrew'},
    {'code': 'bn', 'name': 'Bengali'},
    {'code': 'uk', 'name': 'Ukrainian'},
    {'code': 'ro', 'name': 'Romanian'},
  ];

  LanguageProvider() {
    _loadLanguage();
  }

  String get currentLanguageCode => _currentLanguageCode;
  String get currentLanguageName => _currentLanguageName;
  List<Map<String, String>> get supportedLanguages => _supportedLanguages;

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_languageKey);
    if (savedCode != null) {
      _currentLanguageCode = savedCode;
      _currentLanguageName = _supportedLanguages.firstWhere(
        (lang) => lang['code'] == savedCode,
        orElse: () => _supportedLanguages[0],
      )['name']!;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String code) async {
    final lang = _supportedLanguages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => _supportedLanguages[0],
    );

    _currentLanguageCode = lang['code']!;
    _currentLanguageName = lang['name']!;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, _currentLanguageCode);

    notifyListeners();
  }

  String getString(String key) {
    if (_translations[_currentLanguageCode]?.containsKey(key) ?? false) {
      return _translations[_currentLanguageCode]![key]!;
    }
    // Fallback to English
    return _translations['en']?[key] ?? key;
  }

  final Map<String, Map<String, String>> _translations = {
    'en': enTranslations,
    'sw': swTranslations,
    'es': esTranslations,
    'fr': frTranslations,
    'de': deTranslations,
    'pt': ptTranslations,
    'it': itTranslations,
    'ar': arTranslations,
    'hi': hiTranslations,
    'zh': zhTranslations,
    'ja': jaTranslations,
    'ko': koTranslations,
    'ru': ruTranslations,
    'tr': trTranslations,
    'nl': nlTranslations,
    'pl': plTranslations,
    'vi': viTranslations,
    'th': thTranslations,
    'id': idTranslations,
    'ms': msTranslations,
    'fa': faTranslations,
    'he': heTranslations,
    'bn': bnTranslations,
    'uk': ukTranslations,
    'ro': roTranslations,
  };
}
