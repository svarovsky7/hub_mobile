import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart' as legacy;
import '../models/unit.dart';
import '../models/defect.dart';
import '../models/defect_attachment.dart';
import 'offline_service.dart';

class DatabaseService {
  static final _supabase = Supabase.instance.client;

  // Получить все проекты пользователя
  static Future<List<legacy.Project>> getProjects() async {
    try {
      // Используем getUserProjects для фильтрации проектов по текущему пользователю
      return await getUserProjects();
    } catch (e) {
      // Log: Error fetching projects: $e
      // Return some mock data for testing when connection fails
      return [
        legacy.Project(id: 1, name: 'Тестовый проект', buildings: ['1', '2', '3']),
      ];
    }
  }

  // Получить проекты конкретного пользователя (для drawer)
  static Future<List<legacy.Project>> getUserProjects() async {
    try {
      final userId = await getCurrentUserId();
      print('Getting projects for user: $userId');
      
      if (userId == null) {
        print('No user ID found');
        return [];
      }

      // Проверяем офлайн-режим
      if (!OfflineService.isOnline) {
        print('Offline mode: loading cached projects');
        return await OfflineService.getCachedProjects(userId);
      }

      // Сначала проверим, есть ли записи в profiles_projects для этого пользователя
      final profileProjectsResponse = await _supabase
          .from('profiles_projects')
          .select('project_id')
          .eq('profile_id', userId);
      
      print('Found ${(profileProjectsResponse as List).length} project associations for user $userId');
      
      if ((profileProjectsResponse as List).isEmpty) {
        print('No project associations found for user $userId');
        // Возвращаем кэшированные данные если нет связей
        return await OfflineService.getCachedProjects(userId);
      }

      // Получаем проекты через связанную таблицу profiles_projects
      final response = await _supabase
          .from('profiles_projects')
          .select('''
            project_id,
            projects!inner(
              id,
              name
            )
          ''')
          .eq('profile_id', userId)
          .order('projects(name)', ascending: true)
          .timeout(const Duration(seconds: 10));

      print('Raw response from profiles_projects join: $response');

      final projects = <legacy.Project>[];
      for (final item in (response as List)) {
        final projectData = item['projects'];
        final projectId = projectData['id'] as int;
        
        // Получаем здания для каждого проекта (без проверки доступа для избежания рекурсии)
        final buildings = await _getBuildingsForProjectDirect(projectId);
        
        // Создаем проект с полученными зданиями
        final project = legacy.Project(
          id: projectData['id'],
          name: projectData['name'],
          buildings: buildings,
        );
        
        projects.add(project);
        
        // Кэшируем проект
        await OfflineService.cacheProjectData(project, userId);
      }

      print('Successfully loaded ${projects.length} user projects');
      return projects;
    } catch (e) {
      print('Error fetching user projects: $e');
      // Возвращаем кэшированные данные при ошибке
      final userId = await getCurrentUserId();
      if (userId != null) {
        return await OfflineService.getCachedProjects(userId);
      }
      return [];
    }
  }

  // Получить активный проект пользователя
  static Future<legacy.Project?> getUserActiveProject() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return null;

      // Получаем ID основного проекта из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final defaultProjectId = prefs.getInt('default_project_id_$userId');
      
      final projects = await getProjects();
      
      if (defaultProjectId != null) {
        // Ищем основной проект среди доступных проектов
        final defaultProject = projects.where((p) => p.id == defaultProjectId).firstOrNull;
        if (defaultProject != null) {
          return defaultProject;
        }
        // Если основной проект больше не доступен, очищаем настройку
        await prefs.remove('default_project_id_$userId');
      }
      
