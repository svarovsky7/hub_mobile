import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../entities/project/bloc/project_bloc.dart';
import '../../entities/project/bloc/project_event.dart';
import '../../entities/project/bloc/project_state.dart';
import '../../entities/project/model/project.dart';
import '../../models/project.dart' as legacy;
import '../../shared/ui/components/feedback/loading_overlay.dart';
import '../../shared/ui/components/feedback/empty_state.dart';
import '../building_units/building_units_page.dart';
import '../defect_details/defect_details_page.dart';
import '../../models/unit.dart';
import '../../models/defect.dart';
import '../../services/database_service.dart';
import '../../services/offline_service.dart';
import '../../widgets/dialogs/status_change_dialog.dart';
import '../../widgets/dialogs/mark_fixed_dialog.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/connectivity_indicator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

enum DashboardView { home, apartment, addDefect }

enum DashboardTab { building, complaints, defects }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardView _currentView = DashboardView.home;
  DashboardTab _activeTab = DashboardTab.building;
  Unit? _selectedUnit;
  List<Unit> _units = [];
  bool _isLoadingUnits = false;
  List<legacy.DefectType> _defectTypes = [];
  List<legacy.DefectStatus> _defectStatuses = [];
  List<Map<String, dynamic>> _brigades = [];
  List<Map<String, dynamic>> _contractors = [];
  List<Map<String, dynamic>> _engineers = [];
  bool _showOnlyDefects = false;
  Map<int, String> _statusColors = {};
  int? _selectedDefectType;
  String? _lastLoadedBuilding;

  @override
  void initState() {
    super.initState();
    _loadStaticData();
    // Trigger project loading and auto-select active project
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectBloc>().add(const ProjectEventLoad());
      _loadActiveProject();
    });
  }

  Future<void> _loadActiveProject() async {
    try {
      print('Loading active project...');
      final activeProject = await DatabaseService.getUserActiveProject();
      
      if (activeProject != null && mounted) {
        print('Found active project: ${activeProject.name} with ${activeProject.buildings.length} buildings');
        
        // Convert legacy.Project to entities.Project
        final entitiesProject = Project(
          id: activeProject.id,
          name: activeProject.name,
          buildings: activeProject.buildings,
        );
        
        // Auto-select the active project
        context.read<ProjectBloc>().add(ProjectEventSelectProject(entitiesProject));
        
        // Auto-select first building if available to load chess board
        if (activeProject.buildings.isNotEmpty) {
          final firstBuilding = activeProject.buildings.first;
          print('Auto-selecting first building: $firstBuilding');
          context.read<ProjectBloc>().add(ProjectEventSelectBuilding(firstBuilding));
        } else {
          print('No buildings found for project ${activeProject.name}');
        }
      } else {
        print('No active project found, trying to select first available project');
        // Если нет активного проекта, пробуем выбрать первый доступный
        await _loadFirstAvailableProject();
      }
    } catch (e) {
      print('Error loading active project: $e');
      // В случае ошибки пробуем загрузить первый доступный проект
      await _loadFirstAvailableProject();
    }
  }
  
  Future<void> _loadFirstAvailableProject() async {
    try {
      final projects = await DatabaseService.getProjects();
      if (projects.isNotEmpty && mounted) {
        final firstProject = projects.first;
        print('Selecting first available project: ${firstProject.name}');
        
        final entitiesProject = Project(
          id: firstProject.id,
          name: firstProject.name,
          buildings: firstProject.buildings,
        );
        
        context.read<ProjectBloc>().add(ProjectEventSelectProject(entitiesProject));
        
        if (firstProject.buildings.isNotEmpty) {
          final firstBuilding = firstProject.buildings.first;
          print('Auto-selecting first building: $firstBuilding');
          context.read<ProjectBloc>().add(ProjectEventSelectBuilding(firstBuilding));
        }
      } else {
        print('No projects available for user');
      }
    } catch (e) {
      print('Error loading first available project: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // If we're not on home view, navigate to home
        if (_currentView != DashboardView.home) {
          setState(() {
            _currentView = DashboardView.home;
          });
        } else {
          // If already on home, allow normal back behavior (minimize app)
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        body: Column(
          children: [
            const ConnectivityIndicator(),
            Expanded(
              child: SafeArea(
                child: BlocListener<ProjectBloc, ProjectState>(
                listenWhen: (previous, current) {
                  // Слушаем переходы в loaded состояние или значимые изменения
                  if (current is ProjectStateLoaded) {
                    // Первый раз загружаемся
                    if (previous is! ProjectStateLoaded) {
                      return true;
                    }
                    
                    // Проверяем изменения
                    final projectChanged = previous.selectedProject?.id != current.selectedProject?.id;
                    final buildingChanged = previous.selectedBuilding != current.selectedBuilding;
                    
                    return projectChanged || buildingChanged;
                  }
                  return false;
                },
                listener: (context, state) {
                  if (state is ProjectStateLoaded) {
                    print('ProjectStateLoaded - Project: ${state.selectedProject?.name}, Building: ${state.selectedBuilding}');
                    
                    // Только при смене проекта возвращаемся к главному экрану
                    if (_currentView != DashboardView.home) {
                      setState(() {
                        _currentView = DashboardView.home;
                      });
                    }
                    
                    if (state.selectedProject != null && state.selectedBuilding != null) {
                      print('Loading units for project ${state.selectedProject!.id}, building ${state.selectedBuilding}');
                      _loadUnits(state.selectedProject!.id, state.selectedBuilding!);
                    } else {
                      print('Missing project or building - Project: ${state.selectedProject?.name}, Building: ${state.selectedBuilding}');
                      // Очищаем юниты если нет выбранного проекта или корпуса
                      if (_units.isNotEmpty || _selectedUnit != null) {
                        setState(() {
                          _units = [];
                          _selectedUnit = null;
                        });
                      }
                    }
                  }
                },
                child: BlocBuilder<ProjectBloc, ProjectState>(
                  buildWhen: (previous, current) {
                    // Перестраиваем только при смене типа состояния или значимых изменениях
                    return previous.runtimeType != current.runtimeType ||
                           (previous is ProjectStateLoaded && 
                            current is ProjectStateLoaded &&
                            (previous.projects != current.projects ||
                             previous.selectedProject?.id != current.selectedProject?.id ||
                             previous.selectedBuilding != current.selectedBuilding));
                  },
                  builder: (context, state) {
                    if (state is ProjectStateInitial) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is ProjectStateLoading) {
                      return const LoadingOverlay(
                        isLoading: true,
                        child: SizedBox.expand(),
                      );
                    } else if (state is ProjectStateLoaded) {
                      return _buildContent(
                        state.projects,
                        state.selectedProject,
                        state.selectedBuilding,
                      );
                    } else if (state is ProjectStateError) {
                      return EmptyState(
                        title: 'Ошибка загрузки',
                        subtitle: state.message,
                        icon: Icons.error_outline,
                        actionText: 'Повторить',
                        onAction: () => context.read<ProjectBloc>().add(
                              const ProjectEventRefresh(),
                            ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildContent(
    List<Project> projects,
    Project? selectedProject,
    String? selectedBuilding,
  ) {
    return Stack(
      children: [
        // Main content
        if (_currentView == DashboardView.home &&
            _activeTab == DashboardTab.building)
          BuildingUnitsPage(
            projects: projects,
            selectedProject: selectedProject,
            selectedBuilding: selectedBuilding,
            units: _units,
            isLoading: _isLoadingUnits,
            onProjectChanged: _onProjectChanged,
            onBuildingChanged: _onBuildingChanged,
            onUnitTap: _onUnitTap,
            onRefresh: _onRefresh,
            onToggleShowOnlyDefects: _onToggleShowOnlyDefects,
            showOnlyDefects: _showOnlyDefects,
            statusColors: _statusColors,
            defectTypes: _defectTypes,
            onDefectTypeChanged: _onDefectTypeChanged,
            onResetFilters: _onResetFilters,
            selectedDefectType: _selectedDefectType,
            defectStatuses: _defectStatuses,
          )
        else if (_currentView == DashboardView.apartment &&
            selectedProject != null &&
            selectedBuilding != null)
          _buildApartmentView(selectedProject, selectedBuilding)
        else if (_currentView == DashboardView.addDefect)
          _buildAddDefectView()
        else
          const EmptyState(
            title: 'В разработке',
            subtitle: 'Эта функция будет добавлена в следующих версиях',
            icon: Icons.construction,
          ),

        // Bottom navigation
        if (_currentView == DashboardView.home) _buildBottomNavigation(),
      ],
    );
  }

  Widget _buildApartmentView(Project project, String building) {
    if (_selectedUnit == null) {
      return const EmptyState(
        title: 'Квартира не выбрана',
        icon: Icons.home_outlined,
      );
    }

    return BlocBuilder<ProjectBloc, ProjectState>(
      builder: (context, state) {
        if (state is ProjectStateLoaded) {
          return DefectDetailsPage(
            unit: _selectedUnit!,
            project: project,
            building: building,
            defectTypes: _defectTypes,
            defectStatuses: _defectStatuses,
            onBack: () => setState(() => _currentView = DashboardView.home),
            onAddDefect: () =>
                setState(() => _currentView = DashboardView.addDefect),
            onStatusTap: _onStatusTap,
            onMarkFixed: _onMarkFixed,
            onRefresh: _refreshCurrentUnit,
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildAddDefectView() {
    // TODO: Implement add defect form
    return const EmptyState(
      title: 'Форма добавления дефекта',
      subtitle: 'В разработке',
      icon: Icons.add_circle_outline,
    );
  }

  Widget _buildBottomNavigation() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: NavigationBar(
        selectedIndex: _activeTab.index,
        onDestinationSelected: (index) {
          setState(() => _activeTab = DashboardTab.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_3x3),
            label: 'Шахматка',
          ),
          NavigationDestination(
            icon: Icon(Icons.message),
            label: 'Претензии',
          ),
          NavigationDestination(
            icon: Icon(Icons.build),
            label: 'Дефекты',
          ),
        ],
      ),
    );
  }

  void _onProjectChanged(Project project) {
    context.read<ProjectBloc>().add(ProjectEventSelectProject(project));
    // Автоматически выбираем первый корпус, если он есть
    if (project.buildings.isNotEmpty) {
      final firstBuilding = project.buildings.first;
      context.read<ProjectBloc>().add(ProjectEventSelectBuilding(firstBuilding));
      _loadUnits(project.id, firstBuilding);
    }
  }

  void _onBuildingChanged(String building) {
    context.read<ProjectBloc>().add(ProjectEventSelectBuilding(building));

    final state = context.read<ProjectBloc>().state;
    if (state is ProjectStateLoaded && state.selectedProject != null) {
      _loadUnits(state.selectedProject!.id, building);
    }
  }

  void _onUnitTap(Unit unit) async {
    setState(() {
      _selectedUnit = unit;
      _currentView = DashboardView.apartment;
    });
    
    // Загружаем вложения для дефектов при первом открытии юнита
    final defectsWithAttachments = <Defect>[];
    for (final defect in unit.defects) {
      final attachments = await DatabaseService.getDefectAttachments(defect.id);
      defectsWithAttachments.add(defect.copyWith(attachments: attachments));
    }
    
    final unitWithAttachments = unit.copyWith(defects: defectsWithAttachments);
    
    setState(() {
      _selectedUnit = unitWithAttachments;
      // Также обновляем юнит в общем списке
      final unitIndex = _units.indexWhere((u) => u.id == unit.id);
      if (unitIndex != -1) {
        _units[unitIndex] = unitWithAttachments;
      }
    });
  }

  Future<void> _onRefresh() async {
    try {
      // Запускаем синхронизацию, если есть интернет
      if (OfflineService.isOnline) {
        print('Начинаем синхронизацию данных...');
        await OfflineService.performSync(
          onProgress: (progress, operation) {
            print('Sync progress: ${(progress * 100).toInt()}% - $operation');
          },
        );
        print('Синхронизация завершена');
      }
      
      // Обновляем проекты
      context.read<ProjectBloc>().add(const ProjectEventRefresh());
      
      // Перезагружаем статические данные
      await _loadStaticData();
      
    } catch (e) {
      print('Ошибка при обновлении данных: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e')),
        );
      }
    }
  }

  void _onToggleShowOnlyDefects() {
    setState(() {
      _showOnlyDefects = !_showOnlyDefects;
    });
  }

  void _onDefectTypeChanged(int? defectTypeId) {
    setState(() {
      _selectedDefectType = defectTypeId;
    });
  }

  void _onResetFilters() {
    setState(() {
      _selectedDefectType = null;
      _showOnlyDefects = false;
    });
  }

  Future<void> _loadUnits(int projectId, String? building) async {
    if (building == null) {
      setState(() {
        _units = [];
        _selectedUnit = null;
        _lastLoadedBuilding = null;
      });
      return;
    }

    // Сохраняем текущий корпус для проверки актуальности результата
    final currentBuilding = building;
    
    setState(() {
      _isLoadingUnits = true;
      // Не очищаем юниты сразу, чтобы избежать мигания
      _selectedUnit = null;
      _lastLoadedBuilding = building;
    });

    try {
      print('Loading units for project $projectId, building: $building');
      final result = await DatabaseService.getUnitsWithDefectsForBuilding(
        projectId,
        building,
      );
      
      final units = result['units'] as List<Unit>;
      print('Loaded ${units.length} units');
      
      // Проверяем, что пользователь еще на том же корпусе
      if (currentBuilding == _lastLoadedBuilding && mounted) {
        setState(() {
          _units = units;
        });
        
        // Показываем сообщение только если прошло достаточно времени и корпус не изменился
        if (units.isEmpty) {
          // Добавляем небольшую задержку, чтобы пользователь успел переключиться
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Проверяем еще раз, что корпус не изменился
          if (currentBuilding == _lastLoadedBuilding && mounted && _units.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('В этом корпусе нет квартир'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error loading units: $e');
      if (mounted && currentBuilding == _lastLoadedBuilding) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    } finally {
      if (mounted && currentBuilding == _lastLoadedBuilding) {
        setState(() => _isLoadingUnits = false);
      }
    }
  }

  Future<void> _loadStaticData() async {

    try {
      final results = await Future.wait([
        DatabaseService.getDefectTypes(),
        DatabaseService.getDefectStatuses(),
        DatabaseService.getBrigades(),
        DatabaseService.getContractors(),
        DatabaseService.getEngineers(),
      ]);

      setState(() {
        _defectTypes = results[0] as List<legacy.DefectType>;
        _defectStatuses = results[1] as List<legacy.DefectStatus>;
        _brigades = results[2] as List<Map<String, dynamic>>;
        _contractors = results[3] as List<Map<String, dynamic>>;
        _engineers = results[4] as List<Map<String, dynamic>>;
        
        // Создаем карту цветов по ID статуса
        _statusColors = {};
        for (final status in _defectStatuses) {
          _statusColors[status.id] = status.color;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    } finally {
    }
  }

  void _onStatusTap(Defect defect) async {
    if (_defectStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Статусы дефектов не загружены')),
      );
      return;
    }

    final currentStatus = _defectStatuses.firstWhere(
      (s) => s.id == defect.statusId,
      orElse: () => legacy.DefectStatus(
        id: 0,
        entity: 'defect',
        name: 'Неизвестный статус',
        color: '#999999',
      ),
    );

    await showDialog(
      context: context,
      builder: (context) => StatusChangeDialog(
        currentStatus: currentStatus,
        availableStatuses: _defectStatuses,
        onStatusSelected: (newStatus) async {
          await _updateDefectStatus(defect, newStatus.id);
        },
      ),
    );
  }


  void _onMarkFixed(Defect defect) async {
    if (_brigades.isEmpty && _contractors.isEmpty && _engineers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные исполнителей не загружены')),
      );
      return;
    }

    final currentUserId = await DatabaseService.getCurrentUserId();
    if (currentUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: пользователь не авторизован')),
      );
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => MarkFixedDialog(
        brigades: _brigades,
        contractors: _contractors,
        engineers: _engineers,
        onMarkFixed: ({
          required int executorId,
          required bool isOwnExecutor,
          required DateTime fixDate,
          required String engineerId,
        }) async {
          await _markDefectAsFixed(
            defect,
            executorId,
            isOwnExecutor,
            engineerId,
            fixDate,
          );
        },
      ),
    );
  }

  Future<void> _updateDefectStatus(Defect defect, int newStatusId) async {
    try {
      print('_updateDefectStatus called: defect ${defect.id}, old status ${defect.statusId}, new status $newStatusId, offline: ${!OfflineService.isOnline}');
      final updatedDefect = await DatabaseService.updateDefectStatus(
        defectId: defect.id,
        statusId: newStatusId,
      );
      print('updateDefectStatus result: ${updatedDefect != null ? "success" : "null"}');

      if (updatedDefect != null) {
        await _refreshCurrentUnit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Статус дефекта обновлен')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка обновления статуса')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }


  Future<void> _markDefectAsFixed(
    Defect defect,
    int executorId,
    bool isOwnExecutor,
    String engineerId,
    DateTime fixDate,
  ) async {
    try {
      final updatedDefect = await DatabaseService.markDefectAsFixed(
        defectId: defect.id,
        executorId: executorId,
        isOwnExecutor: isOwnExecutor,
        engineerId: engineerId,
        fixDate: fixDate,
      );

      if (updatedDefect != null) {
        await _refreshCurrentUnit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Дефект отправлен на проверку')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка отправки на проверку')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _refreshCurrentUnit() async {
    if (_selectedUnit != null) {
      final selectedUnitId = _selectedUnit!.id; // Сохраняем ID выбранной квартиры
      final state = context.read<ProjectBloc>().state;
      if (state is ProjectStateLoaded &&
          state.selectedProject != null &&
          state.selectedBuilding != null) {
        
        // Загружаем обновленные данные без сброса _selectedUnit
        final result = await DatabaseService.getUnitsWithDefectsForBuilding(
          state.selectedProject!.id,
          state.selectedBuilding!,
        );
        
        final units = result['units'] as List<Unit>;
        
        // Находим обновленную выбранную квартиру
        final updatedUnit = units.firstWhere(
          (u) => u.id == selectedUnitId,
          orElse: () => _selectedUnit!,
        );
        
        // Загружаем вложения для дефектов текущего юнита
        final defectsWithAttachments = <Defect>[];
        for (final defect in updatedUnit.defects) {
          final attachments = await DatabaseService.getDefectAttachments(defect.id);
          defectsWithAttachments.add(defect.copyWith(attachments: attachments));
        }
        
        final unitWithAttachments = updatedUnit.copyWith(defects: defectsWithAttachments);
        
        setState(() {
          _units = units; // Обновляем общий список
          _selectedUnit = unitWithAttachments; // Сохраняем выбранную квартиру с обновленными данными
        });
      }
    }
  }
}
