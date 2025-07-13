import 'package:flutter/material.dart';
import '../../models/unit.dart';

class UnitTile extends StatelessWidget {
  const UnitTile({
    super.key,
    required this.unit,
    required this.onTap,
    this.width = 60,
    this.height = 48,
  });

  final Unit unit;
  final VoidCallback onTap;
  final double width;
  final double height;

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
            width: 2,
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
    switch (status) {
      case UnitStatus.noDefects:
        return theme.colorScheme.surfaceVariant;
      case UnitStatus.hasNew:
        return theme.colorScheme.errorContainer;
      case UnitStatus.inProgress:
        return Colors.amber.shade100;
      case UnitStatus.completed:
        return theme.colorScheme.primaryContainer;
      default:
        return theme.colorScheme.surface;
    }
  }

  Color _getUnitBorderColor(UnitStatus status, ThemeData theme) {
    switch (status) {
      case UnitStatus.noDefects:
        return theme.colorScheme.outline;
      case UnitStatus.hasNew:
        return theme.colorScheme.error;
      case UnitStatus.inProgress:
        return Colors.amber.shade400;
      case UnitStatus.completed:
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.outline;
    }
  }

  Color _getUnitTextColor(UnitStatus status, ThemeData theme) {
    switch (status) {
      case UnitStatus.noDefects:
        return theme.colorScheme.onSurfaceVariant;
      case UnitStatus.hasNew:
        return theme.colorScheme.onErrorContainer;
      case UnitStatus.inProgress:
        return Colors.amber.shade800;
      case UnitStatus.completed:
        return theme.colorScheme.onPrimaryContainer;
      default:
        return theme.colorScheme.onSurface;
    }
  }
}