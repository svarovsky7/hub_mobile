import 'package:flutter/material.dart';

class MarkFixedDialog extends StatefulWidget {
  const MarkFixedDialog({
    super.key,
    required this.brigades,
    required this.contractors,
    required this.onMarkFixed,
  });

  final List<Map<String, dynamic>> brigades;
  final List<Map<String, dynamic>> contractors;
  final Function({
    required int executorId,
    required bool isOwnExecutor,
    required DateTime fixDate,
  }) onMarkFixed;

  @override
  State<MarkFixedDialog> createState() => _MarkFixedDialogState();
}

class _MarkFixedDialogState extends State<MarkFixedDialog> {
  bool _isOwnExecutor = true;
  int? _selectedExecutorId;
  DateTime _fixDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final executors = _isOwnExecutor ? widget.brigades : widget.contractors;
    
    return AlertDialog(
      title: const Text('Отправить дефект на проверку'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Дата устранения'),
            subtitle: Text('${_fixDate.day}.${_fixDate.month}.${_fixDate.year}'),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _fixDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _fixDate = date;
                });
              }
            },
          ),
          
          const SizedBox(height: 16),
          
          // Executor type toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Своя бригада'),
                icon: Icon(Icons.groups),
              ),
              ButtonSegment(
                value: false,
                label: Text('Подрядчик'),
                icon: Icon(Icons.business),
              ),
            ],
            selected: {_isOwnExecutor},
            onSelectionChanged: (Set<bool> selection) {
              setState(() {
                _isOwnExecutor = selection.first;
                _selectedExecutorId = null; // Reset selection
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Executor dropdown
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: _isOwnExecutor ? 'Бригада' : 'Подрядчик',
              border: const OutlineInputBorder(),
            ),
            value: _selectedExecutorId,
            items: executors.map((executor) => DropdownMenuItem<int>(
              value: executor['id'] as int,
              child: Text(executor['name'] as String),
            )).toList(),
            onChanged: (value) {
              setState(() {
                _selectedExecutorId = value;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Выберите ${_isOwnExecutor ? 'бригаду' : 'подрядчика'}';
              }
              return null;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _selectedExecutorId != null
              ? () {
                  widget.onMarkFixed(
                    executorId: _selectedExecutorId!,
                    isOwnExecutor: _isOwnExecutor,
                    fixDate: _fixDate,
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Отправить на проверку'),
        ),
      ],
    );
  }
}