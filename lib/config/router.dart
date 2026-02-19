import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/screens/login_screen.dart';
import 'package:moneii_manager/features/auth/presentation/screens/register_screen.dart';
import 'package:moneii_manager/features/auth/presentation/screens/setup_screen.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';
import 'package:moneii_manager/features/expenses/presentation/screens/expense_list_screen.dart';
import 'package:moneii_manager/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:moneii_manager/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:moneii_manager/features/profile/presentation/screens/profile_screen.dart';
import 'package:moneii_manager/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:moneii_manager/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:moneii_manager/shared/widgets/app_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final hasSeenOnboarding = ref.watch(hasSeenOnboardingProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isOnboardingRoute = location == '/onboarding';
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = location == '/login' || location == '/register';
      final isSetupRoute = location == '/setup';

      if (!hasSeenOnboarding && !isOnboardingRoute) return '/onboarding';
      if (hasSeenOnboarding && isOnboardingRoute) {
        return isLoggedIn ? '/' : '/login';
      }

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      if (isLoggedIn && !isSetupRoute) {
        final profile = ref.read(profileProvider).valueOrNull;
        if (profile != null && !profile.isSetupComplete) return '/setup';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const RegisterScreen()),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const SetupScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const ExpenseListScreen()),
          ),
          GoRoute(
            path: '/analytics',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const AnalyticsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/add-expense',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: AddExpenseScreen(
            initialExpense: state.extra is Expense
                ? state.extra as Expense
                : null,
            initialData: state.extra is AddExpenseInitialData
                ? state.extra as AddExpenseInitialData
                : null,
          ),
        ),
      ),
    ],
  );
});

CustomTransitionPage<void> _buildPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
