import 'package:flutter/material.dart';
import '../../entities/project/model/project.dart';
import '../../models/unit.dart';
import '../../shared/ui/components/feedback/loading_overlay.dart';
import '../../shared/ui/components/feedback/empty_state.dart';
import '../../widgets/unit_grid/unit_tile.dart';

class BuildingUnitsPage extends StatefulWidget {
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
    required this.onResetFilters,
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
  final VoidCallback onResetFilters;
  final int? selectedDefectType;

  @override
  State<BuildingUnitsPage> createState() => _BuildingUnitsPageState();
}

class _BuildingUnitsPageState extends State<BuildingUnitsPage> {
  bool _showDefectTypes = false;
  bool _showUnitStatuses = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (widget.selectedProject == null) {
      return EmptyState(
        title: 'Нет доступных проектов',
        icon: Icons.error_outline,
        actionText: 'Обновить',
        onAction: widget.onRefresh,
      );
    }

    return LoadingOverlay(
      isLoading: widget.isLoading,
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
                  _buildCollapsibleDefectTypes(theme),
                  const SizedBox(height: 16),
                  _buildCollapsibleUnitStatuses(theme),
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
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Project title and filter buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showProjectSelector(context, theme),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.selectedProject?.name ?? 'Выберите проект',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                      if (widget.selectedBuilding != null)
                        GestureDetector(
                          onTap: () => _showBuildingSelector(context, theme),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.selectedBuilding!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white.withOpacity(0.8),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reset filters button
                  if (widget.showOnlyDefects || widget.selectedDefectType != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: widget.onResetFilters,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.clear_all, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'Сброс',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Show only defects filter button
                  Material(
                    color: widget.showOnlyDefects 
                        ? Colors.orange.withOpacity(0.9)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: widget.onToggleShowOnlyDefects,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.showOnlyDefects ? Icons.filter_alt : Icons.filter_alt_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.selectedDefectType != null ? 'Фильтр' : (widget.showOnlyDefects ? 'Все' : 'Фильтр'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Statistics grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '${stats['totalUnits']}',
                  'Всего квартир',
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

  Widget _buildCollapsibleDefectTypes(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showDefectTypes = !_showDefectTypes),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Типы дефектов',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _showDefectTypes ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_showDefectTypes) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.defectTypes.map<Widget>((type) {
                  final allDefects = widget.units.expand((unit) => unit.defects).toList();
                  final count = allDefects.where((d) => d.typeId == type.id).length;
                  final isSelected = widget.selectedDefectType == type.id;
                  
                  return InkWell(
                    onTap: count > 0 ? () {
                      if (widget.selectedDefectType == type.id) {
                        widget.onDefectTypeChanged(null);
                      } else {
                        widget.onDefectTypeChanged(type.id);
                      }
                    } : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : count > 0
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${type.name} ($count)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : count > 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsibleUnitStatuses(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showUnitStatuses = !_showUnitStatuses),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Статусы квартир',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _showUnitStatuses ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_showUnitStatuses) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusLegendItem(
                          theme.colorScheme.surfaceVariant,
                          theme.colorScheme.outline,
                          'Без дефектов',
                          theme,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatusLegendItem(
                          const Color(0xFFEF4444),
                          const Color(0xFFEF4444),
                          'Новые дефекты',
                          theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusLegendItem(
                          const Color(0xFFF59E0B),
                          const Color(0xFFF59E0B),
                          'В работе',
                          theme,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatusLegendItem(
                          const Color(0xFF10B981),
                          const Color(0xFF10B981),
                          'Устранено',
                          theme,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusLegendItem(Color bgColor, Color borderColor, String label, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.2),
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
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


  Widget _buildUnitsGrid(ThemeData theme) {
    if (widget.units.isEmpty) {
      return const EmptyState(
        title: 'Нет данных о квартирах',
        icon: Icons.home_outlined,
      );
    }

    // Group units by floor
    final unitsByFloor = <int, List<Unit>>{};
    for (final unit in widget.units) {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
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
      if (widget.showOnlyDefects && unit.defects.isEmpty) {
        return false;
      }
      
      // Фильтр по типу дефекта
      if (widget.selectedDefectType != null) {
        return unit.defects.any((defect) => defect.typeId == widget.selectedDefectType);
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
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$floor',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
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
                            onTap: () => widget.onUnitTap(unit),
                            statusColors: widget.statusColors,
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
    final totalUnits = widget.units.length;
    final unitsWithDefects = widget.units.where((unit) => unit.defects.isNotEmpty).length;
    final totalDefects = widget.units.fold(0, (sum, unit) => sum + unit.defects.length);
    final completedDefects = widget.units.fold(
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
    if (widget.projects.isEmpty) return;
    
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
                itemCount: widget.projects.length,
                itemBuilder: (context, index) {
                  final project = widget.projects[index];
                  final isSelected = widget.selectedProject?.id == project.id;
                  
                  return ListTile(
                    title: Text(project.name),
                    trailing: isSelected 
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onProjectChanged(project);
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
    if (widget.selectedProject == null || widget.selectedProject!.buildings.isEmpty) return;
    
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
                itemCount: widget.selectedProject!.buildings.length,
                itemBuilder: (context, index) {
                  final building = widget.selectedProject!.buildings[index];
                  final isSelected = widget.selectedBuilding == building;
                  
                  return ListTile(
                    title: Text(building),
                    trailing: isSelected 
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      widget.onBuildingChanged(building);
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

}