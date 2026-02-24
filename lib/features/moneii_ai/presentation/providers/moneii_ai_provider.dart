import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/moneii_ai/data/datasources/moneii_ai_remote_datasource.dart';

class MoneiiAiMessage {
  const MoneiiAiMessage({
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String role;
  final String text;
  final DateTime createdAt;
}

class MoneiiAiState {
  const MoneiiAiState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.dailyUsed = 0,
    this.dailyLimit,
    this.monthlyUsed = 0,
    this.monthlyLimit = 0,
    this.planTier = 'premium',
  });

  final List<MoneiiAiMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final int dailyUsed;
  final int? dailyLimit;
  final int monthlyUsed;
  final int monthlyLimit;
  final String planTier;

  MoneiiAiState copyWith({
    List<MoneiiAiMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    int? dailyUsed,
    int? dailyLimit,
    bool clearDailyLimit = false,
    int? monthlyUsed,
    int? monthlyLimit,
    String? planTier,
  }) {
    return MoneiiAiState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      dailyUsed: dailyUsed ?? this.dailyUsed,
      dailyLimit: clearDailyLimit ? null : (dailyLimit ?? this.dailyLimit),
      monthlyUsed: monthlyUsed ?? this.monthlyUsed,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      planTier: planTier ?? this.planTier,
    );
  }
}

class MoneiiAiNotifier extends StateNotifier<MoneiiAiState> {
  MoneiiAiNotifier({MoneiiAiRemoteDatasource? datasource})
    : _datasource = datasource ?? MoneiiAiRemoteDatasource(),
      super(
        MoneiiAiState(
          messages: [
            MoneiiAiMessage(
              role: 'assistant',
              text:
                  'I am Moneii AI. Ask me anything about your spending, income, transfers, and trends.',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );

  final MoneiiAiRemoteDatasource _datasource;

  Future<void> sendPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final nextMessages = [
      ...state.messages,
      MoneiiAiMessage(role: 'user', text: trimmed, createdAt: DateTime.now()),
    ];
    state = state.copyWith(
      messages: nextMessages,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final result = await _datasource.ask(trimmed);
      state = state.copyWith(
        messages: [
          ...nextMessages,
          MoneiiAiMessage(
            role: 'assistant',
            text: result.answer,
            createdAt: DateTime.now(),
          ),
        ],
        isLoading: false,
        dailyUsed: result.dailyUsed,
        dailyLimit: result.dailyLimit,
        clearDailyLimit: result.dailyLimit == null,
        monthlyUsed: result.monthlyUsed,
        monthlyLimit: result.monthlyLimit,
        planTier: result.planTier,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final moneiiAiProvider =
    StateNotifierProvider.autoDispose<MoneiiAiNotifier, MoneiiAiState>(
      (ref) => MoneiiAiNotifier(),
    );
