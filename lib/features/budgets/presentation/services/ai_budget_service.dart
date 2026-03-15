import 'package:dio/dio.dart' as dio;
import 'package:moneii_manager/config/env.dart';

// ─── AiBudgetSuggestion ───────────────────────────────────────────────────────

class AiBudgetSuggestion {
  const AiBudgetSuggestion({
    required this.categoryName,
    required this.suggestedAmount,
    required this.reason,
    required this.difficulty,
  });

  final String categoryName;
  final double suggestedAmount;
  final String reason;

  /// 'easy' | 'medium' | 'challenging'
  final String difficulty;

  factory AiBudgetSuggestion.fromJson(Map<String, dynamic> json) {
    return AiBudgetSuggestion(
      categoryName: json['category_name'] as String? ?? '',
      suggestedAmount:
          (json['suggested_amount'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
    );
  }
}

// ─── AiBudgetService ──────────────────────────────────────────────────────────

class AiBudgetService {
  AiBudgetService({dio.Dio? dioClient})
      : _dio = dioClient ?? dio.Dio();

  final dio.Dio _dio;

  Future<List<AiBudgetSuggestion>> getSuggestions({
    required List<Map<String, double>> categoryAverages,
    required double monthlyIncomeAverage,
    required String currency,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '${Env.supabaseUrl}/functions/v1/ai-utils',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          'action': 'budget-suggestions',
          'categoryAverages': categoryAverages,
          'monthlyIncomeAverage': monthlyIncomeAverage,
          'currency': currency,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Unexpected response format.');
      }

      if (data['error'] != null) {
        throw Exception(data['error'] as String);
      }

      final suggestions = data['suggestions'] as List?;
      if (suggestions == null) {
        throw Exception('No suggestions returned.');
      }

      return suggestions
          .whereType<Map<String, dynamic>>()
          .map((e) => AiBudgetSuggestion.fromJson(e))
          .where((s) => s.categoryName.isNotEmpty && s.suggestedAmount > 0)
          .toList();
    } on dio.DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 429) {
        throw Exception('AI rate limit reached. Please try again in a moment.');
      }
      throw Exception('Could not get AI budget suggestions. Please try again.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to generate budget suggestions.');
    }
  }
}
