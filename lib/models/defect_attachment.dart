class DefectAttachment {
  final int id;
  final int defectId;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String? createdBy;
  final String? createdAt;

  DefectAttachment({
    required this.id,
    required this.defectId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    this.createdBy,
    this.createdAt,
  });

  factory DefectAttachment.fromJson(Map<String, dynamic> json) {
    return DefectAttachment(
      id: json['id'],
      defectId: json['defect_id'],
      fileName: json['name'] ?? 'file',
      filePath: json['path'] ?? '',
      fileSize: json['size'] ?? 0,
      createdBy: json['created_by'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'defect_id': defectId,
      'name': fileName,
      'path': filePath,
      'size': fileSize,
      'created_by': createdBy,
      'created_at': createdAt,
    };
  }

  String get fileExtension => fileName.split('.').last.toLowerCase();
  
  bool get isImage => ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension);
  
  String get formattedSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}