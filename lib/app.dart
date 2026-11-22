import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/board_provider.dart';
import 'providers/column_provider.dart';
import 'providers/card_provider.dart';
import 'providers/my_task_provider.dart';

// Authentication navigation
import 'screens/auth/auth_gate.dart';

class BoardBuddyApp extends StatelessWidget {
  const BoardBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Firebase Authentication
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Existing board management
        ChangeNotifierProvider(create: (_) => BoardProvider()),

        // Existing Kanban columns
        ChangeNotifierProvider(create: (_) => ColumnProvider()),

        // Existing task management
        ChangeNotifierProvider(create: (_) => CardProvider()),

        // Assigned tasks across boards
        ChangeNotifierProvider(
          create: (context) => MyTasksProvider(context.read<CardProvider>()),
        ),
      ],

      child: MaterialApp(
        title: 'BoardBuddy',

        debugShowCheckedModeBanner: false,

        // Keep the existing theme
        theme: AppTheme.light,

        // Firebase decides the starting screen
        home: const AuthGate(),
      ),
    );
  }
}
