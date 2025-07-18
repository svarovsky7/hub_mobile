import 'defect.dart';

class Unit {
  final int id;
  final int? projectId;
  final String name;
  final String? building;
  final int? floor;
  final String? personId;
  final bool locked;
  final List<Defect> defects;

  Unit({
    required this.id,
    this.projectId,
    required this.name,
    this.building,
    this.floor,
    this.personId,
    required this.locked,
    required this.defects,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'],
      projectId: json['project_id'],
      name: json['name'],
      building: json['building'],
      floor: json['floor'],
      personId: json['person_id'],
      locked: json['locked'] ?? false,
      defects: (json['defects'] as List?)
          ?.map((defect) => Defect.fromJson(defect))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'building': building,
      'floor': floor,
      'person_id': personId,
      'locked': locked,
      'defects': defects.map((defect) => defect.toJson()).toList(),
    };
  }

  Unit copyWith({
    int? id,
    int? projectId,
    String? name,
    String? building,
    int? floor,
    String? personId,
    bool? locked,
    List<Defect>? defects,
  }) {
    return Unit(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      personId: personId ?? this.personId,
      locked: locked ?? this.locked,
      defects: defects ?? this.defects,
    );
  }

  // Статус юнита по дефектам (на основе приоритета статусов)
  UnitStatus getStatus() {
    if (defects.isEmpty) return UnitStatus.noDefects;
    
    final statusIds = defects
        .where((d) => d.statusId != null)
        .map((d) => d.statusId!)
        .toList();
    
    if (statusIds.isEmpty) return UnitStatus.noDefects;
    
    // Определяем приоритет статусов (чем меньше число, тем выше приоритет)
    final priorityOrder = [1, 2, 9, 4, 7, 8, 10, 3]; // Новый -> В работе -> На проверке -> Отклонен -> Прочие -> Устранен
    
    // Находим статус с наивысшим приоритетом
    int? highestPriorityStatus;
    for (final priority in priorityOrder) {
      if (statusIds.contains(priority)) {
        highestPriorityStatus = priority;
        break;
      }
    }
    
    // Если не найден в приоритетах, берем первый доступный
    final finalStatusId = highestPriorityStatus ?? statusIds.first;
    
    // Маппим статус дефекта на статус юнита
    switch (finalStatusId) {
      case 1: // Получен
        return UnitStatus.hasNew;
      case 2: // В работе
        return UnitStatus.inProgress;
      case 3: // Устранен
        return UnitStatus.completed;
      case 4: // Отклонен
        return UnitStatus.rejected;
      case 7: // Фиолетовый статус
        return UnitStatus.hasDefects;
      case 8: // Оранжевый статус
        return UnitStatus.inProgress;
      case 9: // На проверку
        return UnitStatus.onReview;
      case 10: // Зеленый статус
        return UnitStatus.completed;
      default:
        return UnitStatus.hasDefects;
    }
  }
}

enum UnitStatus {
  noDefects,
  hasNew,
  inProgress,
  completed,
  rejected,
  onReview,
  hasDefects,
}