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
      state = VoiceError(_friendlyError(e.toString(), forStart: true));
    }
  }

  Future<void> stopAndTranscribe() async {
    if (state is! VoiceRecording) return;
    state = const VoiceTranscribing();
    try {
      final path = await _recorder.stopRecording();
      if (path == null) {
        state = const VoiceError(
          'No audio transcript detected. Please try again or add manually.',
        );
        return;
      }
      final result = await _whisper.transcribe(path);
      final transcript = result.transcript;
      if (transcript.trim().isEmpty) {
        state = const VoiceError(
          'No audio transcript detected. Please try again or add manually.',
        );
        return;
      }
      final parsed = _parser.parse(transcript);
      final aiDescription = result.description;
      state = VoiceParsed(
        aiDescription == null || aiDescription.isEmpty
            ? parsed
            : parsed.copyWith(description: aiDescription),
      );
    } catch (e) {
      state = VoiceError(_friendlyError(e.toString()));
    }
  }

  void reset() => state = const VoiceIdle();

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  String _friendlyError(String raw, {bool forStart = false}) {
    final text = raw.toLowerCase();

    if (forStart ||
        text.contains('permission') ||
        text.contains('microphone')) {
      return 'Microphone permission is required. Please allow mic access and try again.';
    }
    if (text.contains('no clear speech detected') ||
        text.contains('inaudible') ||
        text.contains('empty audio')) {
      return 'Inaudible audio detected. Please speak clearly and try again.';
    }
    if (text.contains('socketexception') ||
        text.contains('connection') ||
        text.contains('network') ||
        text.contains('timeout')) {
      return 'Network issue while transcribing. Please check internet and try again.';
    }
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('api key') ||
        text.contains('unauthorized')) {
      return 'Voice service is unavailable right now. Please try again later or add manually.';
    }
    if (text.contains('daily voice ai limit reached') ||
        text.contains('monthly voice ai limit reached')) {
      return 'You have reached your AI voice limit. Upgrade to Premium for higher limits.';
    }
    return 'Could not process voice input. Please try again or add manually.';
  }
}

final voiceInputProvider =
    StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
      (ref) => VoiceInputNotifier(),
    );
