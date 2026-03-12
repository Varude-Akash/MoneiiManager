import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:moneii_manager/config/theme.dart';

class AiHubScreen extends StatelessWidget {
  const AiHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moneii AI')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              'AI-powered tools for smarter money decisions',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _MoneiiAiHeroCard(),
              const SizedBox(height: 24),
              const Text(
                'AI Tools',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: const [
                  _AiToolCard(
                    icon: Iconsax.wallet,
                    title: 'Smart Budget',
                    description: 'AI-powered budget recommendations',
                    status: _ToolStatus.premium,
                    route: '/analytics',
                  ),
                  _AiToolCard(
                    icon: Iconsax.microphone,
                    title: 'Voice Entry',
                    description: 'Log expenses with your voice',
                    status: _ToolStatus.free,
                    route: '/',
                  ),
                  _AiToolCard(
                    icon: Iconsax.chart_square,
                    title: 'AI Spending Insights',
                    description: 'Personalised insights into your spending habits',
                    status: _ToolStatus.comingSoon,
                  ),
                  _AiToolCard(
                    icon: Iconsax.graph,
                    title: 'Expense Predictions',
                    description: 'Forecast your upcoming expenses',
                    status: _ToolStatus.comingSoon,
                  ),
                  _AiToolCard(
                    icon: Iconsax.money,
                    title: 'Investment Suggestions',
                    description: 'AI-driven investment ideas for your surplus',
                    status: _ToolStatus.comingSoon,
                  ),
                  _AiToolCard(
                    icon: Iconsax.heart,
                    title: 'Account Health Score',
                    description: 'Deep analysis of your financial wellness',
                    status: _ToolStatus.comingSoon,
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

class _MoneiiAiHeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/moneii-ai'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Iconsax.magic_star,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'Zora',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Your personal financial AI assistant',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ask anything about your finances. Where did I overspend? How much did I save last month?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pro & Pro+',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap to chat',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ToolStatus { free, premium, comingSoon }

class _AiToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final _ToolStatus status;
  final String? route;

  const _AiToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    final isComingSoon = status == _ToolStatus.comingSoon;

    return GestureDetector(
      onTap: isComingSoon || route == null ? null : () => context.go(route!),
      child: Opacity(
        opacity: isComingSoon ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 18),
                  ),
                  const Spacer(),
                  _StatusBadge(status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _ToolStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _ToolStatus.free:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Free',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        );
      case _ToolStatus.premium:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Pro',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        );
      case _ToolStatus.comingSoon:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Soon',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        );
    }
  }
}
