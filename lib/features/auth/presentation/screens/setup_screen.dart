import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _selectedAvatar;
  String _currency = 'USD';

  @override
  void dispose() {
    _nameController.dispose();
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
    if (selectedAvatar == null) return null;

    final client = ref.read(supabaseClientProvider);
    final filePath =
        'avatars/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await client.storage
          .from('avatars')
          .upload(filePath, File(selectedAvatar.path));
      return client.storage.from('avatars').getPublicUrl(filePath);
    } catch (_) {
      return null;
    }
  }

  Future<void> _completeSetup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final user = ref.read(authStateProvider).valueOrNull;
    final avatarUrl = user == null ? null : await _uploadAvatar(user.id);

    await ref
        .read(authNotifierProvider.notifier)
        .completeSetup(
          name,
          avatarUrl: avatarUrl,
          currencyPreference: _currency,
        );
    ref.invalidate(profileProvider);

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('👋', style: TextStyle(fontSize: 64))
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      )
                      .rotate(begin: -0.1, end: 0.05),
                  const SizedBox(height: 24),
                  const Text(
                    'What should we\ncall you?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 8),
                  const Text(
                    'Optional avatar, then you are in.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: _selectedAvatar == null
                          ? null
                          : FileImage(File(_selectedAvatar!.path)),
                      child: _selectedAvatar == null
                          ? const Icon(
                              Icons.add_a_photo_rounded,
                              color: AppColors.textSecondary,
                            )
                          : null,
                    ),
                  ).animate().fadeIn(delay: 340.ms),
                  const SizedBox(height: 32),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Preferred currency',
                      prefixIcon: Icon(Icons.currency_exchange_rounded),
                    ),
                    items: CurrencyUtils.supportedCurrencies
                        .map(
                          (currency) => DropdownMenuItem(
                            value: currency,
                            child: Text(CurrencyUtils.currencyLabel(currency)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _currency = value);
                      }
                    },
                  ).animate().fadeIn(delay: 370.ms),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'Your name',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 34),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _completeSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Let's Go!",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isLoading ? null : _completeSetup,
                    child: const Text('Skip avatar and continue'),
                  ).animate().fadeIn(delay: 550.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
