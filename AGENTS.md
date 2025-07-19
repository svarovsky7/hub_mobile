# Hub Mobile - Система управления дефектами · Agent Definition
_Last updated: 2025-07-19_

## 0 · Purpose

Данный файл определяет правила, которые должны соблюдать **агенты ИИ** при генерации или ревью кода для мобильного приложения **Hub Mobile** (Flutter). Приложение работает с **существующей Supabase базой данных** и обеспечивает современный UX с быстрой работой и **полной офлайн-поддержкой**.

---

## 1 · Текущее состояние проекта

### Реализованные функции
- ✅ **Авторизация пользователей** через Supabase Auth
- ✅ **Управление проектами** с выбором по умолчанию
- ✅ **Шахматка квартир** с цветовыми статусами дефектов
- ✅ **Карточки дефектов** с компактным дизайном
- ✅ **Переключатель гарантии** для каждого дефекта
- ✅ **Полная офлайн-поддержка** с SQLite кешированием
- ✅ **Синхронизация данных** при восстановлении соединения
- ✅ **Система вложений файлов** с поддержкой камеры/галереи
- ✅ **Открытие файлов** системными приложениями по умолчанию
- ✅ **Индикатор соединения** с уведомлениями об офлайн-режиме

### Текущая архитектура
```
lib/
├── app/                          # Инициализация приложения
│   ├── app.dart                 # Главный класс App
│   └── theme/                   # Material 3 темы
├── entities/                    # BLoC управление состоянием
│   └── project/                 # Управление проектами
├── models/                      # Модели данных
│   ├── project.dart            # Проект
│   ├── unit.dart               # Квартира/юнит  
│   ├── defect.dart             # Дефект
│   ├── claim.dart              # Претензия
│   └── defect_attachment.dart  # Файловые вложения
├── services/                    # Бизнес-сервисы
│   ├── database_service.dart   # Основной API сервис (Supabase)
│   ├── offline_service.dart    # Офлайн кеширование (SQLite)
│   ├── file_attachment_service.dart # Управление файлами
│   └── sync_notification_service.dart # Уведомления о синхронизации
├── pages/                       # Страницы приложения
│   ├── dashboard/              # Главная панель с шахматкой
│   ├── building_units/         # Список квартир
│   └── defect_details/         # Детали дефектов
├── widgets/                     # Переиспользуемые виджеты
│   ├── defect_card/            # Карточка дефекта
│   ├── app_drawer.dart         # Боковая панель навигации
│   ├── connectivity_indicator.dart # Индикатор соединения
│   └── file_attachment_widget.dart # Виджет файлов
├── shared/ui/components/        # UI Kit компоненты
│   ├── buttons/                # Кнопки
│   ├── cards/                  # Карточки
│   └── feedback/               # Обратная связь (загрузка, ошибки)
└── providers/                   # Provider для состояния
    └── theme_provider.dart     # Управление темой
```

---

## 2 · Принципы высокого уровня

| Цель | Требование | Статус |
|------|------------|--------|
| **Производительность** | Запуск < 2 сек; отклик UI < 100мс; lazy loading | ✅ Реализовано |
| **Офлайн-first** | Полная работа без интернета; синхронизация в фоне | ✅ Реализовано |
| **Современный UX** | Material Design 3; компактный дизайн; плавные анимации | ✅ Реализовано |
| **Качество кода** | Строгая типизация Dart; файлы < 500 строк | ✅ Соблюдается |

---

## 3 · Технологический стек

| Компонент | Технология | Использование |
|-----------|------------|---------------|
| **Язык** | Dart 3.6+ | Null safety, современный синтаксис |
| **Фреймворк** | Flutter 3.24+ | Material 3, современный UI |
| **Состояние** | BLoC 8+ + Provider | Управление состоянием проектов |
| **База данных** | Supabase PostgreSQL | Основное хранилище данных |
| **Локальный кеш** | SQLite (sqflite) | Офлайн кеширование данных |
| **Настройки** | SharedPreferences | Пользовательские предпочтения |
| **Сеть** | Supabase Client + http | API запросы и мониторинг соединения |
| **Файлы** | file_picker + image_picker | Выбор файлов и камера |
| **Системные файлы** | open_file | Открытие файлов системными приложениями |

---

## 4 · Офлайн-архитектура (Критически важно)

### Принцип работы
```dart
// services/offline_service.dart
class OfflineService {
  static Database? _database;
  static bool _isOnline = true;
  static final Set<String> _pendingSyncOperations = {};

  // Основные методы
  static Future<void> cacheProjectData(Project project, String userId);
  static Future<List<Project>> getCachedProjects(String userId);
  static Future<void> addPendingSync(String operationType, String entityType, int? entityId, Map<String, dynamic> data);
  static Future<bool> performSync();
}
```

