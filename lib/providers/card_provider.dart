import 'package:flutter/foundation.dart';

import '../data/mock/mock_task.dart';
import '../models/task_card.dart';
import '../models/task_interaction.dart';

class CardProvider extends ChangeNotifier {
  // Local data storage
  final List<TaskCard> _cards = List.from(mockTasks);
  final List<TaskComment> _comments = [];
  final List<TaskActivity> _activities = [];

  int _idCounter = 0;

  // Initialize activity history for mock tasks
  CardProvider() {
    for (final card in _cards) {
      _activities.add(
        TaskActivity(
          id: _newId('activity'),
          boardId: card.boardId,
          cardId: card.id,
          actorId: card.createdBy,
          action: 'task_created',
          message: 'Task created',
          createdAt: card.createdAt,
        ),
      );
    }
  }

  // Generate unique local IDs
  String _newId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';
  }

  // Record task activity
  void _recordActivity(
    TaskCard card,
    String action,
    String message, {
    String actorId = 'user1',
  }) {
    _activities.add(
      TaskActivity(
        id: _newId('activity'),
        boardId: card.boardId,
        cardId: card.id,
        actorId: actorId,
        action: action,
        message: message,
        createdAt: DateTime.now(),
      ),
    );
  }

  // Get visible cards from a column
  List<TaskCard> cardsForColumn(String boardId, String columnId) {
    final result = _cards.where((card) {
      return card.boardId == boardId &&
          card.columnId == columnId &&
          !card.archived;
    }).toList();

    result.sort((a, b) {
      final positionOrder = a.position.compareTo(b.position);

      if (positionOrder != 0) {
        return positionOrder;
      }

      final dateOrder = a.createdAt.compareTo(b.createdAt);

      if (dateOrder != 0) {
        return dateOrder;
      }

      return a.id.compareTo(b.id);
    });

    return List.unmodifiable(result);
  }

  // Check whether a column contains ANY cards.
  // Includes completed and archived cards.
  bool hasCardsInColumn(String boardId, String columnId) {
    return _cards.any(
      (card) => card.boardId == boardId && card.columnId == columnId,
    );
  }

  // Count incomplete and non-archived cards
  int openCardCount(String boardId) {
    return _cards.where((card) {
      return card.boardId == boardId && !card.completed && !card.archived;
    }).length;
  }

  // Find a task by ID
  TaskCard? getCard(String cardId) {
    for (final card in _cards) {
      if (card.id == cardId) {
        return card;
      }
    }

    return null;
  }

  // Get all active tasks assigned to a user,
  // across every board.
  List<TaskCard> assignedCardsFor(String userId) {
    final tasks = _cards.where((card) {
      return card.assigneeIds.contains(userId) &&
          !card.completed &&
          !card.archived;
    }).toList();

    return List.unmodifiable(tasks);
  }

  // Get comments for a specific task
  List<TaskComment> commentsForCard(String cardId) {
    final result = _comments
        .where((comment) => comment.cardId == cardId)
        .toList();

    result.sort((a, b) {
      final order = a.createdAt.compareTo(b.createdAt);

      if (order != 0) return order;

      return a.id.compareTo(b.id);
    });

    return List.unmodifiable(result);
  }

  // Get task activity, newest first
  List<TaskActivity> activitiesForCard(String cardId) {
    final result = _activities
        .where((activity) => activity.cardId == cardId)
        .toList();

    result.sort((a, b) {
      final order = b.createdAt.compareTo(a.createdAt);

      if (order != 0) return order;

      return b.id.compareTo(a.id);
    });

    return List.unmodifiable(result);
  }

  // Add a comment
  void addComment({
    required String cardId,
    required String text,
    String userId = 'user1',
  }) {
    final card = getCard(cardId);

    if (card == null || card.archived || text.trim().isEmpty) {
      return;
    }

    _comments.add(
      TaskComment(
        id: _newId('comment'),
        boardId: card.boardId,
        cardId: card.id,
        userId: userId,
        text: text.trim(),
        createdAt: DateTime.now(),
      ),
    );

    _recordActivity(card, 'comment_added', 'Added a comment', actorId: userId);

    notifyListeners();
  }

  // Create a new task
  void addCard({
    required String boardId,
    required String columnId,
    required String title,
    String description = '',
    String createdBy = 'user1',
  }) {
    if (title.trim().isEmpty) return;

    final existing = cardsForColumn(boardId, columnId);

    final position = existing.isEmpty
        ? 1000.0
        : existing.last.position + 1000.0;

    final card = TaskCard(
      id: _newId('task'),
      boardId: boardId,
      columnId: columnId,
      title: title.trim(),
      description: description.trim(),
      position: position,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    _cards.add(card);

    _recordActivity(card, 'task_created', 'Task created', actorId: createdBy);

    notifyListeners();
  }

  // Update task information
  void updateCard(
    String cardId, {
    String? title,
    String? description,
    List<String>? assigneeIds,
    List<TaskLabel>? labels,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<ChecklistItem>? checklist,
  }) {
    final index = _cards.indexWhere((card) => card.id == cardId);

    if (index == -1) return;

    if (title != null && title.trim().isEmpty) {
      return;
    }

    final oldCard = _cards[index];
    final changes = <String>[];

    if (title != null && title.trim() != oldCard.title) {
      changes.add('title');
    }

    if (description != null && description != oldCard.description) {
      changes.add('description');
    }

    if (assigneeIds != null && !listEquals(assigneeIds, oldCard.assigneeIds)) {
      changes.add('assignees');
    }

    if (labels != null) {
      final oldValues = oldCard.labels
          .map((label) => '${label.name}:${label.colorHex}')
          .toList();

      final newValues = labels
          .map((label) => '${label.name}:${label.colorHex}')
          .toList();

      if (!listEquals(oldValues, newValues)) {
        changes.add('labels');
      }
    }

    if (clearDueDate) {
      if (oldCard.dueDate != null) {
        changes.add('due date');
      }
    } else if (dueDate != null && dueDate != oldCard.dueDate) {
      changes.add('due date');
    }

    if (checklist != null) {
      final oldItems = oldCard.checklist
          .map((item) => '${item.id}:${item.text}:${item.isChecked}')
          .toList();

      final newItems = checklist
          .map((item) => '${item.id}:${item.text}:${item.isChecked}')
          .toList();

      if (!listEquals(oldItems, newItems)) {
        changes.add('checklist');
      }
    }

    // No changes means no update
    if (changes.isEmpty) return;

    final updated = oldCard.copyWith(
      title: title?.trim(),
      description: description,
      assigneeIds: assigneeIds,
      labels: labels,
      dueDate: dueDate,
      clearDueDate: clearDueDate,
      checklist: checklist,
    );

    _cards[index] = updated;

    _recordActivity(updated, 'task_updated', 'Updated ${changes.join(', ')}');

    notifyListeners();
  }

  // Move or reorder a task
  void moveCard({
    required String cardId,
    required String targetColumnId,
    required int newIndex,
  }) {
    final card = getCard(cardId);

    if (card == null || card.archived || targetColumnId.isEmpty) {
      return;
    }

    final sourceCards = cardsForColumn(card.boardId, card.columnId);

    final oldIndex = sourceCards.indexWhere((item) => item.id == cardId);

    // Remove the moving task from destination ordering
    final targetCards = cardsForColumn(
      card.boardId,
      targetColumnId,
    ).where((item) => item.id != cardId).toList();

    final index = newIndex.clamp(0, targetCards.length).toInt();

    if (card.columnId == targetColumnId && oldIndex == index) {
      return;
    }

    // Neighbor positions
    final double? before = index > 0 ? targetCards[index - 1].position : null;

    final double? after = index < targetCards.length
        ? targetCards[index].position
        : null;

    double position;

    if (before == null && after == null) {
      position = 1000.0;
    } else if (before == null) {
      position = after! - 1000.0;
    } else if (after == null) {
      position = before + 1000.0;
    } else {
      position = (before + after) / 2;
    }

    final updated = card.copyWith(columnId: targetColumnId, position: position);

    // Rebalance when numeric gaps become too small
    if (before != null && after != null && after - before < 0.000001) {
      targetCards.insert(index, updated);

      for (int i = 0; i < targetCards.length; i++) {
        final itemIndex = _cards.indexWhere(
          (item) => item.id == targetCards[i].id,
        );

        if (itemIndex != -1) {
          _cards[itemIndex] = targetCards[i].copyWith(
            position: (i + 1) * 1000.0,
          );
        }
      }
    } else {
      final cardIndex = _cards.indexWhere((item) => item.id == cardId);

      if (cardIndex == -1) return;

      _cards[cardIndex] = updated;
    }

    _recordActivity(
      updated,
      'task_moved',
      card.columnId == targetColumnId
          ? 'Reordered task'
          : 'Moved task to another column',
    );

    notifyListeners();
  }

  // Complete or reopen a task
  void setCompleted(String cardId, bool completed) {
    final index = _cards.indexWhere((card) => card.id == cardId);

    if (index == -1) return;

    final card = _cards[index];

    if (card.completed == completed) return;

    final updated = card.copyWith(completed: completed);

    _cards[index] = updated;

    _recordActivity(
      updated,
      completed ? 'task_completed' : 'task_reopened',
      completed ? 'Marked task as completed' : 'Marked task as incomplete',
    );

    notifyListeners();
  }

  // Toggle a checklist item
  void toggleChecklistItem(String cardId, String itemId) {
    final index = _cards.indexWhere((card) => card.id == cardId);

    if (index == -1) return;

    final card = _cards[index];

    if (!card.checklist.any((item) => item.id == itemId)) {
      return;
    }

    final updatedChecklist = card.checklist.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isChecked: !item.isChecked);
      }

      return item;
    }).toList();

    final updated = card.copyWith(checklist: updatedChecklist);

    _cards[index] = updated;

    _recordActivity(updated, 'checklist_updated', 'Updated checklist progress');

    notifyListeners();
  }

  // Archive or restore a task
  void setArchived(String cardId, bool archived) {
    final index = _cards.indexWhere((card) => card.id == cardId);

    if (index == -1) return;

    final card = _cards[index];

    if (card.archived == archived) return;

    final updated = card.copyWith(archived: archived);

    _cards[index] = updated;

    _recordActivity(
      updated,
      archived ? 'task_archived' : 'task_restored',
      archived ? 'Archived task' : 'Restored task',
    );

    notifyListeners();
  }

  // Delete task and its comments/activity
  void deleteCard(String cardId) {
    final card = getCard(cardId);

    if (card == null) return;

    _cards.removeWhere((item) => item.id == cardId);

    _comments.removeWhere((comment) => comment.cardId == cardId);

    _activities.removeWhere((activity) => activity.cardId == cardId);

    notifyListeners();
  }

  // Count completed tasks assigned to this user
  int completedTaskCount(String userId) {
    return _cards.where((card) {
      return card.assigneeIds.contains(userId) && card.completed;
    }).length;
  }
}
