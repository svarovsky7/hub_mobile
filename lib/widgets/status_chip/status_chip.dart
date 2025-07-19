import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.isClickable = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final Color? textColor;
  final bool isClickable;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? 
        (ThemeData.estimateBrightnessForColor(color) == Brightness.dark 
            ? Colors.white 
            : Colors.black87);

    Widget chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: effectiveTextColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: effectiveTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isClickable) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 12,
              color: effectiveTextColor,
            ),
          ],
        ],
      ),
    );

    if (isClickable && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: chipContent,
      );
    }

    return chipContent;
  }
}