import 'dart:convert';
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
  }) async {
    final apiKey = Env.openaiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('OpenAI API key is not configured.');
    }

    final categoryLines = categoryAverages.map((cat) {
      final name = cat.keys.first;
      final avg = cat.values.first;
      return '- $name: ${avg.toStringAsFixed(2)} $currency/month (3-month avg)';
    }).join('\n');

    final prompt = '''
You are a personal finance advisor. Based on the user's 3-month spending averages and income, suggest smart monthly budgets for each category.

Monthly Income Average: ${monthlyIncomeAverage.toStringAsFixed(2)} $currency

3-Month Category Averages:
$categoryLines

Return a JSON array of budget suggestions. Each item must have these exact fields:
- category_name (string): same as provided
- suggested_amount (number): the recommended monthly budget in $currency
- reason (string): short, friendly Gen Z tone explanation (max 60 chars)
- difficulty (string): one of "easy", "medium", or "challenging"

Only return the JSON array, no other text.
Example:
[{"category_name":"Food","suggested_amount":400,"reason":"You typically spend 420 — small trim possible","difficulty":"easy"}]
''';

    try {
      final response = await _dio.post<dynamic>(
        'https://api.openai.com/v1/chat/completions',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 500,
          'temperature': 0.3,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Unexpected response format from OpenAI.');
      }

      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('OpenAI returned no choices.');
      }

      final content = (choices.first as Map<String, dynamic>)['message']
          ?['content'] as String?;
      if (content == null || content.isEmpty) {
        throw Exception('OpenAI returned empty content.');
      }

      // Parse JSON from content
      final cleanContent = content.trim();
      final jsonStart = cleanContent.indexOf('[');
      final jsonEnd = cleanContent.lastIndexOf(']');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('Could not parse budget suggestions from AI response.');
      }

      final jsonStr = cleanContent.substring(jsonStart, jsonEnd + 1);
      final parsed = jsonDecode(jsonStr) as List;

      return parsed
          .whereType<Map<String, dynamic>>()
          .map((e) => AiBudgetSuggestion.fromJson(e))
          .where((s) => s.categoryName.isNotEmpty && s.suggestedAmount > 0)
          .toList();
    } on dio.DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        throw Exception('Invalid OpenAI API key. Please check your settings.');
      }
      if (statusCode == 429) {
        throw Exception(
            'AI rate limit reached. Please try again in a moment.');
      }
      throw Exception(
          'Could not get AI budget suggestions. Please try again.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to generate budget suggestions.');
    }
  }
}
