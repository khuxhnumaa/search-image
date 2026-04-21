import 'dart:async';

import 'package:flutter/material.dart';

import '../clip/clip_index.dart';

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');

  String _profileName = 'Your Name';
  String _profileEmail = 'you@example.com';
  String _profilePhone = '+91 00000 00000';
  String _profileLocation = 'India';

  final List<String> _recentQueries = <String>[];

  ClipIndex? _clip;
  bool _clipInitializing = false;
  String? _clipError;
  bool _indexingStarted = false;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  String get profileName => _profileName;
  String get profileEmail => _profileEmail;
  String get profilePhone => _profilePhone;
  String get profileLocation => _profileLocation;

  List<String> get recentQueries => List.unmodifiable(_recentQueries);

  ClipIndex? get clipIndex => _clip;
  String? get clipError => _clipError;
  bool get clipInitializing => _clipInitializing;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? phone,
    String? location,
  }) {
    var changed = false;
    if (name != null && name != _profileName) {
      _profileName = name;
      changed = true;
    }
    if (email != null && email != _profileEmail) {
      _profileEmail = email;
      changed = true;
    }
    if (phone != null && phone != _profilePhone) {
      _profilePhone = phone;
      changed = true;
    }
    if (location != null && location != _profileLocation) {
      _profileLocation = location;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void addRecentQuery(String q, {int max = 20}) {
    final query = q.trim();
    if (query.isEmpty) return;
    _recentQueries.removeWhere((e) => e.toLowerCase() == query.toLowerCase());
    _recentQueries.insert(0, query);
    if (_recentQueries.length > max) {
      _recentQueries.removeRange(max, _recentQueries.length);
    }
    notifyListeners();
  }

  void clearRecentQueries() {
    if (_recentQueries.isEmpty) return;
    _recentQueries.clear();
    notifyListeners();
  }

  Future<ClipIndex?> ensureClipLoaded() async {
    if (_clip != null) return _clip;
    if (_clipInitializing) return _clip;

    _clipInitializing = true;
    _clipError = null;
    notifyListeners();

    try {
      final idx = await ClipIndex.instance();
      _clip = idx;
      _clipError = null;
      return idx;
    } catch (e) {
      _clip = null;
      _clipError = e.toString();
      return null;
    } finally {
      _clipInitializing = false;
      notifyListeners();
    }
  }

  // ✅ Only start indexing if DB is empty
  Future<void> startIndexingIfNeeded() async {
    final idx = _clip;
    if (idx == null) return;
    if (_indexingStarted) return;

    final existingCount = await idx.indexedCount;
    if (existingCount > 0) return;

    _indexingStarted = true;
    unawaited(idx.startIndexingAllImages());
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in context');
    return scope!.notifier!;
  }
}