# Hub Mobile - Система управления дефектами · Agent Definition
_Last updated: 2025-07-13_

## 0 · Purpose

Данный файл определяет правила, которые должны соблюдать **агенты ИИ** при генерации или ревью кода для мобильного приложения **Hub Mobile** (Flutter). Приложение потребляет **существующую Supabase базу данных** и должно обеспечивать современный UX с быстрой работой и офлайн-поддержкой.

---

## 1 · Принципы высокого уровня

| Цель | Требование |
|------|-------------|
| **Производительность** | Запуск < 2 сек; отклик UI < 100мс; lazy loading для списков >1000 элементов |
| **Современный UX** | Material Design 3; темная/светлая темы; плавные анимации 60fps |
| **Офлайн-first** | Кеширование данных; синхронизация в фоне; работа без интернета |
| **Качество кода** | Feature-Sliced Design; файлы < 500 строк; строгая типизация Dart |

---

## 2 · Архитектура · Feature-Sliced Design

```
lib/
├── app/                    # Инициализация приложения
│   ├── di/                # Dependency Injection (GetIt)
│   ├── router/            # Навигация (GoRouter)
│   ├── theme/             # Material 3 темы
│   └── cache/             # Кеш менеджер
├── shared/                # Общие компоненты
│   ├── api/               # Supabase клиенты
│   ├── cache/             # Стратегии кеширования
│   ├── ui/                # UI Kit (Material 3)
│   ├── utils/             # Утилиты и хелперы
│   └── config/            # Конфигурация
├── entities/              # Бизнес-сущности
│   ├── project/           # Проект (модель + репозиторий)
│   ├── unit/              # Квартира/юнит
│   ├── defect/            # Дефект
│   ├── attachment/        # Файлы и вложения
│   └── user/              # Пользователь и профиль
├── features/              # Бизнес-функции
│   ├── auth/              # Авторизация
│   ├── defect_tracking/   # Трекинг дефектов
│   ├── file_management/   # Управление файлами
│   ├── offline_sync/      # Офлайн синхронизация
│   └── project_selector/  # Выбор проекта
├── widgets/               # Переиспользуемые виджеты
│   ├── defect_card/       # Карточка дефекта
│   ├── status_chip/       # Чип статуса
│   ├── unit_grid/         # Сетка квартир
│   └── attachment_list/   # Список файлов
└── pages/                 # Страницы (экраны)
    ├── splash/            # Загрузочный экран
    ├── auth/              # Авторизация
    ├── dashboard/         # Главная панель
    ├── projects/          # Список проектов
    ├── building_units/    # Шахматка квартир
    └── defect_details/    # Детали дефекта
```

**Правила FSD:**
- Каждый слой имеет **публичный API** через `index.dart`
- Импорты только "вниз" по иерархии
- UI и бизнес-логика в одном слое
- Абсолютные импорты через алиасы

---

## 3 · Технологический стек

| Слой | Технология |
|------|------------|
| **Язык** | Dart 3.6+ (null safety, records, patterns) |
| **Фреймворк** | Flutter 3.24+ (Material 3, Impeller) |
| **Навигация** | GoRouter 14+ с deep linking |
| **Состояние** | BLoC 8+ + Freezed для immutable моделей |
| **База данных** | Supabase (PostgreSQL + Realtime) |
| **Локальное хранение** | SQLite (drift) + Hive для кеша |
| **DI** | GetIt + Injectable для автогенерации |
| **Сеть** | Dio + Retrofit для REST API |
| **Изображения** | cached_network_image с оптимизацией |

---

## 4 · Современный UI/UX

### Material Design 3
```dart
// app/theme/app_theme.dart
class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    // Кастомные компоненты
    extensions: [
      CustomColors.light,
      CustomTextStyles.light,
    ],
  );
}
```

