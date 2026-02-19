import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:moneii_manager/core/constants.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _autoStopTimer;
  String? _currentPath;

  Future<void> startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw Exception('Microphone permission is required');
    }

    final dir = await getTemporaryDirectory();
    _currentPath =
        '${dir.path}/voice_input_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        bitRate: 128000,
      ),
      path: _currentPath!,
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
    if (path != null && File(path).existsSync()) return path;
    return _currentPath != null && File(_currentPath!).existsSync()
        ? _currentPath
        : null;
  }

  Future<void> dispose() async {
    _autoStopTimer?.cancel();
    await _recorder.dispose();
  }
}
