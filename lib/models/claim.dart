class Claim {
  final int id;
  final int projectId;
  final int claimStatusId;
  final String claimNo;
  final String claimedOn;
  final String? acceptedOn;
  final String? registeredOn;
  final String? resolvedOn;
  final String? engineerId;
  final String description;
  final String? createdBy;
  final String createdAt;
  final String? updatedBy;
  final String updatedAt;
  final String? caseUidId;
  final bool preTrialClaim;
  final String? owner;
  final List<int> unitIds;

  Claim({
    required this.id,
    required this.projectId,
    required this.claimStatusId,
    required this.claimNo,
    required this.claimedOn,
    this.acceptedOn,
    this.registeredOn,
    this.resolvedOn,
    this.engineerId,
    required this.description,
    this.createdBy,
    required this.createdAt,
    this.updatedBy,
    required this.updatedAt,
    this.caseUidId,
    required this.preTrialClaim,
    this.owner,
    required this.unitIds,
  });

  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      id: json['id'],
      projectId: json['project_id'],
      claimStatusId: json['claim_status_id'],
      claimNo: json['claim_no'],
      claimedOn: json['claimed_on'],
      acceptedOn: json['accepted_on'],
      registeredOn: json['registered_on'],
      resolvedOn: json['resolved_on'],
      engineerId: json['engineer_id'],
      description: json['description'],
      createdBy: json['created_by'],
      createdAt: json['created_at'],
      updatedBy: json['updated_by'],
      updatedAt: json['updated_at'],
      caseUidId: json['case_uid_id'],
      preTrialClaim: json['pre_trial_claim'] ?? false,
      owner: json['owner'],
      unitIds: List<int>.from(json['unit_ids'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'claim_status_id': claimStatusId,
      'claim_no': claimNo,
      'claimed_on': claimedOn,
      'accepted_on': acceptedOn,
      'registered_on': registeredOn,
      'resolved_on': resolvedOn,
      'engineer_id': engineerId,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_by': updatedBy,
      'updated_at': updatedAt,
      'case_uid_id': caseUidId,
      'pre_trial_claim': preTrialClaim,
      'owner': owner,
      'unit_ids': unitIds,
    };
  }

  Claim copyWith({
    int? id,
    int? projectId,
    int? claimStatusId,
    String? claimNo,
    String? claimedOn,
    String? acceptedOn,
    String? registeredOn,
    String? resolvedOn,
    String? engineerId,
    String? description,
    String? createdBy,
    String? createdAt,
    String? updatedBy,
    String? updatedAt,
    String? caseUidId,
    bool? preTrialClaim,
    String? owner,
    List<int>? unitIds,
  }) {
    return Claim(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      claimStatusId: claimStatusId ?? this.claimStatusId,
      claimNo: claimNo ?? this.claimNo,
      claimedOn: claimedOn ?? this.claimedOn,
      acceptedOn: acceptedOn ?? this.acceptedOn,
      registeredOn: registeredOn ?? this.registeredOn,
      resolvedOn: resolvedOn ?? this.resolvedOn,
      engineerId: engineerId ?? this.engineerId,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      caseUidId: caseUidId ?? this.caseUidId,
      preTrialClaim: preTrialClaim ?? this.preTrialClaim,
      owner: owner ?? this.owner,
      unitIds: unitIds ?? this.unitIds,
    );
  }
}