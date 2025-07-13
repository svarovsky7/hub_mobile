import 'package:flutter/material.dart';
import '../../models/project.dart';

class StatusChangeDialog extends StatefulWidget {
  const StatusChangeDialog({
    super.key,
    required this.currentStatus,
    required this.availableStatuses,
    required this.onStatusSelected,
  });

  final DefectStatus currentStatus;
  final List<DefectStatus> availableStatuses;
  final Function(DefectStatus) onStatusSelected;

  @override
  State<StatusChangeDialog> createState() => _StatusChangeDialogState();
}

class _StatusChangeDialogState extends State<StatusChangeDialog> {
  DefectStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Изменить статус дефекта'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Текущий статус: ${widget.currentStatus.name}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Выберите новый статус:'),
          const SizedBox(height: 12),
          ...widget.availableStatuses.map((status) => RadioListTile<DefectStatus>(
            title: Text(status.name),
            subtitle: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Color(
                  int.parse(status.color.substring(1), radix: 16) + 0xFF000000,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            value: status,
            groupValue: _selectedStatus,
            onChanged: (value) {
              setState(() {
                _selectedStatus = value;
              });
            },
          )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _selectedStatus != null && _selectedStatus != widget.currentStatus
              ? () {
                  widget.onStatusSelected(_selectedStatus!);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Применить'),
        ),
      ],
    );
  }
}