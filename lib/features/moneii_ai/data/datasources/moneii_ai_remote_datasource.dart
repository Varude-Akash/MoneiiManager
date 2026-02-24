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

class MoneiiAiRemoteDatasource {
  MoneiiAiRemoteDatasource({dio.Dio? dioClient}) : _dio = dioClient ?? dio.Dio();

  final dio.Dio _dio;

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
      throw Exception('Moneii AI request failed. Please try again.');
    }

    return _parseResponse(response.data ?? <String, dynamic>{});
  }

  MoneiiAiResponse _parseResponse(Map<String, dynamic> data) {
    final answer = (data['answer'] as String?)?.trim();
    final usage = data['usage'] as Map<String, dynamic>? ?? <String, dynamic>{};
    if (answer == null || answer.isEmpty) {
      throw Exception('Moneii AI returned an empty response. Please retry.');
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
        return refreshed.session?.accessToken ?? client.auth.currentSession?.accessToken;
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
      data: {'prompt': prompt},
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
}
