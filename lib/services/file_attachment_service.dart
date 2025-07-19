import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/defect_attachment.dart';
import 'offline_service.dart';
import 'database_service.dart';

class FileAttachmentService {
  static final _supabase = Supabase.instance.client;
  
  // Максимальный размер файла (10 МБ)
  static const int maxFileSize = 10 * 1024 * 1024;
  
  // Поддерживаемые форматы файлов
  static const List<String> supportedFormats = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', // Изображения
    'pdf', // PDF
    'doc', 'docx', // Word
    'txt', // Текст
    'mp4', 'mov', 'avi', // Видео
  ];

  // Выбрать файлы из галереи или камеры
  static Future<List<File>> pickFiles({
    bool allowMultiple = true,
    bool includeCamera = true,
  }) async {
    final List<File> selectedFiles = [];

    // Показываем диалог выбора источника
    if (includeCamera) {
      // Здесь можно добавить диалог выбора между файлами и камерой
      // Пока реализуем только файлы
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.custom,
        allowedExtensions: supportedFormats,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            final fileObj = File(file.path!);
            
            // Проверяем размер файла
            final fileSize = await fileObj.length();
            if (fileSize > maxFileSize) {
              throw Exception('Файл ${file.name} слишком большой. Максимальный размер: ${maxFileSize ~/ (1024 * 1024)} МБ');
            }
            
            selectedFiles.add(fileObj);
          }
        }
      }
    } catch (e) {
      throw Exception('Ошибка при выборе файлов: $e');
    }

    return selectedFiles;
  }

  // Сделать фото с камеры
  static Future<File?> takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        final file = File(photo.path);
        
        // Проверяем размер
        final fileSize = await file.length();
        if (fileSize > maxFileSize) {
          throw Exception('Фото слишком большое. Максимальный размер: ${maxFileSize ~/ (1024 * 1024)} МБ');
        }
        
        return file;
      }
    } catch (e) {
      throw Exception('Ошибка при создании фото: $e');
    }

    return null;
  }

  // Прикрепить файлы к дефекту
  static Future<List<DefectAttachment>> attachFilesToDefect({
    required int defectId,
    required List<File> files,
  }) async {
    final List<DefectAttachment> attachments = [];

    try {
      for (final file in files) {
        final attachment = await _processFile(file, defectId);
        if (attachment != null) {
          attachments.add(attachment);
        }
      }

      // Если есть прикрепленные файлы, обновляем дефект
      if (attachments.isNotEmpty) {
        await _updateDefectAttachments(defectId, attachments);
      }

      return attachments;
    } catch (e) {
      // Очищаем созданные файлы при ошибке
      for (final attachment in attachments) {
        await _deleteLocalFile(attachment.filePath);
      }
      rethrow;
    }
  }

  // Обработать один файл
  static Future<DefectAttachment?> _processFile(File file, int defectId) async {
    try {
      // Генерируем уникальное имя файла
      final fileName = path.basename(file.path);
      final extension = path.extension(fileName).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${timestamp}_$fileName';

      // Определяем тип файла
      final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension);

      // Если офлайн, сохраняем файл локально
      if (!OfflineService.isOnline) {
        final localPath = await _saveFileLocally(file, uniqueFileName);
        
        // Сохраняем в локальную БД
        final attachmentId = await _saveLocalAttachment(
          defectId: defectId,
          fileName: fileName,
          filePath: localPath,
        );

        final fileBytes = await file.readAsBytes();
        return DefectAttachment(
          id: attachmentId,
          fileName: fileName,
          filePath: localPath,
          defectId: defectId,
          fileSize: fileBytes.length,
          createdAt: DateTime.now().toIso8601String(),
        );
      } else {
        // Если онлайн, загружаем на сервер
        final uploadedPath = await _uploadFileToServer(file, uniqueFileName);
        
        // Сохраняем в основную БД
        final attachment = await _saveServerAttachment(
          defectId: defectId,
          fileName: fileName,
          filePath: uploadedPath,
        );

        return attachment;
      }
    } catch (e) {
      print('Error processing file ${file.path}: $e');
      rethrow;
    }
  }

  // Сохранить файл локально
  static Future<String> _saveFileLocally(File file, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/attachments');
      
      if (!await attachmentsDir.exists()) {
        await attachmentsDir.create(recursive: true);
      }

      final localPath = '${attachmentsDir.path}/$fileName';
      await file.copy(localPath);
      
      return localPath;
    } catch (e) {
      throw Exception('Ошибка сохранения файла локально: $e');
    }
  }

  // Загрузить файл на сервер
  static Future<String> _uploadFileToServer(File file, String fileName) async {
    try {
      final bytes = await file.readAsBytes();
      final uploadPath = 'defects/$fileName';
      
      await _supabase.storage
          .from('attachments')
          .uploadBinary(uploadPath, bytes);

      return uploadPath;
    } catch (e) {
      throw Exception('Ошибка загрузки файла на сервер: $e');
    }
  }

  // Сохранить локальное вложение в БД
  static Future<int> _saveLocalAttachment({
    required int defectId,
    required String fileName,
    required String filePath,
  }) async {
    final db = OfflineService.database;
    if (db == null) throw Exception('Local database not initialized');

    final id = await db.insert('local_files', {
      'file_path': filePath,
      'original_name': fileName,
      'entity_type': 'defect',
      'entity_id': defectId,
      'uploaded': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Добавляем операцию синхронизации
    await OfflineService.addPendingSync(
      'upload_attachment',
      'defect',
      defectId,
      {
        'file_path': filePath,
        'file_name': fileName,
      },
    );

    return id;
  }

  // Сохранить серверное вложение в БД
  static Future<DefectAttachment> _saveServerAttachment({
    required int defectId,
    required String fileName,
    required String filePath,
  }) async {
    try {
      // Здесь должен быть вызов API для сохранения в БД
      // Пока возвращаем mock объект
      return DefectAttachment(
        id: DateTime.now().millisecondsSinceEpoch,
        fileName: fileName,
        filePath: filePath,
        defectId: defectId,
        fileSize: 0, // Mock size, should be provided by API
        createdAt: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      throw Exception('Ошибка сохранения вложения на сервере: $e');
    }
  }

  // Обновить вложения дефекта
  static Future<void> _updateDefectAttachments(int defectId, List<DefectAttachment> attachments) async {
    // Здесь можно добавить логику обновления дефекта с новыми вложениями
    print('Updated defect $defectId with ${attachments.length} attachments');
  }

  // Удалить локальный файл
  static Future<void> _deleteLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting local file $filePath: $e');
    }
  }

  // Получить локальные файлы для дефекта
  static Future<List<DefectAttachment>> getLocalAttachments(int defectId) async {
    final db = OfflineService.database;
    if (db == null) return [];

    final maps = await db.query(
      'local_files',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['defect', defectId],
    );

    return maps.map((map) => DefectAttachment(
      id: map['id'] as int,
      fileName: map['original_name'] as String,
      filePath: map['file_path'] as String,
      defectId: defectId,
      fileSize: 0, // File size not stored in local db schema
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int).toIso8601String(),
    )).toList();
  }

  // Синхронизировать локальные файлы
  static Future<bool> syncLocalFiles() async {
    if (!OfflineService.isOnline) return false;

    final db = OfflineService.database;
    if (db == null) return false;

    try {
      final unuploadedFiles = await db.query(
        'local_files',
        where: 'uploaded = 0',
      );

      for (final fileRecord in unuploadedFiles) {
        final filePath = fileRecord['file_path'] as String;
        final fileName = fileRecord['original_name'] as String;
        final file = File(filePath);

        if (await file.exists()) {
          try {
            // Загружаем на сервер
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final uniqueFileName = '${timestamp}_$fileName';
            final serverPath = await _uploadFileToServer(file, uniqueFileName);

            // Сохраняем в серверную БД
            await _saveServerAttachment(
              defectId: fileRecord['entity_id'] as int,
              fileName: fileName,
              filePath: serverPath,
            );

            // Помечаем как загруженный
            await db.update(
              'local_files',
              {'uploaded': 1},
              where: 'id = ?',
              whereArgs: [fileRecord['id']],
            );

            print('Successfully synced file: $fileName');
          } catch (e) {
            print('Failed to sync file $fileName: $e');
            return false;
          }
        } else {
          // Файл не существует, помечаем как ошибочный
          await db.delete(
            'local_files',
            where: 'id = ?',
            whereArgs: [fileRecord['id']],
          );
        }
      }

      return true;
    } catch (e) {
      print('Error syncing files: $e');
      return false;
    }
  }

  // Проверить является ли файл изображением
  static bool _isImageFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension);
  }

  // Получить размер файла в человекочитаемом формате
  static String getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Получить иконку для типа файла
  static String getFileIcon(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension)) {
      return '🖼️';
    } else if (extension == '.pdf') {
      return '📄';
    } else if (['.doc', '.docx'].contains(extension)) {
      return '📝';
    } else if (['.mp4', '.mov', '.avi'].contains(extension)) {
      return '🎬';
    } else if (extension == '.txt') {
      return '📃';
    }
    
    return '📎';
  }

  // Очистить старые локальные файлы
  static Future<void> cleanupOldFiles({int daysOld = 30}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/attachments');
      
      if (await attachmentsDir.exists()) {
        final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
        
        await for (final entity in attachmentsDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await entity.delete();
              print('Deleted old file: ${entity.path}');
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning up old files: $e');
    }
  }
}