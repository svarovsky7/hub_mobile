import 'package:flutter/material.dart';
import '../models/unit.dart';
import '../models/defect.dart';
import '../models/claim.dart';
import '../models/project.dart';
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
  
  // Форма для нового дефекта
  final _descriptionController = TextEditingController();
  int? _selectedDefectTypeId;
  DateTime _selectedDate = DateTime.now();
  bool _isWarranty = true;

  // Типы дефектов и статусы загружаются из БД
  List<DefectType> defectTypes = [];
  List<DefectStatus> defectStatuses = [];
  List<ClaimStatus> claimStatuses = [];

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
      
      if (projects.isNotEmpty) {
        selectedProject = projects.first;
        
        // Загружаем корпуса для первого проекта
        final buildings = await DatabaseService.getBuildingsForProject(selectedProject!.id);
        selectedProject = selectedProject!.copyWith(buildings: buildings);
        
        if (buildings.isNotEmpty) {
          selectedBuilding = buildings.first;
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
    final theme = Theme.of(context);
    switch (status) {
      case UnitStatus.noDefects:
        return theme.colorScheme.surfaceVariant;
      case UnitStatus.hasNew:
        return const Color(0xFFEF4444); // Красный - Получен
      case UnitStatus.inProgress:
        return const Color(0xFFF59E0B); // Оранжевый - В работе
      case UnitStatus.completed:
        return const Color(0xFF10B981); // Зеленый - Устранен
      case UnitStatus.rejected:
        return const Color(0xFF6B7280); // Серый - Отклонен
      case UnitStatus.onReview:
        return const Color(0xFF3B82F6); // Синий - На проверку
      default:
        return theme.colorScheme.surface;
    }
  }

  // Получить цвет границы юнита
  Color getUnitBorderColor(UnitStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case UnitStatus.noDefects:
        return theme.colorScheme.outline;
      case UnitStatus.hasNew:
        return const Color(0xFFDC2626); // Темно-красный
      case UnitStatus.inProgress:
        return const Color(0xFFD97706); // Темно-оранжевый
      case UnitStatus.completed:
        return const Color(0xFF059669); // Темно-зеленый
      case UnitStatus.rejected:
        return const Color(0xFF4B5563); // Темно-серый
      case UnitStatus.onReview:
        return const Color(0xFF2563EB); // Темно-синий
      default:
        return theme.colorScheme.outline;
    }
  }

  // Получить цвет текста юнита
  Color getUnitTextColor(UnitStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case UnitStatus.noDefects:
        return theme.colorScheme.onSurfaceVariant;
      case UnitStatus.hasNew:
        return Colors.white; // Белый текст на красном фоне
      case UnitStatus.inProgress:
        return Colors.white; // Белый текст на оранжевом фоне
      case UnitStatus.completed:
        return Colors.white; // Белый текст на зеленом фоне
      case UnitStatus.rejected:
        return Colors.white; // Белый текст на сером фоне
      case UnitStatus.onReview:
        return Colors.white; // Белый текст на синем фоне
      default:
        return theme.colorScheme.onSurface;
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
  }

  // Сменить проект
  Future<void> changeProject(Project project) async {
    setState(() => isLoading = true);
    
    try {
      selectedProject = project;
      
      // Загружаем корпуса для нового проекта
      final buildings = await DatabaseService.getBuildingsForProject(project.id);
      selectedProject = selectedProject!.copyWith(buildings: buildings);
      
      if (buildings.isNotEmpty) {
        selectedBuilding = buildings.first;
        await loadUnitsForCurrentSelection();
      } else {
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
      final updatedDefect = await DatabaseService.updateDefectStatus(defectId, newStatusId);
      
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
                            onChanged: (int? newProjectId) {
                              if (newProjectId != null) {
                                final newProject = projects.firstWhere((p) => p.id == newProjectId);
                                if (newProject != selectedProject) {
                                  changeProject(newProject);
                                }
                              }
                            },
                            items: projects.map<DropdownMenuItem<int>>((Project project) {
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
                              onChanged: (String? newBuilding) {
                                if (newBuilding != null && newBuilding != selectedBuilding) {
                                  changeBuilding(newBuilding);
                                }
                              },
                              items: selectedProject!.buildings.map<DropdownMenuItem<String>>((String building) {
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
                      IconButton(
                        onPressed: () => setState(() => showMenu = true),
                        icon: const Icon(Icons.menu, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.shade500,
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${stats['totalUnits']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Квартир',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${stats['unitsWithDefects']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'С дефектами',
                            style: TextStyle(
                              color: Colors.blue.shade100,
                              fontSize: 10,
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
            physics: const AlwaysScrollableScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                    _buildStatusLegend('Без дефектов', Theme.of(context).colorScheme.surfaceVariant, Theme.of(context).colorScheme.outline),
                    _buildStatusLegend('Получен', const Color(0xFFEF4444), const Color(0xFFDC2626)),
                    _buildStatusLegend('В работе', const Color(0xFFF59E0B), const Color(0xFFD97706)),
                    _buildStatusLegend('На проверку', const Color(0xFF3B82F6), const Color(0xFF2563EB)),
                    _buildStatusLegend('Устранен', const Color(0xFF10B981), const Color(0xFF059669)),
                    _buildStatusLegend('Отклонен', const Color(0xFF6B7280), const Color(0xFF4B5563)),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Схема дома
                const Text(
                  'Схема дома',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
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
                          '${selectedUnit?.floor} этаж • ${selectedProject?.name ?? ''} • $selectedBuilding',
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
        final type = defectTypes.firstWhere((t) => t.id == defect.typeId);
        final status = defectStatuses.firstWhere((s) => s.id == defect.statusId);
        
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(int.parse(status.color.substring(1), radix: 16) + 0xFF000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    defect.receivedAt != null 
                      ? 'Получен: ${DateTime.parse(defect.receivedAt!).day.toString().padLeft(2, '0')}.${DateTime.parse(defect.receivedAt!).month.toString().padLeft(2, '0')}.${DateTime.parse(defect.receivedAt!).year}'
                      : 'Дата получения не указана',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (defect.statusId != 3 && defect.statusId != 4)
                    DropdownButton<int>(
                      value: defect.statusId,
                      onChanged: (newStatusId) {
                        if (newStatusId != null) {
                          updateDefectStatus(defect.id, newStatusId);
                        }
                      },
                      items: defectStatuses.map((status) {
                        return DropdownMenuItem<int>(
                          value: status.id,
                          child: Text(
                            status.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ],
          ),
        );
      },
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
      children: floors.map((floor) {
        final floorUnits = unitsByFloor[floor]!;
        floorUnits.sort((a, b) => a.name.compareTo(b.name));

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$floor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  child: Row(
                    children: floorUnits.map((unit) {
                      final status = unit.getStatus();
                      final unitColor = getUnitColor(status);
                      final borderColor = getUnitBorderColor(status);
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
            ],
          ),
        ),
        );
      }).toList(),
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
                      'Квартира ${selectedUnit?.name} • ${selectedProject?.name ?? ''} • $selectedBuilding',
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
}