import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/task_card.dart';
import '../models/task_interaction.dart';
import '../services/card_service.dart';
import '../services/task_interaction_service.dart';
import '../services/task_deletion_service.dart';
import 'board_provider.dart';

class CardProvider extends ChangeNotifier {
  final BoardProvider _boardProvider;
  final CardService _service;
  final TaskInteractionService _interactionService;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final TaskDeletionService _deletionService = TaskDeletionService();
  // Live Firestore card listeners.
  final Map<String, StreamSubscription<List<TaskCard>>> _subscriptions = {};
  // Cards grouped by board.
  final Map<String, List<TaskCard>> _cardsByBoard = {};
  // Live comment and activity listeners.
  final Map<String, StreamSubscription<List<TaskComment>>>
  _commentSubscriptions = {};
  final Map<String, StreamSubscription<List<TaskActivity>>>
  _activitySubscriptions = {};
  // Comments and activity loaded from Firestore.
  final Map<String, List<TaskComment>> _commentsByCard = {};
  final Map<String, List<TaskActivity>> _activitiesByCard = {};
  // Track which board each watched card belongs to.
  final Map<String, String> _interactionBoardIds = {};
  String _currentUserId = '';
  String? _errorMessage;
  bool _disposed = false;
  CardProvider(
    this._boardProvider, {
    CardService? cardService,
    TaskInteractionService? interactionService,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _service = cardService ?? CardService(),
       _interactionService = interactionService ?? TaskInteractionService(),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance {
    _boardProvider.addListener(_syncBoards);
    _syncBoards();
  }
  String? get errorMessage => _errorMessage;
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _fail(String message) {
    _errorMessage = message;
    _notify();
    return false;
  }

  // Stop watching a card's comments and activity.
  void _removeInteractionWatchers(String cardId) {
    final commentListener = _commentSubscriptions.remove(cardId);
    final activityListener = _activitySubscriptions.remove(cardId);
    if (commentListener != null) {
      unawaited(commentListener.cancel());
    }
    if (activityListener != null) {
      unawaited(activityListener.cancel());
    }
    _commentsByCard.remove(cardId);
    _activitiesByCard.remove(cardId);
    _interactionBoardIds.remove(cardId);
  }

  // Stop watching a board and its card interactions.
  void _removeBoard(String boardId) {
    final subscription = _subscriptions.remove(boardId);
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _cardsByBoard.remove(boardId);
    final cardIds = _interactionBoardIds.entries
        .where((entry) => entry.value == boardId)
        .map((entry) => entry.key)
        .toList();
    for (final cardId in cardIds) {
      _removeInteractionWatchers(cardId);
    }
  }

  // Keep Firestore listeners synchronized with
  // the authenticated user's accessible boards.
  void _syncBoards() {
    if (_disposed) return;
    final userId = _boardProvider.currentUserId;
    // Prevent another account from seeing cached data.
    if (_currentUserId != userId) {
      for (final boardId in _subscriptions.keys.toList()) {
        _removeBoard(boardId);
      }
      for (final cardId in _interactionBoardIds.keys.toList()) {
        _removeInteractionWatchers(cardId);
      }
      _currentUserId = userId;
      _cardsByBoard.clear();
      _errorMessage = null;
    }
    final allowedBoardIds = userId.isEmpty
        ? <String>{}
        : _boardProvider.boards.map((board) => board.id).toSet();
    // Remove listeners for inaccessible boards.
    for (final boardId in _subscriptions.keys.toList()) {
      if (!allowedBoardIds.contains(boardId)) {
        _removeBoard(boardId);
      }
    }
    // Start watching accessible boards.
    for (final boardId in allowedBoardIds) {
      if (_subscriptions.containsKey(boardId)) {
        continue;
      }
      final listeningUserId = _currentUserId;
      _subscriptions[boardId] = _service
          .watchCards(boardId)
          .listen(
            (cards) {
              if (_disposed ||
                  _currentUserId != listeningUserId ||
                  !_subscriptions.containsKey(boardId)) {
                return;
              }
              _cardsByBoard[boardId] = cards;
              // Stop watching interactions of deleted cards.
              final existingIds = cards.map((card) => card.id).toSet();
              final removedIds = _interactionBoardIds.entries
                  .where(
                    (entry) =>
                        entry.value == boardId &&
                        !existingIds.contains(entry.key),
                  )
                  .map((entry) => entry.key)
                  .toList();
              for (final cardId in removedIds) {
                _removeInteractionWatchers(cardId);
              }
              _errorMessage = null;
              _notify();
            },
            onError: (Object error) {
              if (_disposed ||
                  _currentUserId != listeningUserId ||
                  !_subscriptions.containsKey(boardId)) {
                return;
              }
              debugPrint('Card loading error: $error');
              _errorMessage = 'Unable to load tasks from Firestore.';
              _notify();
            },
          );
    }
    _notify();
  }

  // All cards from the user's accessible boards.
  Iterable<TaskCard> get _allCards {
    return _cardsByBoard.values.expand((cards) => cards);
  }

  int _compareCards(TaskCard a, TaskCard b) {
    final positionOrder = a.position.compareTo(b.position);
    if (positionOrder != 0) return positionOrder;
    final dateOrder = a.createdAt.compareTo(b.createdAt);
    if (dateOrder != 0) return dateOrder;
    return a.id.compareTo(b.id);
  }

  // Visible cards for one Kanban column.
  List<TaskCard> cardsForColumn(String boardId, String columnId) {
    final cards = (_cardsByBoard[boardId] ?? const <TaskCard>[])
        .where((card) => card.columnId == columnId && !card.archived)
        .toList();
    cards.sort(_compareCards);
    return List.unmodifiable(cards);
  }

  TaskCard? getCard(String cardId) {
    for (final card in _allCards) {
      if (card.id == cardId) {
        return card;
      }
    }
    return null;
  }

  bool hasCardsInColumn(String boardId, String columnId) {
    return (_cardsByBoard[boardId] ?? const <TaskCard>[]).any(
      (card) => card.columnId == columnId,
    );
  }

  int openCardCount(String boardId) {
    return (_cardsByBoard[boardId] ?? const <TaskCard>[])
        .where((card) => !card.completed && !card.archived)
        .length;
  }

  List<TaskCard> assignedCardsFor(String userId) {
    final tasks = _allCards
        .where(
          (card) =>
              card.assigneeIds.contains(userId) &&
              !card.completed &&
              !card.archived,
        )
        .toList();
    tasks.sort((a, b) {
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
      return a.createdAt.compareTo(b.createdAt);
    });
    return List.unmodifiable(tasks);
  }

  int completedTaskCount(String userId) {
    return _allCards
        .where((card) => card.assigneeIds.contains(userId) && card.completed)
        .length;
  }

  // =====================================
  // FIRESTORE COMMENTS AND ACTIVITY

  // =====================================
  // Start listeners only when a card's interactions
  // are requested (normally in Task Details).
  void _ensureInteractionListeners(String cardId) {
    if (_disposed || _currentUserId.isEmpty) return;
    final card = getCard(cardId);
    if (card == null) return;
    if (_interactionBoardIds.containsKey(cardId)) {
      return;
    }
    final boardId = card.boardId;
    final listeningUserId = _currentUserId;
    _interactionBoardIds[cardId] = boardId;
    _commentSubscriptions[cardId] = _interactionService
        .watchComments(boardId: boardId, cardId: cardId)
        .listen(
          (comments) {
            if (_disposed ||
                _currentUserId != listeningUserId ||
                _interactionBoardIds[cardId] != boardId) {
              return;
            }
            _commentsByCard[cardId] = comments;
            _notify();
          },
          onError: (Object error) {
            debugPrint('Comment loading error: $error');
            if (_currentUserId == listeningUserId) {
              _errorMessage = 'Unable to load comments.';
              _notify();
            }
          },
        );
    _activitySubscriptions[cardId] = _interactionService
        .watchActivities(boardId: boardId, cardId: cardId)
        .listen(
          (activities) {
            if (_disposed ||
                _currentUserId != listeningUserId ||
                _interactionBoardIds[cardId] != boardId) {
              return;
            }
            _activitiesByCard[cardId] = activities;
            _notify();
          },
          onError: (Object error) {
            debugPrint('Activity loading error: $error');
            if (_currentUserId == listeningUserId) {
              _errorMessage = 'Unable to load activity history.';
              _notify();
            }
          },
        );
  }

  // Load real-time comments for a task.
  List<TaskComment> commentsForCard(String cardId) {
    _ensureInteractionListeners(cardId);
    return List.unmodifiable(_commentsByCard[cardId] ?? const <TaskComment>[]);
  }

  // Load real-time activity for a task.
  List<TaskActivity> activitiesForCard(String cardId) {
    _ensureInteractionListeners(cardId);
    return List.unmodifiable(
      _activitiesByCard[cardId] ?? const <TaskActivity>[],
    );
  }

  // Record a task action in Firestore.
  // Failure is logged separately from the main task write.
  Future<void> _recordActivity(
    TaskCard card,
    String action,
    String message,
  ) async {
    try {
      await _interactionService.recordActivity(
        boardId: card.boardId,
        cardId: card.id,
        action: action,
        message: message,
      );
    } catch (error) {
      debugPrint('Save activity error: $error');
    }
  }

  // Save comments permanently in Firestore.
  // The userId parameter is retained for compatibility
  // with the existing Task Details screen.
  Future<void> addComment({
    required String cardId,
    required String text,
    String userId = 'user1',
  }) async {
    final card = getCard(cardId);
    if (card == null) {
      _fail('Task not found.');
      return;
    }
    if (card.archived) {
      _fail('Cannot comment on an archived task.');
      return;
    }
    if (text.trim().isEmpty) {
      _fail('Comment cannot be empty.');
      return;
    }
    try {
      await _interactionService.postComment(
        boardId: card.boardId,
        cardId: card.id,
        text: text.trim(),
      );
      _errorMessage = null;
      // Record comment activity after successful saving.
      unawaited(_recordActivity(card, 'comment_added', 'Added a comment'));
      // Firestore listeners update the comment list.
      _notify();
    } catch (error) {
      debugPrint('Save comment error: $error');
      _fail('Unable to save comment.');
    }
  }

  // =====================================
  // TASK CREATION

  // =====================================
  Future<bool> addCard({
    required String boardId,
    required String columnId,
    required String title,
    String description = '',
    String createdBy = 'user1',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return _fail('Please sign in first.');
    }
    final belongsToBoard = _boardProvider.boards.any(
      (board) => board.id == boardId,
    );
    if (!belongsToBoard) {
      return _fail('You cannot access this board.');
    }
    final existing = cardsForColumn(boardId, columnId);
    final position = existing.isEmpty
        ? 1000.0
        : existing.last.position + 1000.0;
    try {
      final cardId = await _service.addCard(
        boardId: boardId,
        columnId: columnId,
        title: title.trim(),
        description: description.trim(),
        position: position,
      );
      final newCard = TaskCard(
        id: cardId,
        boardId: boardId,
        columnId: columnId,
        title: title.trim(),
        description: description.trim(),
        position: position,
        createdBy: user.uid,
        createdAt: DateTime.now(),
      );
      unawaited(_recordActivity(newCard, 'task_created', 'Task created'));
      _errorMessage = null;
      _notify();
      return true;
    } catch (error) {
      debugPrint('Create task error: $error');
      return _fail('Unable to create task. Check Firestore permissions.');
    }
  }

  // =====================================
  // TASK EDITING

  // =====================================
  Future<bool> updateCard(
    String cardId, {
    String? title,
    String? description,
    List<String>? assigneeIds,
    List<TaskLabel>? labels,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<ChecklistItem>? checklist,
  }) async {
    final card = getCard(cardId);
    if (card == null) {
      return _fail('Task not found.');
    }
    try {
      await _service.updateCard(
        boardId: card.boardId,
        cardId: card.id,
        title: title,
        description: description,
        assigneeIds: assigneeIds,
        labels: labels,
        dueDate: dueDate,
        clearDueDate: clearDueDate,
        checklist: checklist,
      );
      unawaited(_recordActivity(card, 'task_updated', 'Updated task details'));
      _errorMessage = null;
      _notify();
      return true;
    } catch (error) {
      debugPrint('Update task error: $error');
      return _fail('Unable to update task.');
    }
  }

  // =====================================
  // DRAG AND DROP

  // =====================================
  Future<bool> moveCard({
    required String cardId,
    required String targetColumnId,
    required int newIndex,
  }) async {
    final card = getCard(cardId);
    if (card == null || card.archived) {
      return _fail('Task is unavailable.');
    }
    final targetCards = cardsForColumn(
      card.boardId,
      targetColumnId,
    ).where((item) => item.id != cardId).toList();
    final index = newIndex.clamp(0, targetCards.length).toInt();
    if (card.columnId == targetColumnId) {
      final original = cardsForColumn(card.boardId, targetColumnId);
      final oldIndex = original.indexWhere((item) => item.id == cardId);
      if (oldIndex == index) return true;
    }
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
    try {
      // Rebalance when two positions are too close.
      if (before != null && after != null && after - before < 0.000001) {
        final orderedCards = List<TaskCard>.from(targetCards);
        orderedCards.insert(index, card);
        final batch = _firestore.batch();
        final collection = _firestore
            .collection('boards')
            .doc(card.boardId)
            .collection('cards');
        for (int i = 0; i < orderedCards.length; i++) {
          final updates = <String, dynamic>{'position': (i + 1) * 1000.0};
          if (orderedCards[i].id == cardId) {
            updates['columnId'] = targetColumnId;
          }
          batch.update(collection.doc(orderedCards[i].id), updates);
        }
        await batch.commit();
      } else {
        // Normal moves update one card document.
        await _service.moveCard(
          boardId: card.boardId,
          cardId: card.id,
          columnId: targetColumnId,
          position: position,
        );
      }
      unawaited(
        _recordActivity(
          card,
          'task_moved',
          card.columnId == targetColumnId
              ? 'Reordered task'
              : 'Moved task to another column',
        ),
      );
      _errorMessage = null;
      _notify();
      return true;
    } catch (error) {
      debugPrint('Move task error: $error');
      return _fail('Unable to move task.');
    }
  }

  // =====================================
  // COMPLETION

  // =====================================
  Future<bool> setCompleted(String cardId, bool completed) async {
    final card = getCard(cardId);
    if (card == null) {
      return _fail('Task not found.');
    }
    if (card.completed == completed) return true;
    try {
      await _service.setCompleted(
        boardId: card.boardId,
        cardId: card.id,
        completed: completed,
      );
      unawaited(
        _recordActivity(
          card,
          completed ? 'task_completed' : 'task_reopened',
          completed ? 'Marked task as completed' : 'Marked task as incomplete',
        ),
      );
      _errorMessage = null;
      _notify();
      return true;
    } catch (error) {
      debugPrint('Complete task error: $error');
      return _fail('Unable to update completion.');
    }
  }

  // =====================================
  // CHECKLIST

  // =====================================
  Future<bool> toggleChecklistItem(String cardId, String itemId) async {
    final card = getCard(cardId);
    if (card == null) {
      return _fail('Task not found.');
    }
    final hasItem = card.checklist.any((item) => item.id == itemId);
    if (!hasItem) return false;
    final checklist = card.checklist.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isChecked: !item.isChecked);
      }
      return item;
    }).toList();
    try {
      await _service.updateCard(
        boardId: card.boardId,
        cardId: card.id,
        checklist: checklist,
      );
      unawaited(
        _recordActivity(
          card,
          'checklist_updated',
          'Updated checklist progress',
        ),
      );
      _errorMessage = null;
      _notify();
      return true;
    } catch (error) {
      debugPrint('Checklist error: $error');
      return _fail('Unable to update checklist.');
    }
  }

  // =====================================
  // ARCHIVE

  // =====================================
  Future<bool> setArchived(String cardId, bool archived) async {
    final card = getCard(cardId);
    if (card == null) {
      return _fail('Task not found.');
    }
    try {
      await _service.setArchived(
        boardId: card.boardId,
        cardId: card.id,
        archived: archived,
      );
      unawaited(
        _recordActivity(
          card,
          archived ? 'task_archived' : 'task_restored',
          archived ? 'Archived task' : 'Restored task',
        ),
      );
      _errorMessage = null;
      _notify();
      return true;
    } catch (error) {
      debugPrint('Archive task error: $error');
      return _fail('Unable to archive task.');
    }
  }

  // Only the board owner can permanently delete a task.
  // The service removes comments and activity first.
  Future<bool> deleteCard(String cardId) async {
    final card = getCard(cardId);
    if (card == null) {
      return _fail('Task not found.');
    }
    if (_currentUserId.isEmpty) {
      return _fail('Please sign in first.');
    }
    try {
      await _deletionService.deleteTask(boardId: card.boardId, cardId: card.id);
      // Firestore card and interaction listeners update the UI.
      _errorMessage = null;
      _notify();
      return true;
    } catch (error) {
      debugPrint('Delete task error: $error');
      return _fail(
        'Unable to delete task. Only the board owner can delete it. '
        'Check your connection and permissions.',
      );
    }
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _boardProvider.removeListener(_syncBoards);
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final subscription in _commentSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final subscription in _activitySubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _commentSubscriptions.clear();
    _activitySubscriptions.clear();
    _cardsByBoard.clear();
    _commentsByCard.clear();
    _activitiesByCard.clear();
    _interactionBoardIds.clear();
    super.dispose();
  }
}
