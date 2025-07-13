import '../model/project.dart';

abstract class ProjectEvent {
  const ProjectEvent();
}

class ProjectEventLoad extends ProjectEvent {
  const ProjectEventLoad();
}

class ProjectEventSelectProject extends ProjectEvent {
  const ProjectEventSelectProject(this.project);
  final Project project;
}

class ProjectEventSelectBuilding extends ProjectEvent {
  const ProjectEventSelectBuilding(this.building);
  final String building;
}

class ProjectEventRefresh extends ProjectEvent {
  const ProjectEventRefresh();
}