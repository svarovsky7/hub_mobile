import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../entities/project/bloc/project_bloc.dart';
import '../entities/project/repository/project_repository.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../services/offline_service.dart';
import '../services/sync_notification_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    OfflineService.connectivityStream.listen((isOnline) {
      if (isOnline && mounted) {
        // Проверяем нужно ли показать уведомление о синхронизации
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SyncNotificationService.checkAndShowSyncNotification(context);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ProjectRepository>(
      create: (context) => ProjectRepositoryImpl(),
      child: Builder(
        builder: (context) => BlocProvider(
          create: (context) => ProjectBloc(
            context.read<ProjectRepository>(),
          ),
          child: const DashboardPage(),
        ),
      ),
    );
  }
}