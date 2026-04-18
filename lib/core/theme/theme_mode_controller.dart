import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/services/local_storage_service.dart';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._storage) : super(_storage.getThemeMode());

  final LocalStorageService _storage;

  void toggleTheme() {
    final ThemeMode next = state == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    state = next;
    _storage.saveThemeMode(next);
  }
}
