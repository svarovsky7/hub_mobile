import 'defect_attachment.dart';

class Defect {
  final int id;
  final String description;
  final int? typeId;
  final int? statusId;
  final String? receivedAt;
  final String? fixedAt;
  final bool isWarranty;
  final int projectId;
  final int? unitId;
  final String? createdAt;
  final String? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String? engineerId;
  final int? brigadeId;
  final int? contractorId;
  final String? fixedBy;
  final List<DefectAttachment> attachments;

  Defect({
    required this.id,
    required this.description,
    this.typeId,
    this.statusId,
    this.receivedAt,
    this.fixedAt,
    this.isWarranty = false,
    required this.projectId,
    this.unitId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.engineerId,
    this.brigadeId,
    this.contractorId,
    this.fixedBy,
    this.attachments = const [],
  });

  factory Defect.fromJson(Map<String, dynamic> json) {
    return Defect(
      id: json['id'],
      description: json['description'] ?? '',
      typeId: json['type_id'],
      statusId: json['status_id'],
      receivedAt: json['received_at'],
      fixedAt: json['fixed_at'],
      isWarranty: json['is_warranty'] ?? false,
      projectId: json['project_id'],
      unitId: json['unit_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      engineerId: json['engineer_id'],
      brigadeId: json['brigade_id'],
      contractorId: json['contractor_id'],
      fixedBy: json['fixed_by'],
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((attachment) => DefectAttachment.fromJson(attachment))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'type_id': typeId,
      'status_id': statusId,
      'received_at': receivedAt,
      'fixed_at': fixedAt,
      'is_warranty': isWarranty,
      'project_id': projectId,
      'unit_id': unitId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'engineer_id': engineerId,
      'brigade_id': brigadeId,
      'contractor_id': contractorId,
      'fixed_by': fixedBy,
      'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
    };
  }

  Defect copyWith({
    int? id,
    String? description,
    int? typeId,
    int? statusId,
    String? receivedAt,
    String? fixedAt,
    bool? isWarranty,
    int? projectId,
    int? unitId,
    String? createdAt,
    String? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? engineerId,
    int? brigadeId,
    int? contractorId,
    String? fixedBy,
    List<DefectAttachment>? attachments,
  }) {
    return Defect(
      id: id ?? this.id,
      description: description ?? this.description,
      typeId: typeId ?? this.typeId,
      statusId: statusId ?? this.statusId,
      receivedAt: receivedAt ?? this.receivedAt,
      fixedAt: fixedAt ?? this.fixedAt,
      isWarranty: isWarranty ?? this.isWarranty,
      projectId: projectId ?? this.projectId,
      unitId: unitId ?? this.unitId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      engineerId: engineerId ?? this.engineerId,
      brigadeId: brigadeId ?? this.brigadeId,
      contractorId: contractorId ?? this.contractorId,
      fixedBy: fixedBy ?? this.fixedBy,
      attachments: attachments ?? this.attachments,
    );
  }
}