import 'package:dio/dio.dart';
import 'package:moneii_manager/config/env.dart';
import 'package:moneii_manager/core/constants.dart';

class WhisperRemoteDatasource {
  final Dio _dio;

  WhisperRemoteDatasource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.openai.com/v1',
              headers: {'Authorization': 'Bearer ${Env.openaiApiKey}'},
            ),
          );

  Future<String> transcribe(String filePath) async {
    final prompt =
        'Transcribe short personal expense statements with clear amounts and items, for example: spent 12 dollars on lunch.';

    final verboseForm = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'audio.m4a'),
      'model': AppConstants.whisperModel,
      'response_format': 'verbose_json',
      'language': 'en',
      'temperature': 0,
      'prompt': prompt,
    });

    final verboseResponse = await _dio.post<Map<String, dynamic>>(
      '/audio/transcriptions',
      data: verboseForm,
    );

    final verboseData = verboseResponse.data ?? <String, dynamic>{};
    var text = (verboseData['text'] as String?)?.trim() ?? '';

    // Some responses can have segment text even when top-level text is blank.
    if (text.isEmpty && verboseData['segments'] is List) {
      final segments = (verboseData['segments'] as List)
          .whereType<Map<String, dynamic>>()
          .map((segment) => (segment['text'] as String?)?.trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
      text = segments.join(' ').trim();
    }

    if (text.isNotEmpty) {
      final lower = text.toLowerCase();
      final isKnownHallucination =
          lower.contains('www.fema.gov') ||
          lower.contains('for more information');
      if (!isKnownHallucination) {
        return text;
      }
    }

    // Fallback to plain text format, which can be more stable on some recordings.
    final plainForm = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'audio.m4a'),
      'model': AppConstants.whisperModel,
      'response_format': 'text',
      'language': 'en',
      'temperature': 0,
      'prompt': prompt,
    });

    final plainResponse = await _dio.post<String>(
      '/audio/transcriptions',
      data: plainForm,
    );
    final plainText = (plainResponse.data ?? '').trim();
    if (plainText.isEmpty) {
      throw Exception(
        'No transcription returned from Whisper. Please try again.',
      );
    }
    return plainText;
  }
}
