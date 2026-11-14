
import 'package:flutter/material.dart';
import '../boards/boards_screen.dart';

// Main navigation screen
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Current selected tab
  int selectedIndex = 0;

  // Titles for each screen
  final List<String> titles = [
    'BoardBuddy',
    'My Tasks',
    'Profile',
  ];

  //boards 
final List<Widget> pages = const [
  BoardsScreen(),
  Center(child: Text('My Tasks Screen')),
  Center(child: Text('Profile Screen')),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top app bar
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
      ),

      // Display selected screen
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),

      // Bottom navigation
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,

        // When user clicks a tab
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
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
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