      // Возвращаем первый доступный проект как fallback
      return projects.isNotEmpty ? projects.first : null;
    } catch (e) {
      // Log: Error fetching user active project: $e
      return null;
    }
  }

  // Установить основной проект пользователя
  static Future<bool> setUserDefaultProject(int projectId) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return false;

      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt('default_project_id_$userId', projectId);
    } catch (e) {
      // Log: Error setting default project: $e
      return false;
    }
  }

  // Получить ID основного проекта пользователя
  static Future<int?> getUserDefaultProjectId() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return null;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('default_project_id_$userId');
    } catch (e) {
      // Log: Error getting default project ID: $e
      return null;
    }
  }

  // Очистить основной проект пользователя
  static Future<bool> clearUserDefaultProject() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return false;

      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove('default_project_id_$userId');
    } catch (e) {
      // Log: Error clearing default project: $e
      return false;
    }
  }

  // Получить все корпуса для проекта (без проверки доступа, используется внутренне)
  static Future<List<String>> _getBuildingsForProjectDirect(int projectId) async {
    try {
      // Log: Fetching buildings for project $projectId...
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
        if (records.isEmpty || records.length < limit) {
          hasMore = false;
        }

        for (final record in records) {
          final building = record['building'] as String?;
          if (building != null && building.isNotEmpty) {
            buildingsSet.add(building);
          }
        }

        offset += limit;
      }

      final buildings = buildingsSet.toList()..sort();
      // Log: Found ${buildings.length} buildings: $buildings
      return buildings;
    } catch (e) {
      // Log: Error fetching buildings: $e
      return [];
    }
  }

  // Получить все корпуса для проекта
  static Future<List<String>> getBuildingsForProject(int projectId) async {
    try {
      // Проверяем, есть ли у пользователя доступ к этому проекту
      final userProjects = await getUserProjects();
      final hasAccess = userProjects.any((project) => project.id == projectId);
      
      if (!hasAccess) {
        print('Access denied: User does not have access to project $projectId');
        return [];
      }

      // Log: Fetching buildings for project $projectId...
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
        // Log: 'Fetched ${records.length} unit records (offset: $offset)
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
          // Log: Reached maximum offset limit for safety
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

      // Log: 'Unique buildings found for project $projectId: $buildings (total: ${buildings.length})     
      return buildings;
    } catch (e) {
      // Log: Error fetching buildings: $e     
      return [];
    }
  }

  // Получить все юниты для проекта и корпуса
  static Future<List<Unit>> getUnitsForProjectAndBuilding(int projectId, String building) async {
    try {
      // Проверяем, есть ли у пользователя доступ к этому проекту
      final userProjects = await getUserProjects();
      final hasAccess = userProjects.any((project) => project.id == projectId);
      
      if (!hasAccess) {
        print('Access denied: User does not have access to project $projectId');
        return [];
      }

      final response = await _supabase
          .from('units')
          .select('*')
          .eq('project_id', projectId)
          .eq('building', building)
          .order('name');
      return (response as List)
          .map(
            (unit) => Unit.fromJson({
              ...unit,
              'defects': [], // Дефекты загружаем отдельно
            }),
          )
          .toList();
    } catch (e) {
      // Log: Error fetching units: $e     
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

      final defects = (response as List).map((defect) => Defect.fromJson(defect)).toList();
      
      // Загружаем вложения для каждого дефекта
      for (int i = 0; i < defects.length; i++) {
        final attachments = await getDefectAttachments(defects[i].id);
        defects[i] = defects[i].copyWith(attachments: attachments);
      }
      
      return defects;
    } catch (e) {
      // Log: Error fetching defects: $e     
      return [];
    }
  }

  // Получить все дефекты для проекта
  static Future<List<Defect>> getDefectsForProject(int projectId) async {
    try {
      // Проверяем, есть ли у пользователя доступ к этому проекту
      final userProjects = await getUserProjects();
      final hasAccess = userProjects.any((project) => project.id == projectId);
      
      if (!hasAccess) {
        print('Access denied: User does not have access to project $projectId');
        return [];
      }

      final response = await _supabase
          .from('defects')
          .select('*')
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      final defects = (response as List).map((defect) => Defect.fromJson(defect)).toList();
      
      // Загружаем вложения для каждого дефекта
      for (int i = 0; i < defects.length; i++) {
        final attachments = await getDefectAttachments(defects[i].id);
        defects[i] = defects[i].copyWith(attachments: attachments);
      }
      
      return defects;
    } catch (e) {
      // Log: Error fetching project defects: $e     
      return [];
    }
  }

  // Получить типы дефектов
  static Future<List<legacy.DefectType>> getDefectTypes() async {
    try {
      final response = await _supabase.from('defect_types').select('*').order('name');
      return (response as List).map((type) => legacy.DefectType(id: type['id'], name: type['name'])).toList();
    } catch (e) {
      // Log: Error fetching defect types: $e     
      return [
        legacy.DefectType(id: 1, name: 'Сантехника'),
        legacy.DefectType(id: 2, name: 'Электрика'),
        legacy.DefectType(id: 3, name: 'Отделка'),
        legacy.DefectType(id: 4, name: 'Окна/Двери'),
        legacy.DefectType(id: 5, name: 'Общие зоны'),
      ];
    }
  }

  // Получить статусы дефектов
  static Future<List<legacy.DefectStatus>> getDefectStatuses() async {
    try {
      final response = await _supabase.from('statuses').select('*').eq('entity', 'defect').order('id');
      final statuses = (response as List)
          .map(
            (status) => legacy.DefectStatus(
              id: status['id'],
              entity: status['entity'],
              name: status['name'],
              color: status['color'] ?? '#6b7280',
            ),
          )
          .toList();

      // Удаляем дублирующиеся статусы по ID
      final uniqueStatuses = <int, legacy.DefectStatus>{};
      for (final status in statuses) {
        uniqueStatuses[status.id] = status;
      }

      return uniqueStatuses.values.toList();
    } catch (e) {
      // Log: Error fetching defect statuses: $e     
      return [
        legacy.DefectStatus(id: 1, entity: 'defect', name: 'Получен', color: '#ef4444'),
        legacy.DefectStatus(id: 2, entity: 'defect', name: 'В работе', color: '#f59e0b'),
        legacy.DefectStatus(id: 3, entity: 'defect', name: 'Устранен', color: '#10b981'),
        legacy.DefectStatus(id: 4, entity: 'defect', name: 'Отклонен', color: '#6b7280'),
        legacy.DefectStatus(id: 9, entity: 'defect', name: 'НА ПРОВЕРКУ', color: '#3b82f6'),
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
      // Log: Error adding defect: $e     
      return null;
    }
  }

  // Получить юниты с дефектами для шахматки
  static Future<Map<String, dynamic>> getUnitsWithDefectsForBuilding(int projectId, String building) async {
    try {
      // Проверяем, есть ли у пользователя доступ к этому проекту
      final userProjects = await getUserProjects();
      final hasAccess = userProjects.any((project) => project.id == projectId);
      
      if (!hasAccess) {
        print('Access denied: User does not have access to project $projectId');
        return {'units': <Unit>[], 'unitsByFloor': <int, List<Unit>>{}, 'floors': <int>[]};
      }

      // Получаем юниты для здания
      final unitsResponse = await _supabase
          .from('units')
          .select('*')
          .eq('project_id', projectId)
          .eq('building', building)
          .order('name');
      
      final units = (unitsResponse as List)
          .map((unit) => Unit.fromJson({...unit, 'defects': []}))
          .toList();

      if (units.isEmpty) {
        return {'units': <Unit>[], 'unitsByFloor': <int, List<Unit>>{}, 'floors': <int>[]};
      }

      // Получаем ID всех юнитов для эффективного запроса дефектов
      final unitIds = units.map((unit) => unit.id).toList();

      // Получаем дефекты только для юнитов этого здания
      final defectsResponse = await _supabase
          .from('defects')
          .select('*')
          .eq('project_id', projectId)
          .inFilter('unit_id', unitIds)
          .order('created_at', ascending: false);

      final defects = (defectsResponse as List).map((defect) => Defect.fromJson(defect)).toList();

      // Для ускорения загрузки шахматки не загружаем вложения сразу
      // Вложения будут загружены при открытии конкретного дефекта

      // Группируем дефекты по юнитам
      final defectsByUnit = <int, List<Defect>>{};
      for (final defect in defects) {
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
      // Log: Error fetching units with defects: $e
      print('Error in getUnitsWithDefectsForBuilding: $e');
      return {'units': <Unit>[], 'unitsByFloor': <int, List<Unit>>{}, 'floors': <int>[]};
    }
  }

  // Проверить доступ пользователя к дефекту через проект
  static Future<bool> _hasAccessToDefect(int defectId) async {
    try {
      // Получаем проект дефекта
      final defectResponse = await _supabase
          .from('defects')
          .select('project_id')
          .eq('id', defectId)
          .single();
      
      final projectId = defectResponse['project_id'] as int;
      
      // Проверяем доступ к проекту
      final userProjects = await getUserProjects();
      return userProjects.any((project) => project.id == projectId);
    } catch (e) {
      print('Error checking defect access: $e');
      return false;
    }
  }

  // Загрузить файл к дефекту
  static Future<DefectAttachment?> uploadDefectAttachment({
    required int defectId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      // Проверяем доступ к дефекту
      final hasAccess = await _hasAccessToDefect(defectId);
      if (!hasAccess) {
        print('Access denied: User does not have access to defect $defectId');
        return null;
      }
      // Создаем уникальное имя файла
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last;
      final uniqueFileName = '${timestamp}_$fileName';
      final filePath = 'defects/$defectId/$uniqueFileName';

      // Загружаем файл в storage
      await _supabase.storage.from('attachments').uploadBinary(filePath, Uint8List.fromList(fileBytes));

      // Сначала создаем запись в таблице attachments
      final attachmentResponse = await _supabase
          .from('attachments')
          .insert({
            'path': filePath,
            'storage_path': filePath,
            'original_name': fileName,
            'mime_type': _getMimeType(fileExtension),
            'created_by': _supabase.auth.currentUser?.id,
            'uploaded_by': _supabase.auth.currentUser?.id,
          })
          .select()
          .single();

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
      // Log: Error uploading file: $e     
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
      // Проверяем доступ к дефекту
      final hasAccess = await _hasAccessToDefect(defectId);
      if (!hasAccess) {
        print('Access denied: User does not have access to defect $defectId');
        return [];
      }
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
        // Log: 'Attachment data: $attachment       
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
      // Log: Error fetching defect attachments: $e     
      return [];
    }
  }

  // Получить бригады
  static Future<List<Map<String, dynamic>>> getBrigades() async {
    try {
      final response = await _supabase.from('brigades').select('id, name').order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Log: Error fetching brigades: $e
      return [];
    }
  }

  // Получить подрядчиков
  static Future<List<Map<String, dynamic>>> getContractors() async {
    try {
      final response = await _supabase.from('contractors').select('id, name').order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Log: Error fetching contractors: $e
      return [];
    }
  }

  // Получить инженеров
  static Future<List<Map<String, dynamic>>> getEngineers() async {
    try {
      final response = await _supabase.from('profiles').select('id, name').eq('role', 'ENGINEER').order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Log: Error fetching engineers: $e
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
      // Log: Error getting current user ID: $e     
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
      await _supabase.storage.from('attachments').remove([filePath]);

      // Удаляем запись из БД
      await _supabase.from('defect_attachments').delete().eq('id', attachmentId);

      return true;
    } catch (e) {
      // Log: Error deleting attachment: $e     
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
      // Проверяем доступ к дефекту
      final hasAccess = await _hasAccessToDefect(defectId);
      if (!hasAccess) {
        print('Access denied: User does not have access to defect $defectId');
        return null;
      }
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

      final response = await _supabase.from('defects').update(updates).eq('id', defectId).select().single();

      return Defect.fromJson(response);
    } catch (e) {
      // Log: Error marking defect as fixed: $e     
      return null;
    }
  }

  // Обновить статус дефекта
  static Future<Defect?> updateDefectStatus({required int defectId, required int statusId}) async {
    try {
      // Проверяем доступ к дефекту
      final hasAccess = await _hasAccessToDefect(defectId);
      if (!hasAccess) {
        print('Access denied: User does not have access to defect $defectId');
        return null;
      }
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
      // Log: Error updating defect status: $e     
      return null;
    }
  }

  // Обновить статус гарантии дефекта
  static Future<Defect?> updateDefectWarranty({required int defectId, required bool isWarranty}) async {
    try {
      // Если офлайн, добавляем операцию в очередь синхронизации
      if (!OfflineService.isOnline) {
        print('Offline mode: queuing warranty update for defect $defectId');
        await OfflineService.addPendingSync(
          'update_defect_warranty',
          'defect',
          defectId,
          {'is_warranty': isWarranty},
        );
        
        // Возвращаем обновленный дефект из локального кэша
        // Здесь нужно будет реализовать обновление локального кэша
        // Пока возвращаем null чтобы указать что операция в очереди
        return null;
      }

      // Проверяем доступ к дефекту
      final hasAccess = await _hasAccessToDefect(defectId);
      if (!hasAccess) {
        print('Access denied: User does not have access to defect $defectId');
        return null;
      }
      
      final response = await _supabase
          .from('defects')
          .update({
            'is_warranty': isWarranty,
            'updated_by': _supabase.auth.currentUser?.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', defectId)
          .select()
          .single();

      return Defect.fromJson(response);
    } catch (e) {
      print('Error updating defect warranty status: $e');
      
      // При ошибке сети добавляем в очередь синхронизации
      await OfflineService.addPendingSync(
        'update_defect_warranty',
        'defect',
        defectId,
        {'is_warranty': isWarranty},
      );
      
      return null;
    }
  }

  // Получить URL для просмотра файла
  static String? getAttachmentUrl(String filePath) {
    try {
      // Проверяем, является ли filePath уже полным URL
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        return filePath;
      }
      
      // Если это относительный путь, строим полный URL
      return _supabase.storage.from('attachments').getPublicUrl(filePath);
    } catch (e) {
      // Log: Error getting attachment URL: $e
      print('Error getting attachment URL: $e');
      return null;
    }
  }

  // Выйти из аккаунта
  static Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      // Log: Error during logout: $e
      throw Exception('Ошибка при выходе из аккаунта');
    }
  }

  // Получить информацию о пользователе
  static Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        return {
          'name': user.userMetadata?['name'] ?? user.email?.split('@')[0] ?? 'Пользователь',
          'email': user.email ?? '',
          'id': user.id,
        };
      }
      return {};
    } catch (e) {
      // Log: Error getting user info: $e     
      return {};
    }
  }

  // Получить статистику пользователя
  static Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return {};

      // Получаем общее количество проектов
      final projectsResponse = await _supabase
          .from('projects')
          .select('id')
          .count();

      // Получаем статистику по дефектам
      final defectsResponse = await _supabase
          .from('defects')
          .select('id, status_id')
          .count();

      final activeDefectsResponse = await _supabase
          .from('defects')
          .select('id')
          .inFilter('status_id', [1, 2, 9]) // Активные статусы
          .count();

      final closedDefectsResponse = await _supabase
          .from('defects')
          .select('id')
          .inFilter('status_id', [3, 10]) // Закрытые статусы
          .count();

      return {
        'totalProjects': projectsResponse.count,
        'totalDefects': defectsResponse.count,
        'activeDefects': activeDefectsResponse.count,
        'closedDefects': closedDefectsResponse.count,
      };
    } catch (e) {
      // Log: Error getting user statistics: $e     
      return {
        'totalProjects': 0,
        'totalDefects': 0,
        'activeDefects': 0,
        'closedDefects': 0,
      };
    }
  }

  // Получить статистику по конкретному проекту
  static Future<Map<String, dynamic>> getProjectStatistics(int projectId) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return {};

      // Получаем количество квартир в проекте
      final unitsResponse = await _supabase
          .from('units')
          .select('id')
          .eq('project_id', projectId)
          .count();

      // Получаем статистику по дефектам в проекте
      final defectsResponse = await _supabase
          .from('defects')
          .select('id, status_id')
          .eq('project_id', projectId)
          .count();

      final activeDefectsResponse = await _supabase
          .from('defects')
          .select('id')
          .eq('project_id', projectId)
          .inFilter('status_id', [1, 2, 9]) // Активные статусы
          .count();

      final closedDefectsResponse = await _supabase
          .from('defects')
          .select('id')
          .eq('project_id', projectId)
          .inFilter('status_id', [3, 10]) // Закрытые статусы
          .count();

      return {
        'totalUnits': unitsResponse.count,
        'totalDefects': defectsResponse.count,
        'activeDefects': activeDefectsResponse.count,
        'closedDefects': closedDefectsResponse.count,
      };
    } catch (e) {
      // Log: Error getting project statistics: $e     
      return {
        'totalUnits': 0,
        'totalDefects': 0,
        'activeDefects': 0,
        'closedDefects': 0,
      };
    }
  }
}
