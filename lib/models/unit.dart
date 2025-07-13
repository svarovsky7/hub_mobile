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

  // Статус юнита по дефектам
  UnitStatus getStatus() {
    if (defects.isEmpty) return UnitStatus.noDefects;
    
    final hasNew = defects.any((d) => d.statusId == 1);
    final hasInProgress = defects.any((d) => d.statusId == 2);
    final allCompleted = defects.every((d) => d.statusId == 3 || d.statusId == 4);
    
    if (hasNew) return UnitStatus.hasNew;
    if (hasInProgress) return UnitStatus.inProgress;
    if (allCompleted) return UnitStatus.completed;
    return UnitStatus.hasDefects;
  }
}

enum UnitStatus {
  noDefects,
  hasNew,
  inProgress,
  completed,
  hasDefects,
}