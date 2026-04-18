import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:air_sky/services/local_storage_service.dart';

class OnboardingController extends StateNotifier<bool> {
  OnboardingController(this._storage)
    : super(_storage.getOnboardingCompleted());

  final LocalStorageService _storage;

  Future<void> markCompleted() async {
    state = true;
    await _storage.saveOnboardingCompleted(true);
  }
}
