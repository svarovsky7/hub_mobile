import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  static DateTime? _lastConnectivityChange;
  static bool _isCurrentlySyncing = false;

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
      version: 4,
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

        // Таблица кешированных файлов с сервера
        await db.execute('''
          CREATE TABLE cached_attachments (
            id INTEGER PRIMARY KEY,
            defect_id INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_size INTEGER DEFAULT 0,
            created_by TEXT,
            created_at TEXT,
            last_sync INTEGER NOT NULL
          )
        ''');

        // Таблица бригад
        await db.execute('''
          CREATE TABLE brigades (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            last_sync INTEGER NOT NULL
          )
        ''');

        // Таблица подрядчиков
        await db.execute('''
          CREATE TABLE contractors (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            last_sync INTEGER NOT NULL
          )
        ''');

        // Таблица ожидающих синхронизации unit attachments
        await db.execute('''
          CREATE TABLE pending_unit_attachments (
            id INTEGER PRIMARY KEY,
            unit_id INTEGER NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_size INTEGER DEFAULT 0,
            created_at TEXT,
            sync_status TEXT DEFAULT 'pending',
            created_timestamp INTEGER NOT NULL
          )
        ''');

        // Таблица ожидающих удаления unit attachments
        await db.execute('''
          CREATE TABLE pending_unit_deletions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            attachment_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        // Таблица инженеров
        await db.execute('''
          CREATE TABLE engineers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            last_sync INTEGER NOT NULL
          )
        ''');

        // Индексы для быстрого поиска
        await db.execute('CREATE INDEX idx_units_project ON units(project_id)');
        await db.execute('CREATE INDEX idx_defects_project ON defects(project_id)');
        await db.execute('CREATE INDEX idx_defects_unit ON defects(unit_id)');
        await db.execute('CREATE INDEX idx_pending_sync_type ON pending_sync(operation_type)');
        await db.execute('CREATE INDEX idx_cached_attachments_defect ON cached_attachments(defect_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Добавляем таблицу кешированных файлов
          await db.execute('''
            CREATE TABLE cached_attachments (
              id INTEGER PRIMARY KEY,
              defect_id INTEGER NOT NULL,
              file_name TEXT NOT NULL,
              file_path TEXT NOT NULL,
              file_size INTEGER DEFAULT 0,
              created_by TEXT,
              created_at TEXT,
              last_sync INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_cached_attachments_defect ON cached_attachments(defect_id)');
        }
        if (oldVersion < 3) {
          // Добавляем таблицы бригад, подрядчиков и инженеров
          await db.execute('''
            CREATE TABLE brigades (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              last_sync INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE contractors (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              last_sync INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE engineers (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              last_sync INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          // Добавляем таблицы для unit attachments
          await db.execute('''
            CREATE TABLE pending_unit_attachments (
              id INTEGER PRIMARY KEY,
              unit_id INTEGER NOT NULL,
              file_name TEXT NOT NULL,
              file_path TEXT NOT NULL,
              file_size INTEGER DEFAULT 0,
              created_at TEXT,
              sync_status TEXT DEFAULT 'pending',
              created_timestamp INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE pending_unit_deletions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              attachment_id INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
        }
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
    final now = DateTime.now();
    
    // Проверяем, не было ли недавнего восстановления соединения
    if (_lastConnectivityChange != null && 
        now.difference(_lastConnectivityChange!).inSeconds < 5) {
      return; // Игнорируем частые изменения состояния
    }
    
    _lastConnectivityChange = now;
    print('Internet connection restored - starting full sync');
    
    try {
      // Проверяем незавершенные операции синхронизации
      await _resumeIncompleteSync();
      
      await _checkPendingSync();
      
      // Запускаем полную синхронизацию дефектов и файлов
      await _syncAllDefectsAndAttachments();
      
      // Синхронизируем unit attachments
      await syncUnitAttachments();
      
      if (hasPendingSync) {
        // Ждем немного и показываем уведомление о синхронизации
        await Future.delayed(const Duration(milliseconds: 500));
        // Здесь можно добавить глобальное уведомление через EventBus или Provider
      }
      
      print('Full sync completed after connectivity restoration');
    } catch (e) {
      print('Error during connectivity restoration sync: $e');
    }
  }

  // Полная синхронизация всех дефектов и вложений
  static Future<void> _syncAllDefectsAndAttachments() async {
    if (!_isOnline || _database == null) return;
    
    try {
      print('Starting full defects and attachments sync...');
      
      // Получаем все кешированные дефекты
      final cachedDefects = await _database!.query('defects');
      
      for (final defectMap in cachedDefects) {
        final defectId = defectMap['id'] as int;
        
        try {
          // Синхронизируем дефект с сервером
          final serverDefect = await DatabaseService.getDefectById(defectId);
          if (serverDefect != null) {
            await _updateCachedDefectFromServer(serverDefect);
          }
          
          // Синхронизируем вложения дефекта
          final serverAttachments = await DatabaseService.getDefectAttachments(defectId);
          await clearCachedAttachments(defectId);
          await cacheDefectAttachments(serverAttachments);
          
        } catch (e) {
          print('Error syncing defect $defectId: $e');
          // Продолжаем с следующим дефектом
        }
      }
      
      print('Full defects and attachments sync completed');
    } catch (e) {
      print('Error in _syncAllDefectsAndAttachments: $e');
    }
  }

  // Обновление кешированного дефекта данными с сервера
  static Future<void> _updateCachedDefectFromServer(Defect defect) async {
    if (_database == null) return;
    
    await _database!.update(
      'defects',
      {
        'description': defect.description,
        'is_warranty': defect.isWarranty ? 1 : 0,
        'status_id': defect.statusId,
        'type_id': defect.typeId,
        'received_at': defect.receivedAt,
        'fixed_by': defect.fixedBy,
        'last_sync': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [defect.id],
    );
  }

  // Возобновление незавершенной синхронизации
  static Future<void> _resumeIncompleteSync() async {
    if (_database == null) return;

    try {
      // Проверяем есть ли операции, которые были начаты, но не завершены
      final pendingOperations = await _database!.query('pending_sync');
      final unuploadedFiles = await _database!.query('local_files', where: 'uploaded = 0');
      
      if (pendingOperations.isNotEmpty || unuploadedFiles.isNotEmpty) {
        print('Resuming incomplete sync: ${pendingOperations.length} operations, ${unuploadedFiles.length} files');
        
        // Обновляем список ожидающих операций
        _pendingSyncOperations.clear();
        for (final op in pendingOperations) {
          _pendingSyncOperations.add('${op['operation_type']}_${op['entity_id']}');
        }
        
        for (final file in unuploadedFiles) {
          _pendingSyncOperations.add('upload_file_${file['id']}');
        }
      }
    } catch (e) {
      print('Error resuming incomplete sync: $e');
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

  // Кеширование списка проектов
  static Future<void> cacheProjects(List<legacy.Project> projects, String userId) async {
    if (_database == null) return;

    final batch = _database!.batch();
    for (final project in projects) {
      batch.insert(
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
    await batch.commit();
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
      
      final defects = await Future.wait(defectMaps.map((defectMap) => _mapToDefect(defectMap)));
      
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
  static Future<Defect> _mapToDefect(Map<String, dynamic> map) async {
    // Получаем кешированные файлы для этого дефекта
    final attachments = await getCachedAttachments(map['id'] as int);
    
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
      attachments: attachments,
    );
  }

  // Добавление операции для синхронизации
  static Future<void> addPendingSync(String operationType, String entityType, int? entityId, Map<String, dynamic> data) async {
    if (_database == null) return;

    await _database!.insert('pending_sync', {
      'operation_type': operationType,
      'entity_type': entityType,
      'entity_id': entityId,
      'data': jsonEncode(data), // Правильно кодируем в JSON
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    _pendingSyncOperations.add('${operationType}_$entityId');
  }

  // Кеширование файлов дефекта
  static Future<void> cacheDefectAttachments(List<DefectAttachment> attachments) async {
    if (_database == null) return;

    final batch = _database!.batch();
    for (final attachment in attachments) {
      batch.insert(
        'cached_attachments',
        {
          'id': attachment.id,
          'defect_id': attachment.defectId,
          'file_name': attachment.fileName,
          'file_path': attachment.filePath,
          'file_size': attachment.fileSize,
          'created_by': attachment.createdBy,
          'created_at': attachment.createdAt,
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  // Получение кешированных файлов дефекта
  static Future<List<DefectAttachment>> getCachedAttachments(int defectId) async {
    if (_database == null) {
      print('Database is null when getting cached attachments for defect $defectId');
      return [];
    }

    final maps = await _database!.query(
      'cached_attachments',
      where: 'defect_id = ?',
      whereArgs: [defectId],
      orderBy: 'created_at DESC',
    );

    print('Found ${maps.length} cached attachments for defect $defectId');
    for (final map in maps) {
      print('Cached attachment: ${map['file_name']} (ID: ${map['id']})');
    }

    return maps.map((map) => DefectAttachment(
      id: map['id'] as int,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      defectId: defectId,
      fileSize: (map['file_size'] as int?) ?? 0,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as String?,
    )).toList();
  }

  // Удаление кешированных файлов дефекта (для обновления)
  static Future<void> clearCachedAttachments(int defectId) async {
    if (_database == null) return;
    
    await _database!.delete(
      'cached_attachments',
      where: 'defect_id = ?',
      whereArgs: [defectId],
    );
  }

  // Обновление статуса дефекта в кеше
  static Future<void> updateCachedDefectStatus(int defectId, int statusId) async {
    if (_database == null) return;

    await _database!.update(
      'defects',
      {'status_id': statusId},
      where: 'id = ?',
      whereArgs: [defectId],
    );
  }

  // Получение дефекта из кеша
  static Future<Defect?> getCachedDefect(int defectId) async {
    if (_database == null) return null;

    try {
      final maps = await _database!.query(
        'defects',
        where: 'id = ?',
        whereArgs: [defectId],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      final map = maps.first;
      return Defect(
        id: map['id'] as int,
        description: map['description'] as String? ?? '',
        isWarranty: (map['is_warranty'] as int?) == 1,
        projectId: map['project_id'] as int? ?? 0,
        unitId: map['unit_id'] as int? ?? 0,
        statusId: map['status_id'] as int? ?? 0,
        typeId: map['type_id'] as int? ?? 0,
        attachments: [],
        receivedAt: map['received_at'] as String?,
      );
    } catch (e) {
      print('Error getting cached defect: $e');
      return null;
    }
  }

  // Кэширование бригад
  static Future<void> cacheBrigades(List<Map<String, dynamic>> brigades) async {
    if (_database == null) return;

    final batch = _database!.batch();
    for (final brigade in brigades) {
      batch.insert(
        'brigades',
        {
          'id': brigade['id'] as int,
          'name': brigade['name'] as String,
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  // Кэширование подрядчиков
  static Future<void> cacheContractors(List<Map<String, dynamic>> contractors) async {
    if (_database == null) return;

    final batch = _database!.batch();
    for (final contractor in contractors) {
      batch.insert(
        'contractors',
        {
          'id': contractor['id'] as int,
          'name': contractor['name'] as String,
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  // Кэширование инженеров
  static Future<void> cacheEngineers(List<Map<String, dynamic>> engineers) async {
    if (_database == null) return;

    final batch = _database!.batch();
    for (final engineer in engineers) {
      batch.insert(
        'engineers',
        {
          'id': engineer['id'] as String,
          'name': engineer['name'] as String,
          'last_sync': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  // Получение кешированных бригад
  static Future<List<Map<String, dynamic>>> getCachedBrigades() async {
    if (_database == null) return [];

    final maps = await _database!.query('brigades', orderBy: 'name ASC');
    return maps.map((map) => {
      'id': map['id'] as int,
      'name': map['name'] as String,
    }).toList();
  }

  // Получение кешированных подрядчиков
  static Future<List<Map<String, dynamic>>> getCachedContractors() async {
    if (_database == null) return [];

    final maps = await _database!.query('contractors', orderBy: 'name ASC');
    return maps.map((map) => {
      'id': map['id'] as int,
      'name': map['name'] as String,
    }).toList();
  }

  // Получение кешированных инженеров
  static Future<List<Map<String, dynamic>>> getCachedEngineers() async {
    if (_database == null) return [];

    final maps = await _database!.query('engineers', orderBy: 'name ASC');
    return maps.map((map) => {
      'id': map['id'] as String,
      'name': map['name'] as String,
    }).toList();
  }

  // Получить список файлов, ожидающих удаления
  static Future<List<int>> getPendingDeleteAttachmentIds() async {
    if (_database == null) return [];
    
    try {
      final pendingDeletes = await _database!.query(
        'pending_sync',
        where: 'operation_type = ?',
        whereArgs: ['delete_attachment'],
      );
      
      return pendingDeletes.map((operation) {
        final data = jsonDecode(operation['data'] as String) as Map<String, dynamic>;
        final attachmentId = data['attachment_id'];
        if (attachmentId is int) {
          return attachmentId;
        } else if (attachmentId is String) {
          return int.tryParse(attachmentId) ?? 0;
        }
        return 0;
      }).where((id) => id > 0).toList();
    } catch (e) {
      print('Error getting pending delete attachments: $e');
      return [];
    }
  }

  // Выполнение синхронизации
  static Future<bool> performSync({
    Function(double progress, String operation)? onProgress,
  }) async {
    if (!_isOnline || _database == null) return false;
    if (_isCurrentlySyncing) return false; // Предотвращаем повторную синхронизацию

    _isCurrentlySyncing = true;
    
    try {
      // Получаем все операции для синхронизации
      final pendingOperations = await _database!.query('pending_sync', orderBy: 'created_at ASC');
      final localFiles = await _database!.query('local_files', where: 'uploaded = 0');
      
      final totalOperations = pendingOperations.length + localFiles.length;
      if (totalOperations == 0) return true;
      
      int completedOperations = 0;
      
      // Синхронизация операций
      for (final operation in pendingOperations) {
        if (!_isOnline) {
          // Интернет пропал во время синхронизации
          _isCurrentlySyncing = false;
          return false;
        }
        
        final operationType = operation['operation_type'] as String;
        final entityId = operation['entity_id'] as int?;
        
        onProgress?.call(
          completedOperations / totalOperations,
          'Синхронизация $operationType...',
        );
        
        bool success = false;
        
        switch (operationType) {
          case 'update_defect_warranty':
            success = await _syncDefectWarrantyUpdate(entityId!, operation['data'] as String);
            break;
          case 'update_defect_status':
            success = await _syncDefectStatusUpdate(entityId!, operation['data'] as String);
            break;
          case 'create_defect':
            success = await _syncDefectCreate(operation['data'] as String);
            break;
          case 'delete_attachment':
            success = await _syncDeleteAttachment(entityId!, operation['data'] as String);
            break;
          case 'mark_defect_fixed':
            success = await _syncMarkDefectFixed(entityId!, operation['data'] as String);
            break;
        }
        
        if (success) {
          await _database!.delete('pending_sync', where: 'id = ?', whereArgs: [operation['id']]);
          _pendingSyncOperations.remove('${operationType}_$entityId');
          completedOperations++;
        }
      }
      
      // Синхронизация файлов
      for (final fileRecord in localFiles) {
        if (!_isOnline) {
          // Интернет пропал во время синхронизации
          _isCurrentlySyncing = false;
          return false;
        }
        
        final fileName = fileRecord['original_name'] as String;
        onProgress?.call(
          completedOperations / totalOperations,
          'Загрузка файла $fileName...',
        );
        
        final success = await _syncSingleFile(fileRecord);
        if (success) {
          completedOperations++;
        }
      }
      
      // Финальный прогресс
      onProgress?.call(1.0, 'Завершение синхронизации...');
      
      // После успешной синхронизации проверяем, остались ли еще операции
      await _checkPendingSync();
      
      _isCurrentlySyncing = false;
      return true;
    } catch (e) {
      print('Sync error: $e');
      _isCurrentlySyncing = false;
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

  // Синхронизация обновления статуса дефекта
  static Future<bool> _syncDefectStatusUpdate(int defectId, String data) async {
    try {
      print('Syncing defect status update with data: $data');
      final dataMap = Map<String, dynamic>.from(jsonDecode(data));
      final statusId = dataMap['status_id'] as int;
      
      // Вызываем Supabase API напрямую для обновления статуса
      final supabase = DatabaseService.supabaseClient;
      await supabase
          .from('defects')
          .update({
            'status_id': statusId,
            'updated_by': supabase.auth.currentUser?.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', defectId);
      
      return true;
    } catch (e) {
      print('Failed to sync defect status update: $e');
      return false;
    }
  }

  // Синхронизация удаления вложения
  static Future<bool> _syncDeleteAttachment(int defectId, String data) async {
    try {
      print('Syncing attachment deletion with data: $data');
      // Парсим JSON данные
      final dataMap = Map<String, dynamic>.from(jsonDecode(data));
      final attachmentId = dataMap['attachment_id'] as int;
      
      // Вызываем API для удаления
      final result = await DatabaseService.deleteDefectAttachment(attachmentId);
      
      if (result) {
        // После успешного удаления на сервере, обновляем локальный кеш
        // Получаем актуальный список вложений с сервера
        final updatedAttachments = await DatabaseService.getDefectAttachments(defectId);
        
        // Очищаем старый кеш и сохраняем обновленный список
        await clearCachedAttachments(defectId);
        await cacheDefectAttachments(updatedAttachments);
        
        print('Successfully synced attachment deletion and updated cache');
      }
      
      return result;
    } catch (e) {
      print('Failed to sync attachment deletion: $e');
      return false;
    }
  }

  // Синхронизация отправки дефекта на проверку
  static Future<bool> _syncMarkDefectFixed(int defectId, String data) async {
    try {
      print('Syncing mark defect fixed with data: $data');
      final dataMap = Map<String, dynamic>.from(jsonDecode(data));
      final executorId = dataMap['executor_id'] as int;
      final isOwnExecutor = dataMap['is_own_executor'] as bool;
      final engineerId = dataMap['engineer_id'] as String;
      final fixDate = DateTime.parse(dataMap['fix_date'] as String);
      
      // Вызываем API для отправки на проверку
      final result = await DatabaseService.markDefectAsFixed(
        defectId: defectId,
        executorId: executorId,
        isOwnExecutor: isOwnExecutor,
        engineerId: engineerId,
        fixDate: fixDate,
      );
      return result != null;
    } catch (e) {
      print('Failed to sync mark defect fixed: $e');
      return false;
    }
  }

  // Синхронизация одного файла
  static Future<bool> _syncSingleFile(Map<String, dynamic> fileRecord) async {
    try {
      final filePath = fileRecord['file_path'] as String;
      final fileName = fileRecord['original_name'] as String;
      final file = File(filePath);

      if (await file.exists()) {
        final fileBytes = await file.readAsBytes();
        final attachment = await DatabaseService.uploadDefectAttachment(
          defectId: fileRecord['entity_id'] as int,
          fileName: fileName,
          fileBytes: fileBytes,
        );

        if (attachment != null) {
          await _database!.update(
            'local_files',
            {'uploaded': 1},
            where: 'id = ?',
            whereArgs: [fileRecord['id']],
          );
          
          _pendingSyncOperations.remove('upload_file_${fileRecord['id']}');
          print('Successfully synced file: $fileName');
          return true;
        }
      } else {
        // Файл не существует, удаляем запись
        await _database!.delete(
          'local_files',
          where: 'id = ?',
          whereArgs: [fileRecord['id']],
        );
        _pendingSyncOperations.remove('upload_file_${fileRecord['id']}');
      }
      
      return false;
    } catch (e) {
      print('Failed to sync file: $e');
      return false;
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
    await _database!.delete('brigades');
    await _database!.delete('contractors');
    await _database!.delete('engineers');
    await _database!.delete('cached_attachments');
  }

  // Закрытие сервиса
  static Future<void> dispose() async {
    _syncTimer?.cancel();
    await _connectivityController.close();
    await _database?.close();
    _database = null;
  }


  // Получить кешированные документы объекта
  static Future<List<DefectAttachment>> getCachedUnitAttachments(int unitId) async {
    if (_database == null) return [];
    
    try {
      final attachments = <DefectAttachment>[];

      // Получаем pending attachments из новой таблицы
      final pendingMaps = await _database!.query(
        'pending_unit_attachments',
        where: 'unit_id = ? AND sync_status = ?',
        whereArgs: [unitId, 'pending'],
      );

      for (final map in pendingMaps) {
        try {
          attachments.add(DefectAttachment(
            id: map['id'] as int,
            defectId: unitId,
            fileName: map['file_name'] as String,
            filePath: map['file_path'] as String,
            fileSize: map['file_size'] as int,
            createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
          ));
        } catch (e) {
          print('Error parsing pending unit attachment data: $e');
        }
      }

      // Также проверяем старую таблицу для совместимости
      final results = await _database!.query(
        'pending_sync',
        where: 'operation_type = ? AND entity_id = ? AND entity_type = ?',
        whereArgs: ['upload_unit_attachment', unitId, 'unit'],
      );
      
      for (final row in results) {
        try {
          final data = jsonDecode(row['data'] as String);
          attachments.add(DefectAttachment(
            id: data['id'],
            defectId: data['defectId'],
            fileName: data['fileName'] ?? 'Без названия',
            filePath: data['filePath'] ?? '',
            fileSize: data['fileSize'] ?? 0,
            createdAt: data['createdAt'],
          ));
        } catch (e) {
          print('Error parsing unit attachment data: $e');
        }
      }
      
      return attachments;
    } catch (e) {
      print('Error getting cached unit attachments: $e');
      return [];
    }
  }

  // Сохранение unit attachment для последующей синхронизации
  static Future<void> saveUnitAttachmentForSync(int unitId, DefectAttachment attachment) async {
    try {
      final db = _database;
      if (db == null) {
        print('Error: Database not initialized');
        return;
      }

      await db.insert('pending_unit_attachments', {
        'unit_id': unitId,
        'id': attachment.id,
        'file_name': attachment.fileName,
        'file_path': attachment.filePath,
        'file_size': attachment.fileSize,
        'created_at': attachment.createdAt,
        'sync_status': 'pending',
        'created_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      print('Saved unit attachment for sync: unitId=$unitId, fileName=${attachment.fileName}');
    } catch (e) {
      print('Error saving unit attachment for sync: $e');
    }
  }

  // Получение pending unit attachments для синхронизации
  static Future<List<Map<String, dynamic>>> getPendingUnitAttachments() async {
    try {
      final db = _database;
      if (db == null) return [];

      final maps = await db.query(
        'pending_unit_attachments',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
      );

      return maps;
    } catch (e) {
      print('Error getting pending unit attachments: $e');
      return [];
    }
  }

  // Помечаем unit attachment как синхронизированный
  static Future<void> markUnitAttachmentAsSynced(int id) async {
    try {
      final db = _database;
      if (db == null) return;

      await db.update(
        'pending_unit_attachments',
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [id],
      );

      print('Marked unit attachment as synced: id=$id');
    } catch (e) {
      print('Error marking unit attachment as synced: $e');
    }
  }

  // Удаление unit attachment из очереди синхронизации
  static Future<void> removeUnitAttachmentFromSync(int id) async {
    try {
      final db = _database;
      if (db == null) return;

      await db.delete(
        'pending_unit_attachments',
        where: 'id = ?',
        whereArgs: [id],
      );

      print('Removed unit attachment from sync: id=$id');
    } catch (e) {
      print('Error removing unit attachment from sync: $e');
    }
  }

  // Добавление unit attachment в очередь на удаление
  static Future<void> addUnitAttachmentToDeleteQueue(int attachmentId) async {
    try {
      final db = _database;
      if (db == null) return;

      await db.insert('pending_unit_deletions', {
        'attachment_id': attachmentId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      print('Added unit attachment to delete queue: attachmentId=$attachmentId');
    } catch (e) {
      print('Error adding unit attachment to delete queue: $e');
    }
  }

  // Синхронизация unit attachments
  static Future<bool> syncUnitAttachments() async {
    if (!_isOnline) return false;

    try {
      final pendingAttachments = await getPendingUnitAttachments();
      
      for (final pending in pendingAttachments) {
        try {
          final file = File(pending['file_path']);
          if (!await file.exists()) {
            await markUnitAttachmentAsSynced(pending['id']);
            continue;
          }

          // Загружаем файл в storage
          final originalFileName = pending['file_name'];
          final unitId = pending['unit_id'];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_$originalFileName';
          final storagePath = 'unit_attachments/$unitId/$fileName';
          
          await DatabaseService.supabaseClient.storage
              .from('attachments')
              .upload(storagePath, file);
          
          // Получаем публичный URL файла
          final publicUrl = DatabaseService.supabaseClient.storage
              .from('attachments')
              .getPublicUrl(storagePath);
          
          // Получаем текущего пользователя
          final user = DatabaseService.supabaseClient.auth.currentUser;
          final userId = user?.id;
          
          // Определяем MIME тип файла
          final mimeType = _getMimeType(originalFileName);
          
          // Создаем запись в таблице attachments
          final attachmentResponse = await DatabaseService.supabaseClient
              .from('attachments')
              .insert({
                'path': publicUrl,
                'storage_path': storagePath,
                'original_name': originalFileName,
                'mime_type': mimeType,
                'uploaded_by': userId,
                'created_by': userId,
              })
              .select()
              .single();
          
          // Создаем связь в unit_attachments
          await DatabaseService.supabaseClient
              .from('unit_attachments')
              .insert({
                'unit_id': unitId,
                'attachment_id': attachmentResponse['id'],
              });

          await markUnitAttachmentAsSynced(pending['id']);
          print('Successfully synced unit attachment: $originalFileName');
        } catch (e) {
          print('Failed to sync unit attachment ${pending['file_name']}: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error during unit attachments sync: $e');
      return false;
    }
  }

  // Определение MIME типа файла
  static String _getMimeType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/avi';
      default:
        return 'application/octet-stream';
    }
  }
}