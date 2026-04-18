import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/services/local_storage_service.dart';

class GuestModeController extends StateNotifier<bool> {
  GuestModeController(this._storage) : super(_storage.getGuestModeEnabled());

  final LocalStorageService _storage;

  Future<void> enableGuestMode() async {
    state = true;
    await _storage.saveGuestModeEnabled(true);
  }

  Future<void> disableGuestMode() async {
    state = false;
    await _storage.saveGuestModeEnabled(false);
  }
}
