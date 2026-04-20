import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../services/app_settings_service.dart';
import '../controllers/settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _controller = SettingsController();
  final _stockAlertController = TextEditingController();
  final _expiryAlertController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _syncTextFields();
  }

  @override
  void dispose() {
    _stockAlertController.dispose();
    _expiryAlertController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncTextFields() {
    _stockAlertController.text = _controller.settings.stockAlertThreshold.toString();
    _expiryAlertController.text = _controller.settings.expiryAlertDays.toString();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await _controller.saveAlertSettings(
      stockAlertThreshold: int.tryParse(_stockAlertController.text.trim()) ?? 0,
      expiryAlertDays: int.tryParse(_expiryAlertController.text.trim()) ?? 0,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );
      _syncTextFields();
    } else if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
      _controller.clearError();
    }
  }

  Future<void> _applyRecommendedSettings() async {
    final success = await _controller.applyRecommendedSettings();
    if (!mounted) {
      return;
    }

    if (success) {
      _syncTextFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recommended settings applied.')),
      );
    } else if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
      _controller.clearError();
    }
  }

  Future<void> _sendPasswordReset() async {
    final success = await _controller.sendPasswordResetEmail();
    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset email sent to ${_controller.currentUserEmail}.',
          ),
        ),
      );
    } else if (_controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
      _controller.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return ListView(
            padding: AppSpacing.pagePadding,
            children: [
              const SectionHeader(
                title: 'Settings',
                subtitle: 'Control stock alerts, expiry alerts, and account security from one place.',
              ),
              AppSpacing.heightMd,
              AppCard(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How Alert Logic Works',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    AppSpacing.heightMd,
                    const Text('Out of Stock: quantity is exactly 0.'),
                    AppSpacing.heightXs,
                    Text(
                      'Stock Alert: quantity is between 1 and ${_controller.settings.stockAlertThreshold}.',
                    ),
                    AppSpacing.heightXs,
                    const Text('Expired: expiry date is before today.'),
                    AppSpacing.heightXs,
                    Text(
                      'Expiry Alert: medication expires within ${_controller.settings.expiryAlertDays} days.',
                    ),
                  ],
                ),
              ),
              AppSpacing.heightLg,
              Form(
                key: _formKey,
                child: AppCard(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Alert Rules',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      AppSpacing.heightMd,
                      AppTextField(
                        controller: _stockAlertController,
                        label: 'Stock Alert Threshold',
                        hintText: 'e.g. 100',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.heightSm,
                      AppTextField(
                        controller: _expiryAlertController,
                        label: 'Expiry Alert Days',
                        hintText: 'e.g. 180',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse(value ?? '');
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      AppSpacing.heightMd,
                      AppButton(
                        text: 'Save Alert Rules',
                        onPressed: _saveSettings,
                        isLoading: _controller.isSaving,
                      ),
                      AppSpacing.heightSm,
                      AppButton(
                        text: 'Use Recommended',
                        onPressed: _applyRecommendedSettings,
                        isOutlined: true,
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.heightLg,
              AppCard(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended Setup',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    AppSpacing.heightMd,
                    const Text(
                      'Stock Alert Threshold: ${AppSettingsService.recommendedStockAlertThreshold}',
                    ),
                    AppSpacing.heightXs,
                    const Text(
                      'Expiry Alert Days: ${AppSettingsService.recommendedExpiryAlertDays}',
                    ),
                    AppSpacing.heightXs,
                    const Text(
                      'This setup works well for pharmacies that want early reorder and early expiry visibility.',
                    ),
                  ],
                ),
              ),
              AppSpacing.heightLg,
              AppCard(
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    AppSpacing.heightMd,
                    Text(
                      _controller.currentUserEmail.isEmpty
                          ? 'No signed-in email found.'
                          : 'Password reset email will be sent to ${_controller.currentUserEmail}.',
                    ),
                    AppSpacing.heightMd,
                    AppButton(
                      text: 'Send Password Reset Email',
                      onPressed: _sendPasswordReset,
                      isOutlined: true,
                      isLoading: _controller.isSendingPasswordReset,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
