import 'package:dio/dio.dart';
import 'package:moneii_manager/config/env.dart';
import 'package:moneii_manager/core/constants.dart';

class VoiceDescriptionRemoteDatasource {
  VoiceDescriptionRemoteDatasource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.openai.com/v1',
              headers: {'Authorization': 'Bearer ${Env.openaiApiKey}'},
            ),
          );

  final Dio _dio;

  Future<String?> summarizeExpense({
    required String transcript,
    required String fallbackDescription,
  }) async {
    if (Env.openaiApiKey.trim().isEmpty) return null;

    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: {
        'model': AppConstants.descriptionModel,
        'temperature': 0.1,
        'messages': [
          {
            'role': 'system',
            'content':
                'You convert expense speech into short meaningful descriptions. '
                    'Return only a short noun phrase (2-5 words), no emojis, no quotes, no full sentence.',
          },
          {
            'role': 'user',
            'content':
                'Transcript: "$transcript"\n'
                    'Fallback description: "$fallbackDescription"\n'
                    'Return only the cleaned short description.',
          },
        ],
      },
    );

    final choices = response.data?['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map<String, dynamic>) return null;
    final message = first['message'];
    if (message is! Map<String, dynamic>) return null;
    final content = (message['content'] as String?)?.trim();
    if (content == null || content.isEmpty) return null;

    return _clean(content);
  }

  String _clean(String text) {
    final singleLine = text.split('\n').first;
    final cleaned = singleLine
        .replaceAll(RegExp(r'["`]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final withoutTrail = cleaned.replaceAll(RegExp(r'[.,;:!?]+$'), '').trim();
    if (withoutTrail.length <= 42) return withoutTrail;
    return withoutTrail.substring(0, 42).trim();
  }
}
