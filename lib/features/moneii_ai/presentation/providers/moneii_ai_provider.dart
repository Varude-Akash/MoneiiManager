import 'dart:async';

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
    this.isBootstrapping = false,
    this.errorMessage,
    this.dailyUsed = 0,
    this.dailyLimit,
    this.monthlyUsed = 0,
    this.monthlyLimit = 0,
    this.planTier = 'premium',
    this.availableMonths = const [],
    this.selectedMonthStart,
  });

  final List<MoneiiAiMessage> messages;
  final bool isLoading;
  final bool isBootstrapping;
  final String? errorMessage;
  final int dailyUsed;
  final int? dailyLimit;
  final int monthlyUsed;
  final int monthlyLimit;
  final String planTier;
  final List<DateTime> availableMonths;
  final DateTime? selectedMonthStart;

  MoneiiAiState copyWith({
    List<MoneiiAiMessage>? messages,
    bool? isLoading,
    bool? isBootstrapping,
    String? errorMessage,
    int? dailyUsed,
    int? dailyLimit,
    bool clearDailyLimit = false,
    int? monthlyUsed,
    int? monthlyLimit,
    String? planTier,
    List<DateTime>? availableMonths,
    DateTime? selectedMonthStart,
    bool clearSelectedMonth = false,
  }) {
    return MoneiiAiState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      errorMessage: errorMessage,
      dailyUsed: dailyUsed ?? this.dailyUsed,
      dailyLimit: clearDailyLimit ? null : (dailyLimit ?? this.dailyLimit),
      monthlyUsed: monthlyUsed ?? this.monthlyUsed,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      planTier: planTier ?? this.planTier,
      availableMonths: availableMonths ?? this.availableMonths,
      selectedMonthStart: clearSelectedMonth
          ? null
          : (selectedMonthStart ?? this.selectedMonthStart),
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
                  'I am Zora, your personal financial AI assistant. Ask me anything about your spending, income, transfers, and trends.',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      ) {
    unawaited(bootstrap());
  }

  final MoneiiAiRemoteDatasource _datasource;
  final Map<DateTime, List<MoneiiAiMessage>> _monthMessages = {};

  Future<void> bootstrap() async {
    state = state.copyWith(isBootstrapping: true, errorMessage: null);
    try {
      final result = await _datasource.bootstrap();
      _monthMessages.clear();
      for (final entry in result.historyByMonth.entries) {
        _monthMessages[entry.key] = [
          for (final record in entry.value) ...[
            MoneiiAiMessage(
              role: 'user',
              text: record.prompt,
              createdAt: record.createdAt,
            ),
            MoneiiAiMessage(
              role: 'assistant',
              text: _cleanAssistantText(record.response),
              createdAt: record.createdAt,
            ),
          ],
        ];
      }

      final months = _buildLastThreeMonths();
      final nowMonth = DateTime(DateTime.now().year, DateTime.now().month);
      state = state.copyWith(
        isBootstrapping: false,
        planTier: result.planTier,
        dailyUsed: result.dailyUsed,
        dailyLimit: result.dailyLimit,
        clearDailyLimit: result.dailyLimit == null,
        monthlyUsed: result.monthlyUsed,
        monthlyLimit: result.monthlyLimit,
        availableMonths: months,
        selectedMonthStart: nowMonth,
        messages: _messagesForMonth(nowMonth),
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isBootstrapping: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void selectMonth(DateTime monthStart) {
    final normalized = DateTime(monthStart.year, monthStart.month);
    if (!state.availableMonths.any(
      (month) => month.year == normalized.year && month.month == normalized.month,
    )) {
      return;
    }
    state = state.copyWith(
      selectedMonthStart: normalized,
      messages: _messagesForMonth(normalized),
      errorMessage: null,
    );
  }

  Future<void> sendPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || state.isLoading) return;
    if (!isCurrentMonthSelected) {
      state = state.copyWith(
        errorMessage:
            'Previous months are read-only. Ask new questions in current month.',
      );
      return;
    }

    final selected = state.selectedMonthStart ??
        DateTime(DateTime.now().year, DateTime.now().month);

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
      final assistantMessage = MoneiiAiMessage(
        role: 'assistant',
        text: _cleanAssistantText(result.answer),
        createdAt: DateTime.now(),
      );
      _monthMessages[selected] = [...nextMessages, assistantMessage];
      state = state.copyWith(
        messages: _messagesForMonth(selected),
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

  bool get isCurrentMonthSelected {
    final selected = state.selectedMonthStart;
    if (selected == null) return true;
    final now = DateTime.now();
    return selected.year == now.year && selected.month == now.month;
  }

  List<DateTime> _buildLastThreeMonths() {
    final now = DateTime.now();
    return List<DateTime>.generate(
      3,
      (index) => DateTime(now.year, now.month - index),
    );
  }

  List<MoneiiAiMessage> _messagesForMonth(DateTime monthStart) {
    final existing = _monthMessages[monthStart] ?? const <MoneiiAiMessage>[];
    if (existing.isNotEmpty) return existing;
    if (_isCurrentMonth(monthStart)) {
      return [
        MoneiiAiMessage(
          role: 'assistant',
          text:
              'I am Moneii AI. Ask me anything about your spending, income, transfers, and trends.',
          createdAt: DateTime.now(),
        ),
      ];
    }
    return [
      MoneiiAiMessage(
        role: 'assistant',
        text: 'No chats found for this month.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  bool _isCurrentMonth(DateTime monthStart) {
    final now = DateTime.now();
    return monthStart.year == now.year && monthStart.month == now.month;
  }

  String _cleanAssistantText(String raw) {
    final noMarkdown = raw.replaceAll('**', '');
    return noMarkdown.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

final moneiiAiProvider =
    StateNotifierProvider<MoneiiAiNotifier, MoneiiAiState>(
      (ref) => MoneiiAiNotifier(),
    );
