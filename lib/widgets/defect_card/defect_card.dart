import 'package:flutter/material.dart';
import '../../models/defect.dart';
import '../../models/project.dart';
import '../../shared/ui/components/cards/elevated_card.dart';
import '../status_chip/status_chip.dart';

class DefectCard extends StatelessWidget {
  const DefectCard({
    super.key,
    required this.defect,
    required this.defectType,
    required this.defectStatus,
    this.onStatusTap,
    this.showActions = true,
    this.onAttachFiles,
    this.onMarkFixed,
  });

  final Defect defect;
  final DefectType defectType;
  final DefectStatus defectStatus;
  final VoidCallback? onStatusTap;
  final bool showActions;
  final VoidCallback? onAttachFiles;
  final VoidCallback? onMarkFixed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ElevatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type and warranty
                    Row(
                      children: [
                        Text(
                          defectType.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (defect.isWarranty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Гарантия',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Status chip
                    StatusChip(
                      label: defectStatus.name,
                      color: Color(
                        int.parse(defectStatus.color.substring(1), radix: 16) + 
                        0xFF000000,
                      ),
                      isClickable: onStatusTap != null,
                      onTap: onStatusTap,
                      icon: onStatusTap != null ? Icons.edit : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Description
          Text(
            defect.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Date
          Text(
            defect.receivedAt != null
                ? 'Получен: ${_formatDate(defect.receivedAt!)}'
                : 'Дата получения не указана',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          
          // Actions
          if (showActions && _shouldShowActions()) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onAttachFiles != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAttachFiles,
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Прикрепить файлы'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                
                if (onAttachFiles != null && onMarkFixed != null)
                  const SizedBox(width: 12),
                
                if (onMarkFixed != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onMarkFixed,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Отправить на проверку'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.tertiary,
                        foregroundColor: theme.colorScheme.onTertiary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowActions() {
    // Don't show actions for completed or rejected defects
    return defect.statusId != 3 && defect.statusId != 4 && defect.statusId != 9;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}