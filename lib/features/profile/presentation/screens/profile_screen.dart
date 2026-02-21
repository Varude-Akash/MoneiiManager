import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/config/theme_mode_provider.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:moneii_manager/features/profile/domain/entities/financial_account.dart';
import 'package:moneii_manager/features/profile/presentation/providers/financial_account_provider.dart';
import 'package:moneii_manager/shared/widgets/glass_card.dart';
import 'package:moneii_manager/shared/widgets/shimmer_skeleton.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.autoOpenAddAccount = false});

  final bool autoOpenAddAccount;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  String _currency = 'USD';
  bool _saving = false;
  bool _notificationsEnabled = true;
  bool _settingsLoaded = false;
  bool _autoDialogHandled = false;
  XFile? _selectedAvatar;
  String? _avatarUrl;

  static const _notificationKey = 'notifications_enabled';

  static const _premiumFeatures = [
    'AI Spending Insights',
    'Investment Suggestions',
    'Smart Budget Recommendations',
    'Expense Predictions',
    'Export Reports (PDF/CSV)',
    'Multi-currency Support',
    'Custom Categories',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (image == null) return;

    HapticFeedback.selectionClick();
    setState(() {
      _selectedAvatar = image;
    });
  }

  Future<String?> _uploadAvatar(String userId) async {
    final selectedAvatar = _selectedAvatar;
    if (selectedAvatar == null) return _avatarUrl;

    final client = ref.read(supabaseClientProvider);
    final filePath =
        'avatars/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await client.storage
          .from('avatars')
          .upload(filePath, File(selectedAvatar.path));
      return client.storage.from('avatars').getPublicUrl(filePath);
    } catch (_) {
      return _avatarUrl;
    }
  }

  Future<void> _saveProfile() async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;
    final previousCurrency = profile.currencyPreference;
    final changedCurrency = previousCurrency != _currency;
    final currentYear = DateTime.now().year;

    var changeCount = profile.currencyChangeCount;
    var changeYear = profile.currencyChangeYear;
    if (profile.isPremium && changeYear != currentYear) {
      changeCount = 0;
      changeYear = currentYear;
    }

    if (changedCurrency) {
      final allowedChanges = profile.isPremium ? 5 : 3;
      if (changeCount >= allowedChanges) {
        final message = profile.isPremium
            ? 'Premium limit reached: you can change currency up to 5 times per year.'
            : 'Free limit reached: you can change currency up to 3 times. Upgrade to Premium for up to 5 changes/year.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final confirmed = await _showCurrencyChangeConfirmDialog(
        remainingAfterChange: allowedChanges - (changeCount + 1),
        isPremium: profile.isPremium,
      );
      if (!confirmed) return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final avatarUrl = await _uploadAvatar(profile.id);

      await client
          .from('profiles')
          .update({
            'display_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'bio': _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            'currency_preference': _currency,
            'currency_change_count': changedCurrency
                ? changeCount + 1
                : changeCount,
            'currency_change_year': changeYear,
            'avatar_url': avatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profile.id);

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_notificationKey, _notificationsEnabled);

      ref.invalidate(profileProvider);
      if (!mounted) return;
      final allowedChanges = profile.isPremium ? 5 : 3;
      final updatedCount = changedCurrency ? changeCount + 1 : changeCount;
      final remainingChanges = (allowedChanges - updatedCount).clamp(
        0,
        allowedChanges,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changedCurrency
                ? 'Currency changed to ${CurrencyUtils.currencyLabel(_currency)}. Remaining currency changes: $remainingChanges.'
                : 'Profile updated',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autoOpenAddAccount && !_autoDialogHandled) {
      _autoDialogHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAddAccountDialog();
      });
    }

    final profileAsync = ref.watch(profileProvider);
    final accountsAsync = ref.watch(financialAccountsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const ExpenseListShimmer(),
        error: (error, _) => Center(
          child: Text(
            error.toString(),
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text(
                'Profile not found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          if (_nameController.text.isEmpty) {
            _nameController.text = profile.displayName ?? '';
            _phoneController.text = profile.phone ?? '';
            _bioController.text = profile.bio ?? '';
            _currency = profile.currencyPreference;
            _avatarUrl = profile.avatarUrl;
          }

          if (!_settingsLoaded) {
            _settingsLoaded = true;
            _notificationsEnabled =
                ref.read(sharedPreferencesProvider).getBool(_notificationKey) ??
                true;
          }

          final freeOrPremiumLimit = profile.isPremium ? 5 : 3;
          var trackedCount = profile.currencyChangeCount;
          if (profile.isPremium &&
              profile.currencyChangeYear != DateTime.now().year) {
            trackedCount = 0;
          }
          final remainingChanges = (freeOrPremiumLimit - trackedCount).clamp(
            0,
            freeOrPremiumLimit,
          );

          final name = profile.displayName?.trim().isNotEmpty == true
              ? profile.displayName!
              : user?.email.split('@').first ?? 'User';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              GlassCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.2,
                        ),
                        backgroundImage: _selectedAvatar != null
                            ? FileImage(File(_selectedAvatar!.path))
                            : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                      ? NetworkImage(_avatarUrl!)
                                      : null)
                                  as ImageProvider<Object>?,
                        child:
                            (_selectedAvatar == null &&
                                (_avatarUrl == null || _avatarUrl!.isEmpty))
                            ? Text(
                                name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? profile.email,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                margin: EdgeInsets.zero,
                child: _AccountManagerSection(
                  accountsAsync: accountsAsync,
                  currency: profile.currencyPreference,
                  onAdd: _showAddAccountDialog,
                  onEdit: _showEditAccountDialog,
                  onSetDefault: (account) async {
                    await ref
                        .read(financialAccountActionsProvider.notifier)
                        .setDefault(
                          accountId: account.id,
                          accountType: account.accountType,
                        );
                  },
                  onDelete: (account) async {
                    await ref
                        .read(financialAccountActionsProvider.notifier)
                        .deleteAccount(account.id);
                  },
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bio (optional)',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Currency preference',
                        prefixIcon: Icon(Icons.currency_exchange_rounded),
                      ),
                      items: CurrencyUtils.supportedCurrencies
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(
                                CurrencyUtils.currencyLabel(currency),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _currency = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.isPremium
                          ? 'You can change currency $remainingChanges more time(s) this year.'
                          : 'You can change currency $remainingChanges more time(s) on free plan.',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: themeMode == ThemeMode.dark,
                      title: const Text('Dark mode'),
                      subtitle: const Text('Default experience is dark mode'),
                      onChanged: (_) {
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _notificationsEnabled,
                      title: const Text('Notifications'),
                      subtitle: const Text('Expense reminders and summaries'),
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Premium',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Locked',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._premiumFeatures.map((feature) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.textMuted,
                        ),
                        title: Text(feature),
                        subtitle: const Text('Coming soon'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Coming Soon - Premium feature'),
                            ),
                          );
                        },
                      );
                    }),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Upgrade flow coming soon'),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Upgrade to Premium'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(authNotifierProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'MoneiiManager v1.0.0',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.03);
        },
      ),
    );
  }

  Future<bool> _showCurrencyChangeConfirmDialog({
    required int remainingAfterChange,
    required bool isPremium,
  }) async {
    final message = isPremium
        ? 'This change will be counted in your yearly premium limit. Remaining after this change: $remainingAfterChange.'
        : 'Free plan allows 3 currency changes total. Remaining after this change: $remainingAfterChange.';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Currency Change'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showAddAccountDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    final utilizedController = TextEditingController();
    var type = 'bank_account';
    var isDefault = true;

    final added = await showDialog<bool>(
        context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (e.g. HDFC Salary)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'bank_account',
                        child: Text('Bank Account'),
                      ),
                      DropdownMenuItem(
                        value: 'credit_card',
                        child: Text('Credit Card'),
                      ),
                      DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          type = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: type == 'credit_card'
                          ? 'Credit limit'
                          : 'Account balance (optional)',
                      hintText: type == 'credit_card'
                          ? 'Enter your card limit'
                          : 'Leave empty to start from 0',
                    ),
                  ),
                  if (type == 'credit_card') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: utilizedController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Currently utilized (optional)',
                        hintText: 'Leave empty for 0',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    type == 'credit_card'
                        ? 'Tip: We track cards using limit and utilized amount. Available credit is shown as limit minus utilized.'
                        : 'Tip: Adding initial balance helps track account balance accurately. '
                              'If you leave it empty, it starts at 0 and can go negative after expenses.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isDefault,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as default'),
                    onChanged: (value) {
                      setDialogState(() {
                        isDefault = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added != true) return;
    final name = nameController.text.trim();
    final initialBalance =
        double.tryParse(balanceController.text.trim().replaceAll(',', '')) ?? 0;
    final initialUtilized =
        double.tryParse(utilizedController.text.trim().replaceAll(',', '')) ??
        0;
    if (name.isEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter account name.')),
      );
      return;
    }
    if (type == 'credit_card' && initialBalance <= 0) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid credit limit.')),
      );
      return;
    }
    if (type == 'credit_card' && initialUtilized < 0) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Utilized amount cannot be negative.')),
      );
      return;
    }

    try {
      await ref
          .read(financialAccountActionsProvider.notifier)
          .addAccount(
            name: name,
            accountType: type,
            isDefault: isDefault,
            initialBalance: type == 'credit_card' ? 0 : initialBalance,
            creditLimit: type == 'credit_card' ? initialBalance : 0,
            initialUtilizedAmount: type == 'credit_card' ? initialUtilized : 0,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            type == 'credit_card'
                ? 'Credit card added. Available credit is tracked automatically.'
                : initialBalance == 0
                ? 'Account added. It starts at 0 and may go negative after expenses.'
                : 'Account added with initial balance.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showEditAccountDialog(FinancialAccount account) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: account.name);
    final balanceController = TextEditingController(
      text: account.accountType == 'credit_card'
          ? account.creditLimit.toStringAsFixed(2)
          : account.initialBalance.toStringAsFixed(2),
    );
    final utilizedController = TextEditingController(
      text: account.utilizedAmount.toStringAsFixed(2),
    );
    var isDefault = account.isDefault;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: account.accountType == 'credit_card'
                          ? 'Credit limit'
                          : 'Account balance',
                    ),
                  ),
                  if (account.accountType == 'credit_card') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: utilizedController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Current utilized amount',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isDefault,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as default'),
                    onChanged: (value) {
                      setDialogState(() => isDefault = value ?? false);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated != true) return;
    final name = nameController.text.trim();
    final parsedPrimary =
        double.tryParse(balanceController.text.trim().replaceAll(',', '')) ?? 0;
    final parsedUtilized =
        double.tryParse(utilizedController.text.trim().replaceAll(',', '')) ?? 0;

    if (name.isEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter account name.')),
      );
      return;
    }
    if (account.accountType == 'credit_card' && parsedPrimary <= 0) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid credit limit.')),
      );
      return;
    }
    if (account.accountType == 'credit_card' && parsedUtilized < 0) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Utilized amount cannot be negative.')),
      );
      return;
    }

    try {
      await ref
          .read(financialAccountActionsProvider.notifier)
          .updateAccount(
            account: account,
            name: name,
            isDefault: isDefault,
            initialBalance: account.accountType == 'credit_card'
                ? null
                : parsedPrimary,
            creditLimit: account.accountType == 'credit_card'
                ? parsedPrimary
                : null,
            utilizedAmount: account.accountType == 'credit_card'
                ? parsedUtilized
                : null,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Account updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }
}

