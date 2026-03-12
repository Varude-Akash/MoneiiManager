import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/activity') return 1;
    if (location == '/analytics') return 2;
    if (location == '/ai') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final topPadding = MediaQuery.of(context).padding.top;
    final location = GoRouterState.of(context).matchedLocation;
    final showProfileButton = location != '/profile';

    return Scaffold(
      body: Stack(
        children: [
          child,
          if (showProfileButton)
          Positioned(
            top: topPadding + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.glassBorder, width: 1.5),
                  color: AppColors.surface,
                ),
                child: ClipOval(
                  child: profile?.avatarUrl != null &&
                          profile!.avatarUrl!.isNotEmpty
                      ? Image.network(
                          profile.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => const Icon(
                            Iconsax.profile_circle,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                        )
                      : const Icon(
                          Iconsax.profile_circle,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? AppColors.primary : AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/');
                break;
              case 1:
                context.go('/activity');
                break;
              case 2:
                context.go('/analytics');
                break;
              case 3:
                context.go('/ai');
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Iconsax.home_2),
              selectedIcon: Icon(Iconsax.home_25),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.chart_2),
              selectedIcon: Icon(Iconsax.chart_21),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Iconsax.magic_star),
              selectedIcon: Icon(Iconsax.magic_star),
              label: 'Moneii AI',
            ),
          ],
        ),
      ),
    );
  }
}
