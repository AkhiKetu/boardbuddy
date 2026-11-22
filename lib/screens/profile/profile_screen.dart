import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/board_provider.dart';
import '../../providers/card_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Find the current user's name from board membership
  String _getUserName(BoardProvider provider, String userId) {
    for (final board in provider.boards) {
      final name = board.memberNames[userId];

      if (name != null && name.trim().isNotEmpty) {
        return name;
      }
    }

    return 'BoardBuddy User';
  }

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BoardProvider>();
    final cardProvider = context.watch<CardProvider>();

    // Current demo account
    final userId = boardProvider.currentUserId;
    final userName = _getUserName(boardProvider, userId);

    // Boards joined by the current user
    final joinedBoards = boardProvider.boards
        .where((board) => board.memberIds.contains(userId))
        .length;

    // Active tasks assigned to the user
    final activeTasks = cardProvider.assignedCardsFor(userId).length;

    // Completed tasks assigned to the user
    final completedTasks = cardProvider.completedTaskCount(userId);

    // Profile avatar initial
    final initial = userName.trim().isEmpty
        ? 'U'
        : userName.trim()[0].toUpperCase();

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
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

                const Chip(
                  label: Text('Demo Account'),
                  avatar: Icon(Icons.person_outline, size: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Account statistics
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

          const SizedBox(height: 28),

          // Personal information
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
                  title: const Text('Name'),
                  subtitle: Text(userName),
                ),

                const Divider(height: 1),

                const ListTile(
                  leading: Icon(Icons.email_outlined),
                  title: Text('Email'),
                  subtitle: Text('Not available in demo mode'),
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

          const Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.grey),
              title: Text('Log Out'),
              subtitle: Text('Available after Firebase Authentication'),
              trailing: Icon(Icons.lock_outline, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 24),

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
