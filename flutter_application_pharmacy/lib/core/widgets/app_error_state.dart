import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'An unexpected error occurred while loading data.',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
            AppSpacing.heightMd,
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.heightXs,
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            AppSpacing.heightLg,
            AppButton(
              text: 'Retry',
              width: 120,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
