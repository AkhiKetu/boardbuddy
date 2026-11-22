import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/board.dart';
import '../../models/task_card.dart';

import '../../providers/board_provider.dart';
import '../../providers/my_task_provider.dart';

import '../../core/widgets/task_card_widget.dart';
import '../boards/task_details_screen.dart';

class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  // Display name for each task group
  String _groupTitle(MyTaskGroup group) {
    switch (group) {
      case MyTaskGroup.overdue:
        return 'Overdue';
      case MyTaskGroup.today:
        return 'Today';
      case MyTaskGroup.thisWeek:
        return 'This Week';
      case MyTaskGroup.later:
        return 'Later';
    }
  }

  // Icon for each group
  IconData _groupIcon(MyTaskGroup group) {
    switch (group) {
      case MyTaskGroup.overdue:
        return Icons.warning_amber_rounded;
      case MyTaskGroup.today:
        return Icons.today_outlined;
      case MyTaskGroup.thisWeek:
        return Icons.date_range_outlined;
      case MyTaskGroup.later:
        return Icons.event_note_outlined;
    }
  }

  // Color for each group
  Color _groupColor(MyTaskGroup group) {
    switch (group) {
      case MyTaskGroup.overdue:
        return Colors.red;
      case MyTaskGroup.today:
        return Colors.orange;
      case MyTaskGroup.thisWeek:
        return Colors.blue;
      case MyTaskGroup.later:
        return Colors.purple;
    }
  }

  // Open the existing Task Details screen
  void _openTask(BuildContext context, Board board, TaskCard task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(board: board, cardId: task.id),
      ),
    );
  }

  // Build one section: Overdue, Today, This Week, Later
  Widget _buildTaskSection(
    BuildContext context, {
    required MyTaskGroup group,
    required List<TaskCard> tasks,
    required Map<String, Board> boardsById,
  }) {
    final color = _groupColor(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section heading
          Row(
            children: [
              Icon(_groupIcon(group), color: color, size: 24),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  _groupTitle(group),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Task count
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Empty group message
          if (tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No tasks in this section',
                style: TextStyle(color: Colors.grey),
              ),
            ),

          // Task cards in this group
          ...tasks.map((task) {
            final board = boardsById[task.boardId];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Board name
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 5),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.dashboard_outlined,
                          size: 15,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            board?.title ?? 'Unknown Board',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reuse existing task card widget
                  TaskCardWidget(
                    task: task,
                    onTap: board == null
                        ? null
                        : () {
                            _openTask(context, board, task);
                          },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current mock logged-in user
    final boardProvider = context.watch<BoardProvider>();
    final currentUserId = boardProvider.currentUserId;

    // Listen for changes to assigned tasks
    final myTasksProvider = context.watch<MyTasksProvider>();

    final groupedTasks = myTasksProvider.groupedTasks(currentUserId);

    final totalTasks = myTasksProvider.totalAssignedTasks(currentUserId);

    // Find each task's board
    final boardsById = <String, Board>{
      for (final board in boardProvider.boards) board.id: board,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks'), centerTitle: false),

      body: totalTasks == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 70,
                      color: Colors.grey,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'No assigned tasks',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Tasks assigned to you will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.task_alt, size: 38),

                        const SizedBox(width: 16),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalTasks Active Tasks',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('Assigned to you across all boards'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Required four task groups
                for (final group in MyTaskGroup.values)
                  _buildTaskSection(
                    context,
                    group: group,
                    tasks: groupedTasks[group] ?? [],
                    boardsById: boardsById,
                  ),
              ],
            ),
    );
  }
}
