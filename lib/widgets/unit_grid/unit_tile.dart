import 'package:flutter/material.dart';
import '../../models/unit.dart';

class UnitTile extends StatelessWidget {
  const UnitTile({
    super.key,
    required this.unit,
    required this.onTap,
    this.width = 60,
    this.height = 48,
    this.statusColors = const {},
  });

  final Unit unit;
  final VoidCallback onTap;
  final double width;
  final double height;
  final Map<int, String> statusColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = unit.getStatus();
    final unitColor = _getUnitColor(status, theme);
    final borderColor = _getUnitBorderColor(status, theme);
    final textColor = _getUnitTextColor(status, theme);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: unitColor,
          border: Border.all(
            color: unit.locked ? theme.colorScheme.error : borderColor,
            width: status == UnitStatus.noDefects ? 1 : 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Unit name
            Center(
              child: Text(
                unit.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            
            // Lock icon for locked units
            if (unit.locked)
              Positioned(
                top: -6,
                left: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            
            // Defect count badge
            if (unit.defects.isNotEmpty)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${unit.defects.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getUnitColor(UnitStatus status, ThemeData theme) {
    if (status == UnitStatus.noDefects) {
      return theme.colorScheme.surfaceVariant;
    }
    
    // Для ячеек с дефектами используем светлый фон для читаемости номера
    return theme.colorScheme.surface;
  }
  
  int? _getStatusId(UnitStatus status) {
    switch (status) {
      case UnitStatus.hasNew:
        return 1;
      case UnitStatus.inProgress:
        return 2;
      case UnitStatus.completed:
        return 3;
      case UnitStatus.rejected:
        return 4;
      case UnitStatus.onReview:
        return 9;
      default:
        return null;
    }
  }

  Color _getUnitBorderColor(UnitStatus status, ThemeData theme) {
    if (status == UnitStatus.noDefects) {
      return theme.colorScheme.outline;
    }
    
    // Получаем цвет статуса дефекта для границы
    final statusId = _getStatusId(status);
    if (statusId != null && statusColors.containsKey(statusId)) {
      final colorHex = statusColors[statusId]!;
      return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
    }
    
    // Fallback цвета для границы если нет в базе
    switch (status) {
      case UnitStatus.hasNew:
        return const Color(0xFFEF4444);
      case UnitStatus.inProgress:
        return const Color(0xFFF59E0B);
      case UnitStatus.completed:
        return const Color(0xFF10B981);
      case UnitStatus.rejected:
        return const Color(0xFF6B7280);
      case UnitStatus.onReview:
        return const Color(0xFF3B82F6);
      default:
        return theme.colorScheme.outline;
    }
  }

  Color _getUnitTextColor(UnitStatus status, ThemeData theme) {
    if (status == UnitStatus.noDefects) {
      return theme.colorScheme.onSurfaceVariant;
    }
    
    // Темный текст на светлом фоне для лучшей читаемости
    return theme.colorScheme.onSurface;
  }
}