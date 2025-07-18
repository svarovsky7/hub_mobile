import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../entities/project/bloc/project_bloc.dart';
import '../entities/project/bloc/project_state.dart';
import '../entities/project/bloc/project_event.dart';
import '../entities/project/model/project.dart';
import '../models/project.dart' as legacy;
import '../services/database_service.dart';
import '../providers/theme_provider.dart';
import '../main.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  int? _defaultProjectId;

  @override
  void initState() {
    super.initState();
    _loadDefaultProject();
  }

  Future<void> _loadDefaultProject() async {
    final defaultProjectId = await DatabaseService.getUserDefaultProjectId();
    if (mounted) {
      setState(() {
        _defaultProjectId = defaultProjectId;
      });
    }
  }

  Future<void> _setAsDefault(int projectId) async {
    final success = await DatabaseService.setUserDefaultProject(projectId);
    if (success && mounted) {
      setState(() {
        _defaultProjectId = projectId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Проект установлен как основной'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearDefault() async {
    final success = await DatabaseService.clearUserDefaultProject();
    if (success && mounted) {
      setState(() {
        _defaultProjectId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Основной проект убран'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Drawer(
      child: Column(
        children: [
          // Header с информацией о пользователе
          _buildUserHeader(theme),
          
          // Разделитель
          const Divider(height: 1),
          
          // Основной контент
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Проекты пользователя
                  _buildProjectsSection(context, theme),
                  
                  const SizedBox(height: 16),
                  
                  // Статистика
                  _buildStatisticsSection(context, theme),
                  
                  const SizedBox(height: 16),
                  
                  // Настройки
                  _buildSettingsSection(context, theme),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Кнопка разлогиниться внизу
          _buildLogoutButton(context, theme),
        ],
      ),
    );
  }

  Widget _buildUserHeader(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DrawerHeader(
            decoration: const BoxDecoration(),
            child: Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            ),
          );
        }
        
        final userInfo = snapshot.data ?? {};
        final userName = userInfo['name'] ?? 'Пользователь';
        final userEmail = userInfo['email'] ?? '';
        
        return DrawerHeader(
          decoration: const BoxDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Аватар
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'П',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Имя пользователя
              Text(
                userName,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              // Email
              if (userEmail.isNotEmpty)
                Text(
                  userEmail,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectsSection(BuildContext context, ThemeData theme) {
    return FutureBuilder<List<legacy.Project>>(
      future: _getUserProjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final userProjects = snapshot.data ?? [];
        if (userProjects.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return BlocBuilder<ProjectBloc, ProjectState>(
          builder: (context, state) {
            final selectedProject = state is ProjectStateLoaded ? state.selectedProject : null;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Мои проекты',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: userProjects.length,
                  itemBuilder: (context, index) {
                    final project = userProjects[index];
                    final isSelected = selectedProject?.id == project.id;
                    final isDefault = _defaultProjectId == project.id;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.business,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                project.name,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Основной',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${project.buildings.length} корпусов',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Кнопка установки как основной
                            GestureDetector(
                              onTap: () {
                                if (isDefault) {
                                  _clearDefault();
                                } else {
                                  _setAsDefault(project.id);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  isDefault ? Icons.star : Icons.star_border,
                                  color: isDefault 
                                      ? theme.colorScheme.secondary 
                                      : theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ),
                            // Индикатор выбранного проекта
                            if (isSelected) 
                              Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          // Конвертируем legacy.Project в entities.Project для ProjectBloc
                          final entitiesProject = Project(
                            id: project.id,
                            name: project.name,
                            buildings: project.buildings,
                          );
                          context.read<ProjectBloc>().add(ProjectEventSelectProject(entitiesProject));
                          // Автоматически выбираем первый корпус
                          if (project.buildings.isNotEmpty) {
                            context.read<ProjectBloc>().add(ProjectEventSelectBuilding(project.buildings.first));
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatisticsSection(BuildContext context, ThemeData theme) {
    return BlocBuilder<ProjectBloc, ProjectState>(
      builder: (context, projectState) {
        // Проверяем, что состояние загружено и есть выбранный проект
        if (projectState is! ProjectStateLoaded) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final selectedProject = projectState.selectedProject;
        
        if (selectedProject == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Статистика',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Выберите проект для просмотра статистики',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(selectedProject.id), // Rebuild when project changes
          future: _getProjectStatistics(selectedProject.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            
            final stats = snapshot.data ?? {};
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Статистика проекта',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        selectedProject.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildStatItem(
                            'Всего квартир',
                            '${stats['totalUnits'] ?? 0}',
                            Icons.apartment_outlined,
                            theme,
                          ),
                          const SizedBox(height: 12),
                          _buildStatItem(
                            'Всего дефектов',
                            '${stats['totalDefects'] ?? 0}',
                            Icons.bug_report_outlined,
                            theme,
                          ),
                          const SizedBox(height: 12),
                          _buildStatItem(
                            'Активных дефектов',
                            '${stats['activeDefects'] ?? 0}',
                            Icons.warning_outlined,
                            theme,
                          ),
                          const SizedBox(height: 12),
                          _buildStatItem(
                            'Закрытых дефектов',
                            '${stats['closedDefects'] ?? 0}',
                            Icons.check_circle_outline,
                            theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Настройки',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Переключатель темы
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Темная тема',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) => themeProvider.toggleTheme(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _handleLogout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Выйти'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getUserInfo() async {
    try {
      return await DatabaseService.getUserInfo();
    } catch (e) {
      // Log error: Error getting user info: $e
      return {};
    }
  }

  Future<Map<String, dynamic>> _getUserStatistics() async {
    try {
      return await DatabaseService.getUserStatistics();
    } catch (e) {
      // Log error: Error getting user statistics: $e
      return {};
    }
  }

  Future<Map<String, dynamic>> _getProjectStatistics(int projectId) async {
    try {
      return await DatabaseService.getProjectStatistics(projectId);
    } catch (e) {
      // Log error: Error getting project statistics: $e
      return {};
    }
  }

  Future<List<legacy.Project>> _getUserProjects() async {
    try {
      return await DatabaseService.getUserProjects();
    } catch (e) {
      // Log error: Error getting user projects: $e
      return [];
    }
  }

  void _handleLogout(BuildContext context) async {
    try {
      await DatabaseService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при выходе: $e')),
        );
      }
    }
  }
}