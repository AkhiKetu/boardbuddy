import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../home/app_shell.dart';

import 'login_screen.dart';
import 'register_screen.dart';

// Decides which screen the user should see.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Wait until Firebase checks the login session.
    if (!authProvider.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // User is logged in: open BoardBuddy.
    if (authProvider.isLoggedIn) {
      return const AppShell();
    }

    // User is not logged in: show Login/Register.
    return const _AuthFlow();
  }
}

// Handles switching between Login and Registration.
class _AuthFlow extends StatefulWidget {
  const _AuthFlow();

  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  bool _showRegister = false;

  // Open Registration screen.
  void _openRegister() {
    setState(() {
      _showRegister = true;
    });
  }

  // Return to Login screen.
  void _openLogin() {
    setState(() {
      _showRegister = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterScreen(onLoginTap: _openLogin);
    }

    return LoginScreen(onRegisterTap: _openRegister);
  }
}
