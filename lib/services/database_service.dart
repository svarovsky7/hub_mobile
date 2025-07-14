import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart' as Legacy;
import '../models/unit.dart';
import '../models/defect.dart';
import '../models/defect_attachment.dart';

class DatabaseService {
  static final _supabase = Supabase.instance.client;

  // Получить все проекты пользователя
  static Future<List<Legacy.Project>> getProjects() async {
    try {
      print('Attempting to fetch projects from Supabase...');
      final response = await _supabase
          .from('projects')
          .select('*')
          .order('name')
          .timeout(const Duration(seconds: 10));

      print('Successfully fetched ${(response as List).length} projects');
      final projects = (response as List)
          .map((project) => Legacy.Project.fromJson(project))
          .toList();
      
      // Сортируем проекты по имени
      projects.sort((a, b) => a.name.compareTo(b.name));
      
      return projects;
    } catch (e) {
      print('Error fetching projects: $e');
      // Return some mock data for testing when connection fails
      return [
        Legacy.Project(
          id: 1,
          name: 'Тестовый проект',
          buildings: ['1', '2', '3'],
        ),
      ];
    }
  }

  // Получить все корпуса для проекта
  static Future<List<String>> getBuildingsForProject(int projectId) async {
    try {
      print('Fetching buildings for project $projectId...');
      
      final buildingsSet = <String>{};
      int offset = 0;
      const limit = 1000;
      bool hasMore = true;
      
      // Загружаем данные пачками пока не получим все
      while (hasMore) {
        final response = await _supabase
            .from('units')
            .select('building')
            .eq('project_id', projectId)
            .range(offset, offset + limit - 1);

        final List<dynamic> records = response as List;
        print('Fetched ${records.length} unit records (offset: $offset)');
        
        if (records.isEmpty || records.length < limit) {
          hasMore = false;
        }
        
        // Добавляем уникальные корпуса
        for (final unit in records) {
          final building = unit['building'] as String?;
          if (building != null && building.isNotEmpty) {
            buildingsSet.add(building);
          }
        }
        
        offset += limit;
        
        // Защита от бесконечного цикла
        if (offset > 10000) {
          print('Reached maximum offset limit for safety');
          break;
        }
      }

      // Преобразуем в список и сортируем: сначала числа, потом текст
      final buildings = buildingsSet.toList();
      buildings.sort((a, b) {
        // Проверяем, является ли строка чисто числовой
        bool isNumericOnly(String s) {
          return RegExp(r'^\d+$').hasMatch(s.trim());
        }
        
        final aIsNumeric = isNumericOnly(a);
        final bIsNumeric = isNumericOnly(b);
        
        // Если обе строки - чисто числовые
        if (aIsNumeric && bIsNumeric) {
          return int.parse(a).compareTo(int.parse(b));
        }
        
        // Если только одна строка числовая - она идет первой
        if (aIsNumeric && !bIsNumeric) return -1;
        if (!aIsNumeric && bIsNumeric) return 1;
        
        // Если обе строки содержат текст, применяем умную сортировку
        RegExpMatch? getNumberPart(String s) {
          return RegExp(r'(\d+)').firstMatch(s);
        }
        
        final matchA = getNumberPart(a);
        final matchB = getNumberPart(b);
        
        // Если в обеих строках есть числа
        if (matchA != null && matchB != null) {
          final numA = int.parse(matchA.group(0)!);
          final numB = int.parse(matchB.group(0)!);
          
          // Сначала сравниваем числа
          final numberComparison = numA.compareTo(numB);
          if (numberComparison != 0) {
            return numberComparison;
          }
        }
        
        // В остальных случаях сравниваем как строки
        return a.compareTo(b);
      });
      
      print('Unique buildings found for project $projectId: $buildings (total: ${buildings.length})');
      return buildings;
    } catch (e) {
      print('Error fetching buildings: $e');
      return [];
    }
  }