class _AccountManagerSection extends StatelessWidget {
  const _AccountManagerSection({
    required this.accountsAsync,
    required this.currency,
    required this.onAdd,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final AsyncValue<List<FinancialAccount>> accountsAsync;
  final String currency;
  final VoidCallback onAdd;
  final Future<void> Function(FinancialAccount account) onEdit;
  final Future<void> Function(FinancialAccount account) onSetDefault;
  final Future<void> Function(FinancialAccount account) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Accounts, Cards & Wallets',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        accountsAsync.when(
          loading: () => const Text(
            'Loading accounts...',
            style: TextStyle(color: AppColors.textMuted),
          ),
          error: (error, _) => Text(
            error.toString(),
            style: const TextStyle(color: AppColors.error),
          ),
          data: (accounts) {
            if (accounts.isEmpty) {
              return const Text(
                'Add accounts/cards/wallets so transactions can map correctly.',
                style: TextStyle(color: AppColors.textMuted),
              );
            }

            return Column(
              children: accounts.map((account) {
                final typeLabel = switch (account.accountType) {
                  'credit_card' => 'Credit Card',
                  'wallet' => 'Wallet',
                  _ => 'Bank Account',
                };
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    switch (account.accountType) {
                      'credit_card' => Icons.credit_card_rounded,
                      'wallet' => Icons.account_balance_wallet_rounded,
                      _ => Icons.account_balance_rounded,
                    },
                  ),
                  title: Text(account.name),
                  subtitle: Text(
                    account.accountType == 'credit_card'
                        ? account.isDefault
                              ? '$typeLabel • Default • Utilized ${CurrencyUtils.format(account.utilizedAmount, currency: currency)} / Limit ${CurrencyUtils.format(account.creditLimit, currency: currency)}'
                              : '$typeLabel • Utilized ${CurrencyUtils.format(account.utilizedAmount, currency: currency)} / Limit ${CurrencyUtils.format(account.creditLimit, currency: currency)}'
                        : account.isDefault
                        ? '$typeLabel • Default • ${CurrencyUtils.format(account.currentBalance, currency: currency)}'
                        : '$typeLabel • ${CurrencyUtils.format(account.currentBalance, currency: currency)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await onEdit(account);
                      } else if (value == 'default') {
                        await onSetDefault(account);
                      } else if (value == 'delete') {
                        await onDelete(account);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'default',
                        child: Text('Set as default'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
