import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneii_manager/features/auth/domain/entities/app_user.dart';
import 'package:moneii_manager/features/profile/domain/entities/user_profile.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) {
    final user = event.session?.user;
    if (user == null) return null;
    return AppUser(id: user.id, email: user.email ?? '');
  });
});

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (response == null) return null;
  return UserProfile.fromJson(response);
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseClient _client;

  AuthNotifier(this._client) : super(const AsyncValue.data(null));

  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signUp(email: email, password: password);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> completeSetup(
    String displayName, {
    String? avatarUrl,
    required String currencyPreference,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      await _client.from('profiles').upsert({
        'id': userId,
        'display_name': displayName,
        'email': _client.auth.currentUser?.email ?? '',
        'avatar_url': avatarUrl,
        'is_setup_complete': true,
        'currency_preference': currencyPreference,
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
      return AuthNotifier(ref.watch(supabaseClientProvider));
    });
