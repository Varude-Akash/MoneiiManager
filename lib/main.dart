import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneii_manager/app.dart';
import 'package:moneii_manager/config/env.dart';
import 'package:moneii_manager/features/onboarding/presentation/providers/onboarding_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ads are currently configured only for Android in this project.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await MobileAds.instance.initialize();
    } catch (error, stackTrace) {
      debugPrint('AdMob initialization skipped: $error\n$stackTrace');
    }
  }

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MoneiiApp(),
    ),
  );
}
