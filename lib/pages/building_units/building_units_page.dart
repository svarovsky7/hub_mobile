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
    this.showOnlyDefects = false,
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
  final bool showOnlyDefects;

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
              padding: const EdgeInsets.all(16),
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
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(16),
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
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'ЖК "${selectedProject?.name ?? 'Выберите проект'}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Корпус ${selectedBuilding ?? 'Выберите корпус'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
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
          children: [
            _buildLegendItem('Без дефектов', theme.colorScheme.surfaceVariant),
            _buildLegendItem('Новые дефекты', theme.colorScheme.errorContainer),
            _buildLegendItem('В работе', Colors.amber.shade100),
            _buildLegendItem('Устранено', theme.colorScheme.primaryContainer),
          ],
        ),
      ],
    );
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
            children: floors.map((floor) => _buildFloorRow(floor, unitsByFloor[floor]!)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFloorRow(int floor, List<Unit> floorUnits) {
    floorUnits.sort((a, b) => a.name.compareTo(b.name));
    
    final filteredUnits = showOnlyDefects
        ? floorUnits.where((unit) => unit.defects.isNotEmpty).toList()
        : floorUnits;

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
              child: Row(
                children: filteredUnits
                    .map((unit) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: UnitTile(
                            unit: unit,
                            onTap: () => onUnitTap(unit),
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
                    title: Text('Корпус $building'),
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
}