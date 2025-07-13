import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/unit.dart';
import '../models/defect.dart';
import '../models/claim.dart';
import '../models/project.dart';
import '../models/defect_attachment.dart';
import '../services/database_service.dart';

class DefectTrackerScreen extends StatefulWidget {
  const DefectTrackerScreen({super.key});

  @override
  State<DefectTrackerScreen> createState() => _DefectTrackerScreenState();
}

class _DefectTrackerScreenState extends State<DefectTrackerScreen> {
  List<Unit> units = [];
  List<Claim> claims = [];
  List<Project> projects = [];
  String currentView = 'home';
  String activeTab = 'building';
  Unit? selectedUnit;
  bool showMenu = false;
  Project? selectedProject;
  String? selectedBuilding;
  bool isLoading = true;
  bool showOnlyDefects = false; // Фильтр для отображения только квартир с дефектами
  
  // Форма для нового дефекта
  final _descriptionController = TextEditingController();
  int? _selectedDefectTypeId;
  DateTime _selectedDate = DateTime.now();
  bool _isWarranty = true;

  // Типы дефектов и статусы загружаются из БД
  List<DefectType> defectTypes = [];
  List<DefectStatus> defectStatuses = [];
  List<ClaimStatus> claimStatuses = [];
  
  // Контроллеры для горизонтальной прокрутки шахматки (один для каждого этажа)
  final Map<int, ScrollController> _floorScrollControllers = {};
  
  // Вложения для дефектов
  final Map<int, List<DefectAttachment>> _defectAttachments = {};
  
