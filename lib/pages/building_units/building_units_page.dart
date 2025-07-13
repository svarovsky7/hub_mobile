import 'package:flutter/material.dart';
import '../../entities/project/model/project.dart';
import '../../models/unit.dart';
import '../../shared/ui/components/feedback/loading_overlay.dart';
import '../../shared/ui/components/feedback/empty_state.dart';
import '../../widgets/unit_grid/unit_tile.dart';

class BuildingUnitsPage extends StatelessWidget {
  const BuildingUnitsPage({
    super.key,
    required this.projects,
    required this.selectedProject,
    required this.selectedBuilding,
    required this.units,
    required this.isLoading,
    required this.onProjectChanged,
    required this.onBuildingChanged,
    required this.onUnitTap,
    required this.onRefresh,
    required this.onToggleShowOnlyDefects,
    required this.defectTypes,
    required this.onDefectTypeChanged,
    this.showOnlyDefects = false,
    this.statusColors = const {},
    this.selectedDefectType,
  });

  final List<Project> projects;
  final Project? selectedProject;
  final String? selectedBuilding;
  final List<Unit> units;
  final bool isLoading;
  final Function(Project) onProjectChanged;
  final Function(String) onBuildingChanged;
  final Function(Unit) onUnitTap;
  final VoidCallback onRefresh;
  final VoidCallback onToggleShowOnlyDefects;
  final bool showOnlyDefects;
  final Map<int, String> statusColors;
  final List<dynamic> defectTypes;
  final Function(int?) onDefectTypeChanged;
  final int? selectedDefectType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (selectedProject == null) {
      return EmptyState(
        title: 'Нет доступных проектов',
        icon: Icons.error_outline,
        actionText: 'Обновить',
        onAction: onRefresh,
      );
    }

