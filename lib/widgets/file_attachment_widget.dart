import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
}

class _FileAttachmentWidgetState extends State<FileAttachmentWidget> {
  List<DefectAttachment> _attachments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    setState(() => _isLoading = true);
    
    try {
      // Загружаем существующие вложения
      List<DefectAttachment> attachments = widget.defect.attachments;
      
      // Если офлайн, добавляем локальные файлы
      if (!OfflineService.isOnline) {
        final localAttachments = await FileAttachmentService.getLocalAttachments(widget.defect.id);
        attachments.addAll(localAttachments);
      }
      
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
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Выбрать файлы'),
                onTap: () {
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
    setState(() => _isLoading = true);
    
    try {
      final photo = await FileAttachmentService.takePhoto();
      if (photo != null) {
        await _attachFiles([photo]);
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
    setState(() => _isLoading = true);
    
    try {
      final files = await FileAttachmentService.pickFiles(
        allowMultiple: true,
        includeCamera: !filesOnly,
      );
      
      if (files.isNotEmpty) {
        await _attachFiles(files);
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
      final newAttachments = await FileAttachmentService.attachFilesToDefect(
        defectId: widget.defect.id,
        files: files,
      );

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
            else
              IconButton(
                onPressed: _showAttachmentOptions,
                icon: const Icon(Icons.add),
                tooltip: 'Прикрепить файл',
              ),
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
                TextButton.icon(
                  onPressed: _showAttachmentOptions,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить файл'),
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
              );
            },
          ),
      ],
    );
  }

  Future<void> _openFileWithSystem(DefectAttachment attachment) async {
    try {
      final isLocal = attachment.filePath.startsWith('/');
      
      if (isLocal) {
        // Открываем локальный файл
        final result = await OpenFile.open(attachment.filePath);
        if (result.type != ResultType.done) {
          _showOpenFileError(result);
        }
      } else {
        // Скачиваем и открываем удаленный файл
        await _downloadAndOpenFile(attachment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка открытия файла: $e')),
        );
      }
    }
  }

  Future<void> _downloadAndOpenFile(DefectAttachment attachment) async {
    if (!mounted) return;
    
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

        if (mounted) {
          Navigator.of(context).pop(); // Закрываем индикатор загрузки
        }

        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          _showOpenFileError(result);
        }
      } else {
        throw Exception('Ошибка загрузки файла: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Закрываем индикатор загрузки
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _showOpenFileError(OpenResult result) {
    if (!mounted) return;
    
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
        errorMessage = result.message ?? 'Не удалось открыть файл';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final DefectAttachment attachment;
  final VoidCallback onTap;

  const _AttachmentTile({
    required this.attachment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocal = attachment.filePath.startsWith('/');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: attachment.isImage 
              ? Colors.blue.shade100 
              : Colors.grey.shade100,
          child: Icon(
            attachment.isImage ? Icons.image : Icons.insert_drive_file,
            color: attachment.isImage ? Colors.blue : Colors.grey.shade600,
          ),
        ),
        title: Text(
          attachment.fileName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            if (isLocal) ...[
              Icon(
                Icons.cloud_off,
                size: 14,
                color: Colors.orange.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                'Локально',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade600,
                ),
              ),
            ] else ...[
              Icon(
                Icons.cloud_done,
                size: 14,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                'Загружено',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.visibility),
          tooltip: 'Просмотреть',
        ),
        onTap: onTap,
      ),
    );
  }

  static Future<void> _openAttachmentWithSystem(BuildContext context, DefectAttachment attachment) async {
    try {
      final isLocal = attachment.filePath.startsWith('/');
      
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
        errorMessage = result.message ?? 'Не удалось открыть файл';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
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
    final isLocal = attachment.filePath.startsWith('/');
    
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
              await _openAttachmentWithSystem(context, attachment);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Открыть файл'),
          ),
        ],
      ),
    );
  }
}