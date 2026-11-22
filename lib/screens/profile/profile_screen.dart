import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/board_provider.dart';
import '../../providers/card_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Confirm before logging out.
  Future<void> _confirmLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Out?'),
          content: const Text(
            'Are you sure you want to log out of BoardBuddy?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    // Sign out from Firebase Authentication.
    await authProvider.logout();

    if (!context.mounted) return;

    // AuthGate automatically returns to Login
    // when logout succeeds.
    if (authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Unable to log out. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final boardProvider = context.watch<BoardProvider>();
    final cardProvider = context.watch<CardProvider>();

    // Firebase account information
    final firebaseUser = authProvider.user;

    final displayName = firebaseUser?.displayName?.trim();

    final userName = displayName != null && displayName.isNotEmpty
        ? displayName
        : 'BoardBuddy User';

    final userEmail = firebaseUser?.email ?? 'No email available';

    final initial = userName[0].toUpperCase();

    // Temporary statistics based on existing mock data.
    // These will use real Firebase user IDs after
    // Firestore integration.
    final demoUserId = boardProvider.currentUserId;

    final joinedBoards = boardProvider.boards
        .where((board) => board.memberIds.contains(demoUserId))
        .length;

    final activeTasks = cardProvider.assignedCardsFor(demoUserId).length;

    final completedTasks = cardProvider.completedTaskCount(demoUserId);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  userName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  userEmail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),

                const SizedBox(height: 10),

                const Chip(
                  label: Text('Firebase Account'),
                  avatar: Icon(Icons.verified_user_outlined, size: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Statistics
          Row(
            children: [
              Expanded(
                child: _ProfileStatCard(
                  title: 'Boards',
                  count: joinedBoards,
                  icon: Icons.dashboard_outlined,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _ProfileStatCard(
                  title: 'Assigned',
                  count: activeTasks,
                  icon: Icons.assignment_outlined,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _ProfileStatCard(
                  title: 'Completed',
                  count: completedTasks,
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Statistics currently use demo task data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),

          const SizedBox(height: 28),

          // Account information
          const Text(
            'Account Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Full Name'),
                  subtitle: Text(userName),
                ),

                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(userEmail),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Account actions
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Sign out of your BoardBuddy account'),
              trailing: authProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: authProvider.isLoading
                  ? null
                  : () => _confirmLogout(context),
            ),
          ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              'BoardBuddy — Project Management App',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable statistics card
class _ProfileStatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _ProfileStatCard({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary),

            const SizedBox(height: 10),

            Text(
              '$count',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
