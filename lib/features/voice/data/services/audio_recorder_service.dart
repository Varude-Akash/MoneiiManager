import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:moneii_manager/core/constants.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _autoStopTimer;
  String? _currentPath;

  Future<void> startRecording() async {
    if (!kIsWeb) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission is required');
      }

      final dir = Directory.systemTemp;
      _currentPath =
          '${dir.path}/voice_input_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    final recordingPath = kIsWeb ? 'audio.m4a' : _currentPath!;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      ),
      path: recordingPath,
    );

    _autoStopTimer = Timer(
      Duration(seconds: AppConstants.maxRecordingDurationSeconds),
      () async => await _recorder.stop(),
    );
  }

  Future<String?> stopRecording() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    final path = await _recorder.stop();
    if (kIsWeb) {
      return path;
    }

    final resolvedPath = path != null && File(path).existsSync()
        ? path
        : _currentPath != null && File(_currentPath!).existsSync()
        ? _currentPath
        : null;
    if (resolvedPath == null) return null;

    final size = await File(resolvedPath).length();
    if (size > AppConstants.maxAudioUploadBytes) {
      throw Exception(
        'Audio is too large. Please keep voice note under ${AppConstants.maxRecordingDurationSeconds} seconds.',
      );
    }

    return resolvedPath;
  }

  Future<void> dispose() async {
    _autoStopTimer?.cancel();
    await _recorder.dispose();
  }
}
