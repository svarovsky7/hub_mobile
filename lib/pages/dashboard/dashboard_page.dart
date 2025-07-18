import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../entities/project/bloc/project_bloc.dart';
import '../../entities/project/bloc/project_event.dart';
import '../../entities/project/bloc/project_state.dart';
import '../../entities/project/model/project.dart';
import '../../models/project.dart' as Legacy;
import '../../shared/ui/components/feedback/loading_overlay.dart';
import '../../shared/ui/components/feedback/empty_state.dart';
import '../building_units/building_units_page.dart';
import '../defect_details/defect_details_page.dart';
import '../../models/unit.dart';
import '../../models/defect.dart';
import '../../services/database_service.dart';
import '../../widgets/dialogs/status_change_dialog.dart';
import '../../widgets/dialogs/mark_fixed_dialog.dart';
import '../../widgets/app_drawer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
  List<Legacy.DefectType> _defectTypes = [];
  List<Legacy.DefectStatus> _defectStatuses = [];
  List<Map<String, dynamic>> _brigades = [];
  List<Map<String, dynamic>> _contractors = [];
  bool _isLoadingData = false;
  bool _showOnlyDefects = false;
  Map<int, String> _statusColors = {};
  int? _selectedDefectType;

  @override
  void initState() {
    super.initState();
    _loadStaticData();
    // Trigger project loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectBloc>().add(const ProjectEventLoad());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: BlocListener<ProjectBloc, ProjectState>(
          listenWhen: (previous, current) {
            // Слушаем только значимые изменения
            if (previous is ProjectStateLoaded && current is ProjectStateLoaded) {
              final projectChanged = previous.selectedProject?.id != current.selectedProject?.id;
              final buildingChanged = previous.selectedBuilding != current.selectedBuilding;
              
              // Избегаем лишних срабатываний при одинаковых значениях
              if (!projectChanged && !buildingChanged) return false;
              
              return projectChanged || buildingChanged;
            }
            // Слушаем только первый переход в loaded состояние
            return current is ProjectStateLoaded && previous is ProjectStateInitial;
          },
          listener: (context, state) {
            if (state is ProjectStateLoaded) {
              // Только при смене проекта возвращаемся к главному экрану
              if (_currentView != DashboardView.home) {
                setState(() {
                  _currentView = DashboardView.home;
                });
              }
              
              if (state.selectedProject != null && state.selectedBuilding != null) {
                _loadUnits(state.selectedProject!.id, state.selectedBuilding!);
              } else {
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
            onAttachFiles: _onAttachFiles,
            onMarkFixed: _onMarkFixed,
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

  void _onUnitTap(Unit unit) {
    setState(() {
      _selectedUnit = unit;
      _currentView = DashboardView.apartment;
    });
  }

  void _onRefresh() {
    context.read<ProjectBloc>().add(const ProjectEventRefresh());
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
      });
      return;
    }

    setState(() {
      _isLoadingUnits = true;
      _units = []; // Очищаем предыдущие юниты
      _selectedUnit = null; // Сбрасываем выбранный юнит
    });

    try {
      final result = await DatabaseService.getUnitsWithDefectsForBuilding(
        projectId,
        building,
      );
      setState(() {
        _units = result['units'] as List<Unit>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingUnits = false);
    }
  }

  Future<void> _loadStaticData() async {
    setState(() => _isLoadingData = true);

    try {
      final results = await Future.wait([
        DatabaseService.getDefectTypes(),
        DatabaseService.getDefectStatuses(),
        DatabaseService.getBrigades(),
        DatabaseService.getContractors(),
      ]);

      setState(() {
        _defectTypes = results[0] as List<Legacy.DefectType>;
        _defectStatuses = results[1] as List<Legacy.DefectStatus>;
        _brigades = results[2] as List<Map<String, dynamic>>;
        _contractors = results[3] as List<Map<String, dynamic>>;
        
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
      setState(() => _isLoadingData = false);
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
      orElse: () => Legacy.DefectStatus(
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

  void _onAttachFiles(Defect defect) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Камера'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Галерея'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Файлы'),
            onTap: () => Navigator.pop(context, 'files'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _handleFileSelection(defect, result);
    }
  }

  void _onMarkFixed(Defect defect) async {
    if (_brigades.isEmpty && _contractors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные исполнителей не загружены')),
      );
      return;
    }

    final currentUserId = await DatabaseService.getCurrentUserId();
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: пользователь не авторизован')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => MarkFixedDialog(
        brigades: _brigades,
        contractors: _contractors,
        onMarkFixed: ({
          required int executorId,
          required bool isOwnExecutor,
          required DateTime fixDate,
        }) async {
          await _markDefectAsFixed(
            defect,
            executorId,
            isOwnExecutor,
            currentUserId,
            fixDate,
          );
        },
      ),
    );
  }

  Future<void> _updateDefectStatus(Defect defect, int newStatusId) async {
    try {
      final updatedDefect = await DatabaseService.updateDefectStatus(
        defectId: defect.id,
        statusId: newStatusId,
      );

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

  Future<void> _handleFileSelection(Defect defect, String source) async {
    try {
      List<int>? fileBytes;
      String? fileName;

      if (source == 'camera') {
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.camera);
        if (image != null) {
          fileBytes = await File(image.path).readAsBytes();
          fileName = image.name;
        }
      } else if (source == 'gallery') {
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          fileBytes = await File(image.path).readAsBytes();
          fileName = image.name;
        }
      } else if (source == 'files') {
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.bytes != null) {
          fileBytes = result.files.single.bytes!;
          fileName = result.files.single.name;
        }
      }

      if (fileBytes != null && fileName != null) {
        final attachment = await DatabaseService.uploadDefectAttachment(
          defectId: defect.id,
          fileName: fileName,
          fileBytes: fileBytes,
        );

        if (attachment != null) {
          await _refreshCurrentUnit();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Файл "$fileName" загружен')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ошибка загрузки файла')),
            );
          }
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
      final state = context.read<ProjectBloc>().state;
      if (state is ProjectStateLoaded &&
          state.selectedProject != null &&
          state.selectedBuilding != null) {
        await _loadUnits(state.selectedProject!.id, state.selectedBuilding);
        // Update selected unit with fresh data
        final updatedUnit = _units.firstWhere(
          (u) => u.id == _selectedUnit!.id,
          orElse: () => _selectedUnit!,
        );
        setState(() {
          _selectedUnit = updatedUnit;
        });
      }
    }
  }
}
