import 'package:flutter/material.dart';
import '../../models/unit.dart';
import '../../models/defect.dart';
import '../../entities/project/model/project.dart';
import '../../models/project.dart' as Legacy;
import '../../shared/ui/components/feedback/empty_state.dart';
import '../../shared/ui/components/buttons/app_button.dart';
import '../../widgets/defect_card/defect_card.dart';


class DefectDetailsPage extends StatelessWidget {
  const DefectDetailsPage({
    super.key,
    required this.unit,
    required this.project,
    required this.building,
    required this.defectTypes,
    required this.defectStatuses,
    required this.onBack,
    required this.onAddDefect,
    this.onStatusTap,
    this.onAttachFiles,
    this.onMarkFixed,
  });

  final Unit unit;
  final Project project;
  final String building;
  final List<Legacy.DefectType> defectTypes;
  final List<Legacy.DefectStatus> defectStatuses;
  final VoidCallback onBack;
  final VoidCallback onAddDefect;
  final Function(Defect)? onStatusTap;
  final Function(Defect)? onAttachFiles;
  final Function(Defect)? onMarkFixed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Header
        _buildHeader(theme),
        
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: unit.defects.isEmpty
                ? _buildEmptyState()
                : _buildDefectsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final activeDefects = unit.defects
        .where((d) => d.statusId == 1 || d.statusId == 2)
        .length;
    final completedDefects = unit.defects
        .where((d) => d.statusId == 3)
        .length;

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
          // Navigation and title
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Квартира ${unit.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${unit.floor} этаж • ЖК "${project.name}" • $building',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onAddDefect,
                icon: const Icon(Icons.add, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiary,
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
                  '${unit.defects.length}',
                  'Дефектов',
                  theme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  '$activeDefects',
                  'Активных',
                  theme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  '$completedDefects',
                  'Устранено',
                  theme,
                ),
              ),
            ],
          ),
        ],
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
              fontSize: 18,
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

  Widget _buildEmptyState() {
    return EmptyState(
      title: 'Дефектов нет',
      subtitle: 'В этой квартире пока не зарегистрированы дефекты',
      emoji: '🏠',
      actionText: 'Добавить дефект',
      onAction: onAddDefect,
    );
  }

  Widget _buildDefectsList() {
    return ListView.builder(
      itemCount: unit.defects.length,
      itemBuilder: (context, index) {
        final defect = unit.defects[index];
        final defectType = defectTypes.firstWhere(
          (t) => t.id == defect.typeId,
          orElse: () => Legacy.DefectType(id: 0, name: 'Неизвестный тип'),
        );
        final defectStatus = defectStatuses.firstWhere(
          (s) => s.id == defect.statusId,
          orElse: () => Legacy.DefectStatus(
            id: 0,
            entity: 'defect',
            name: 'Неизвестный статус',
            color: '#999999',
          ),
        );

        return DefectCard(
          defect: defect,
          defectType: defectType,
          defectStatus: defectStatus,
          onStatusTap: onStatusTap != null ? () => onStatusTap!(defect) : null,
          onAttachFiles: onAttachFiles != null ? () => onAttachFiles!(defect) : null,
          onMarkFixed: onMarkFixed != null ? () => onMarkFixed!(defect) : null,
        );
      },
    );
  }
}