  // Получить все юниты для проекта и корпуса
  static Future<List<Unit>> getUnitsForProjectAndBuilding(
    int projectId, 
    String building
  ) async {
    try {
      final response = await _supabase
          .from('units')
          .select('*')
          .eq('project_id', projectId)
          .eq('building', building)
          .order('name');

      return (response as List)
          .map((unit) => Unit.fromJson({
            ...unit,
            'defects': [], // Дефекты загружаем отдельно
          }))
          .toList();
    } catch (e) {
      print('Error fetching units: $e');
      return [];
    }
  }

  // Получить дефекты для юнита
  static Future<List<Defect>> getDefectsForUnit(int unitId) async {
    try {
      final response = await _supabase
          .from('defects')
          .select('*')
          .eq('unit_id', unitId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((defect) => Defect.fromJson(defect))
          .toList();
    } catch (e) {
      print('Error fetching defects: $e');
      return [];
    }
  }

  // Получить все дефекты для проекта
  static Future<List<Defect>> getDefectsForProject(int projectId) async {
    try {
      final response = await _supabase
          .from('defects')
          .select('*')
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((defect) => Defect.fromJson(defect))
          .toList();
    } catch (e) {
      print('Error fetching project defects: $e');
      return [];
    }
  }

  // Получить типы дефектов
  static Future<List<Legacy.DefectType>> getDefectTypes() async {
    try {
      final response = await _supabase
          .from('defect_types')
          .select('*')
          .order('name');

      return (response as List)
          .map((type) => Legacy.DefectType(
            id: type['id'],
            name: type['name'],
          ))
          .toList();
    } catch (e) {
      print('Error fetching defect types: $e');
      return [
        Legacy.DefectType(id: 1, name: 'Сантехника'),
        Legacy.DefectType(id: 2, name: 'Электрика'),
        Legacy.DefectType(id: 3, name: 'Отделка'),
        Legacy.DefectType(id: 4, name: 'Окна/Двери'),
        Legacy.DefectType(id: 5, name: 'Общие зоны'),
      ];
    }
  }

  // Получить статусы дефектов
  static Future<List<Legacy.DefectStatus>> getDefectStatuses() async {
    try {
      final response = await _supabase
          .from('statuses')
          .select('*')
          .eq('entity', 'defects')
          .order('id');

      final statuses = (response as List)
          .map((status) => Legacy.DefectStatus(
            id: status['id'],
            entity: status['entity'],
            name: status['name'],
            color: status['color'] ?? '#6b7280',
          ))
          .toList();
      
      // Удаляем дублирующиеся статусы по ID
      final uniqueStatuses = <int, Legacy.DefectStatus>{};
      for (final status in statuses) {
        uniqueStatuses[status.id] = status;
      }
      
      return uniqueStatuses.values.toList();
    } catch (e) {
      print('Error fetching defect statuses: $e');
      return [
        Legacy.DefectStatus(id: 1, entity: 'defect', name: 'Получен', color: '#ef4444'),
        Legacy.DefectStatus(id: 2, entity: 'defect', name: 'В работе', color: '#f59e0b'),
        Legacy.DefectStatus(id: 3, entity: 'defect', name: 'Устранен', color: '#10b981'),
        Legacy.DefectStatus(id: 4, entity: 'defect', name: 'Отклонен', color: '#6b7280'),
        Legacy.DefectStatus(id: 9, entity: 'defect', name: 'НА ПРОВЕРКУ', color: '#3b82f6'),
      ];
    }
  }

  // Добавить новый дефект
  static Future<Defect?> addDefect({
    required String description,
    required int typeId,
    required String receivedAt,
    required bool isWarranty,
    required int projectId,
    required int unitId,
  }) async {
    try {
      final response = await _supabase
          .from('defects')
          .insert({
            'description': description,
            'type_id': typeId,
            'status_id': 1, // Получен
            'received_at': receivedAt,
            'is_warranty': isWarranty,
            'project_id': projectId,
            'unit_id': unitId,
            'created_by': _supabase.auth.currentUser?.id,
          })
          .select()
          .single();

      return Defect.fromJson(response);
    } catch (e) {
      print('Error adding defect: $e');
      return null;
    }
  }

  // Получить юниты с дефектами для шахматки
  static Future<Map<String, dynamic>> getUnitsWithDefectsForBuilding(
    int projectId, 
    String building
  ) async {
    try {
      // Получаем юниты
      final units = await getUnitsForProjectAndBuilding(projectId, building);
      
      // Получаем все дефекты для проекта
      final allDefects = await getDefectsForProject(projectId);
      
      // Группируем дефекты по юнитам
      final defectsByUnit = <int, List<Defect>>{};
      for (final defect in allDefects) {
        if (defect.unitId != null) {
          defectsByUnit.putIfAbsent(defect.unitId!, () => []).add(defect);
        }
      }
      
      // Добавляем дефекты к юнитам
      final unitsWithDefects = units.map((unit) {
        final unitDefects = defectsByUnit[unit.id] ?? [];
        return unit.copyWith(defects: unitDefects);
      }).toList();
      
      // Группируем по этажам для удобства отображения
      final unitsByFloor = <int, List<Unit>>{};
      for (final unit in unitsWithDefects) {
        if (unit.floor != null) {
          unitsByFloor.putIfAbsent(unit.floor!, () => []).add(unit);
        }
      }
      
      // Сортируем юниты в каждом этаже
      unitsByFloor.forEach((floor, units) {
        units.sort((a, b) => a.name.compareTo(b.name));
      });
      
      return {
        'units': unitsWithDefects,
        'unitsByFloor': unitsByFloor,
        'floors': unitsByFloor.keys.toList()..sort((a, b) => b.compareTo(a)), // По убыванию
      };
    } catch (e) {
      print('Error fetching units with defects: $e');
      return {
        'units': <Unit>[],
        'unitsByFloor': <int, List<Unit>>{},
        'floors': <int>[],
      };
    }
  }

  // Загрузить файл к дефекту
  static Future<DefectAttachment?> uploadDefectAttachment({
    required int defectId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      // Создаем уникальное имя файла
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last;
      final uniqueFileName = '${timestamp}_$fileName';
      final filePath = 'defects/$defectId/$uniqueFileName';

      // Загружаем файл в storage
      await _supabase.storage
          .from('attachments')
          .uploadBinary(filePath, Uint8List.fromList(fileBytes));

      // Сначала создаем запись в таблице attachments
      final attachmentResponse = await _supabase.from('attachments').insert({
        'path': filePath,
        'storage_path': filePath,
        'original_name': fileName,
        'mime_type': _getMimeType(fileExtension),
        'created_by': _supabase.auth.currentUser?.id,
        'uploaded_by': _supabase.auth.currentUser?.id,
      }).select().single();

      // Затем создаем связь в defect_attachments
      await _supabase.from('defect_attachments').insert({
        'defect_id': defectId,
        'attachment_id': attachmentResponse['id'],
      });

      // Возвращаем DefectAttachment с данными из attachments
      return DefectAttachment.fromJson({
        'id': attachmentResponse['id'],
        'defect_id': defectId,
        'name': fileName,
        'path': filePath,
        'size': fileBytes.length,
        'created_by': attachmentResponse['created_by'],
        'created_at': attachmentResponse['created_at'],
      });
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  static String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  // Получить вложения дефекта
  static Future<List<DefectAttachment>> getDefectAttachments(int defectId) async {
    try {
      final response = await _supabase
          .from('defect_attachments')
          .select('''
            defect_id,
            attachment_id,
            attachments!inner(
              id,
              path,
              storage_path,
              original_name,
              mime_type,
              created_at,
              created_by
            )
          ''')
          .eq('defect_id', defectId)
          .order('attachments(created_at)', ascending: false);

      return (response as List).map((item) {
        final attachment = item['attachments'];
        print('Attachment data: $attachment');
        return DefectAttachment.fromJson({
          'id': attachment['id'],
          'defect_id': defectId,
          'name': attachment['original_name'] ?? 'file',
          'path': attachment['path'] ?? '',
          'size': 0, // Размер файла пока не сохраняем в БД
          'created_by': attachment['created_by'],
          'created_at': attachment['created_at'],
        });
      }).toList();
    } catch (e) {
      print('Error fetching defect attachments: $e');
      return [];
    }
  }

  // Получить бригады
  static Future<List<Map<String, dynamic>>> getBrigades() async {
    try {
      final response = await _supabase
          .from('brigades')
          .select('id, name')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching brigades: $e');
      return [];
    }
  }

  // Получить подрядчиков
  static Future<List<Map<String, dynamic>>> getContractors() async {
    try {
      final response = await _supabase
          .from('contractors')
          .select('id, name')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching contractors: $e');
      return [];
    }
  }

  // Получить инженеров
  static Future<List<Map<String, dynamic>>> getEngineers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, name')
          .eq('role', 'ENGINEER')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching engineers: $e');
      return [];
    }
  }

  // Получить текущего пользователя
  static Future<String?> getCurrentUserId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // В profiles ID пользователя является UUID, совпадающим с auth ID
        return user.id;
      }
      return null;
    } catch (e) {
      print('Error getting current user ID: $e');
      return null;
    }
  }

  // Удалить прикрепленный файл
  static Future<bool> deleteDefectAttachment(int attachmentId) async {
    try {
      // Получаем информацию о файле для удаления из storage
      final attachmentResponse = await _supabase
          .from('defect_attachments')
          .select('path')
          .eq('id', attachmentId)
          .single();

      final filePath = attachmentResponse['path'];

      // Удаляем файл из storage
      await _supabase.storage
          .from('attachments')
          .remove([filePath]);

      // Удаляем запись из БД
      await _supabase
          .from('defect_attachments')
          .delete()
          .eq('id', attachmentId);

      return true;
    } catch (e) {
      print('Error deleting attachment: $e');
      return false;
    }
  }

  // Отметить дефект как устраненный
  static Future<Defect?> markDefectAsFixed({
    required int defectId,
    required int executorId,
    required bool isOwnExecutor,
    required String engineerId,
    required DateTime fixDate,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status_id': 9, // НА ПРОВЕРКУ
        'fixed_at': fixDate.toIso8601String().split('T')[0],
        'fixed_by': engineerId,
        'engineer_id': engineerId,
        'updated_by': _supabase.auth.currentUser?.id,
      };

      // Добавляем исполнителя в зависимости от типа
      if (isOwnExecutor) {
        updates['brigade_id'] = executorId;
        updates['contractor_id'] = null;
      } else {
        updates['contractor_id'] = executorId;
        updates['brigade_id'] = null;
      }

      final response = await _supabase
          .from('defects')
          .update(updates)
          .eq('id', defectId)
          .select()
          .single();

      return Defect.fromJson(response);
    } catch (e) {
      print('Error marking defect as fixed: $e');
      return null;
    }
  }

  // Обновить статус дефекта
  static Future<Defect?> updateDefectStatus({
    required int defectId,
    required int statusId,
  }) async {
    try {
      final response = await _supabase
          .from('defects')
          .update({
            'status_id': statusId,
            'updated_by': _supabase.auth.currentUser?.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', defectId)
          .select()
          .single();

      return Defect.fromJson(response);
    } catch (e) {
      print('Error updating defect status: $e');
      return null;
    }
  }

  // Получить URL для просмотра файла
  static String? getAttachmentUrl(String filePath) {
    try {
      return _supabase.storage
          .from('attachments')
          .getPublicUrl(filePath);
    } catch (e) {
      print('Error getting attachment URL: $e');
      return null;
    }
  }
}