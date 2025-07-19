import 'package:flutter/material.dart';
import 'offline_service.dart';

class SyncNotificationService {
  static OverlayEntry? _currentOverlay;
  static bool _isShowingNotification = false;

  // Показать уведомление о синхронизации
  static void showSyncNotification(BuildContext context) {
    if (_isShowingNotification) return;
    
    _isShowingNotification = true;
    
    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => _SyncNotificationWidget(
        onSync: () async {
          await _performSync(context);
        },
        onDismiss: () {
          _dismissNotification();
        },
      ),
    );
    
    overlay.insert(_currentOverlay!);
  }

  // Выполнить синхронизацию
  static Future<void> _performSync(BuildContext context) async {
    try {
      // Показываем индикатор загрузки
      _updateNotificationState(context, SyncState.syncing);
      
      final success = await OfflineService.performSync();
      
      if (success) {
        _updateNotificationState(context, SyncState.success);
        // Автоматически скрываем через 2 секунды
        Future.delayed(const Duration(seconds: 2), () {
          _dismissNotification();
        });
      } else {
        _updateNotificationState(context, SyncState.error);
      }
    } catch (e) {
      _updateNotificationState(context, SyncState.error);
    }
  }

  // Обновить состояние уведомления
  static void _updateNotificationState(BuildContext context, SyncState state) {
    _dismissNotification();
    
    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => _SyncNotificationWidget(
        state: state,
        onSync: () async {
          await _performSync(context);
        },
        onDismiss: () {
          _dismissNotification();
        },
      ),
    );
    
    overlay.insert(_currentOverlay!);
  }

  // Скрыть уведомление
  static void _dismissNotification() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _isShowingNotification = false;
  }

  // Проверить и показать уведомление если нужно
  static void checkAndShowSyncNotification(BuildContext context) {
    if (OfflineService.isOnline && OfflineService.hasPendingSync && !_isShowingNotification) {
      showSyncNotification(context);
    }
  }
}

enum SyncState {
  pending,
  syncing,
  success,
  error,
}

class _SyncNotificationWidget extends StatelessWidget {
  final SyncState state;
  final VoidCallback onSync;
  final VoidCallback onDismiss;

  const _SyncNotificationWidget({
    this.state = SyncState.pending,
    required this.onSync,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getBackgroundColor(theme),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildIcon(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getTitle(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _getTextColor(theme),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_getSubtitle() != null)
                      Text(
                        _getSubtitle()!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getTextColor(theme).withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildAction(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    switch (state) {
      case SyncState.pending:
        return Icon(
          Icons.cloud_upload_outlined,
          color: theme.colorScheme.primary,
          size: 24,
        );
      case SyncState.syncing:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        );
      case SyncState.success:
        return Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 24,
        );
      case SyncState.error:
        return Icon(
          Icons.error,
          color: Colors.red,
          size: 24,
        );
    }
  }

  Widget _buildAction(ThemeData theme) {
    switch (state) {
      case SyncState.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onSync,
              child: Text(
                'Синхронизировать',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                color: _getTextColor(theme).withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ],
        );
      case SyncState.syncing:
        return const SizedBox.shrink();
      case SyncState.success:
        return Icon(
          Icons.done,
          color: Colors.green,
          size: 20,
        );
      case SyncState.error:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onSync,
              child: const Text(
                'Повторить',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                color: _getTextColor(theme).withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ],
        );
    }
  }

  Color _getBackgroundColor(ThemeData theme) {
    switch (state) {
      case SyncState.pending:
        return theme.colorScheme.primaryContainer;
      case SyncState.syncing:
        return theme.colorScheme.primaryContainer;
      case SyncState.success:
        return Colors.green.shade50;
      case SyncState.error:
        return Colors.red.shade50;
    }
  }

  Color _getTextColor(ThemeData theme) {
    switch (state) {
      case SyncState.pending:
      case SyncState.syncing:
        return theme.colorScheme.onPrimaryContainer;
      case SyncState.success:
        return Colors.green.shade800;
      case SyncState.error:
        return Colors.red.shade800;
    }
  }

  String _getTitle() {
    switch (state) {
      case SyncState.pending:
        return 'Есть данные для синхронизации';
      case SyncState.syncing:
        return 'Синхронизация...';
      case SyncState.success:
        return 'Синхронизация завершена';
      case SyncState.error:
        return 'Ошибка синхронизации';
    }
  }

  String? _getSubtitle() {
    switch (state) {
      case SyncState.pending:
        return 'Подключение к интернету восстановлено';
      case SyncState.syncing:
        return 'Отправка изменений на сервер';
      case SyncState.success:
        return 'Все изменения сохранены';
      case SyncState.error:
        return 'Проверьте подключение к интернету';
    }
  }
}