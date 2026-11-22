import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Application theme
import 'core/theme/app_theme.dart';

// Main navigation
import 'screens/home/app_shell.dart';

// Providers
import 'providers/board_provider.dart';
import 'providers/column_provider.dart';
import 'providers/card_provider.dart';

import 'providers/my_task_provider.dart';

class BoardBuddyApp extends StatelessWidget {
  const BoardBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Manages project boards
        ChangeNotifierProvider(create: (_) => BoardProvider()),

        // Manages Kanban columns
        ChangeNotifierProvider(create: (_) => ColumnProvider()),

        // Manages task cards
        ChangeNotifierProvider(create: (_) => CardProvider()),
        ChangeNotifierProvider(
          create: (context) => MyTasksProvider(context.read<CardProvider>()),
        ),
      ],

      child: MaterialApp(
        title: 'BoardBuddy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppShell(),
      ),
    );
  }
}
