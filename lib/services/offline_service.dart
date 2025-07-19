import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/project.dart' as legacy;
import '../models/unit.dart';
import '../models/defect.dart';
import '../models/defect_attachment.dart';
import 'database_service.dart';

class OfflineService {
  static Database? _database;
  static final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  static bool _isOnline = true;
  static Timer? _syncTimer;
  static final Set<String> _pendingSyncOperations = {};

  // Getters
  static Stream<bool> get connectivityStream => _connectivityController.stream;
  static bool get isOnline => _isOnline;
  static bool get hasPendingSync => _pendingSyncOperations.isNotEmpty;
  static Database? get database => _database;

  // Инициализация офлайн-сервиса
  static Future<void> initialize() async {
    await _initDatabase();
    await _initConnectivityMonitoring();
    await _checkPendingSync();
  }

  // Инициализация локальной базы данных
  static Future<void> _initDatabase() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'offline_cache.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Таблица проектов
        await db.execute('''
          CREATE TABLE projects (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            buildings TEXT NOT NULL,
            last_sync INTEGER NOT NULL,
            user_id TEXT NOT NULL
          )
        ''');

        // Таблица юнитов
        await db.execute('''
          CREATE TABLE units (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            floor INTEGER,
            project_id INTEGER NOT NULL,
            building TEXT NOT NULL,
            defects_data TEXT,
            last_sync INTEGER NOT NULL
          )
        ''');

        // Таблица дефектов
        await db.execute('''
          CREATE TABLE defects (
            id INTEGER PRIMARY KEY,
            description TEXT NOT NULL,
            type_id INTEGER,
            status_id INTEGER,
            received_at TEXT,
            fixed_at TEXT,
            is_warranty INTEGER NOT NULL DEFAULT 0,
            project_id INTEGER NOT NULL,
            unit_id INTEGER,
            created_at TEXT,
            updated_at TEXT,
            created_by TEXT,
            updated_by TEXT,
            engineer_id TEXT,
            brigade_id INTEGER,
            contractor_id INTEGER,
            fixed_by TEXT,
            attachments_data TEXT,
            last_sync INTEGER NOT NULL
          )
        ''');

        // Таблица типов дефектов
        await db.execute('''
          CREATE TABLE defect_types (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            last_sync INTEGER NOT NULL
          )
        ''');

        // Таблица статусов дефектов
        await db.execute('''
          CREATE TABLE defect_statuses (
            id INTEGER PRIMARY KEY,
            entity TEXT NOT NULL,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            last_sync INTEGER NOT NULL
          )
        ''');

