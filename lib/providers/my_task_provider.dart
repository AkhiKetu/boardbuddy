import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/task_card.dart';
import 'card_provider.dart';

enum MyTaskGroup { overdue, today, thisWeek, later }

class MyTasksProvider extends ChangeNotifier {
  final CardProvider _cardProvider;

  final FirebaseFirestore _firestore;

  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subscriptions = {};

  final Map<String, Set<String>> _assignedIdsByBoard = {};

  final Map<String, Object> _watchTokens = {};

  final Set<String> _pendingBoards = {};

  final Map<String, String> _errors = {};

  String _currentUserId = '';

  bool _disposed = false;

  MyTasksProvider(this._cardProvider, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    _cardProvider.addListener(_syncQueries);
    _syncQueries();
  }

  bool get isLoading => _pendingBoards.isNotEmpty;

  String? get errorMessage => _errors.isEmpty ? null : _errors.values.first;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // Stop watching a board.
  void _removeBoard(String boardId) {
    _watchTokens.remove(boardId);

    final subscription = _subscriptions.remove(boardId);

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    _assignedIdsByBoard.remove(boardId);
    _pendingBoards.remove(boardId);
    _errors.remove(boardId);
  }

  // Synchronize queries with the current user
  // and their accessible boards.
  void _syncQueries() {
    if (_disposed) return;

    final userId = _cardProvider.currentUserId;

    // Clear old data when switching accounts.
    if (_currentUserId != userId) {
      for (final boardId in _subscriptions.keys.toList()) {
        _removeBoard(boardId);
      }

      _assignedIdsByBoard.clear();
      _pendingBoards.clear();
      _errors.clear();

      _currentUserId = userId;
    }

    final allowedBoardIds = userId.isEmpty
        ? <String>{}
        : _cardProvider.accessibleBoardIds;

    // Stop listening when membership is removed.
    for (final boardId in _subscriptions.keys.toList()) {
      if (!allowedBoardIds.contains(boardId)) {
        _removeBoard(boardId);
      }
    }

    // Start one secure collection-group query
    // for each accessible board.
    for (final boardId in allowedBoardIds) {
      if (_subscriptions.containsKey(boardId)) continue;

      final token = Object();

      _watchTokens[boardId] = token;
      _pendingBoards.add(boardId);

      _subscriptions[boardId] = _firestore
          .collectionGroup('cards')
          .where('boardId', isEqualTo: boardId)
          .where('assigneeIds', arrayContains: userId)
          .snapshots()
          .listen(
            (snapshot) {
              if (_disposed ||
                  _currentUserId != userId ||
                  _watchTokens[boardId] != token ||
                  !_cardProvider.accessibleBoardIds.contains(boardId)) {
                return;
              }

              _assignedIdsByBoard[boardId] = snapshot.docs
                  .where(
                    (doc) =>
                        doc.reference.parent.parent?.path == 'boards/$boardId',
                  )
                  .map((doc) => doc.id)
                  .toSet();

              _pendingBoards.remove(boardId);
              _errors.remove(boardId);

              _notify();
            },
            onError: (Object error) {
              if (_disposed ||
                  _currentUserId != userId ||
                  _watchTokens[boardId] != token) {
                return;
              }

              debugPrint('My Tasks query error: $error');

              _assignedIdsByBoard.remove(boardId);
              _pendingBoards.remove(boardId);

              _errors[boardId] =
                  'Unable to load assigned tasks. '
                  'Check your connection, Firestore rules '
                  'and indexes.';

              _notify();
            },
          );
    }

    _notify();
  }

  // Retry failed queries.
  void retry() {
    for (final boardId in _subscriptions.keys.toList()) {
      _removeBoard(boardId);
    }

    _syncQueries();
  }

  // Use collection-group results to select assigned
  // cards, reusing CardProvider's existing models.
  List<TaskCard> tasksForUser(String userId) {
    if (userId.isEmpty || userId != _currentUserId) {
      return [];
    }

    return _cardProvider
        .assignedCardsFor(userId)
        .where(
          (task) =>
              _assignedIdsByBoard[task.boardId]?.contains(task.id) ?? false,
        )
        .toList();
  }

  // Remove the time portion.
  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();

    return DateTime(local.year, local.month, local.day);
  }

  // Determine a task's due-date group.
  MyTaskGroup getTaskGroup(TaskCard task, {DateTime? referenceDate}) {
    if (task.dueDate == null) {
      return MyTaskGroup.later;
    }

    final today = _dateOnly(referenceDate ?? DateTime.now());

    final dueDate = _dateOnly(task.dueDate!);

    if (dueDate.isBefore(today)) {
      return MyTaskGroup.overdue;
    }

    if (dueDate.isAtSameMomentAs(today)) {
      return MyTaskGroup.today;
    }

    // End of the current calendar week.
    final endOfWeek = DateTime(
      today.year,
      today.month,
      today.day + 7 - today.weekday,
    );

    if (!dueDate.isAfter(endOfWeek)) {
      return MyTaskGroup.thisWeek;
    }

    return MyTaskGroup.later;
  }

  // Group all active assigned tasks.
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

    for (final task in tasksForUser(userId)) {
      final group = getTaskGroup(task, referenceDate: referenceDate);

      groups[group]!.add(task);
    }

    for (final groupTasks in groups.values) {
      groupTasks.sort((a, b) {
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

  int totalAssignedTasks(String userId) {
    return tasksForUser(userId).length;
  }

  @override
  void dispose() {
    _disposed = true;

    _cardProvider.removeListener(_syncQueries);

    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }

    _subscriptions.clear();
    _assignedIdsByBoard.clear();
    _watchTokens.clear();
    _pendingBoards.clear();
    _errors.clear();

    super.dispose();
  }
}
