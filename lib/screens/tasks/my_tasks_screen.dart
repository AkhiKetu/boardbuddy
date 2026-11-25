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

  // Group names.
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

  // Group icons.
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

  // Group colors.
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

  // Open task details with current board information.
  void _openTask(BuildContext context, Board board, TaskCard task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(board: board, cardId: task.id),
      ),
    );
  }

  // Build a task group.
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
          // Section heading.
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

              // Task count.
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

          // Empty group.
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

          // Task cards.
          ...tasks.map((task) {
            final board = boardsById[task.boardId];

            if (board == null) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // Board name.
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
                            board.title,

                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  TaskCardWidget(
                    task: task,

                    onTap: () {
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

  // No assigned tasks.
  Widget _buildEmptyState() {
    return Center(
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

              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    );
  }

  // Firestore query error.
  Widget _buildErrorState(MyTasksProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            const Icon(Icons.error_outline, size: 65, color: Colors.red),

            const SizedBox(height: 16),

            const Text(
              'Unable to Load Tasks',

              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              provider.errorMessage ?? 'Something went wrong.',

              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: provider.retry,

              icon: const Icon(Icons.refresh),

              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BoardProvider>();

    final myTasksProvider = context.watch<MyTasksProvider>();

    final currentUserId = boardProvider.currentUserId;

    // Current accessible boards.
    final boardsById = <String, Board>{
      for (final board in boardProvider.boards) board.id: board,
    };

    final groupedTasks = myTasksProvider.groupedTasks(currentUserId);

    final totalTasks = myTasksProvider.totalAssignedTasks(currentUserId);

    // Initial loading.
    if (boardProvider.isLoading || myTasksProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Firestore error.
    if (myTasksProvider.errorMessage != null) {
      return _buildErrorState(myTasksProvider);
    }

    // Empty screen.
    if (totalTasks == 0) {
      return _buildEmptyState();
    }

    // AppShell already provides the AppBar.
    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        // Active tasks summary.
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,

          child: Padding(
            padding: const EdgeInsets.all(18),

            child: Row(
              children: [
                const Icon(Icons.task_alt, size: 38),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
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
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // All four required task groups.
        for (final group in MyTaskGroup.values)
          _buildTaskSection(
            context,
            group: group,
            tasks: groupedTasks[group] ?? [],
            boardsById: boardsById,
          ),
      ],
    );
  }
}
