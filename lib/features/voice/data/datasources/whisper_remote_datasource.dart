import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:moneii_manager/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceTranscriptionResult {
  const VoiceTranscriptionResult({required this.transcript, this.description});

  final String transcript;
  final String? description;
}

class WhisperRemoteDatasource {
  WhisperRemoteDatasource({dio.Dio? dioClient}) : _dio = dioClient ?? dio.Dio();

  final dio.Dio _dio;

  Future<VoiceTranscriptionResult> transcribe(String filePath) async {
    final token = await _getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('You are not signed in. Please sign in and try again.');
    }

    final multipartFile = await _buildMultipartAudio(filePath);

    dio.Response<Map<String, dynamic>> response;
    try {
      response = await _callTranscribe(token, multipartFile);
    } on dio.DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        final refreshedToken = await _getAccessToken(forceRefresh: true);
        if (refreshedToken == null || refreshedToken.isEmpty) {
          throw Exception(
            'Your session expired. Please sign out and sign in again.',
          );
        }
        try {
          response = await _callTranscribe(refreshedToken, multipartFile);
        } on dio.DioException {
          throw Exception(
            'Your session expired. Please sign out and sign in again.',
          );
        }
        return _parseResponse(response.data ?? <String, dynamic>{});
      }
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message =
            ((data['error'] as String?) ?? (data['message'] as String?))
                ?.trim();
        if (message != null && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      throw Exception('Could not process voice input. Please try again.');
    }

    return _parseResponse(response.data ?? <String, dynamic>{});
  }

  VoiceTranscriptionResult _parseResponse(Map<String, dynamic> data) {
    final transcript = (data['transcript'] as String?)?.trim() ?? '';
    final description = (data['description'] as String?)?.trim();

    if (transcript.isEmpty) {
      throw Exception(
        ((data['error'] as String?) ?? (data['message'] as String?)) ??
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

  Future<dio.Response<Map<String, dynamic>>> _callTranscribe(
    String token,
    dio.MultipartFile multipartFile,
  ) {
    return _dio.post<Map<String, dynamic>>(
      '${Env.supabaseUrl}/functions/v1/voice-transcribe',
      data: dio.FormData.fromMap({
        'file': multipartFile,
        'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes.toString(),
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
  }

  Future<dio.MultipartFile> _buildMultipartAudio(String filePath) async {
    if (kIsWeb || filePath.startsWith('blob:')) {
      final response = await _dio.get<List<int>>(
        filePath,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('No audio bytes available for upload.');
      }
      return dio.MultipartFile.fromBytes(
        bytes,
        filename: 'audio.webm',
        contentType: dio.DioMediaType.parse('audio/webm'),
      );
    }

    return dio.MultipartFile.fromFile(filePath, filename: 'audio.m4a');
  }
}
