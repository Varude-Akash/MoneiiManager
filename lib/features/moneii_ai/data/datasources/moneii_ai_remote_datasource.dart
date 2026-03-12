import 'package:dio/dio.dart' as dio;
import 'package:moneii_manager/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MoneiiAiResponse {
  const MoneiiAiResponse({
    required this.answer,
    required this.planTier,
    required this.dailyUsed,
    required this.monthlyUsed,
    this.dailyLimit,
    required this.monthlyLimit,
  });

  final String answer;
  final String planTier;
  final int dailyUsed;
  final int? dailyLimit;
  final int monthlyUsed;
  final int monthlyLimit;
}

class MoneiiAiHistoryRecord {
  const MoneiiAiHistoryRecord({
    required this.prompt,
    required this.response,
    required this.createdAt,
  });

  final String prompt;
  final String response;
  final DateTime createdAt;
}

class MoneiiAiBootstrapData {
  const MoneiiAiBootstrapData({
    required this.planTier,
    this.dailyLimit,
    required this.dailyUsed,
    required this.monthlyUsed,
    required this.monthlyLimit,
    required this.historyByMonth,
  });

  final String planTier;
  final int? dailyLimit;
  final int dailyUsed;
  final int monthlyUsed;
  final int monthlyLimit;
  final Map<DateTime, List<MoneiiAiHistoryRecord>> historyByMonth;
}

class MoneiiAiRemoteDatasource {
  MoneiiAiRemoteDatasource({dio.Dio? dioClient})
    : _dio = dioClient ?? dio.Dio();

  final dio.Dio _dio;

  Future<MoneiiAiBootstrapData> bootstrap() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Your session expired. Please sign in again.');
    }

    final profile = await client
        .from('profiles')
        .select('plan_tier, is_premium')
        .eq('id', user.id)
        .maybeSingle();

    final planTier = _resolvePlanTier(
      profile?['plan_tier'] as String?,
      profile?['is_premium'] == true,
    );

    final nowLocal = DateTime.now();
    final dayStartLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final monthStartLocal = DateTime(nowLocal.year, nowLocal.month);
    final oldestMonthLocal = DateTime(nowLocal.year, nowLocal.month - 2);

    final dailyCountResponse = await client
        .from('ai_assistant_requests')
        .select('id')
        .eq('user_id', user.id)
        .eq('status', 'success')
        .gte('created_at', dayStartLocal.toUtc().toIso8601String());

    final monthlyCountResponse = await client
        .from('ai_assistant_requests')
        .select('id')
        .eq('user_id', user.id)
        .eq('status', 'success')
        .gte('created_at', monthStartLocal.toUtc().toIso8601String());

    final rows = await client
        .from('ai_assistant_requests')
        .select('prompt, response, created_at, status')
        .eq('user_id', user.id)
        .eq('status', 'success')
        .gte('created_at', oldestMonthLocal.toUtc().toIso8601String())
        .order('created_at', ascending: true);

    final historyByMonth = <DateTime, List<MoneiiAiHistoryRecord>>{};
    for (final raw in rows as List<dynamic>) {
      final row = raw as Map<String, dynamic>;
      final prompt = (row['prompt'] as String?)?.trim() ?? '';
      final response = (row['response'] as String?)?.trim() ?? '';
      final createdAtRaw = row['created_at'] as String?;
      if (prompt.isEmpty || response.isEmpty || createdAtRaw == null) continue;
      final createdAt = DateTime.parse(createdAtRaw).toLocal();
      final monthStart = DateTime(createdAt.year, createdAt.month);
      historyByMonth.putIfAbsent(monthStart, () => <MoneiiAiHistoryRecord>[]);
      historyByMonth[monthStart]!.add(
        MoneiiAiHistoryRecord(
          prompt: prompt,
          response: response,
          createdAt: createdAt,
        ),
      );
    }

    return MoneiiAiBootstrapData(
      planTier: planTier,
      dailyLimit: switch (planTier) {
        'premium_plus' => 50,
        'premium' => 5,
        _ => null,
      },
      dailyUsed: (dailyCountResponse as List).length,
      monthlyUsed: (monthlyCountResponse as List).length,
      monthlyLimit: 0,
      historyByMonth: historyByMonth,
    );
  }

  Future<MoneiiAiResponse> ask(String prompt) async {
    final token = await _getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Your session expired. Please sign in again.');
    }

    dio.Response<Map<String, dynamic>> response;
    try {
      response = await _callAsk(token, prompt);
    } on dio.DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        final refreshedToken = await _getAccessToken(forceRefresh: true);
        if (refreshedToken == null || refreshedToken.isEmpty) {
          throw Exception('Your session expired. Please sign in again.');
        }
        try {
          response = await _callAsk(refreshedToken, prompt);
        } on dio.DioException {
          throw Exception('Your session expired. Please sign in again.');
        }
        return _parseResponse(response.data ?? <String, dynamic>{});
      }
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = (data['error'] as String?)?.trim();
        if (message != null && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      throw Exception('Zora request failed. Please try again.');
    }

    return _parseResponse(response.data ?? <String, dynamic>{});
  }

  MoneiiAiResponse _parseResponse(Map<String, dynamic> data) {
    final answer = (data['answer'] as String?)?.trim();
    final usage = data['usage'] as Map<String, dynamic>? ?? <String, dynamic>{};
    if (answer == null || answer.isEmpty) {
      throw Exception('Zora returned an empty response. Please retry.');
    }

    return MoneiiAiResponse(
      answer: answer,
      planTier: (usage['plan_tier'] as String?) ?? 'premium',
      dailyUsed: (usage['daily_used'] as num?)?.toInt() ?? 0,
      dailyLimit: (usage['daily_limit'] as num?)?.toInt(),
      monthlyUsed: (usage['monthly_used'] as num?)?.toInt() ?? 0,
      monthlyLimit: (usage['monthly_limit'] as num?)?.toInt() ?? 0,
    );
  }

  Future<String?> _getAccessToken({bool forceRefresh = false}) async {
    final client = Supabase.instance.client;
    if (forceRefresh) {
      try {
        final refreshed = await client.auth.refreshSession();
        return refreshed.session?.accessToken ??
            client.auth.currentSession?.accessToken;
      } catch (_) {
        return client.auth.currentSession?.accessToken;
      }
    }
    return client.auth.currentSession?.accessToken;
  }

  Future<dio.Response<Map<String, dynamic>>> _callAsk(
    String token,
    String prompt,
  ) {
    return _dio.post<Map<String, dynamic>>(
      '${Env.supabaseUrl}/functions/v1/moneii-ai',
      data: {
        'prompt': prompt,
        'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      },
      options: dio.Options(
        headers: {
          'Authorization': 'Bearer $token',
          'apikey': Env.supabaseAnonKey,
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  String _resolvePlanTier(String? rawTier, bool isPremium) {
    if (rawTier == 'premium_plus') return 'premium_plus';
    if (rawTier == 'premium') return 'premium';
    if (rawTier == 'free') return 'free';
    return isPremium ? 'premium' : 'free';
  }
}
