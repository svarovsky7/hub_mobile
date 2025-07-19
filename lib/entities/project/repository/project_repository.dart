import '../model/project.dart';
import '../../../services/database_service.dart' as db;

abstract class ProjectRepository {
  Future<List<Project>> getProjects();
  Future<List<String>> getBuildingsForProject(int projectId);
  Future<List<DefectType>> getDefectTypes();
  Future<List<DefectStatus>> getDefectStatuses();
  Future<List<ClaimStatus>> getClaimStatuses();
}

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl();

  @override
  Future<List<Project>> getProjects() async {
    try {
      final projects = await db.DatabaseService.getProjects();
      return projects.map((p) => Project(
        id: p.id,
        name: p.name,
        buildings: p.buildings,
      )).toList();
    } catch (e) {
      // Log error: Repository error loading projects: $e
      return [];
    }
  }

  @override
  Future<List<String>> getBuildingsForProject(int projectId) async {
    try {
      return await db.DatabaseService.getBuildingsForProject(projectId);
    } catch (e) {
      // Log error: Repository error loading buildings: $e
      return [];
    }
  }

  @override
  Future<List<DefectType>> getDefectTypes() async {
    try {
      final types = await db.DatabaseService.getDefectTypes();
      return types.map((t) => DefectType(
        id: t.id,
        name: t.name,
      )).toList();
    } catch (e) {
      // Log error: Repository error loading defect types: $e
      return [];
    }
  }

  @override
  Future<List<DefectStatus>> getDefectStatuses() async {
    try {
      final statuses = await db.DatabaseService.getDefectStatuses();
      return statuses.map((s) => DefectStatus(
        id: s.id,
        entity: s.entity,
        name: s.name,
        color: s.color,
      )).toList();
    } catch (e) {
      // Log error: Repository error loading defect statuses: $e
      return [];
    }
  }

  @override
  Future<List<ClaimStatus>> getClaimStatuses() async {
    // TODO: Implement claim statuses when needed
    return [];
  }
}

class ProjectException implements Exception {
  const ProjectException(this.message);
  final String message;

  @override
  String toString() => 'ProjectException: $message';
}