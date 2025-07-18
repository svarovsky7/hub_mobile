import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../entities/project/bloc/project_bloc.dart';
import '../entities/project/bloc/project_event.dart';
import '../entities/project/repository/project_repository.dart';
import '../pages/dashboard/dashboard_page.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

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