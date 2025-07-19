import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/defect.dart';
import '../../models/defect_attachment.dart';
import '../../models/project.dart';
import '../../shared/ui/components/cards/elevated_card.dart';
import '../../services/database_service.dart';
import '../../services/offline_service.dart';
import '../status_chip/status_chip.dart';
import '../file_attachment_widget.dart';

class DefectCard extends StatefulWidget {
  const DefectCard({
    super.key,
    required this.defect,
    required this.defectType,
    required this.defectStatus,
    this.onStatusTap,
    this.showActions = true,
    this.onAttachFiles,
    this.onMarkFixed,
    this.onDefectUpdated,
  });

  final Defect defect;
  final DefectType defectType;
  final DefectStatus defectStatus;
  final VoidCallback? onStatusTap;
  final bool showActions;
  final VoidCallback? onAttachFiles;
  final VoidCallback? onMarkFixed;
  final Function(Defect)? onDefectUpdated;

  @override
  State<DefectCard> createState() => _DefectCardState();
}

class _DefectCardState extends State<DefectCard> {
  bool _isExpanded = false;
  bool _isUpdatingWarranty = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ElevatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with type and status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Defect type
                    Text(
                      'Тип дефекта',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.defectType.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Статус',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: widget.onStatusTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(widget.defectStatus.color.substring(1), radix: 16) + 
                          0xFF000000,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(
                            int.parse(widget.defectStatus.color.substring(1), radix: 16) + 
                            0xFF000000,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getShortStatusName(widget.defectStatus.name),
                            style: TextStyle(
                              color: Color(
                                int.parse(widget.defectStatus.color.substring(1), radix: 16) + 
                                0xFF000000,
                              ),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          if (widget.onStatusTap != null) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: Color(
                                int.parse(widget.defectStatus.color.substring(1), radix: 16) + 
                                0xFF000000,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Warranty switch
          Row(
            children: [
              Expanded(
                child: Text(
                  'Гарантийный случай',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: widget.defect.isWarranty,
                  onChanged: _isUpdatingWarranty ? null : (value) => _toggleWarranty(),
                  activeColor: theme.colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Description
          Text(
            widget.defect.description,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Expandable details section
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Детали',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!_isExpanded)
                        Text(
                          'Показать все',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            
            // Hidden details
            _buildDetailRow('Закрепленный инженер:', 'Не назначен', theme),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Получен:', 
              widget.defect.receivedAt != null
                  ? _formatDate(widget.defect.receivedAt!)
                  : 'Не указано',
              theme,
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Крайняя дата устранения:', 'Не указано', theme),
            const SizedBox(height: 12),
            
            // File attachment widget
            FileAttachmentWidget(
              defect: widget.defect,
              onAttachmentsChanged: (attachments) {
                // Update the defect with new attachments
                final updatedDefect = widget.defect.copyWith(attachments: attachments);
                widget.onDefectUpdated?.call(updatedDefect);
              },
            ),
          ],
          
          // Actions
          if (widget.showActions && _shouldShowActions()) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.onAttachFiles != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onAttachFiles,
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text(
                        'Файлы',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
                
                if (widget.onAttachFiles != null && widget.onMarkFixed != null)
                  const SizedBox(width: 8),
                
                if (widget.onMarkFixed != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onMarkFixed,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text(
                        'На проверку',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.tertiary,
                        foregroundColor: theme.colorScheme.onTertiary,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        minimumSize: const Size(0, 32),
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
    return widget.defect.statusId != 3 && widget.defect.statusId != 4 && widget.defect.statusId != 9;
  }

  String _getShortStatusName(String fullName) {
    // Сокращаем длинные названия статусов
    final shortcuts = {
      'Новый': 'Новый',
      'В работе': 'В работе',
      'Устранено': 'Устранено',
      'Закрыто': 'Закрыто',
      'На проверке': 'Проверка',
      'Отклонено': 'Отклонено',
      'Ожидает проверки': 'Ожидает',
      'Требует уточнения': 'Уточнить',
      'В ожидании': 'Ожидание',
    };
    
    return shortcuts[fullName] ?? fullName;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _toggleWarranty() async {
    if (_isUpdatingWarranty) return;
    
    print('Toggle warranty called for defect ${widget.defect.id}. Current warranty: ${widget.defect.isWarranty}');

    setState(() {
      _isUpdatingWarranty = true;
    });

    try {
      final updatedDefect = await DatabaseService.updateDefectWarranty(
        defectId: widget.defect.id,
        isWarranty: !widget.defect.isWarranty,
      );

      print('Update warranty result: ${updatedDefect?.isWarranty}');

      if (updatedDefect != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                updatedDefect.isWarranty 
                  ? 'Дефект помечен как гарантийный' 
                  : 'Дефект помечен как не гарантийный'
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Уведомляем родительский виджет об обновлении
          widget.onDefectUpdated?.call(updatedDefect);
        }
      } else {
        // Проверяем офлайн-режим
        final isOffline = await _checkOfflineMode();
        
        print('Failed to update warranty status');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isOffline 
                  ? 'Изменение сохранено офлайн. Синхронизируется при подключении к интернету.'
                  : 'Не удалось обновить статус гарантии'
              ),
              duration: Duration(seconds: isOffline ? 3 : 2),
              action: isOffline ? null : SnackBarAction(
                label: 'Повторить',
                onPressed: () => _toggleWarranty(),
              ),
            ),
          );
          
          // В офлайн-режиме создаем локально обновленный дефект
          if (isOffline) {
            final localUpdatedDefect = widget.defect.copyWith(
              isWarranty: !widget.defect.isWarranty,
            );
            widget.onDefectUpdated?.call(localUpdatedDefect);
          }
        }
      }
    } catch (e) {
      print('Error updating warranty: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при обновлении статуса гарантии'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingWarranty = false;
        });
      }
    }
  }

  Future<bool> _checkOfflineMode() async {
    return !OfflineService.isOnline;
  }
}