import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/goals/domain/entities/savings_goal.dart';
import 'package:moneii_manager/features/goals/presentation/providers/goals_provider.dart';
import 'package:moneii_manager/features/goals/presentation/widgets/add_goal_sheet.dart';
import 'package:moneii_manager/features/goals/presentation/widgets/goal_card.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  late ConfettiController _confettiController;
  Set<String> _previouslyCompleted = {};

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _checkForNewCompletions(List<SavingsGoal> goals) {
    for (final goal in goals) {
      if (goal.isCompleted && !_previouslyCompleted.contains(goal.id)) {
        _previouslyCompleted.add(goal.id);
        _confettiController.play();
        break;
      }
    }
    // Update the set
    _previouslyCompleted = goals
        .where((g) => g.isCompleted)
        .map((g) => g.id)
        .toSet();
  }

  Future<void> _showContributionSheet(
      BuildContext context, SavingsGoal goal) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.glassBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add contribution to ${goal.name}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Amount to add',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixText: '${goal.currency} ',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(controller.text.trim());
                  if (amount != null && amount > 0) {
                    Navigator.of(ctx).pop(amount);
                  }
                },
                child: const Text('Add Contribution'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result > 0) {
      try {
        await ref
            .read(goalActionsProvider.notifier)
            .addContribution(goal.id, result);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Error: ${e.toString().replaceFirst('Exception: ', '')}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(savingsGoalsProvider);

    goalsAsync.whenData((goals) => _checkForNewCompletions(goals));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Savings Goals'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddGoalSheet.show(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          goalsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: Text(
                'Something went wrong',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            data: (goals) {
              if (goals.isEmpty) {
                return _EmptyState(
                  onCreateTap: () => AddGoalSheet.show(context),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: goals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  return GestureDetector(
                    onLongPress: () =>
                        _showContributionSheet(context, goal),
                    child: GoalCard(
                      goal: goal,
                      onTap: () =>
                          AddGoalSheet.show(context, existingGoal: goal),
                    ),
                  );
                },
              );
            },
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              colors: const [
                AppColors.primary,
                AppColors.accent,
                AppColors.accentGreen,
                AppColors.accentOrange,
              ],
              shouldLoop: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'No goals yet!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dream big. Set your first savings goal and watch it grow. You got this! 💪',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create First Goal'),
            ),
          ],
        ),
      ),
    );
  }
}