### SQLite схема
```sql
-- Кешированные проекты
CREATE TABLE projects (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  buildings TEXT NOT NULL, -- JSON массив корпусов
  last_sync INTEGER NOT NULL,
  user_id TEXT NOT NULL
);

-- Кешированные квартиры
CREATE TABLE units (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  floor INTEGER,
  project_id INTEGER NOT NULL,
  building TEXT NOT NULL,
  last_sync INTEGER NOT NULL
);

-- Кешированные дефекты
CREATE TABLE defects (
  id INTEGER PRIMARY KEY,
  description TEXT NOT NULL,
  type_id INTEGER,
  status_id INTEGER,
  is_warranty INTEGER NOT NULL DEFAULT 0,
  project_id INTEGER NOT NULL,
  unit_id INTEGER,
  last_sync INTEGER NOT NULL
);

-- Очередь синхронизации
CREATE TABLE pending_sync (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_type TEXT NOT NULL, -- 'update_defect_warranty', 'create_defect', etc.
  entity_type TEXT NOT NULL,    -- 'defect', 'claim', etc.
  entity_id INTEGER,
  data TEXT NOT NULL,           -- JSON данные операции
  created_at INTEGER NOT NULL
);

-- Локальные файлы (для офлайн загрузки)
CREATE TABLE local_files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_path TEXT NOT NULL,     -- Путь к локальному файлу
  original_name TEXT NOT NULL, -- Оригинальное имя файла
  entity_type TEXT NOT NULL,   -- 'defect'
  entity_id INTEGER NOT NULL,  -- ID дефекта
  uploaded INTEGER DEFAULT 0,  -- 0 = не загружен, 1 = загружен
  created_at INTEGER NOT NULL
);
```

### Стратегия синхронизации
1. **При подключении к интернету:** загрузка и кеширование всех данных пользователя
2. **В офлайн режиме:** работа только с кешированными данными
3. **При изменениях офлайн:** добавление операций в очередь синхронизации
4. **При восстановлении соединения:** автоматическая синхронизация изменений

---

## 5 · Система файловых вложений

### FileAttachmentService
```dart
// services/file_attachment_service.dart
class FileAttachmentService {
  // Выбор файлов из разных источников
  static Future<List<File>> pickFiles({bool allowMultiple = true, bool includeCamera = true});
  static Future<File?> takePhoto();
  
  // Прикрепление к дефектам с офлайн поддержкой
  static Future<List<DefectAttachment>> attachFilesToDefect({required int defectId, required List<File> files});
  
  // Офлайн файлы
  static Future<List<DefectAttachment>> getLocalAttachments(int defectId);
  static Future<bool> syncLocalFiles();
}
```

### FileAttachmentWidget
- **Интерактивный UI** для управления файлами дефекта
- **Поддержка офлайн режима** с визуальными индикаторами
- **Выбор источника:** камера, галерея, файловая система
- **Просмотр файлов** с открытием системными приложениями
- **Индикаторы статуса:** локальный/загруженный файл

---

## 6 · UI/UX Компоненты

### Современный дизайн
```dart
// widgets/defect_card/defect_card.dart
class DefectCard extends StatefulWidget {
  // Компактный дизайн с уменьшенными размерами текста
  // Переключатель гарантии с состоянием загрузки
  // Расширяемые детали с файловыми вложениями
  // Callback система для обновления родительских виджетов
}
```

### Индикатор соединения
```dart
// widgets/connectivity_indicator.dart
class ConnectivityIndicator extends StatefulWidget {
  // Оранжевая полоса при отсутствии соединения
  // Показ количества операций для синхронизации
  // Автоматическое скрытие при восстановлении соединения
}
```

### AppDrawer с проектами
```dart
// widgets/app_drawer.dart  
class AppDrawer extends StatefulWidget {
  // Список доступных проектов пользователя
  // Статистика по выбранному проекту (не глобальная!)
  // Возможность установки проекта по умолчанию (звездочка)
  // Сохранение выбора в SharedPreferences
}
```

---

## 7 · Модели данных

### Основные модели
```dart
// models/defect.dart
class Defect {
  final int id;
  final String description;
  final int? typeId;
  final int? statusId;
  final bool isWarranty;        // Ключевое поле для переключателя
  final int projectId;
  final int? unitId;
  final List<DefectAttachment> attachments;
  
  // Метод copyWith для immutable обновлений
  Defect copyWith({bool? isWarranty, List<DefectAttachment>? attachments});
}

// models/unit.dart  
class Unit {
  final int id;
  final String name;
  final int? floor;
  final String? building;
  final bool locked;            // Обязательное поле!
  final List<Defect> defects;
  
  // Автоматический расчет статуса на основе дефектов
  UnitStatus getStatus();
}

// models/defect_attachment.dart
class DefectAttachment {
  final int id;
  final int defectId;
  final String fileName;
  final String filePath;        // Локальный путь или URL
  final int fileSize;           // Обязательное поле!
  final String? createdAt;
  
  // Геттеры для определения типа файла
  bool get isImage;
  String get fileExtension;
}
```

---

## 8 · Критические паттерны