  // Состояние развернутых секций файлов
  final Set<int> _expandedAttachments = {};

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  // Загрузка начальных данных
  Future<void> loadInitialData() async {
    setState(() => isLoading = true);
    
    try {
      // Загружаем проекты
      projects = await DatabaseService.getProjects();
      
      // Загружаем типы дефектов и статусы
      defectTypes = await DatabaseService.getDefectTypes();
      defectStatuses = await DatabaseService.getDefectStatuses();
      print('Loaded ${defectTypes.length} defect types and ${defectStatuses.length} defect statuses');
      
      if (projects.isNotEmpty) {
        selectedProject = projects.first;
        print('Initial project selected: ${selectedProject!.name} (ID: ${selectedProject!.id})');
        
        // Загружаем корпуса для первого проекта
        final buildings = await DatabaseService.getBuildingsForProject(selectedProject!.id);
        print('Initial buildings loaded: ${buildings.length} buildings: $buildings');
        selectedProject = selectedProject!.copyWith(buildings: buildings);
        
        if (buildings.isNotEmpty) {
          selectedBuilding = buildings.first;
          print('Initial building selected: $selectedBuilding');
          await loadUnitsForCurrentSelection();
        }
      }
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Загрузка юнитов для текущего выбора
  Future<void> loadUnitsForCurrentSelection() async {
    if (selectedProject == null || selectedBuilding == null) return;
    
    try {
      final result = await DatabaseService.getUnitsWithDefectsForBuilding(
        selectedProject!.id, 
        selectedBuilding!
      );
      
      setState(() {
        units = result['units'] as List<Unit>;
      });
    } catch (e) {
      print('Error loading units: $e');
    }
  }

  // Получить цвет юнита
  Color getUnitColor(UnitStatus status) {
    switch (status) {
      case UnitStatus.noDefects:
        return Colors.grey.shade100;
      case UnitStatus.hasNew:
        return Colors.red.shade100;
      case UnitStatus.inProgress:
        return Colors.yellow.shade100;
      case UnitStatus.completed:
        return Colors.green.shade100;
      default:
        return Colors.blue.shade100;
    }
  }

  // Получить цвет границы юнита
  Color getUnitBorderColor(UnitStatus status) {
    switch (status) {
      case UnitStatus.noDefects:
        return Colors.grey.shade300;
      case UnitStatus.hasNew:
        return Colors.red.shade400;
      case UnitStatus.inProgress:
        return Colors.yellow.shade400;
      case UnitStatus.completed:
        return Colors.green.shade400;
      default:
        return Colors.blue.shade400;
    }
  }

  // Получить цвет текста юнита
  Color getUnitTextColor(UnitStatus status) {
    switch (status) {
      case UnitStatus.noDefects:
        return Colors.grey.shade700;
      case UnitStatus.hasNew:
        return Colors.red.shade800;
      case UnitStatus.inProgress:
        return Colors.yellow.shade800;
      case UnitStatus.completed:
        return Colors.green.shade800;
      default:
        return Colors.blue.shade800;
    }
  }

  // Получить статистику
  Map<String, int> getStatistics() {
    final totalUnits = units.length;
    final unitsWithDefects = units.where((unit) => unit.defects.isNotEmpty).length;
    final totalDefects = units.fold(0, (sum, unit) => sum + unit.defects.length);
    final completedDefects = units.fold(0, (sum, unit) => 
      sum + unit.defects.where((d) => d.statusId == 3).length);

    return {
      'totalUnits': totalUnits,
      'unitsWithDefects': unitsWithDefects,
      'totalDefects': totalDefects,
      'completedDefects': completedDefects,
    };
  }

  // Открыть юнит
  void openUnit(Unit unit) {
    setState(() {
      selectedUnit = unit;
      currentView = 'apartment';
    });
    _loadDefectAttachments();
  }

  // Сменить проект
  Future<void> changeProject(Project project) async {
    setState(() => isLoading = true);
    
    try {
      print('Changing to project: ${project.name} (ID: ${project.id})');
      selectedProject = project;
      
      // Загружаем корпуса для нового проекта
      final buildings = await DatabaseService.getBuildingsForProject(project.id);
      print('Loaded ${buildings.length} buildings: $buildings');
      selectedProject = selectedProject!.copyWith(buildings: buildings);
      
      if (buildings.isNotEmpty) {
        selectedBuilding = buildings.first;
        print('Selected building: $selectedBuilding');
        await loadUnitsForCurrentSelection();
      } else {
        print('No buildings found for project ${project.id}');
        selectedBuilding = null;
        units.clear();
      }
    } catch (e) {
      print('Error changing project: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Сменить корпус
  Future<void> changeBuilding(String building) async {
    if (selectedProject == null) return;
    
    setState(() => isLoading = true);
    
    try {
      selectedBuilding = building;
      await loadUnitsForCurrentSelection();
    } catch (e) {
      print('Error changing building: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Добавить дефект
  Future<void> addDefect() async {
    if (_descriptionController.text.isEmpty || _selectedDefectTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все обязательные поля')),
      );
      return;
    }

    if (selectedProject == null || selectedUnit == null) return;

    try {
      final newDefect = await DatabaseService.addDefect(
        description: _descriptionController.text,
        typeId: _selectedDefectTypeId!,
        receivedAt: _selectedDate.toIso8601String().split('T')[0],
        isWarranty: _isWarranty,
        projectId: selectedProject!.id,
        unitId: selectedUnit!.id,
      );

      if (newDefect != null) {
        // Обновляем локальные данные
        setState(() {
          final unitIndex = units.indexWhere((u) => u.id == selectedUnit!.id);
          if (unitIndex != -1) {
            units[unitIndex] = units[unitIndex].copyWith(
              defects: [...units[unitIndex].defects, newDefect],
            );
            selectedUnit = units[unitIndex];
          }
          
          // Очистить форму
          _descriptionController.clear();
          _selectedDefectTypeId = null;
          _selectedDate = DateTime.now();
          _isWarranty = true;
          
          currentView = 'apartment';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Дефект успешно добавлен')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при добавлении дефекта'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Обновить статус дефекта
  Future<void> updateDefectStatus(int defectId, int newStatusId) async {
    try {
      final updatedDefect = await DatabaseService.updateDefectStatus(
        defectId: defectId,
        statusId: newStatusId,
      );
      
      if (updatedDefect != null) {
        setState(() {
          final unitIndex = units.indexWhere((u) => u.id == selectedUnit!.id);
          if (unitIndex != -1) {
            final defectIndex = units[unitIndex].defects.indexWhere((d) => d.id == defectId);
            if (defectIndex != -1) {
              final updatedDefects = List<Defect>.from(units[unitIndex].defects);
              updatedDefects[defectIndex] = updatedDefect;
              
              units[unitIndex] = units[unitIndex].copyWith(defects: updatedDefects);
              selectedUnit = units[unitIndex];
            }
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при обновлении статуса: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    // Освобождаем все контроллеры прокрутки этажей
    for (final controller in _floorScrollControllers.values) {
      controller.dispose();
    }
    _floorScrollControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (selectedProject == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Нет доступных проектов'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loadInitialData,
                child: const Text('Обновить'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (currentView == 'home' && activeTab == 'building') 
              _buildBuildingScreen(),
            if (currentView == 'apartment') 
              _buildApartmentScreen(),
            if (currentView == 'addDefect') 
              _buildAddDefectScreen(),
            
            // Нижняя навигация
            if (currentView == 'home') 
              _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingScreen() {
    final stats = getStatistics();
    
    return Column(
      children: [
        // Заголовок
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Выпадающее меню проектов
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: selectedProject?.id,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                            iconSize: 20,
                            elevation: 16,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            underline: Container(),
                            dropdownColor: Colors.blue.shade700,
                            isExpanded: true,
                            menuMaxHeight: 300, // Добавляем прокрутку
                            onChanged: (int? newProjectId) {
                              if (newProjectId != null) {
                                try {
                                  final newProject = projects.firstWhere((p) => p.id == newProjectId);
                                  if (newProject != selectedProject) {
                                    changeProject(newProject);
                                  }
                                } catch (e) {
                                  print('Error finding project with ID $newProjectId: $e');
                                }
                              }
                            },
                            items: (projects.toList()..sort((a, b) => a.name.compareTo(b.name)))
                              .map<DropdownMenuItem<int>>((Project project) {
                              return DropdownMenuItem<int>(
                                value: project.id,
                                child: Text(
                                  project.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Выпадающее меню корпусов
                        if (selectedProject != null && selectedProject!.buildings.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: selectedBuilding,
                              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                              iconSize: 16,
                              elevation: 16,
                              style: TextStyle(
                                color: Colors.blue.shade100,
                                fontSize: 14,
                              ),
                              underline: Container(),
                              dropdownColor: Colors.blue.shade700,
                              isExpanded: true,
                              menuMaxHeight: 300, // Добавляем прокрутку
                              onChanged: (String? newBuilding) {
                                if (newBuilding != null && newBuilding != selectedBuilding) {
                                  changeBuilding(newBuilding);
                                }
                              },
                              items: (selectedProject!.buildings.toList()..sort((a, b) => a.compareTo(b)))
                                .map<DropdownMenuItem<String>>((String building) {
                                return DropdownMenuItem<String>(
                                  value: building,
                                  child: Text(
                                    building,
                                    style: TextStyle(
                                      color: Colors.blue.shade100,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (isLoading)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      // Кнопка фильтра
                      IconButton(
                        onPressed: () => setState(() => showOnlyDefects = !showOnlyDefects),
                        icon: Icon(
                          showOnlyDefects ? Icons.filter_alt : Icons.filter_alt_outlined,
                          color: Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: showOnlyDefects ? Colors.orange.shade600 : Colors.blue.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${stats['totalUnits']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Квартир',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${stats['unitsWithDefects']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'С дефектами',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Легенда статусов
                const Text(
                  'Статусы квартир',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusLegend('Без дефектов', Colors.grey.shade100, Colors.grey.shade300),
                    _buildStatusLegend('Новые дефекты', Colors.red.shade100, Colors.red.shade400),
                    _buildStatusLegend('В работе', Colors.yellow.shade100, Colors.yellow.shade400),
                    _buildStatusLegend('Устранено', Colors.green.shade100, Colors.green.shade400),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Пояснения по иконкам
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Заблокированная квартира',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '3',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Количество дефектов',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Схема дома
                Row(
                  children: [
                    const Text(
                      'Схема дома',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (showOnlyDefects) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_alt,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Только с дефектами',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 100), // Добавляем отступ для нижней навигации
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildFloorUnits(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusLegend(String label, Color bgColor, Color borderColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildApartmentScreen() {
    return Column(
      children: [
        // Заголовок
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() => currentView = 'home'),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade500,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Квартира ${selectedUnit?.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${selectedUnit?.floor} этаж • ЖК "${selectedProject?.name ?? ''}" • $selectedBuilding',
                          style: TextStyle(
                            color: Colors.blue.shade100,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => currentView = 'addDefect'),
                    icon: const Icon(Icons.add, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${selectedUnit?.defects.length ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Дефектов',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${selectedUnit?.defects.where((d) => d.statusId == 1 || d.statusId == 2).length ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Активных',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${selectedUnit?.defects.where((d) => d.statusId == 3).length ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Устранено',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: selectedUnit?.defects.isEmpty ?? true
                ? _buildEmptyDefectsView()
                : _buildDefectsList(),
          ),
        ),
      ],
    );
  }

  // Загрузить вложения для всех дефектов выбранной квартиры
  Future<void> _loadDefectAttachments() async {
    if (selectedUnit != null) {
      for (final defect in selectedUnit!.defects) {
        final attachments = await DatabaseService.getDefectAttachments(defect.id);
        if (attachments.isNotEmpty) {
          setState(() {
            _defectAttachments[defect.id] = attachments;
          });
        }
      }
    }
  }

  Widget _buildEmptyDefectsView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🏠',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'Дефектов нет',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'В этой квартире пока не зарегистрированы дефекты',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => currentView = 'addDefect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Добавить дефект'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectsList() {
    return ListView.builder(
      itemCount: selectedUnit?.defects.length ?? 0,
      itemBuilder: (context, index) {
        final defect = selectedUnit!.defects[index];
        final type = defectTypes.isNotEmpty 
            ? defectTypes.firstWhere((t) => t.id == defect.typeId, 
                orElse: () => DefectType(id: 0, name: 'Неизвестный тип'))
            : DefectType(id: 0, name: 'Неизвестный тип');
        final status = defectStatuses.isNotEmpty 
            ? defectStatuses.firstWhere((s) => s.id == defect.statusId,
                orElse: () => DefectStatus(id: 0, entity: 'defect', name: 'Неизвестный статус', color: '#999999'))
            : DefectStatus(id: 0, entity: 'defect', name: 'Неизвестный статус', color: '#999999');
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            type.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (defect.isWarranty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Гарантия',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showStatusChangeDialog(defect),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(int.parse(status.color.substring(1), radix: 16) + 0xFF000000),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                status.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                defect.description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                defect.receivedAt != null 
                  ? 'Получен: ${DateTime.parse(defect.receivedAt!).day.toString().padLeft(2, '0')}.${DateTime.parse(defect.receivedAt!).month.toString().padLeft(2, '0')}.${DateTime.parse(defect.receivedAt!).year}'
                  : 'Дата получения не указана',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              
              // Прикрепленные файлы (сворачиваемая секция)
              if (_defectAttachments[defect.id]?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_expandedAttachments.contains(defect.id)) {
                        _expandedAttachments.remove(defect.id);
                      } else {
                        _expandedAttachments.add(defect.id);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        _expandedAttachments.contains(defect.id) 
                            ? Icons.keyboard_arrow_down 
                            : Icons.keyboard_arrow_right,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Прикрепленные файлы (${_defectAttachments[defect.id]!.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_expandedAttachments.contains(defect.id)) ...[
                  const SizedBox(height: 8),
                  ...(_defectAttachments[defect.id]!.map((attachment) => 
                    _buildAttachmentTile(defect, attachment)
                  )),
                ],
              ],
              
              // Кнопки действий для дефекта
              if (defect.statusId != 3 && defect.statusId != 4 && defect.statusId != 9) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _attachFiles(defect),
                        icon: const Icon(Icons.attach_file, size: 18),
                        label: const Text('Прикрепить файлы'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _markDefectAsFixed(defect),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Отправить на проверку'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Прикрепить файлы к дефекту
  Future<void> _attachFiles(Defect defect) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Камера'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera(defect);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерея'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery(defect);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Файлы'),
              onTap: () {
                Navigator.pop(context);
                _pickFilesFromStorage(defect);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera(Defect defect) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        await _uploadFile(defect, image.name, bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при съемке: $e')),
      );
    }
  }

  Future<void> _pickImageFromGallery(Defect defect) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      for (final image in images) {
        final bytes = await image.readAsBytes();
        await _uploadFile(defect, image.name, bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе из галереи: $e')),
      );
    }
  }

  Future<void> _pickFilesFromStorage(Defect defect) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.bytes != null) {
            await _uploadFile(defect, file.name, file.bytes!);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе файлов: $e')),
      );
    }
  }

  Future<void> _uploadFile(Defect defect, String fileName, List<int> bytes) async {
    final attachment = await DatabaseService.uploadDefectAttachment(
      defectId: defect.id,
      fileName: fileName,
      fileBytes: bytes,
    );
    
    if (attachment != null) {
      setState(() {
        _defectAttachments.putIfAbsent(defect.id, () => []).add(attachment);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл $fileName успешно прикреплен')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки файла $fileName')),
      );
    }
  }

  Widget _buildAttachmentTile(Defect defect, DefectAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            attachment.isImage ? Icons.image : Icons.insert_drive_file,
            color: Colors.blue.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  attachment.formattedSize,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _viewAttachment(attachment),
            icon: const Icon(Icons.visibility, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            onPressed: () => _deleteAttachment(defect, attachment),
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Future<void> _viewAttachment(DefectAttachment attachment) async {
    try {
      print('Attachment filePath: ${attachment.filePath}');
      
      String? url;
      // Проверяем, является ли filePath уже полным URL
      if (attachment.filePath.startsWith('http')) {
        // Если это полный URL, но возможно с дублированием
        url = attachment.filePath;
        // Исправляем дублирование URL
        if (url.contains('/storage/v1/object/public/attachments/https://')) {
          final parts = url.split('/storage/v1/object/public/attachments/https://');
          if (parts.length > 1) {
            url = 'https://' + parts[1];
          }
        }
      } else {
        url = DatabaseService.getAttachmentUrl(attachment.filePath);
      }
      
      print('Final URL: $url');
      
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удается открыть файл')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не найден')),
        );
      }
    } catch (e) {
      print('Error viewing attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при открытии файла')),
      );
    }
  }

  Future<void> _deleteAttachment(Defect defect, DefectAttachment attachment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл'),
        content: Text('Удалить файл "${attachment.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await DatabaseService.deleteDefectAttachment(attachment.id);
      if (success) {
        setState(() {
          _defectAttachments[defect.id]?.remove(attachment);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл удален')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при удалении файла')),
        );
      }
    }
  }

  // Отметить дефект как устраненный
  Future<void> _markDefectAsFixed(Defect defect) async {
    showDialog(
      context: context,
      builder: (context) => _FixDefectDialog(
        defect: defect,
        onDefectFixed: (updatedDefect) {
          // Обновляем дефект в списке
          setState(() {
            final unitIndex = units.indexWhere((u) => u.id == selectedUnit!.id);
            if (unitIndex != -1) {
              final defectIndex = units[unitIndex].defects.indexWhere((d) => d.id == defect.id);
              if (defectIndex != -1) {
                final updatedDefects = List<Defect>.from(units[unitIndex].defects);
                updatedDefects[defectIndex] = updatedDefect;
                
                units[unitIndex] = units[unitIndex].copyWith(defects: updatedDefects);
                selectedUnit = units[unitIndex];
              }
            }
          });
        },
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavButton(
              icon: Icons.grid_3x3,
              label: 'Шахматка',
              isActive: activeTab == 'building',
              onTap: () => setState(() => activeTab = 'building'),
            ),
            _buildNavButton(
              icon: Icons.message,
              label: 'Претензии',
              isActive: activeTab == 'complaints',
              onTap: () => setState(() => activeTab = 'complaints'),
            ),
            _buildNavButton(
              icon: Icons.build,
              label: 'Дефекты',
              isActive: activeTab == 'defects',
              onTap: () => setState(() => activeTab = 'defects'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.blue.shade600 : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.blue.shade600 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorUnits() {
    // Группируем юниты по этажам
    final unitsByFloor = <int, List<Unit>>{};
    for (final unit in units) {
      if (unit.floor != null) {
        unitsByFloor.putIfAbsent(unit.floor!, () => []).add(unit);
      }
    }

    // Сортируем этажи по убыванию
    final floors = unitsByFloor.keys.toList()..sort((a, b) => b.compareTo(a));

    if (floors.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Нет данных о квартирах',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }


    return Column(
      children: [
        // Заголовок с фиксированной колонкой этажей
        Row(
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text(
                'Этаж',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Квартиры',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        
        // Этажи с прокруткой
        ...floors.map((floor) {
          final allFloorUnits = unitsByFloor[floor]!;
          allFloorUnits.sort((a, b) => a.name.compareTo(b.name));
          
          // Применяем фильтр если нужно показывать только квартиры с дефектами
          final floorUnits = showOnlyDefects 
            ? allFloorUnits.where((unit) => unit.defects.isNotEmpty).toList()
            : allFloorUnits;
          
          // Если после фильтрации нет квартир на этаже, не показываем этаж
          if (floorUnits.isEmpty) {
            return const SizedBox.shrink();
          }

          // Создаем контроллер для этого этажа, если еще не создан
          if (!_floorScrollControllers.containsKey(floor)) {
            _floorScrollControllers[floor] = ScrollController();
          }
          
          final scrollController = _floorScrollControllers[floor]!;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                // Фиксированная колонка с номером этажа
                Container(
                  width: 50,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$floor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Прокручиваемая область с квартирами
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: floorUnits.map((unit) {
                          final status = unit.getStatus();
                          final unitColor = getUnitColor(status);
                          // Для заблокированных квартир используем ярко-красную рамку
                          final borderColor = unit.locked ? Colors.red : getUnitBorderColor(status);
                          final textColor = getUnitTextColor(status);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => openUnit(unit),
                              child: Container(
                                width: 60,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: unitColor,
                                  border: Border.all(color: borderColor, width: 2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Text(
                                        unit.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    // Замочек для заблокированных квартир
                                    if (unit.locked)
                                      Positioned(
                                        top: -6,
                                        left: -6,
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade600,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.3),
                                                spreadRadius: 1,
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.lock,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    // Счетчик дефектов
                                    if (unit.defects.isNotEmpty)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${unit.defects.length}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAddDefectScreen() {
    return Column(
      children: [
        // Заголовок
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF047857)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => currentView = 'apartment'),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Добавить дефект',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Квартира ${selectedUnit?.name} • ЖК "${selectedProject?.name ?? ''}" • $selectedBuilding',
                      style: TextStyle(
                        color: Colors.green.shade100,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Тип дефекта
                  const Text(
                    'Тип дефекта *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _selectedDefectTypeId,
                    decoration: InputDecoration(
                      hintText: 'Выберите тип',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: defectTypes.map((type) {
                      return DropdownMenuItem<int>(
                        value: type.id,
                        child: Text(type.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDefectTypeId = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Дата получения
                  const Text(
                    'Дата получения *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Гарантийный дефект
                  Row(
                    children: [
                      Checkbox(
                        value: _isWarranty,
                        onChanged: (value) {
                          setState(() {
                            _isWarranty = value ?? true;
                          });
                        },
                      ),
                      const Text(
                        'Гарантийный дефект',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Описание дефекта
                  const Text(
                    'Описание дефекта *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Опишите дефект подробно...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Кнопки
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: addDefect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Добавить дефект',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              currentView = 'apartment';
                              _descriptionController.clear();
                              _selectedDefectTypeId = null;
                              _selectedDate = DateTime.now();
                              _isWarranty = true;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Показать диалог изменения статуса дефекта
  void _showStatusChangeDialog(Defect defect) {
    showDialog(
      context: context,
      builder: (context) => _StatusChangeDialog(
        defect: defect,
        statuses: defectStatuses,
        onStatusChanged: (updatedDefect) {
          setState(() {
            // Обновляем дефект в списке
            if (selectedUnit != null) {
              final index = selectedUnit!.defects.indexWhere((d) => d.id == updatedDefect.id);
              if (index != -1) {
                selectedUnit!.defects[index] = updatedDefect;
              }
            }
          });
        },
      ),
    );
  }
}

// Диалог для отметки дефекта как устраненного
class _FixDefectDialog extends StatefulWidget {
  final Defect defect;
  final Function(Defect) onDefectFixed;

  const _FixDefectDialog({
    required this.defect,
    required this.onDefectFixed,
  });

  @override
  State<_FixDefectDialog> createState() => _FixDefectDialogState();
}

class _FixDefectDialogState extends State<_FixDefectDialog> {
  bool isOwnExecutor = true; // true = собственные, false = подряд
  int? selectedExecutorId;
  String? selectedEngineerId;
  DateTime fixDate = DateTime.now();
  List<dynamic> executors = [];
  List<dynamic> engineers = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExecutors();
    _loadEngineers();
  }

  Future<void> _loadExecutors() async {
    setState(() => isLoading = true);
    try {
      if (isOwnExecutor) {
        executors = await DatabaseService.getBrigades();
      } else {
        executors = await DatabaseService.getContractors();
      }
    } catch (e) {
      print('Error loading executors: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadEngineers() async {
    try {
      engineers = await DatabaseService.getEngineers();
      // Устанавливаем текущего пользователя по умолчанию, если он есть в списке инженеров
      final currentUserId = await DatabaseService.getCurrentUserId();
      if (currentUserId != null) {
        final currentUserInList = engineers.any((engineer) => engineer['id'] == currentUserId);
        if (currentUserInList) {
          selectedEngineerId = currentUserId;
        } else if (engineers.isNotEmpty) {
          // Если текущий пользователь не инженер, выбираем первого из списка
          selectedEngineerId = engineers.first['id'];
        }
      } else if (engineers.isNotEmpty) {
        // Если пользователь не авторизован, выбираем первого инженера
        selectedEngineerId = engineers.first['id'];
      }
      setState(() {});
    } catch (e) {
      print('Error loading engineers: $e');
    }
  }

  Future<void> _markAsFixed() async {
    if (selectedExecutorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите исполнителя')),
      );
      return;
    }

    try {
      final updatedDefect = await DatabaseService.markDefectAsFixed(
        defectId: widget.defect.id,
        executorId: selectedExecutorId!,
        isOwnExecutor: isOwnExecutor,
        engineerId: selectedEngineerId!,
        fixDate: fixDate,
      );

      if (updatedDefect != null) {
        widget.onDefectFixed(updatedDefect);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Дефект отмечен как устраненный')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при обновлении дефекта')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Отправить дефект на проверку'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  'После подтверждения статус дефекта изменится на "НА ПРОВЕРКУ"',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Выберите исполнителя:'),
              const SizedBox(height: 12),
              
              // Переключатель типа исполнителя
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          isOwnExecutor = true;
                          selectedExecutorId = null;
                        });
                        _loadExecutors();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOwnExecutor ? Colors.blue.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOwnExecutor ? Colors.blue.shade300 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOwnExecutor ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isOwnExecutor ? Colors.blue.shade600 : Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Собственные')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          isOwnExecutor = false;
                          selectedExecutorId = null;
                        });
                        _loadExecutors();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: !isOwnExecutor ? Colors.blue.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: !isOwnExecutor ? Colors.blue.shade300 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              !isOwnExecutor ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: !isOwnExecutor ? Colors.blue.shade600 : Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Подряд')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Выбор исполнителя
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (executors.isNotEmpty)
                Container(
                  width: double.infinity,
                  child: DropdownButtonFormField<int>(
                    value: selectedExecutorId,
                    decoration: const InputDecoration(
                      labelText: 'Исполнитель',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: executors.map((executor) {
                      return DropdownMenuItem<int>(
                        value: executor['id'],
                        child: Text(
                          executor['name'],
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedExecutorId = value);
                    },
                  ),
                )
              else
                const Text('Нет доступных исполнителей'),
              
              const SizedBox(height: 16),
              
              // Инженер, устранивший замечание
              const Text('Инженер, устранивший замечание:'),
              const SizedBox(height: 8),
              if (engineers.isNotEmpty)
                Container(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: engineers.any((engineer) => engineer['id'] == selectedEngineerId) 
                        ? selectedEngineerId 
                        : null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: engineers.map((engineer) {
                      return DropdownMenuItem<String>(
                        value: engineer['id'],
                        child: Text(
                          engineer['name'],
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedEngineerId = value);
                    },
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Текущий пользователь'),
                ),
            
            const SizedBox(height: 16),
            
            // Дата устранения
            const Text('Дата устранения:'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: fixDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => fixDate = date);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text('${fixDate.day.toString().padLeft(2, '0')}.${fixDate.month.toString().padLeft(2, '0')}.${fixDate.year}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _markAsFixed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
          ),
          child: const Text('Отправить на проверку'),
        ),
      ],
    );
  }
}

// Диалог изменения статуса дефекта
class _StatusChangeDialog extends StatefulWidget {
  final Defect defect;
  final List<DefectStatus> statuses;
  final Function(Defect) onStatusChanged;

  const _StatusChangeDialog({
    required this.defect,
    required this.statuses,
    required this.onStatusChanged,
  });

  @override
  State<_StatusChangeDialog> createState() => _StatusChangeDialogState();
}

class _StatusChangeDialogState extends State<_StatusChangeDialog> {
  int? selectedStatusId;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedStatusId = widget.defect.statusId;
    print('Initial selectedStatusId: $selectedStatusId');
    print('Available statuses: ${widget.statuses.map((s) => '${s.id}:${s.name}').toList()}');
  }

  Future<void> _updateStatus() async {
    if (selectedStatusId == null || selectedStatusId == widget.defect.statusId) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => isLoading = true);

    try {
      final updatedDefect = await DatabaseService.updateDefectStatus(
        defectId: widget.defect.id,
        statusId: selectedStatusId!,
      );

      if (updatedDefect != null) {
        widget.onStatusChanged(updatedDefect);
        Navigator.of(context).pop();
        
        final statusName = widget.statuses
            .firstWhere((s) => s.id == selectedStatusId!, 
                orElse: () => DefectStatus(id: 0, entity: 'defect', name: 'Неизвестный', color: '#999999'))
            .name;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Статус изменен на: $statusName')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при изменении статуса')),
        );
      }
    } catch (e) {
      print('Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при изменении статуса')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<DefectStatus> _getUniqueStatuses(List<DefectStatus> statuses) {
    final uniqueStatusMap = <int, DefectStatus>{};
    for (final status in statuses) {
      uniqueStatusMap[status.id] = status;
    }
    final uniqueList = uniqueStatusMap.values.toList();
    print('Original statuses count: ${statuses.length}');
    print('Unique statuses count: ${uniqueList.length}');
    print('Unique status IDs: ${uniqueList.map((s) => s.id).toList()}');
    return uniqueList;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Изменить статус дефекта'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Текущий статус: ${widget.statuses.firstWhere((s) => s.id == widget.defect.statusId, orElse: () => DefectStatus(id: 0, entity: 'defect', name: 'Неизвестный', color: '#999999')).name}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text('Новый статус:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: () {
              final uniqueStatuses = _getUniqueStatuses(widget.statuses);
              final validStatusIds = uniqueStatuses.map((s) => s.id).toSet();
              if (selectedStatusId != null && validStatusIds.contains(selectedStatusId)) {
                return selectedStatusId;
              }
              print('selectedStatusId $selectedStatusId not found in valid statuses, setting to null');
              return null;
            }(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
            items: _getUniqueStatuses(widget.statuses).map((status) {
              return DropdownMenuItem<int>(
                value: status.id,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(int.parse(status.color.substring(1), radix: 16) + 0xFF000000),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(status.name),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => selectedStatusId = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: isLoading || selectedStatusId == widget.defect.statusId ? null : _updateStatus,
          child: isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Изменить'),
        ),
      ],
    );
  }
}