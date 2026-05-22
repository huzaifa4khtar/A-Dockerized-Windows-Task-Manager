import 'package:flutter/material.dart';
import 'screens/process_screen.dart' as process;
import 'screens/details_screen.dart';
import 'screens/sockets_screen.dart';
import 'screens/files_screen.dart';
import 'screens/services_screen.dart';
import 'screens/users_screen.dart';
import 'widgets/app_header.dart';

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GUI Based Task Manager',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const TaskManagerHome(),
    );
  }
}

class TaskManagerHome extends StatelessWidget {
  const TaskManagerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        body: Column(
          children: [
            const AppHeader(), // Header banner
            const TabBar(
              tabs: [
                Tab(text: 'Process'),
                Tab(text: 'Details'),
                Tab(text: 'Sockets'),
                Tab(text: 'Files'),
                Tab(text: 'Services'),
                Tab(text: 'User'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  process.ProcessScreen(),
                  DetailsScreen(),
                  SocketsScreen(),
                  FilesScreen(),
                  ServicesScreen(),
                  UsersScreen()
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