### UI Kit компоненты
```dart
// shared/ui/components/
├── buttons/
│   ├── app_button.dart          # Основная кнопка
│   ├── icon_button.dart         # Иконочная кнопка
│   └── floating_action_button.dart
├── cards/
│   ├── elevated_card.dart       # Карточка с тенью
│   ├── outlined_card.dart       # Карточка с рамкой
│   └── filled_card.dart         # Заполненная карточка
├── inputs/
│   ├── app_text_field.dart      # Текстовое поле
│   ├── app_dropdown.dart        # Выпадающий список
│   └── file_picker_field.dart   # Выбор файлов
├── feedback/
│   ├── loading_overlay.dart     # Загрузка поверх контента
│   ├── empty_state.dart         # Пустое состояние
│   ├── error_banner.dart        # Баннер ошибки
│   └── success_snackbar.dart    # Успешное действие
└── layout/
    ├── adaptive_scaffold.dart   # Адаптивный скаффолд
    ├── responsive_grid.dart     # Адаптивная сетка
    └── safe_area_wrapper.dart   # Обертка safe area
```

### Анимации и переходы
- **Hero анимации** для навигации между экранами
- **Implicit анимации** для изменений состояний
- **Staggered анимации** для списков элементов
- **Pull-to-refresh** с кастомной анимацией
- **Skeleton loading** во время загрузки данных

---

## 5 · Кеширование и офлайн-поддержка

### Стратегии кеширования
```dart
// shared/cache/cache_strategy.dart
enum CacheStrategy {
  cacheFirst,          // Сначала кеш, потом сеть
  networkFirst,        // Сначала сеть, потом кеш  
  staleWhileRevalidate, // Показать кеш, обновить в фоне
  cacheOnly,           // Только кеш (офлайн режим)
  networkOnly,         // Только сеть (критичные данные)
}
```

### Офлайн синхронизация
```dart
// features/offline_sync/
├── bloc/
│   ├── sync_bloc.dart           # Управление синхронизацией
│   └── sync_state.dart          # Состояния синхронизации
├── repository/
│   ├── sync_repository.dart     # Репозиторий синхронизации
│   └── conflict_resolver.dart   # Разрешение конфликтов
├── models/
│   ├── sync_operation.dart      # Операция синхронизации
│   └── sync_conflict.dart       # Конфликт данных
└── services/
    ├── background_sync.dart     # Фоновая синхронизация
    └── connectivity_service.dart # Мониторинг соединения
```

### Локальная база данных
```dart
// entities/defect/data/local/
├── defect_dao.dart             # Data Access Object
├── defect_entity.dart          # Локальная entity
└── defect_mapper.dart          # Маппинг domain ↔ local

// shared/database/
├── app_database.dart           # Основная база Drift
├── tables/                     # Таблицы БД
└── migrations/                 # Миграции схемы
```

---

## 6 · Управление состоянием

### BLoC + Freezed pattern
```dart
// entities/defect/bloc/defect_bloc.dart
@injectable
class DefectBloc extends Bloc<DefectEvent, DefectState> {
  DefectBloc(this._repository) : super(DefectState.initial()) {
    on<DefectEvent>((event, emit) async {
      await event.when(
        load: () => _onLoad(emit),
        create: (dto) => _onCreate(dto, emit),
        update: (id, dto) => _onUpdate(id, dto, emit),
        delete: (id) => _onDelete(id, emit),
      );
    });
  }
}

// Immutable состояния с Freezed
@freezed
class DefectState with _$DefectState {
  const factory DefectState.initial() = _Initial;
  const factory DefectState.loading() = _Loading;
  const factory DefectState.loaded(List<Defect> defects) = _Loaded;
  const factory DefectState.error(String message) = _Error;
}
```

### Dependency Injection
```dart
// app/di/injection.dart
@InjectableInit()
void configureDependencies() => getIt.init();

@module
abstract class DatabaseModule {
  @singleton
  AppDatabase get database => AppDatabase();
  
  @lazySingleton
  SupabaseClient get supabase => Supabase.instance.client;
}
```

---

## 7 · Производительность

### Оптимизация списков
```dart
// widgets/defect_list/defect_list.dart
class DefectList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Важно: используем itemExtent для фиксированной высоты
      itemExtent: 120,
      // Кешируем виджеты для переиспользования
      addAutomaticKeepAlives: true,
      cacheExtent: 1000, // Кешируем элементы за пределами экрана
      itemBuilder: (context, index) {
        return DefectCard(
          defect: defects[index],
          // Memo для предотвращения лишних перерисовок
          key: ValueKey(defects[index].id),
        );
      },
    );
  }
}
```

