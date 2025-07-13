import '../model/project.dart';

abstract class ProjectState {
  const ProjectState();
}

class ProjectStateInitial extends ProjectState {
  const ProjectStateInitial();
}

class ProjectStateLoading extends ProjectState {
  const ProjectStateLoading();
}

class ProjectStateLoaded extends ProjectState {
  const ProjectStateLoaded({
    required this.projects,
    this.selectedProject,
    this.selectedBuilding,
  });

  final List<Project> projects;
  final Project? selectedProject;
  final String? selectedBuilding;

  ProjectStateLoaded copyWith({
    List<Project>? projects,
    Project? selectedProject,
    String? selectedBuilding,
  }) {
    return ProjectStateLoaded(
      projects: projects ?? this.projects,
      selectedProject: selectedProject ?? this.selectedProject,
      selectedBuilding: selectedBuilding ?? this.selectedBuilding,
    );
  }
}

class ProjectStateError extends ProjectState {
  const ProjectStateError(this.message);
  final String message;
}