class Project {
  const Project({
    required this.id,
    required this.name,
    this.buildings = const [],
  });

  final int id;
  final String name;
  final List<String> buildings;

  Project copyWith({
    int? id,
    String? name,
    List<String>? buildings,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      buildings: buildings ?? this.buildings,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      name: json['name'] as String,
      buildings: json['buildings'] != null
          ? List<String>.from(json['buildings'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'buildings': buildings,
    };
  }
}

class DefectType {
  const DefectType({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory DefectType.fromJson(Map<String, dynamic> json) {
    return DefectType(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class DefectStatus {
  const DefectStatus({
    required this.id,
    required this.entity,
    required this.name,
    required this.color,
  });

  final int id;
  final String entity;
  final String name;
  final String color;

  factory DefectStatus.fromJson(Map<String, dynamic> json) {
    return DefectStatus(
      id: json['id'] as int,
      entity: json['entity'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity': entity,
      'name': name,
      'color': color,
    };
  }
}

class ClaimStatus {
  const ClaimStatus({
    required this.id,
    required this.entity,
    required this.name,
    required this.color,
  });

  final int id;
  final String entity;
  final String name;
  final String color;

  factory ClaimStatus.fromJson(Map<String, dynamic> json) {
    return ClaimStatus(
      id: json['id'] as int,
      entity: json['entity'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity': entity,
      'name': name,
      'color': color,
    };
  }
}