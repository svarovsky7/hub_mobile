class Project {
  final int id;
  final String name;
  final List<String> buildings;

  Project({
    required this.id,
    required this.name,
    this.buildings = const [],
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Project && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      buildings: json['buildings'] != null 
        ? List<String>.from(json['buildings'])
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
}

class DefectType {
  final int id;
  final String name;

  DefectType({
    required this.id,
    required this.name,
  });
}

class DefectStatus {
  final int id;
  final String entity;
  final String name;
  final String color;

  DefectStatus({
    required this.id,
    required this.entity,
    required this.name,
    required this.color,
  });
}

class ClaimStatus {
  final int id;
  final String entity;
  final String name;
  final String color;

  ClaimStatus({
    required this.id,
    required this.entity,
    required this.name,
    required this.color,
  });
}