import 'package:flutter/material.dart';
import '../../models/unit.dart';
import '../../models/defect.dart';
import '../../entities/project/model/project.dart';
import '../../models/project.dart' as legacy;
import '../../shared/ui/components/feedback/empty_state.dart';
import '../../widgets/defect_card/defect_card.dart';


class DefectDetailsPage extends StatefulWidget {
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
    this.onMarkFixed,
    this.onRefresh,
  });

  final Unit unit;
  final Project project;
  final String building;
  final List<legacy.DefectType> defectTypes;
  final List<legacy.DefectStatus> defectStatuses;
  final VoidCallback onBack;
  final VoidCallback onAddDefect;
  final Function(Defect)? onStatusTap;
  final Function(Defect)? onMarkFixed;
  final Future<void> Function()? onRefresh;

  @override
  State<DefectDetailsPage> createState() => _DefectDetailsPageState();
}

class _DefectDetailsPageState extends State<DefectDetailsPage> {
  bool _hideClosedDefects = false;
  List<Defect> _defects = [];

  @override
  void initState() {
    super.initState();
    _defects = widget.unit.defects;
  }

  @override
  void didUpdateWidget(DefectDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unit != widget.unit) {
      _defects = widget.unit.defects;
    }
  }

  void _updateDefect(Defect updatedDefect) {
    setState(() {
      final index = _defects.indexWhere((d) => d.id == updatedDefect.id);
      if (index != -1) {
        _defects[index] = updatedDefect;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Header
        _buildHeader(theme),
        
        // Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _defects.isEmpty
                  ? _buildEmptyState()
                  : _buildDefectsList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
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
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Квартира ${widget.unit.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.unit.floor} этаж, ${widget.building} Корпус',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'ЖК "${widget.project.name}"',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter button
              IconButton(
                onPressed: () {
                  setState(() {
                    _hideClosedDefects = !_hideClosedDefects;
                  });
                },
                icon: Icon(
                  _hideClosedDefects ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _hideClosedDefects 
                      ? Colors.orange.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.2),
                ),
                tooltip: _hideClosedDefects ? 'Показать все дефекты' : 'Скрыть закрытые дефекты',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onAddDefect,
                icon: const Icon(Icons.add, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: EmptyState(
          title: 'Дефектов нет',
          subtitle: 'В этой квартире пока не зарегистрированы дефекты',
          emoji: '🏠',
          actionText: 'Добавить дефект',
          onAction: widget.onAddDefect,
        ),
      ),
    );
  }

  Widget _buildDefectsList() {
    // Фильтруем дефекты в зависимости от состояния фильтра
    final filteredDefects = _hideClosedDefects
        ? _defects.where((defect) {
            // Ищем статус "Закрыто" или "Устранено" (обычно ID 3 или 5)
            final defectStatus = widget.defectStatuses.firstWhere(
              (s) => s.id == defect.statusId,
              orElse: () => legacy.DefectStatus(
                id: 0,
                entity: 'defect',
                name: 'Неизвестный статус',
                color: '#999999',
              ),
            );
            // Скрываем дефекты со статусом "Устранено", "Закрыто", или содержащие эти слова
            final statusName = defectStatus.name.toLowerCase();
            return !statusName.contains('закрыт') && 
                   !statusName.contains('устранен') && 
                   defect.statusId != 3 && // Обычно "Устранено"
                   defect.statusId != 5;   // Обычно "Закрыто"
          }).toList()
        : _defects;

    if (filteredDefects.isEmpty) {
      if (_hideClosedDefects && _defects.isNotEmpty) {
        return EmptyState(
          title: 'Все дефекты закрыты',
          subtitle: 'Остались только закрытые дефекты',
          emoji: '✅',
          actionText: 'Показать все',
          onAction: () {
            setState(() {
              _hideClosedDefects = false;
            });
          },
        );
      }
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: filteredDefects.length,
      itemBuilder: (context, index) {
        final defect = filteredDefects[index];
        final defectType = widget.defectTypes.firstWhere(
          (t) => t.id == defect.typeId,
          orElse: () => legacy.DefectType(id: 0, name: 'Неизвестный тип'),
        );
        final defectStatus = widget.defectStatuses.firstWhere(
          (s) => s.id == defect.statusId,
          orElse: () => legacy.DefectStatus(
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
          onStatusTap: widget.onStatusTap != null ? () => widget.onStatusTap!(defect) : null,
          onMarkFixed: widget.onMarkFixed != null ? () => widget.onMarkFixed!(defect) : null,
          onDefectUpdated: _updateDefect,
        );
      },
    );
  }

  Future<void> _onRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }
}