import 'package:dio/dio.dart' as dio;
import 'package:moneii_manager/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceTranscriptionResult {
  const VoiceTranscriptionResult({
    required this.transcript,
    this.description,
  });

  final String transcript;
  final String? description;
}

class WhisperRemoteDatasource {
  WhisperRemoteDatasource({dio.Dio? dioClient}) : _dio = dioClient ?? dio.Dio();

  final dio.Dio _dio;

  Future<VoiceTranscriptionResult> transcribe(String filePath) async {
    final client = Supabase.instance.client;
    final token = client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('You are not signed in. Please sign in and try again.');
    }

    late final dio.Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        '${Env.supabaseUrl}/functions/v1/voice-transcribe',
        data: dio.FormData.fromMap({
          'file': await dio.MultipartFile.fromFile(
            filePath,
            filename: 'audio.m4a',
          ),
        }),
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
            'apikey': Env.supabaseAnonKey,
          },
          sendTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
    } on dio.DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = (data['error'] as String?)?.trim();
        if (message != null && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      rethrow;
    }

    final data = response.data ?? <String, dynamic>{};
    final transcript = (data['transcript'] as String?)?.trim() ?? '';
    final description = (data['description'] as String?)?.trim();

    if (transcript.isEmpty) {
      throw Exception(
        (data['error'] as String?) ??
            'No transcription returned. Please try again.',
      );
    }

    return VoiceTranscriptionResult(
      transcript: transcript,
      description: description == null || description.isEmpty
          ? null
          : description,
    );
  }
}
