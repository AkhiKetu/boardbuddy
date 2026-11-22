import 'package:flutter/foundation.dart';

import '../models/task_card.dart';
import 'card_provider.dart';

// The four sections required for My Tasks
enum MyTaskGroup { overdue, today, thisWeek, later }

class MyTasksProvider extends ChangeNotifier {
  final CardProvider _cardProvider;

  MyTasksProvider(this._cardProvider) {
    // Refresh My Tasks when a card changes
    _cardProvider.addListener(_onCardsChanged);
  }

  void _onCardsChanged() {
    notifyListeners();
  }

  // Return active tasks assigned to a user
  List<TaskCard> tasksForUser(String userId) {
    return _cardProvider.assignedCardsFor(userId);
  }

  // Remove the time portion from a date
  DateTime _dateOnly(DateTime date) {
    final localDate = date.toLocal();

    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  // Determine which group a task belongs to
  MyTaskGroup getTaskGroup(TaskCard task, {DateTime? referenceDate}) {
    // Tasks without a deadline belong to Later
    if (task.dueDate == null) {
      return MyTaskGroup.later;
    }

    final today = _dateOnly(referenceDate ?? DateTime.now());

    final dueDate = _dateOnly(task.dueDate!);

    // Before today
    if (dueDate.isBefore(today)) {
      return MyTaskGroup.overdue;
    }

    // Due today
    if (dueDate.isAtSameMomentAs(today)) {
      return MyTaskGroup.today;
    }

    // End of current calendar week (Sunday)
    final endOfWeek = today.add(Duration(days: 7 - today.weekday));

    // Tomorrow through Sunday
    if (!dueDate.isAfter(endOfWeek)) {
      return MyTaskGroup.thisWeek;
    }

    // Next week, future dates and no due date
    return MyTaskGroup.later;
  }

  // Get tasks grouped by due date
  Map<MyTaskGroup, List<TaskCard>> groupedTasks(
    String userId, {
    DateTime? referenceDate,
  }) {
    final groups = <MyTaskGroup, List<TaskCard>>{
      MyTaskGroup.overdue: [],
      MyTaskGroup.today: [],
      MyTaskGroup.thisWeek: [],
      MyTaskGroup.later: [],
    };

    final tasks = tasksForUser(userId);

    for (final task in tasks) {
      final group = getTaskGroup(task, referenceDate: referenceDate);

      groups[group]!.add(task);
    }

    // Sort cards by nearest due date
    for (final groupTasks in groups.values) {
      groupTasks.sort((a, b) {
        // Tasks with no due date go last
        if (a.dueDate == null && b.dueDate != null) {
          return 1;
        }

        if (a.dueDate != null && b.dueDate == null) {
          return -1;
        }

        if (a.dueDate != null && b.dueDate != null) {
          final result = a.dueDate!.compareTo(b.dueDate!);

          if (result != 0) return result;
        }

        final dateOrder = a.createdAt.compareTo(b.createdAt);

        if (dateOrder != 0) return dateOrder;

        return a.id.compareTo(b.id);
      });
    }

    return groups;
  }

  // Count all active assigned tasks
  int totalAssignedTasks(String userId) {
    return tasksForUser(userId).length;
  }

  // Release the listener when the Provider is disposed
  @override
  void dispose() {
    _cardProvider.removeListener(_onCardsChanged);
    super.dispose();
  }
}
