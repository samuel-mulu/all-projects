import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedForegroundColor = foregroundColor ??
        (isOutlined
            ? Theme.of(context).colorScheme.primary
            : Colors.white);

    final style = isOutlined
        ? OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: resolvedForegroundColor,
          )
        : ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: resolvedForegroundColor,
          );

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(resolvedForegroundColor),
            ),
          )
        : Text(text);

    return SizedBox(
      width: width ?? double.infinity,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: style,
              child: child,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: style,
              child: child,
            ),
    );
  }
}
