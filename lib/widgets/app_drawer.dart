import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../entities/project/bloc/project_bloc.dart';
import '../entities/project/bloc/project_state.dart';
import '../entities/project/bloc/project_event.dart';
import '../entities/project/model/project.dart';
import '../services/database_service.dart';
import '../main.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        
        final userInfo = snapshot.data ?? {};
        final userName = userInfo['name'] ?? 'Пользователь';
        final userEmail = userInfo['email'] ?? '';
        
        return DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Аватар
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              // Email
              if (userEmail.isNotEmpty)
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
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
    return BlocBuilder<ProjectBloc, ProjectState>(
      builder: (context, state) {
        if (state is ProjectStateLoaded) {
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
                itemCount: state.projects.length,
                itemBuilder: (context, index) {
                  final project = state.projects[index];
                  final isSelected = state.selectedProject?.id == project.id;
                  
                  return ListTile(
                    leading: Icon(
                      Icons.business,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      project.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${project.buildings.length} корпусов',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isSelected 
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.read<ProjectBloc>().add(ProjectEventSelectProject(project));
                      // Автоматически выбираем первый корпус
                      if (project.buildings.isNotEmpty) {
                        context.read<ProjectBloc>().add(ProjectEventSelectBuilding(project.buildings.first));
                      }
                    },
                  );
                },
              ),
            ],
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStatisticsSection(BuildContext context, ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserStatistics(),
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
              child: Text(
                'Статистика',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
                        'Всего проектов',
                        '${stats['totalProjects'] ?? 0}',
                        Icons.folder_outlined,
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

  Widget _buildLogoutButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
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
      print('Error getting user info: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getUserStatistics() async {
    try {
      return await DatabaseService.getUserStatistics();
    } catch (e) {
      print('Error getting user statistics: $e');
      return {};
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