### Lazy loading и пагинация
```dart
// features/defect_tracking/bloc/defect_list_bloc.dart
class DefectListBloc extends Bloc<DefectListEvent, DefectListState> {
  static const _pageSize = 20;
  
  Future<void> _onLoadMore(emit) async {
    if (state.hasReachedMax) return;
    
    final defects = await _repository.getDefects(
      offset: state.defects.length,
      limit: _pageSize,
    );
    
    emit(state.copyWith(
      defects: [...state.defects, ...defects],
      hasReachedMax: defects.length < _pageSize,
    ));
  }
}
```

### Оптимизация изображений
```dart
// shared/ui/widgets/optimized_image.dart
class OptimizedImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(color: Colors.white),
      ),
      errorWidget: (context, url, error) => Icon(Icons.error),
      // Автоматическое изменение размера
      fit: BoxFit.cover,
      // Кеширование на диске
      cacheManager: DefaultCacheManager(),
    );
  }
}
```

---

## 8 · Supabase интеграция

### Типобезопасные запросы
```dart
// entities/defect/data/remote/defect_remote_datasource.dart
@injectable
class DefectRemoteDataSource {
  final SupabaseClient _client;
  
  Future<List<DefectDto>> getDefects(int unitId) async {
    final response = await _client
        .from('defects')
        .select('''
          id, description, status_id, type_id, created_at,
          statuses!inner(id, name, color),
          defect_types!inner(id, name)
        ''')
        .eq('unit_id', unitId)
        .order('created_at', ascending: false);
    
    return response.map(DefectDto.fromJson).toList();
  }
}
```

### Realtime подписки
```dart
// entities/defect/data/remote/defect_realtime_service.dart
@injectable  
class DefectRealtimeService {
  late final RealtimeChannel _channel;
  
  Stream<DefectRealtimeEvent> watchDefects(int unitId) {
    return _client
        .channel('defects:$unitId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'defects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'unit_id',
            value: unitId,
          ),
        )
        .map((payload) => DefectRealtimeEvent.fromPayload(payload));
  }
}
```

---

## 9 · Тестирование

### Unit тесты
```dart
// test/entities/defect/bloc/defect_bloc_test.dart
void main() {
  group('DefectBloc', () {
    late MockDefectRepository mockRepository;
    late DefectBloc defectBloc;

    setUp(() {
      mockRepository = MockDefectRepository();
      defectBloc = DefectBloc(mockRepository);
    });

    blocTest<DefectBloc, DefectState>(
      'emits [loading, loaded] when defects are loaded successfully',
      build: () => defectBloc,
      act: (bloc) => bloc.add(DefectEvent.load()),
      expect: () => [
        DefectState.loading(),
        DefectState.loaded(mockDefects),
      ],
    );
  });
}
```

### Widget тесты
```dart
// test/widgets/defect_card/defect_card_test.dart
void main() {
  testWidgets('DefectCard displays defect information', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefectCard(defect: mockDefect),
      ),
    );

    expect(find.text(mockDefect.description), findsOneWidget);
    expect(find.text(mockDefect.status.name), findsOneWidget);
  });
}
```

### Покрытие тестами
- **Unit тесты**: ≥85% для бизнес-логики
- **Widget тесты**: ≥70% для UI компонентов  
- **Integration тесты**: критические сценарии пользователя

---

## 10 · Файловая структура проекта

### Naming conventions
- **Файлы**: `snake_case.dart`
- **Классы**: `PascalCase`
- **Переменные/функции**: `camelCase`
- **Константы**: `SCREAMING_SNAKE_CASE`

### Максимальные размеры
- **Файл**: ≤500 строк кода (без импортов/комментариев)
- **Класс**: ≤300 строк
- **Метод**: ≤50 строк
- **Параметры**: ≤5 на метод

### Структура файлов
```dart
// Порядок секций в файле
// 1. Импорты (сначала dart:, потом package:, потом локальные)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../models/defect.dart';

// 2. Класс/виджет
@injectable
class DefectRepository {
  // 3. Поля (константы, затем переменные)
  static const String _tableName = 'defects';
  final SupabaseClient _client;
  
  // 4. Конструктор
  DefectRepository(this._client);
  
  // 5. Публичные методы
  Future<List<Defect>> getDefects() async {
    // implementation
  }
  
  // 6. Приватные методы  
  void _logError(String message) {
    // implementation
  }
}
```

