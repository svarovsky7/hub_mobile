import 'package:flutter/material.dart';
import '../../models/unit.dart';
import '../../models/defect_attachment.dart';
import '../../services/database_service.dart';
import '../../services/file_attachment_service.dart';
import '../../services/offline_service.dart';
import '../../widgets/file_attachment_widget.dart';
import 'dart:io';

class UnitDocumentArchivePage extends StatefulWidget {
  final Unit unit;

  const UnitDocumentArchivePage({
    super.key,
    required this.unit,
  });

  @override
  State<UnitDocumentArchivePage> createState() => _UnitDocumentArchivePageState();
}

class _UnitDocumentArchivePageState extends State<UnitDocumentArchivePage> {
  // Состояние раскрытия блоков
  bool _isUnitDocsExpanded = true;
  bool _isClaimDocsExpanded = false;
  bool _isDefectDocsExpanded = false;
  bool _isCourtDocsExpanded = false;
  bool _isLetterDocsExpanded = false;

  // Списки документов
  List<DefectAttachment> _unitDocuments = [];
  List<DefectAttachment> _claimDocuments = [];
  List<DefectAttachment> _defectDocuments = [];
  List<DefectAttachment> _courtDocuments = [];
  List<DefectAttachment> _letterDocuments = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllDocuments();
  }

  Future<void> _loadAllDocuments() async {
    setState(() => _isLoading = true);

    try {
      // Загружаем документы по объекту
      await _loadUnitDocuments();
      
      // Загружаем документы по замечаниям
      await _loadClaimDocuments();
      
      // Загружаем документы по дефектам
      await _loadDefectDocuments();
      
      // Загружаем документы по судебным делам
      await _loadCourtDocuments();
      
      // Загружаем файлы из писем
      await _loadLetterDocuments();
    } catch (e) {
      print('Error loading documents: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки документов: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUnitDocuments() async {
    try {
      final docs = await DatabaseService.getUnitDocuments(widget.unit.id);
      if (mounted) {
        setState(() {
          _unitDocuments = docs;
        });
      }
    } catch (e) {
      print('Error loading unit documents: $e');
    }
  }

  Future<void> _loadClaimDocuments() async {
    try {
      final docs = await DatabaseService.getClaimDocumentsByUnit(widget.unit.id);
      if (mounted) {
        setState(() {
          _claimDocuments = docs;
        });
      }
    } catch (e) {
      print('Error loading claim documents: $e');
    }
  }

  Future<void> _loadDefectDocuments() async {
    try {
      // Собираем все файлы из дефектов этого объекта
      final allDefectDocs = <DefectAttachment>[];
      for (final defect in widget.unit.defects) {
        final docs = await DatabaseService.getDefectAttachments(defect.id);
        allDefectDocs.addAll(docs);
      }
      
      if (mounted) {
        setState(() {
          _defectDocuments = allDefectDocs;
        });
      }
    } catch (e) {
      print('Error loading defect documents: $e');
    }
  }

  Future<void> _loadCourtDocuments() async {
    try {
      final docs = await DatabaseService.getCourtDocumentsByUnit(widget.unit.id);
      if (mounted) {
        setState(() {
          _courtDocuments = docs;
        });
      }
    } catch (e) {
      print('Error loading court documents: $e');
    }
  }

  Future<void> _loadLetterDocuments() async {
    try {
      final docs = await DatabaseService.getLetterDocumentsByUnit(widget.unit.id);
      if (mounted) {
        setState(() {
          _letterDocuments = docs;
        });
      }
    } catch (e) {
      print('Error loading letter documents: $e');
    }
  }

  Future<void> _attachFilesToUnit() async {
    _showAttachmentOptions();
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Прикрепить файл',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Сделать фото'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Выбрать файлы'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles(filesOnly: true);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    try {
      setState(() => _isLoading = true);
      
      final photo = await FileAttachmentService.takePhoto();
      if (photo != null) {
        await _attachFiles([photo]);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при создании фото: $e')),
        );
      }
    }
  }

  Future<void> _pickFiles({bool filesOnly = false}) async {
    try {
      setState(() => _isLoading = true);
      
      final files = await FileAttachmentService.pickFiles(
        allowMultiple: true,
        includeCamera: !filesOnly,
      );
      
      if (files.isNotEmpty) {
        await _attachFiles(files);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выборе файлов: $e')),
        );
      }
    }
  }

  Future<void> _attachFiles(List<File> files) async {
    try {
      final newAttachments = await FileAttachmentService.attachFilesToUnit(
        unitId: widget.unit.id,
        files: files,
      );
      
      setState(() {
        _unitDocuments.addAll(newAttachments);
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              OfflineService.isOnline
                  ? 'Файлы успешно прикреплены и загружены'
                  : 'Файлы сохранены локально. Автоматически загрузятся при восстановлении интернета.',
            ),
            backgroundColor: OfflineService.isOnline ? Colors.green : Colors.orange,
            duration: Duration(seconds: OfflineService.isOnline ? 2 : 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при прикреплении файлов: $e')),
        );
      }
    }
  }

  Future<void> _deleteUnitDocument(DefectAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text('Вы уверены, что хотите удалить файл "${attachment.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      
      await FileAttachmentService.deleteUnitAttachment(attachment);
      
      setState(() {
        _unitDocuments.removeWhere((a) => a.id == attachment.id);
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл удален')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления файла: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Архив документации'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllDocuments,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Информация об объекте
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Квартира ${widget.unit.name}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.unit.floor} этаж',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Блок 1: Документы по объекту
                  _buildDocumentBlock(
                    title: 'Документы по объекту',
                    documents: _unitDocuments,
                    isExpanded: _isUnitDocsExpanded,
                    onExpandedChanged: (expanded) {
                      setState(() => _isUnitDocsExpanded = expanded);
                    },
                    canEdit: true,
                    onAddFiles: _attachFilesToUnit,
                    onDeleteFile: _deleteUnitDocument,
                    icon: Icons.home,
                    iconColor: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  
                  // Блок 2: Документы по замечаниям
                  _buildDocumentBlock(
                    title: 'Документы по замечаниям',
                    documents: _claimDocuments,
                    isExpanded: _isClaimDocsExpanded,
                    onExpandedChanged: (expanded) {
                      setState(() => _isClaimDocsExpanded = expanded);
                    },
                    canEdit: false,
                    icon: Icons.warning_amber,
                    iconColor: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  
                  // Блок 3: Документы по дефектам
                  _buildDocumentBlock(
                    title: 'Документы по дефектам',
                    documents: _defectDocuments,
                    isExpanded: _isDefectDocsExpanded,
                    onExpandedChanged: (expanded) {
                      setState(() => _isDefectDocsExpanded = expanded);
                    },
                    canEdit: false,
                    icon: Icons.bug_report,
                    iconColor: Colors.red,
                  ),
                  const SizedBox(height: 8),
                  
                  // Блок 4: Документы по судебным делам
                  _buildDocumentBlock(
                    title: 'Документы по судебным делам',
                    documents: _courtDocuments,
                    isExpanded: _isCourtDocsExpanded,
                    onExpandedChanged: (expanded) {
                      setState(() => _isCourtDocsExpanded = expanded);
                    },
                    canEdit: false,
                    icon: Icons.gavel,
                    iconColor: Colors.brown,
                  ),
                  const SizedBox(height: 8),
                  
                  // Блок 5: Файлы из писем
                  _buildDocumentBlock(
                    title: 'Файлы из писем',
                    documents: _letterDocuments,
                    isExpanded: _isLetterDocsExpanded,
                    onExpandedChanged: (expanded) {
                      setState(() => _isLetterDocsExpanded = expanded);
                    },
                    canEdit: false,
                    icon: Icons.mail,
                    iconColor: Colors.blue,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDocumentBlock({
    required String title,
    required List<DefectAttachment> documents,
    required bool isExpanded,
    required ValueChanged<bool> onExpandedChanged,
    required bool canEdit,
    VoidCallback? onAddFiles,
    Function(DefectAttachment)? onDeleteFile,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpandedChanged,
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${documents.length} документов',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit && onAddFiles != null)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: onAddFiles,
                tooltip: 'Добавить файлы',
              ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
          ],
        ),
        children: [
          if (documents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Нет документов',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return ListTile(
                  leading: Icon(
                    doc.isImage ? Icons.image : Icons.insert_drive_file,
                    color: doc.isImage ? Colors.blue : Colors.grey,
                  ),
                  title: Text(doc.fileName),
                  subtitle: _buildDocumentStatus(doc),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () => _viewDocument(doc),
                        tooltip: 'Просмотреть',
                      ),
                      if (canEdit && onDeleteFile != null)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () => onDeleteFile(doc),
                          tooltip: 'Удалить',
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatus(DefectAttachment doc) {
    final isLocal = doc.filePath.startsWith('/') && !doc.filePath.startsWith('http');
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isLocal ? Icons.cloud_off : Icons.cloud_done,
          size: 12,
          color: isLocal ? Colors.orange : Colors.green,
        ),
        const SizedBox(width: 4),
        Text(
          isLocal ? 'Ожидает синхронизации' : 'Загружено',
          style: TextStyle(
            fontSize: 11,
            color: isLocal ? Colors.orange : Colors.green,
          ),
        ),
      ],
    );
  }

  void _viewDocument(DefectAttachment doc) async {
    await FileAttachmentWidget.openAttachmentWithSystem(context, doc);
  }
}