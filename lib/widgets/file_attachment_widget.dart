import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import '../models/defect.dart';
import '../models/defect_attachment.dart';
import '../services/file_attachment_service.dart';
import '../services/offline_service.dart';
import '../services/database_service.dart';

class FileAttachmentWidget extends StatefulWidget {
  final Defect defect;
  final Function(List<DefectAttachment>)? onAttachmentsChanged;

  const FileAttachmentWidget({
    super.key,
    required this.defect,
    this.onAttachmentsChanged,
  });

  @override
  State<FileAttachmentWidget> createState() => _FileAttachmentWidgetState();

  static Future<void> openAttachmentWithSystem(BuildContext context, DefectAttachment attachment) async {
    try {
      final isLocal = attachment.filePath.startsWith('/') && !attachment.filePath.startsWith('http');
      
      if (isLocal) {
        // Открываем локальный файл
        final result = await OpenFile.open(attachment.filePath);
        if (result.type != ResultType.done) {
          _showOpenFileErrorStatic(context, result);
        }
      } else {
        // Скачиваем и открываем удаленный файл
        await _downloadAndOpenFileStatic(context, attachment);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка открытия файла: $e')),
        );
      }
    }
  }

  static Future<void> _downloadAndOpenFileStatic(BuildContext context, DefectAttachment attachment) async {
    if (!context.mounted) return;
    
    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final url = DatabaseService.getAttachmentUrl(attachment.filePath);
      if (url == null) {
        throw Exception('URL файла не найден');
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${attachment.fileName}');
        await file.writeAsBytes(response.bodyBytes);

        if (context.mounted) {
          Navigator.of(context).pop(); // Закрываем индикатор загрузки
        }

        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _showOpenFileErrorStatic(context, result);
        }
      } else {
        throw Exception('Ошибка загрузки файла: ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Закрываем индикатор загрузки
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  static void _showOpenFileErrorStatic(BuildContext context, OpenResult result) {
    if (!context.mounted) return;
    
    String errorMessage = 'Не удалось открыть файл';
    switch (result.type) {
      case ResultType.noAppToOpen:
        errorMessage = 'Нет приложения для открытия этого типа файлов';
        break;
      case ResultType.fileNotFound:
        errorMessage = 'Файл не найден';
        break;
      case ResultType.permissionDenied:
        errorMessage = 'Нет разрешения на открытие файла';
        break;
      default:
        errorMessage = result.message;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }
}

class _FileAttachmentWidgetState extends State<FileAttachmentWidget> {
  List<DefectAttachment> _attachments = [];
  bool _isLoading = false;
  StreamSubscription<bool>? _connectivitySubscription;

  // Проверяем, можно ли редактировать дефект (добавлять/удалять файлы)
  bool get _canEditDefect {
    final statusId = widget.defect.statusId;
    // Статус 10 означает "Закрыто"
    final canEdit = statusId != 10;
    print('_canEditDefect for defect ${widget.defect.id}: statusId=$statusId, canEdit=$canEdit');
    return canEdit;
  }

  @override
  void initState() {
    super.initState();
    _loadAttachments();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = OfflineService.connectivityStream.listen((isOnline) {
      if (isOnline && mounted) {
        // Когда интернет восстанавливается, обновляем список файлов
        _syncAttachmentsWithServer();
      }
    });
  }

  Future<void> _syncAttachmentsWithServer() async {
    try {
      print('Syncing attachments with server for defect ${widget.defect.id}');
      
      // Получаем актуальный список файлов с сервера
      final serverAttachments = await DatabaseService.getDefectAttachments(widget.defect.id);
      print('Server attachments from sync: ${serverAttachments.length}');
      
      // Получаем локальные файлы
      final localAttachments = await FileAttachmentService.getLocalAttachments(widget.defect.id);
      print('Local attachments from sync: ${localAttachments.length}');
      
      // Объединяем списки, исключая дубликаты
      final allAttachments = <DefectAttachment>[];
      allAttachments.addAll(serverAttachments);
      
      // Добавляем локальные файлы, которых нет на сервере
      for (final local in localAttachments) {
        final exists = serverAttachments.any((server) => 
          server.fileName == local.fileName && 
          server.defectId == local.defectId
        );
        if (!exists) {
          allAttachments.add(local);
        }
      }
      
      print('All attachments before filtering (sync): ${allAttachments.length}');
      
      // Получаем список файлов, ожидающих удаления
      final pendingDeleteIds = await OfflineService.getPendingDeleteAttachmentIds();
      print('Pending delete IDs (sync): $pendingDeleteIds');
      
      // Фильтруем файлы, которые ожидают удаления
      final filteredAttachments = allAttachments.where((attachment) {
        final shouldKeep = !pendingDeleteIds.contains(attachment.id);
        if (!shouldKeep) {
          print('Filtering out attachment in sync ${attachment.id} (${attachment.fileName})');
        }
        return shouldKeep;
      }).toList();
      
      print('Final attachments after sync: ${filteredAttachments.length}');
      
      if (mounted) {
        setState(() {
          _attachments = filteredAttachments;
        });
        
        // Обновляем дефект с новым списком файлов
        widget.onAttachmentsChanged?.call(_attachments);
      }
    } catch (e) {
      print('Error syncing attachments: $e');
    }
  }

  Future<void> _loadAttachments() async {
    setState(() => _isLoading = true);
    
    try {
      List<DefectAttachment> attachments = [];
      
      print('Loading attachments for defect ${widget.defect.id}, isOnline: ${OfflineService.isOnline}');
      
      if (OfflineService.isOnline) {
        // Если онлайн, загружаем с сервера и объединяем с локальными
        try {
          final serverAttachments = await DatabaseService.getDefectAttachments(widget.defect.id);
          print('Server attachments count: ${serverAttachments.length}');
          attachments.addAll(serverAttachments);
        } catch (e) {
          print('Error loading server attachments: $e');
          // Если не удалось загрузить с сервера, используем данные из дефекта
          attachments = List.from(widget.defect.attachments);
          print('Using defect attachments count: ${attachments.length}');
        }
        
        // Добавляем локальные файлы, которых нет на сервере
        final localAttachments = await FileAttachmentService.getLocalAttachments(widget.defect.id);
        print('Local attachments count: ${localAttachments.length}');
        for (final local in localAttachments) {
          final exists = attachments.any((server) => 
            server.fileName == local.fileName && 
            server.defectId == local.defectId
          );
          if (!exists) {
            attachments.add(local);
          }
        }
      } else {
        // Если офлайн, загружаем кешированные файлы + локальные
        final cachedAttachments = await OfflineService.getCachedAttachments(widget.defect.id);
        print('Cached attachments count: ${cachedAttachments.length}');
        attachments.addAll(cachedAttachments);
        
        final localAttachments = await FileAttachmentService.getLocalAttachments(widget.defect.id);
        print('Local attachments count: ${localAttachments.length}');
        
        // Добавляем локальные файлы, избегая дубликатов
        for (final local in localAttachments) {
          final exists = attachments.any((existing) => 
            existing.fileName == local.fileName && 
            existing.defectId == local.defectId
          );
          if (!exists) {
            attachments.add(local);
          }
        }
      }
      
      print('Total attachments before filtering: ${attachments.length}');
      
      // Получаем список файлов, ожидающих удаления
      final pendingDeleteIds = await OfflineService.getPendingDeleteAttachmentIds();
      print('Pending delete IDs: $pendingDeleteIds');
      
      // Фильтруем файлы, которые ожидают удаления
      attachments = attachments.where((attachment) {
        final shouldKeep = !pendingDeleteIds.contains(attachment.id);
        if (!shouldKeep) {
          print('Filtering out attachment ${attachment.id} (${attachment.fileName})');
        }
        return shouldKeep;
      }).toList();
      
      print('Final attachments count: ${attachments.length}');
      
      setState(() {
        _attachments = attachments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки файлов: $e')),
        );
      }
    }
  }

  Future<void> _showAttachmentOptions() async {
    print('_showAttachmentOptions called');
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Прикрепить файл',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Сделать фото'),
                onTap: () {
                  print('Camera button tapped');
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  print('Gallery button tapped');
                  Navigator.pop(context);
                  _pickFiles();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Выбрать файлы'),
                onTap: () {
                  print('Files button tapped');
                  Navigator.pop(context);
                  _pickFiles(filesOnly: true);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    print('_takePhoto called');
    setState(() => _isLoading = true);
    
    try {
      print('Calling FileAttachmentService.takePhoto()');
      final photo = await FileAttachmentService.takePhoto();
      print('takePhoto returned: ${photo?.path}');
      if (photo != null) {
        print('Photo taken, calling _attachFiles');
        await _attachFiles([photo]);
      } else {
        print('No photo taken');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при создании фото: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles({bool filesOnly = false}) async {
    print('_pickFiles called (filesOnly: $filesOnly)');
    setState(() => _isLoading = true);
    
    try {
      print('Calling FileAttachmentService.pickFiles()');
      final files = await FileAttachmentService.pickFiles(
        allowMultiple: true,
        includeCamera: !filesOnly,
      );
      
      print('pickFiles returned ${files.length} files');
      if (files.isNotEmpty) {
        print('Files picked, calling _attachFiles');
        await _attachFiles(files);
      } else {
        print('No files picked');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выборе файлов: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _attachFiles(List<File> files) async {
    try {
      print('_attachFiles called with ${files.length} files for defect ${widget.defect.id}');
      print('OfflineService.isOnline: ${OfflineService.isOnline}');
      print('About to call FileAttachmentService.attachFilesToDefect');
      
      print('Attaching ${files.length} files to defect ${widget.defect.id} (offline: ${!OfflineService.isOnline})');
      
      final newAttachments = await FileAttachmentService.attachFilesToDefect(
        defectId: widget.defect.id,
        files: files,
      );

      print('Successfully attached ${newAttachments.length} files');

      setState(() {
        _attachments.addAll(newAttachments);
      });

      widget.onAttachmentsChanged?.call(_attachments);

      if (mounted) {
        final message = OfflineService.isOnline
            ? 'Файлы успешно прикреплены'
            : 'Файлы сохранены локально. Будут загружены при подключении к интернету.';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error attaching files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при прикреплении файлов: $e')),
        );
      }
    }
  }

  void _viewAttachment(DefectAttachment attachment) {
    showDialog(
      context: context,
      builder: (context) => _AttachmentViewDialog(attachment: attachment),
    );
  }

  Future<void> _deleteAttachment(DefectAttachment attachment) async {
    // Запрашиваем подтверждение
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text('Вы уверены, что хотите удалить файл "${attachment.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Удаляем файл через сервис
      await FileAttachmentService.deleteAttachment(attachment);

      // Удаляем из локального списка
      setState(() {
        _attachments.removeWhere((a) => 
          a.id == attachment.id || 
          (a.fileName == attachment.fileName && a.defectId == attachment.defectId)
        );
        _isLoading = false;
      });

      // Уведомляем родительский виджет
      widget.onAttachmentsChanged?.call(_attachments);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл удален'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления файла: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Прикрепленные файлы (${_attachments.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_canEditDefect) ...[
              Builder(
                builder: (context) {
                  print('Building add file button for defect ${widget.defect.id}, canEdit: $_canEditDefect');
                  return IconButton(
                    onPressed: () {
                      print('Add file button pressed for defect ${widget.defect.id}');
                      _showAttachmentOptions();
                    },
                    icon: const Icon(Icons.add),
                    tooltip: 'Прикрепить файл',
                  );
                }
              )
            ]
          ],
        ),
        const SizedBox(height: 8),
        if (_attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.attach_file,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'Нет прикрепленных файлов',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (_canEditDefect)
                  TextButton.icon(
                    onPressed: _showAttachmentOptions,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить файл'),
                  )
                else
                  Text(
                    'Дефект закрыт',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attachments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final attachment = _attachments[index];
              return _AttachmentTile(
                attachment: attachment,
                onTap: () => _viewAttachment(attachment),
                onDelete: _canEditDefect ? () => _deleteAttachment(attachment) : null,
              );
            },
          ),
      ],
    );
  }

}

class _AttachmentTile extends StatelessWidget {
  final DefectAttachment attachment;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _AttachmentTile({
    required this.attachment,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocal = attachment.filePath.startsWith('/') && !attachment.filePath.startsWith('http');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Компактная иконка файла
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: attachment.isImage 
                      ? Colors.blue.shade100 
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  attachment.isImage ? Icons.image : Icons.insert_drive_file,
                  size: 20,
                  color: attachment.isImage ? Colors.blue : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              // Название файла и статус
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.fileName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          isLocal ? Icons.cloud_off : Icons.cloud_done,
                          size: 12,
                          color: isLocal ? Colors.orange.shade600 : Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLocal ? 'Локально' : 'Загружено',
                          style: TextStyle(
                            fontSize: 11,
                            color: isLocal ? Colors.orange.shade600 : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Кнопки действий
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility_outlined),
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    tooltip: 'Просмотреть',
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      iconSize: 20,
                      color: theme.colorScheme.error,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      tooltip: 'Удалить',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentViewDialog extends StatelessWidget {
  final DefectAttachment attachment;

  const _AttachmentViewDialog({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(attachment.fileName),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        backgroundColor: Colors.black,
        body: Center(
          child: attachment.isImage
              ? _buildImageViewer()
              : _buildFileViewer(context),
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    final isLocal = attachment.filePath.startsWith('/') && !attachment.filePath.startsWith('http');
    
    if (isLocal) {
      return InteractiveViewer(
        child: Image.file(
          File(attachment.filePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    'Не удалось загрузить изображение',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      // Удаленное изображение
      return InteractiveViewer(
        child: Image.network(
          attachment.filePath,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    'Не удалось загрузить изображение',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildFileViewer(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 64,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            attachment.fileName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await FileAttachmentWidget.openAttachmentWithSystem(context, attachment);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Открыть файл'),
          ),
        ],
      ),
    );
  }
}