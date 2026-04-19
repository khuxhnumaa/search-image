import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('hi')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(l != null, 'AppLocalizations not found in context');
    return l!;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'appTitle': 'Text to Image',
      'home': 'Home',
      'recent': 'Recent',
      'profile': 'Profile',
      'searchHint': 'Search (e.g., cat, bike, sunset)',
      'search': 'Search',
      'privacyNote': 'Your photos stay private. Images will only appear after you search.',
      'noResults': 'No results yet.',
      'indexEmpty': 'Index is empty (still indexing). Try again shortly.',
      'permissionRequired': 'Gallery permission is required for search results.',
      'openSettings': 'Open settings',
      'indexing': 'Indexing',
      'searching': 'Searching',
      'darkTheme': 'Dark theme',
      'language': 'Language',
      'english': 'English',
      'hindi': 'Hindi',
      'personalDetails': 'Personal details',
      'name': 'Name',
      'email': 'Email',
      'phone': 'Phone',
      'location': 'Location',
      'searchToSeePhotos': 'Search to see photos',
      'clear': 'Clear',
      'rebuildIndex': 'Rebuild index',
      'rebuildIndexHint': 'Clear and re-index your gallery for better results',
      'rebuildTitle': 'Rebuild index?',
      'rebuildBody': 'This will delete the current embeddings database and re-index your photos. It may take some time.',
      'cancel': 'Cancel',
      'rebuild': 'Rebuild',
      'indexRebuilt': 'Index cleared. Start searching to re-index.',
    },
    'hi': {
      'appTitle': 'टेक्स्ट से इमेज',
      'home': 'होम',
      'recent': 'हाल ही में',
      'profile': 'प्रोफ़ाइल',
      'searchHint': 'खोजें (जैसे: बिल्ली, बाइक, सूर्यास्त)',
      'search': 'खोजें',
      'privacyNote': 'आपकी फ़ोटो निजी रहती हैं। तस्वीरें केवल खोज के बाद दिखाई देंगी।',
      'noResults': 'अभी कोई परिणाम नहीं।',
      'indexEmpty': 'इंडेक्स खाली है (इंडेक्सिंग चल रही है)। थोड़ी देर बाद फिर कोशिश करें।',
      'permissionRequired': 'खोज परिणामों के लिए गैलरी अनुमति चाहिए।',
      'openSettings': 'सेटिंग्स खोलें',
      'indexing': 'इंडेक्सिंग',
      'searching': 'खोज रहे हैं',
      'darkTheme': 'डार्क थीम',
      'language': 'भाषा',
      'english': 'अंग्रेज़ी',
      'hindi': 'हिंदी',
      'personalDetails': 'व्यक्तिगत विवरण',
      'name': 'नाम',
      'email': 'ईमेल',
      'phone': 'फ़ोन',
      'location': 'स्थान',
      'searchToSeePhotos': 'फ़ोटो देखने के लिए खोजें',
      'clear': 'साफ़ करें',
      'rebuildIndex': 'इंडेक्स फिर से बनाएं',
      'rebuildIndexHint': 'बेहतर परिणाम के लिए इंडेक्स साफ़ करके दोबारा बनाएं',
      'rebuildTitle': 'इंडेक्स फिर से बनाएं?',
      'rebuildBody': 'यह मौजूदा एम्बेडिंग डेटाबेस हटाकर आपकी फ़ोटो को फिर से इंडेक्स करेगा। इसमें कुछ समय लग सकता है।',
      'cancel': 'रद्द करें',
      'rebuild': 'फिर से बनाएं',
      'indexRebuilt': 'इंडेक्स साफ़ कर दिया गया। दोबारा इंडेक्स करने के लिए खोजें।',
    },
  };

  String _t(String key) {
    final lang = locale.languageCode;
    return _strings[lang]?[key] ?? _strings['en']![key] ?? key;
  }

  String get appTitle => _t('appTitle');
  String get home => _t('home');
  String get recent => _t('recent');
  String get profile => _t('profile');
  String get searchHint => _t('searchHint');
  String get search => _t('search');
  String get privacyNote => _t('privacyNote');
  String get noResults => _t('noResults');
  String get indexEmpty => _t('indexEmpty');
  String get permissionRequired => _t('permissionRequired');
  String get openSettings => _t('openSettings');
  String get indexing => _t('indexing');
  String get searching => _t('searching');
  String get darkTheme => _t('darkTheme');
  String get language => _t('language');
  String get english => _t('english');
  String get hindi => _t('hindi');
  String get personalDetails => _t('personalDetails');
  String get name => _t('name');
  String get email => _t('email');
  String get phone => _t('phone');
  String get location => _t('location');
  String get searchToSeePhotos => _t('searchToSeePhotos');
  String get clear => _t('clear');
  String get rebuildIndex => _t('rebuildIndex');
  String get rebuildIndexHint => _t('rebuildIndexHint');
  String get rebuildTitle => _t('rebuildTitle');
  String get rebuildBody => _t('rebuildBody');
  String get cancel => _t('cancel');
  String get rebuild => _t('rebuild');
  String get indexRebuilt => _t('indexRebuilt');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
