import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/voice/data/datasources/whisper_remote_datasource.dart';
import 'package:moneii_manager/features/voice/data/services/audio_recorder_service.dart';
import 'package:moneii_manager/features/voice/data/services/expense_parser_service.dart';
import 'package:moneii_manager/features/voice/domain/entities/parsed_expense.dart';

sealed class VoiceInputState {
  const VoiceInputState();
}

class VoiceIdle extends VoiceInputState {
  const VoiceIdle();
}

class VoiceRecording extends VoiceInputState {
  const VoiceRecording();
}

class VoiceTranscribing extends VoiceInputState {
  const VoiceTranscribing();
}

class VoiceParsed extends VoiceInputState {
  final ParsedExpense expense;
  const VoiceParsed(this.expense);
}

class VoiceError extends VoiceInputState {
  final String message;
  const VoiceError(this.message);
}

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  final AudioRecorderService _recorder;
  final WhisperRemoteDatasource _whisper;
  final ExpenseParserService _parser;

  VoiceInputNotifier()
    : _recorder = AudioRecorderService(),
      _whisper = WhisperRemoteDatasource(),
      _parser = ExpenseParserService(),
      super(const VoiceIdle());

  Future<void> startRecording() async {
    try {
      await _recorder.startRecording();
      state = const VoiceRecording();
    } catch (e) {
      state = VoiceError('Could not start recording: $e');
    }
  }

  Future<void> stopAndTranscribe() async {
    if (state is! VoiceRecording) return;
    state = const VoiceTranscribing();
    try {
      final path = await _recorder.stopRecording();
      if (path == null) {
        state = const VoiceError('No audio recorded.');
        return;
      }
      final transcript = await _whisper.transcribe(path);
      state = VoiceParsed(_parser.parse(transcript));
    } catch (e) {
      state = VoiceError('Failed to process: $e');
    }
  }

  void reset() => state = const VoiceIdle();

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}

final voiceInputProvider =
    StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
      (ref) => VoiceInputNotifier(),
    );
