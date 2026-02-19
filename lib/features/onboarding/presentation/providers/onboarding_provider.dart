import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingSeenKey = 'has_seen_onboarding';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.dart');
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._prefs)
    : super(_prefs.getBool(_onboardingSeenKey) ?? false);

  final SharedPreferences _prefs;

  Future<void> markSeen() async {
    state = true;
    await _prefs.setBool(_onboardingSeenKey, true);
  }
}

final hasSeenOnboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
      return OnboardingNotifier(ref.watch(sharedPreferencesProvider));
    });
