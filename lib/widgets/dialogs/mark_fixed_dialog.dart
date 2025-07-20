import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../services/offline_service.dart';
import '../../services/database_service.dart';

class MarkFixedDialog extends StatefulWidget {
  const MarkFixedDialog({
    super.key,
    required this.brigades,
    required this.contractors,
    required this.engineers,
    required this.onMarkFixed,
  });

  final List<Map<String, dynamic>> brigades;
  final List<Map<String, dynamic>> contractors;
  final List<Map<String, dynamic>> engineers;
  final Function({
    required int executorId,
    required bool isOwnExecutor,
    required DateTime fixDate,
    required String engineerId,
  }) onMarkFixed;

  @override
  State<MarkFixedDialog> createState() => _MarkFixedDialogState();
}

class _MarkFixedDialogState extends State<MarkFixedDialog> {
  bool _isOwnExecutor = true;
  int? _selectedExecutorId;
  String? _selectedEngineerId;
  DateTime _fixDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setCurrentUserAsEngineer();
  }

  Future<void> _setCurrentUserAsEngineer() async {
    final userId = await DatabaseService.getCurrentUserId();
    if (userId != null && mounted) {
      // Проверяем, есть ли текущий пользователь в списке инженеров
      final hasCurrentUser = widget.engineers.any((engineer) => engineer['id'] == userId);
      if (hasCurrentUser) {
        setState(() {
          _selectedEngineerId = userId;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final executors = _isOwnExecutor ? widget.brigades : widget.contractors;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Отправить на проверку')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date picker - compact design
            InkWell(
              onTap: () => _selectDate(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Дата устранения',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${_fixDate.day}.${_fixDate.month.toString().padLeft(2, '0')}.${_fixDate.year}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Executor type toggle - compact
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectExecutorType(true),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _isOwnExecutor ? theme.colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.groups,
                              size: 18,
                              color: _isOwnExecutor 
                                ? theme.colorScheme.onPrimaryContainer 
                                : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Своя бригада',
                              style: TextStyle(
                                color: _isOwnExecutor 
                                  ? theme.colorScheme.onPrimaryContainer 
                                  : theme.colorScheme.onSurfaceVariant,
                                fontWeight: _isOwnExecutor ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectExecutorType(false),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: !_isOwnExecutor ? theme.colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business,
                              size: 18,
                              color: !_isOwnExecutor 
                                ? theme.colorScheme.onPrimaryContainer 
                                : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Подрядчик',
                              style: TextStyle(
                                color: !_isOwnExecutor 
                                  ? theme.colorScheme.onPrimaryContainer 
                                  : theme.colorScheme.onSurfaceVariant,
                                fontWeight: !_isOwnExecutor ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Executor dropdown - compact
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: _isOwnExecutor ? 'Бригада' : 'Подрядчик',
                prefixIcon: Icon(_isOwnExecutor ? Icons.groups : Icons.business),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              value: _selectedExecutorId,
              items: executors.map((executor) => DropdownMenuItem<int>(
                value: executor['id'] as int,
                child: Text(
                  executor['name'] as String,
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: (value) => setState(() => _selectedExecutorId = value),
              isExpanded: true,
              hint: Text('Выберите ${_isOwnExecutor ? 'бригаду' : 'подрядчика'}'),
            ),
            
            const SizedBox(height: 16),
            
            // Engineer dropdown - compact
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Инженер',
                prefixIcon: Icon(Icons.engineering),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              value: _selectedEngineerId,
              items: widget.engineers.map((engineer) => DropdownMenuItem<String>(
                value: engineer['id'] as String,
                child: Text(
                  engineer['name'] as String,
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: (value) => setState(() => _selectedEngineerId = value),
              isExpanded: true,
              hint: const Text('Выберите инженера'),
            ),
            
            if (!OfflineService.isOnline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Данные будут отправлены при подключении к интернету',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submitForm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: const Text('Отправить'),
        ),
      ],
    );
  }

  bool get _canSubmit => 
    _selectedExecutorId != null && _selectedEngineerId != null;

  void _selectExecutorType(bool isOwnExecutor) {
    setState(() {
      _isOwnExecutor = isOwnExecutor;
      _selectedExecutorId = null; // Reset selection when switching types
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fixDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Выберите дату устранения',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _fixDate = date);
    }
  }

  void _submitForm() {
    if (!_canSubmit) return;
    
    widget.onMarkFixed(
      executorId: _selectedExecutorId!,
      isOwnExecutor: _isOwnExecutor,
      fixDate: _fixDate,
      engineerId: _selectedEngineerId!,
    );
    Navigator.of(context).pop();
  }
}