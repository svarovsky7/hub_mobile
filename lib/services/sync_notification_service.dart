import 'package:flutter/material.dart';
import 'offline_service.dart';

class SyncNotificationService {
  static OverlayEntry? _currentOverlay;
  static bool _isShowingNotification = false;
  static bool _isSyncing = false;

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
    
    // Автоматически начинаем синхронизацию
    Future.delayed(const Duration(milliseconds: 500), () {
      _performSync(context);
    });
  }

  // Выполнить синхронизацию
  static Future<void> _performSync(BuildContext context) async {
    if (_isSyncing) return; // Предотвращаем повторную синхронизацию
    
    _isSyncing = true;
    
    try {
      // Показываем индикатор загрузки
      _updateNotificationState(context, SyncState.syncing);
      
      final success = await OfflineService.performSync(
        onProgress: (progress, operation) {
          _updateNotificationState(
            context, 
            SyncState.syncing, 
            progress: progress,
            currentOperation: operation,
          );
        },
      );
      
      if (success) {
        _updateNotificationState(context, SyncState.success);
        // Автоматически скрываем через 2 секунды
        Future.delayed(const Duration(seconds: 2), () {
          _dismissNotification();
          _isSyncing = false;
        });
      } else {
        _updateNotificationState(context, SyncState.error);
        _isSyncing = false;
      }
    } catch (e) {
      _updateNotificationState(context, SyncState.error);
      _isSyncing = false;
    }
  }

  // Обновить состояние уведомления
  static void _updateNotificationState(
    BuildContext context, 
    SyncState state, {
    double progress = 0.0,
    String? currentOperation,
  }) {
    _dismissNotification();
    
    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => _SyncNotificationWidget(
        state: state,
        progress: progress,
        currentOperation: currentOperation,
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
    if (OfflineService.isOnline && OfflineService.hasPendingSync && !_isShowingNotification && !_isSyncing) {
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

class _SyncNotificationWidget extends StatefulWidget {
  final SyncState state;
  final VoidCallback onSync;
  final VoidCallback onDismiss;
  final double progress;
  final String? currentOperation;

  const _SyncNotificationWidget({
    this.state = SyncState.pending,
    required this.onSync,
    required this.onDismiss,
    this.progress = 0.0,
    this.currentOperation,
  });

  @override
  State<_SyncNotificationWidget> createState() => _SyncNotificationWidgetState();
}

class _SyncNotificationWidgetState extends State<_SyncNotificationWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: _fadeAnimation.value * 0.5),
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildIcon(theme),
                      const SizedBox(height: 16),
                      Text(
                        _getTitle(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (_getSubtitle() != null)
                        Text(
                          _getSubtitle()!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (widget.state == SyncState.syncing) ...[
                        const SizedBox(height: 24),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: widget.progress,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(widget.progress * 100).toInt()}%',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        if (widget.currentOperation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.currentOperation!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      _buildAction(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(ThemeData theme) {
    switch (widget.state) {
      case SyncState.pending:
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_upload_outlined,
            color: theme.colorScheme.primary,
            size: 32,
          ),
        );
      case SyncState.syncing:
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        );
      case SyncState.success:
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 40,
          ),
        );
      case SyncState.error:
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error,
            color: Colors.red,
            size: 40,
          ),
        );
    }
  }

  Widget _buildAction(ThemeData theme) {
    switch (widget.state) {
      case SyncState.pending:
        return IconButton(
          onPressed: widget.onDismiss,
          icon: Icon(
            Icons.close,
            color: _getTextColor(theme).withValues(alpha: 0.6),
            size: 20,
          ),
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
              onPressed: widget.onSync,
              child: const Text(
                'Повторить',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: widget.onDismiss,
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
    switch (widget.state) {
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
    switch (widget.state) {
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
    switch (widget.state) {
      case SyncState.pending:
        return 'Подключение к интернету восстановлено';
      case SyncState.syncing:
        return 'Синхронизация...';
      case SyncState.success:
        return 'Синхронизация завершена';
      case SyncState.error:
        return 'Ошибка синхронизации';
    }
  }

  String? _getSubtitle() {
    switch (widget.state) {
      case SyncState.pending:
        return 'Начинается синхронизация изменений';
      case SyncState.syncing:
        return 'Отправка изменений на сервер';
      case SyncState.success:
        return 'Все изменения сохранены';
      case SyncState.error:
        return 'Проверьте подключение к интернету';
    }
  }
}