---

## 11 · Обработка ошибок

### Централизованная обработка
```dart
// shared/error/app_error.dart
@freezed
class AppError with _$AppError implements Exception {
  const factory AppError.network(String message) = NetworkError;
  const factory AppError.cache(String message) = CacheError;
  const factory AppError.validation(String field, String message) = ValidationError;
  const factory AppError.unknown(String message) = UnknownError;
}

// shared/error/error_handler.dart
@injectable
class ErrorHandler {
  void handleError(AppError error) {
    error.when(
      network: (msg) => _showNetworkError(msg),
      cache: (msg) => _logCacheError(msg),
      validation: (field, msg) => _showValidationError(field, msg),
      unknown: (msg) => _reportUnknownError(msg),
    );
  }
}
```

### Error boundaries
```dart
// shared/ui/widgets/error_boundary.dart
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final Widget Function(Object error)? errorBuilder;
  
  @override
  Widget build(BuildContext context) {
    return ErrorWidget.builder = (FlutterErrorDetails details) {
      return errorBuilder?.call(details.exception) ?? 
             DefaultErrorWidget(error: details.exception);
    };
  }
}
```

---

## 12 · Локализация

### Генерация переводов
```dart
// shared/l10n/app_localizations.dart
@GenerateMocks([AppLocalizations])
abstract class AppLocalizations {
  String get defectCreated;
  String get defectUpdated;
  String defectStatus(String status);
  String defectCount(int count);
}

// Использование в UI
Text(context.l10n.defectCreated)
```

### Поддерживаемые локали
- `ru` - Русский (основной)
- `en` - English (fallback)

---

## 13 · CI/CD Pipeline

### GitHub Actions
```yaml
# .github/workflows/ci.yml
name: CI/CD
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter analyze
      - run: dart format --set-exit-if-changed .
      
  test:
    runs-on: ubuntu-latest  
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
      
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter build apk --release
```

### Качество кода
- **0 ошибок** анализатора Dart
- **0 warnings** линтера
- **Форматирование** dart format
- **Покрытие тестами** ≥80%

---

## 14 · Environment Variables

```dart
// shared/config/app_config.dart
@injectable
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const bool isProduction = bool.fromEnvironment('PRODUCTION');
}
```

---

## 15 · Мониторинг и аналитика

### Crashlytics интеграция
```dart
// app/app.dart
class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          FirebaseCrashlytics.instance.recordFlutterError(details);
          return ErrorBoundary(error: details.exception);
        };
        return child!;
      },
    );
  }
}
```

### Performance мониторинг
```dart
// shared/monitoring/performance_monitor.dart
@injectable
class PerformanceMonitor {
  void trackScreenLoad(String screenName) {
    FirebasePerformance.instance
        .newTrace('screen_load_$screenName')
        .start();
  }
  
  void trackApiCall(String endpoint) {
    FirebasePerformance.instance
        .newHttpTrace(endpoint)
        .start();
  }
}
```

---

## 16 · Чек-лист перед коммитом

Перед каждым коммитом должны пройти:

```bash
# Анализ кода
flutter analyze

# Форматирование
dart format .

# Тесты
flutter test

# Сборка
flutter build apk --debug
```

Коммит валиден **только** если все команды завершились с кодом `0`.

---

## 17 · Роль агента (для ИИ помощников)

> **Вы выступаете в роли Senior Flutter Developer**, поддерживающего приложение Hub Mobile.
> 
> **Строго следуйте** данному документу, **спрашивайте уточнения** при отсутствии спецификации, и **оптимизируйте** производительность, developer experience и user experience во всех задачах.
>
> **Приоритеты при разработке:**
> 1. **Быстродействие** - приложение должно отвечать мгновенно
> 2. **Офлайн-поддержка** - работа без интернета критически важна  
> 3. **Современный UX** - следование Material Design 3
> 4. **Чистый код** - Feature-Sliced Design и строгая типизация
> 5. **Тестируемость** - каждая фича покрыта тестами

---