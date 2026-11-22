import 'package:flutter/material.dart';

import '../boards/boards_screen.dart';
import '../tasks/my_tasks_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Currently selected navigation tab
  int selectedIndex = 0;

  // App bar titles
  final List<String> titles = ['Boards', 'My Tasks', 'Profile'];

  // Screens displayed by the bottom navigation
  final List<Widget> pages = [
    const BoardsScreen(),
    const MyTasksScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top app bar
      appBar: AppBar(title: Text(titles[selectedIndex])),

      // Display selected screen
      body: IndexedStack(index: selectedIndex, children: pages),

      // Bottom navigation
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,

        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Boards',
          ),

          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'My Tasks',
          ),

          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
