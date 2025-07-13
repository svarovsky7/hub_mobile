import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/unit.dart';
import '../models/defect.dart';

class DatabaseService {
  static final _supabase = Supabase.instance.client;

  // Получить все проекты пользователя
  static Future<List<Project>> getProjects() async {
    try {
      final response = await _supabase
          .from('projects')
          .select('*')
          .order('name');

      return (response as List)
          .map((project) => Project.fromJson(project))
          .toList();
    } catch (e) {
      print('Error fetching projects: $e');
      return [];
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

      // Преобразуем в список и сортируем
      final buildings = buildingsSet.toList();
      buildings.sort((a, b) => a.compareTo(b));
      
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
  static Future<List<DefectType>> getDefectTypes() async {
    try {
      final response = await _supabase
          .from('defect_types')
          .select('*')
          .order('name');

      return (response as List)
          .map((type) => DefectType(
            id: type['id'],
            name: type['name'],
          ))
          .toList();
    } catch (e) {
      print('Error fetching defect types: $e');
      return [
        DefectType(id: 1, name: 'Сантехника'),
        DefectType(id: 2, name: 'Электрика'),
        DefectType(id: 3, name: 'Отделка'),
        DefectType(id: 4, name: 'Окна/Двери'),
        DefectType(id: 5, name: 'Общие зоны'),
      ];
    }
  }

  // Получить статусы дефектов
  static Future<List<DefectStatus>> getDefectStatuses() async {
    try {
      final response = await _supabase
          .from('statuses')
          .select('*')
          .eq('entity', 'defect')
          .order('id');

      return (response as List)
          .map((status) => DefectStatus(
            id: status['id'],
            entity: status['entity'],
            name: status['name'],
            color: status['color'] ?? '#6b7280',
          ))
          .toList();
    } catch (e) {
      print('Error fetching defect statuses: $e');
      return [
        DefectStatus(id: 1, entity: 'defect', name: 'Получен', color: '#ef4444'),
        DefectStatus(id: 2, entity: 'defect', name: 'В работе', color: '#f59e0b'),
        DefectStatus(id: 3, entity: 'defect', name: 'Устранен', color: '#10b981'),
        DefectStatus(id: 4, entity: 'defect', name: 'Отклонен', color: '#6b7280'),
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

  // Обновить статус дефекта
  static Future<Defect?> updateDefectStatus(
    int defectId, 
    int newStatusId
  ) async {
    try {
      final updates = <String, dynamic>{
        'status_id': newStatusId,
        'updated_by': _supabase.auth.currentUser?.id,
      };

      // Если статус "Устранен", добавляем дату устранения
      if (newStatusId == 3) {
        updates['fixed_at'] = DateTime.now().toIso8601String().split('T')[0];
        updates['fixed_by'] = _supabase.auth.currentUser?.id;
      }

      final response = await _supabase
          .from('defects')
          .update(updates)
          .eq('id', defectId)
          .select()
          .single();

      return Defect.fromJson(response);
    } catch (e) {
      print('Error updating defect status: $e');
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
}