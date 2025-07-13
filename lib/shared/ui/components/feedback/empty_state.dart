import 'package:flutter/material.dart';
import '../buttons/app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.emoji,
    this.actionText,
    this.onAction,
    this.illustration,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? emoji;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon/Emoji/Illustration
            if (illustration != null)
              illustration!
            else if (emoji != null)
              Text(
                emoji!,
                style: const TextStyle(fontSize: 64),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 64,
                color: theme.colorScheme.outline,
              ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            // Action button
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(
                text: actionText!,
                onPressed: onAction,
                variant: AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}