        // Таблица ожидающих синхронизации операций
        await db.execute('''
          CREATE TABLE pending_sync (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_type TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id INTEGER,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        // Таблица локальных файлов
        await db.execute('''
          CREATE TABLE local_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL,
            original_name TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id INTEGER NOT NULL,
            uploaded INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');

        // Индексы для быстрого поиска
        await db.execute('CREATE INDEX idx_units_project ON units(project_id)');
        await db.execute('CREATE INDEX idx_defects_project ON defects(project_id)');
        await db.execute('CREATE INDEX idx_defects_unit ON defects(unit_id)');
        await db.execute('CREATE INDEX idx_pending_sync_type ON pending_sync(operation_type)');
      },
    );
  }

  // Мониторинг подключения к интернету
  static Future<void> _initConnectivityMonitoring() async {
    // Проверяем текущее состояние
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);
    _connectivityController.add(_isOnline);

    // Слушаем изменения подключения
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      
      if (_isOnline && !wasOnline) {
        // Восстановилось подключение
        _onConnectivityRestored();
      }
      
      _connectivityController.add(_isOnline);
    });
  }

  // Обработка восстановления подключения
  static Future<void> _onConnectivityRestored() async {
    print('Internet connection restored');
    await _checkPendingSync();
    
    if (hasPendingSync) {
      // Ждем немного и показываем уведомление о синхронизации
      await Future.delayed(const Duration(milliseconds: 500));
      // Здесь можно добавить глобальное уведомление через EventBus или Provider
    }
  }

  // Проверка наличия операций для синхронизации
  static Future<void> _checkPendingSync() async {
    if (_database == null) return;

    final pendingOperations = await _database!.query('pending_sync');
    final localFiles = await _database!.query('local_files', where: 'uploaded = 0');
    
    _pendingSyncOperations.clear();
    for (final op in pendingOperations) {
      _pendingSyncOperations.add('${op['operation_type']}_${op['entity_id']}');
    }
    
    for (final file in localFiles) {
      _pendingSyncOperations.add('upload_file_${file['id']}');
    }
  }

  // Кэширование данных при загрузке
  static Future<void> cacheProjectData(legacy.Project project, String userId) async {
    if (_database == null) return;

    await _database!.insert(
      'projects',
      {
        'id': project.id,
        'name': project.name,
        'buildings': project.buildings.join(','),
        'last_sync': DateTime.now().millisecondsSinceEpoch,
        'user_id': userId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Кэширование юнитов
  static Future<void> cacheUnits(List<Unit> units, int projectId) async {
    if (_database == null) return;

    final batch = _database!.batch();
    for (final unit in units) {
      batch.insert(
        'units',
        {
          'id': unit.id,
          'name': unit.name,
          'floor': unit.floor,
          'project_id': projectId,
          'building': unit.building ?? '',
          'defects_data': '', // Дефекты кэшируются отдельно
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  // Кэширование дефектов
  static Future<void> cacheDefects(List<Defect> defects) async {
    if (_database == null) return;

    final batch = _database!.batch();
    for (final defect in defects) {
      batch.insert(
        'defects',
        {
          'id': defect.id,
          'description': defect.description,
          'type_id': defect.typeId,
          'status_id': defect.statusId,
          'received_at': defect.receivedAt,
          'fixed_at': defect.fixedAt,
          'is_warranty': defect.isWarranty ? 1 : 0,
          'project_id': defect.projectId,
          'unit_id': defect.unitId,
          'created_at': defect.createdAt,
          'updated_at': defect.updatedAt,
          'created_by': defect.createdBy,
          'updated_by': defect.updatedBy,
          'engineer_id': defect.engineerId,
          'brigade_id': defect.brigadeId,
          'contractor_id': defect.contractorId,
          'fixed_by': defect.fixedBy,
          'attachments_data': defect.attachments.map((a) => a.toJson()).toString(),
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  // Получение кэшированных проектов
  static Future<List<legacy.Project>> getCachedProjects(String userId) async {
    if (_database == null) return [];

    final maps = await _database!.query(
      'projects',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return maps.map((map) => legacy.Project(
      id: map['id'] as int,
      name: map['name'] as String,
      buildings: (map['buildings'] as String).split(','),
    )).toList();
  }

  // Получение кэшированных юнитов
  static Future<List<Unit>> getCachedUnits(int projectId, String? building) async {
    if (_database == null) return [];

    String where = 'project_id = ?';
    List<dynamic> whereArgs = [projectId];
    
    if (building != null) {
      where += ' AND building = ?';
      whereArgs.add(building);
    }

    final maps = await _database!.query(
      'units',
      where: where,
      whereArgs: whereArgs,
    );

    List<Unit> units = [];
    for (final map in maps) {
      // Получаем дефекты для этого юнита
      final defectMaps = await _database!.query(
        'defects',
        where: 'unit_id = ?',
        whereArgs: [map['id']],
      );
      
      final defects = defectMaps.map((defectMap) => _mapToDefect(defectMap)).toList();
      
      units.add(Unit(
        id: map['id'] as int,
        name: map['name'] as String,
        floor: map['floor'] as int?,
        building: map['building'] as String?,
        locked: false, // Default value for cached units
        defects: defects,
      ));
    }

    return units;
  }

  // Преобразование карты в объект Defect
  static Defect _mapToDefect(Map<String, dynamic> map) {
    return Defect(
      id: map['id'] as int,
      description: map['description'] as String,
      typeId: map['type_id'] as int?,
      statusId: map['status_id'] as int?,
      receivedAt: map['received_at'] as String?,
      fixedAt: map['fixed_at'] as String?,
      isWarranty: (map['is_warranty'] as int) == 1,
      projectId: map['project_id'] as int,
      unitId: map['unit_id'] as int?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      createdBy: map['created_by'] as String?,
      updatedBy: map['updated_by'] as String?,
      engineerId: map['engineer_id'] as String?,
      brigadeId: map['brigade_id'] as int?,
      contractorId: map['contractor_id'] as int?,
      fixedBy: map['fixed_by'] as String?,
      attachments: [], // Вложения обрабатываются отдельно
    );
  }

  // Добавление операции для синхронизации
  static Future<void> addPendingSync(String operationType, String entityType, int? entityId, Map<String, dynamic> data) async {
    if (_database == null) return;

    await _database!.insert('pending_sync', {
      'operation_type': operationType,
      'entity_type': entityType,
      'entity_id': entityId,
      'data': data.toString(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    _pendingSyncOperations.add('${operationType}_$entityId');
  }

  // Выполнение синхронизации
  static Future<bool> performSync() async {
    if (!_isOnline || _database == null) return false;

    try {
      // Получаем все операции для синхронизации
      final pendingOperations = await _database!.query('pending_sync', orderBy: 'created_at ASC');
      
      for (final operation in pendingOperations) {
        final operationType = operation['operation_type'] as String;
        final entityType = operation['entity_type'] as String;
        final entityId = operation['entity_id'] as int?;
        
        bool success = false;
        
        switch (operationType) {
          case 'update_defect_warranty':
            // Здесь вызываем реальный API для обновления гарантии
            success = await _syncDefectWarrantyUpdate(entityId!, operation['data'] as String);
            break;
          case 'create_defect':
            // Синхронизация создания дефекта
            success = await _syncDefectCreate(operation['data'] as String);
            break;
          // Добавить другие типы операций...
        }
        
        if (success) {
          await _database!.delete('pending_sync', where: 'id = ?', whereArgs: [operation['id']]);
          _pendingSyncOperations.remove('${operationType}_$entityId');
        }
      }
      
      // Синхронизация файлов
      await _syncLocalFiles();
      
      return true;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }

  // Синхронизация обновления гарантии дефекта
  static Future<bool> _syncDefectWarrantyUpdate(int defectId, String data) async {
    try {
      // Парсим данные и вызываем API
      final isWarranty = data.contains('true');
      final result = await DatabaseService.updateDefectWarranty(
        defectId: defectId,
        isWarranty: isWarranty,
      );
      return result != null;
    } catch (e) {
      print('Failed to sync defect warranty update: $e');
      return false;
    }
  }

  // Синхронизация создания дефекта
  static Future<bool> _syncDefectCreate(String data) async {
    try {
      // Здесь будет логика создания дефекта через API
      // Пока возвращаем true для тестирования
      return true;
    } catch (e) {
      print('Failed to sync defect creation: $e');
      return false;
    }
  }

  // Синхронизация локальных файлов
  static Future<void> _syncLocalFiles() async {
    if (_database == null) return;

    final unuploadedFiles = await _database!.query(
      'local_files',
      where: 'uploaded = 0',
    );

    for (final fileRecord in unuploadedFiles) {
      try {
        // Здесь будет логика загрузки файла на сервер
        // После успешной загрузки:
        // await _database!.update(
        //   'local_files',
        //   {'uploaded': 1},
        //   where: 'id = ?',
        //   whereArgs: [fileRecord['id']],
        // );
        
        _pendingSyncOperations.remove('upload_file_${fileRecord['id']}');
      } catch (e) {
        print('Failed to upload file ${fileRecord['file_path']}: $e');
      }
    }
  }

  // Очистка кэша
  static Future<void> clearCache() async {
    if (_database == null) return;

    await _database!.delete('projects');
    await _database!.delete('units');
    await _database!.delete('defects');
    await _database!.delete('defect_types');
    await _database!.delete('defect_statuses');
  }

  // Закрытие сервиса
  static Future<void> dispose() async {
    _syncTimer?.cancel();
    await _connectivityController.close();
    await _database?.close();
    _database = null;
  }
}