### Callback система для обновлений
```dart
// Важно: используйте callbacks для передачи изменений вверх по иерархии виджетов
class DefectCard extends StatefulWidget {
  final Function(Defect)? onDefectUpdated;  // Callback для родительского виджета
  
  // При изменении дефекта
  void _updateDefect() {
    widget.onDefectUpdated?.call(updatedDefect);
  }
}
```

### Проверка офлайн режима
```dart
// Всегда проверяйте состояние соединения перед API вызовами
if (!OfflineService.isOnline) {
  // Сохранить операцию для синхронизации
  await OfflineService.addPendingSync('update_defect_warranty', 'defect', defectId, data);
  return locallyUpdatedObject;
}
```

### Уведомления о синхронизации
```dart
// services/sync_notification_service.dart
class SyncNotificationService {
  // Показывает overlay уведомление при восстановлении соединения
  // Информирует о количестве операций для синхронизации
  static void showSyncNotification(BuildContext context);
}
```

---

## 9 · Обработка ошибок

### Принципы
1. **Graceful degradation** - приложение продолжает работать при ошибках API
2. **Информативные сообщения** - понятные пользователю уведомления
3. **Fallback на офлайн** - автоматический переход к кешированным данным
4. **Retry механизмы** - повторные попытки критичных операций

### Паттерн обработки
```dart
try {
  final result = await DatabaseService.updateDefectWarranty(defectId: id, isWarranty: value);
  if (result != null) {
    // Успешное онлайн обновление
    widget.onDefectUpdated?.call(result);
  } else {
    // Сохранить для офлайн синхронизации
    await OfflineService.addPendingSync('update_defect_warranty', 'defect', id, {'is_warranty': value});
    final localUpdated = defect.copyWith(isWarranty: value);
    widget.onDefectUpdated?.call(localUpdated);
  }
} catch (e) {
  // Показать ошибку пользователю
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
}
```

---

## 10 · Производительность

### Оптимизации
- **Lazy loading** для больших списков дефектов
- **Кеширование изображений** с compressed_network_image
- **Pagination** для загрузки данных по частям  
- **Debounced search** для поиска с задержкой
- **Optimistic updates** для мгновенного отклика UI

### Мониторинг производительности  
- **Build context** - избегайте лишних пересборок виджетов
- **Memory leaks** - правильное управление подписками и контроллерами
- **Database queries** - эффективные SQL запросы с индексами

---

## 11 · Тестирование

### Требования к покрытию
- **Unit тесты**: ≥80% для бизнес-логики (services, models)
- **Widget тесты**: ≥70% для UI компонентов
- **Integration тесты**: критические пользовательские сценарии

### Приоритетные области для тестирования
1. **OfflineService** - критична для работы приложения
2. **FileAttachmentService** - сложная логика файлов
3. **DatabaseService** - основной API слой
4. **DefectCard** - ключевой UI компонент
5. **Sync операции** - корректность синхронизации

---

## 12 · Чек-лист перед коммитом

```bash
# 1. Анализ кода (0 ошибок!)
flutter analyze

# 2. Форматирование
dart format .

# 3. Тесты (если есть)
flutter test

# 4. Проверка сборки
flutter build apk --debug
```

**Коммит валиден только при успешном выполнении всех команд!**

---

## 13 · Роль агента (для ИИ помощников)

> **Вы выступаете в роли Senior Flutter Developer**, поддерживающего приложение Hub Mobile.
> 
> **Строго следуйте** архитектуре, описанной в данном документе, **спрашивайте уточнения** при неясности требований, и **приоритизируйте** стабильность офлайн-работы.
>
> **Приоритеты при разработке:**
> 1. **Офлайн-поддержка** - приложение должно работать без интернета
> 2. **Стабильность данных** - никогда не терять пользовательские изменения  
> 3. **Производительность** - мгновенный отклик UI
> 4. **Простота использования** - интуитивный и компактный интерфейс
> 5. **Качество кода** - читаемый, тестируемый, maintainable код

### Ключевые правила при разработке

#### ✅ ОБЯЗАТЕЛЬНО делать:
- Проверять `OfflineService.isOnline` перед API вызовами
- Использовать `callback` функции для передачи изменений вверх по иерархии
- Добавлять операции в `pending_sync` при офлайн изменениях
- Показывать пользователю состояние загрузки и ошибки
- Сохранять все required параметры в конструкторах моделей
- Использовать `copyWith` для immutable обновлений объектов

#### ❌ ЗАПРЕЩЕНО:
- Создавать новые файлы без острой необходимости - всегда редактировать существующие
- Игнорировать офлайн режим - каждая функция должна работать без интернета
- Нарушать существующую архитектуру файлов и папок
- Создавать breaking changes в публичных API методов
- Забывать про обязательные параметры в конструкторах (например, `locked` в Unit)

#### 🔧 При исправлении ошибок:
1. Сначала понять существующую архитектуру
2. Найти корень проблемы, не маскировать симптомы  
3. Протестировать исправление в офлайн и онлайн режимах
4. Убедиться в отсутствии breaking changes
5. Обновить документацию при необходимости

---

**Этот документ является единым источником истины для всех архитектурных решений проекта Hub Mobile.**