    return LoadingOverlay(
      isLoading: isLoading,
      child: Column(
        children: [
          // Header with gradient
          _buildHeader(theme),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusLegend(theme),
                  const SizedBox(height: 24),
                  _buildUnitsGrid(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final stats = _calculateStats();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withBlue(
              (theme.colorScheme.primary.blue * 0.8).round(),
            ),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Project and building selectors
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProjectSelector(theme, context),
                      if (selectedProject != null && 
                          selectedProject!.buildings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildBuildingSelector(theme, context),
                        const SizedBox(height: 8),
                        _buildDefectTypeSelector(theme, context),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleShowOnlyDefects,
                icon: Icon(
                  showOnlyDefects ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: showOnlyDefects 
                      ? Colors.orange.withOpacity(0.8)
                      : Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Statistics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${stats['totalUnits']}',
                  'Квартир',
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '${stats['unitsWithDefects']}',
                  'С дефектами',
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSelector(ThemeData theme, BuildContext context) {
    return GestureDetector(
      onTap: () => _showProjectSelector(context, theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedProject?.name ?? 'Выберите проект',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingSelector(ThemeData theme, BuildContext context) {
    return GestureDetector(
      onTap: () => _showBuildingSelector(context, theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedBuilding ?? 'Выберите корпус',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white.withOpacity(0.8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefectTypeSelector(ThemeData theme, BuildContext context) {
    return GestureDetector(
      onTap: () => _showDefectTypeSelector(context, theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _getDefectTypeName(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white.withOpacity(0.8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  String _getDefectTypeName() {
    if (selectedDefectType == null) {
      return 'Все типы дефектов';
    }
    
    try {
      final defectType = defectTypes.firstWhere(
        (type) => type.id == selectedDefectType,
        orElse: () => null,
      );
      return defectType?.name ?? 'Все типы дефектов';
    } catch (e) {
      return 'Все типы дефектов';
    }
  }

  Widget _buildStatCard(String value, String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Статусы квартир',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _buildLegendItems(theme),
        ),
      ],
    );
  }

  List<Widget> _buildLegendItems(ThemeData theme) {
    final items = <Widget>[];
    
    // Без дефектов
    items.add(_buildLegendItem('Без дефектов', theme.colorScheme.surfaceVariant));
    
    // Динамические статусы из базы
    final statusData = [
      (1, 'Получен'),
      (2, 'В работе'),
      (9, 'На проверку'),
      (3, 'Устранен'),
      (4, 'Отклонен'),
    ];
    
    for (final (statusId, label) in statusData) {
      Color color;
      if (statusColors.containsKey(statusId)) {
        final colorHex = statusColors[statusId]!;
        color = Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
      } else {
        // Fallback цвета
        color = _getFallbackColor(statusId);
      }
      items.add(_buildLegendItem(label, color));
    }
    
    return items;
  }
  
  Color _getFallbackColor(int statusId) {
    switch (statusId) {
      case 1: return const Color(0xFFEF4444);
      case 2: return const Color(0xFFF59E0B);
      case 3: return const Color(0xFF10B981);
      case 4: return const Color(0xFF6B7280);
      case 9: return const Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
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

  Widget _buildUnitsGrid(ThemeData theme) {
    if (units.isEmpty) {
      return const EmptyState(
        title: 'Нет данных о квартирах',
        icon: Icons.home_outlined,
      );
    }

    // Group units by floor
    final unitsByFloor = <int, List<Unit>>{};
    for (final unit in units) {
      if (unit.floor != null) {
        unitsByFloor.putIfAbsent(unit.floor!, () => []).add(unit);
      }
    }

    // Sort floors in descending order
    final floors = unitsByFloor.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Схема дома',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            children: floors.map((floor) => RepaintBoundary(
              child: _buildFloorRow(floor, unitsByFloor[floor]!)
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFloorRow(int floor, List<Unit> floorUnits) {
    floorUnits.sort((a, b) => a.name.compareTo(b.name));
    
    final filteredUnits = floorUnits.where((unit) {
      // Фильтр по наличию дефектов
      if (showOnlyDefects && unit.defects.isEmpty) {
        return false;
      }
      
      // Фильтр по типу дефекта
      if (selectedDefectType != null) {
        return unit.defects.any((defect) => defect.typeId == selectedDefectType);
      }
      
      return true;
    }).toList();

    if (filteredUnits.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Floor number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$floor',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Units
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              child: Row(
                children: filteredUnits
                    .map((unit) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: UnitTile(
                            unit: unit,
                            onTap: () => onUnitTap(unit),
                            statusColors: statusColors,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStats() {
    final totalUnits = units.length;
    final unitsWithDefects = units.where((unit) => unit.defects.isNotEmpty).length;
    final totalDefects = units.fold(0, (sum, unit) => sum + unit.defects.length);
    final completedDefects = units.fold(
      0,
      (sum, unit) => sum + unit.defects.where((d) => d.statusId == 3).length,
    );

    return {
      'totalUnits': totalUnits,
      'unitsWithDefects': unitsWithDefects,
      'totalDefects': totalDefects,
      'completedDefects': completedDefects,
    };
  }

  void _showProjectSelector(BuildContext context, ThemeData theme) {
    if (projects.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Выберите проект',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  final isSelected = selectedProject?.id == project.id;
                  
                  return ListTile(
                    title: Text(project.name),
                    trailing: isSelected 
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onProjectChanged(project);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showBuildingSelector(BuildContext context, ThemeData theme) {
    if (selectedProject == null || selectedProject!.buildings.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Выберите корпус',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: selectedProject!.buildings.length,
                itemBuilder: (context, index) {
                  final building = selectedProject!.buildings[index];
                  final isSelected = selectedBuilding == building;
                  
                  return ListTile(
                    title: Text(building),
                    trailing: isSelected 
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onBuildingChanged(building);
                    },
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showDefectTypeSelector(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Выберите тип дефекта',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Опция "Все типы дефектов"
                  ListTile(
                    title: const Text('Все типы дефектов'),
                    trailing: selectedDefectType == null 
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onDefectTypeChanged(null);
                    },
                  ),
                  // Типы дефектов из БД
                  ...defectTypes.map<Widget>((defectType) {
                    final isSelected = selectedDefectType == defectType.id;
                    
                    return ListTile(
                      title: Text(defectType.name),
                      trailing: isSelected 
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        onDefectTypeChanged(defectType.id);
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}