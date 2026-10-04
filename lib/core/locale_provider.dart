import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the chosen app language. Vietnamese is the default.
class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'language';

  @override
  Locale build() {
    _load();
    return const Locale('vi');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && (code == 'en' || code == 'vi')) {
      state = Locale(code);
    }
  }

  Future<void> setLanguage(String code) async {
    state = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
