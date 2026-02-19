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
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'audio.m4a'),
      'model': AppConstants.whisperModel,
      'response_format': 'text',
      'language': 'en',
    });

    final response = await _dio.post<String>(
      '/audio/transcriptions',
      data: formData,
    );
    final text = response.data;
    if (text == null || text.isEmpty) throw Exception('Empty transcription');
    return text.trim();
  }
}
