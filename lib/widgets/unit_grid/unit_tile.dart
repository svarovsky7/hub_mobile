import 'package:flutter/material.dart';
import '../../models/unit.dart';

class UnitTile extends StatelessWidget {
  const UnitTile({
    super.key,
    required this.unit,
    required this.onTap,
    this.width = 68,
    this.height = 52,
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
            width: status == UnitStatus.noDefects ? 1.5 : 3.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Unit name
            Center(
              child: Text(
                unit.name,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
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
                        color: Colors.black.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock, color: Colors.white, size: 14),
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
                  decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '${unit.defects.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
      return Colors.transparent; // Прозрачный фон для квартир без дефектов
    }

    // Для квартир с дефектами - цветная заливка в цвет статуса
    final statusId = _getStatusId(status);
    
    if (statusId != null && statusColors.containsKey(statusId)) {
      final colorHex = statusColors[statusId]!;
      final baseColor = Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
      return baseColor.withValues(alpha: 0.3); // Полупрозрачная заливка
    }

    // Fallback цвета для квартир с дефектами
    return _getFallbackColor(status).withValues(alpha: 0.3);
  }

  int? _getStatusId(UnitStatus status) {
    // Для всех статусов используем прямой поиск статуса из дефектов
    if (unit.defects.isNotEmpty) {
      // Берем приоритетный статус из дефектов
      final statusIds = unit.defects.where((d) => d.statusId != null).map((d) => d.statusId!).toList();
      if (statusIds.isNotEmpty) {
        final priorityOrder = [1, 2, 9, 4, 7, 8, 10, 3]; // Приоритет как в Unit.getStatus()
        for (final priority in priorityOrder) {
          if (statusIds.contains(priority)) {
            return priority;
          }
        }
        return statusIds.first;
      }
    }
    return null;
  }

  Color _getUnitBorderColor(UnitStatus status, ThemeData theme) {
    if (status == UnitStatus.noDefects) {
      return theme.colorScheme.outline.withValues(alpha: 0.6);
    }

    // Получаем цвет статуса дефекта для границы
    final statusId = _getStatusId(status);
    if (statusId != null && statusColors.containsKey(statusId)) {
      final colorHex = statusColors[statusId]!;
      return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
    }

    return _getFallbackColor(status);
  }

  Color _getUnitTextColor(UnitStatus status, ThemeData theme) {
    if (status == UnitStatus.noDefects) {
      return theme.colorScheme.onSurface; // Контрастный текст для квартир без дефектов
    }

    // Для квартир с дефектами используем темный текст для читаемости на цветном фоне
    return theme.colorScheme.onSurface;
  }

  Color _getFallbackColor(UnitStatus status) {
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
        return const Color(0xFF6B7280);
    }
  }
}
