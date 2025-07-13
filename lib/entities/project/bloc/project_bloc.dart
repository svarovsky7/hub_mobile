import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/project_repository.dart';
import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  ProjectBloc(this._repository) : super(const ProjectStateInitial()) {
    on<ProjectEventLoad>(_onLoad);
    on<ProjectEventSelectProject>(_onSelectProject);
    on<ProjectEventSelectBuilding>(_onSelectBuilding);
    on<ProjectEventRefresh>(_onRefresh);
  }

  final ProjectRepository _repository;

  Future<void> _onLoad(
    ProjectEventLoad event,
    Emitter<ProjectState> emit,
  ) async {
    emit(const ProjectStateLoading());
    
    try {
      final projects = await _repository.getProjects();
      
      if (projects.isEmpty) {
        emit(const ProjectStateLoaded(projects: []));
        return;
      }

      // Select first project by default
      final firstProject = projects.first;
      final buildings = await _repository.getBuildingsForProject(firstProject.id);
      final projectWithBuildings = firstProject.copyWith(buildings: buildings);
      
      final updatedProjects = projects.map((p) => 
        p.id == firstProject.id ? projectWithBuildings : p
      ).toList();
      
      emit(ProjectStateLoaded(
        projects: updatedProjects,
        selectedProject: projectWithBuildings,
        selectedBuilding: buildings.isNotEmpty ? buildings.first : null,
      ));
    } catch (e) {
      emit(ProjectStateError(e.toString()));
    }
  }

  Future<void> _onSelectProject(
    ProjectEventSelectProject event,
    Emitter<ProjectState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProjectStateLoaded) return;
    
    try {
      // Сначала обновляем выбранный проект без зданий
      emit(currentState.copyWith(
        selectedProject: event.project,
        selectedBuilding: null,
      ));
      
      // Затем загружаем здания
      final buildings = await _repository.getBuildingsForProject(event.project.id);
      final projectWithBuildings = event.project.copyWith(buildings: buildings);
      
      // Обновляем с полными данными
      emit(currentState.copyWith(
        selectedProject: projectWithBuildings,
        selectedBuilding: buildings.isNotEmpty ? buildings.first : null,
      ));
    } catch (e) {
      emit(ProjectStateError(e.toString()));
    }
  }

  Future<void> _onSelectBuilding(
    ProjectEventSelectBuilding event,
    Emitter<ProjectState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProjectStateLoaded) return;

    emit(currentState.copyWith(selectedBuilding: event.building));
  }

  Future<void> _onRefresh(
    ProjectEventRefresh event,
    Emitter<ProjectState> emit,
  ) async {
    await _onLoad(const ProjectEventLoad(), emit);
  }
}