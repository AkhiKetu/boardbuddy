
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// App theme
import 'core/theme/app_theme.dart';

// Main navigation
import 'screens/home/app_shell.dart';

// Our Providers
import 'providers/board_provider.dart';
import 'providers/column_provider.dart';

class BoardBuddyApp extends StatelessWidget {
  const BoardBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Manages boards
        ChangeNotifierProvider(
          create: (_) => BoardProvider(),
        ),

        // Manages columns inside boards
        ChangeNotifierProvider(
          create: (_) => ColumnProvider(),
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
