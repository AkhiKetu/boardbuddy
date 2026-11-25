import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/board.dart';
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

  final Map<String, StreamSubscription<List<TaskCard>>> _subscriptions = {};

  final Map<String, List<TaskCard>> _cardsByBoard = {};

  final Map<String, Object> _boardWatchTokens = {};
  final Map<String, Object> _interactionTokens = {};

  final Map<String, StreamSubscription<List<TaskComment>>>
  _commentSubscriptions = {};

  final Map<String, StreamSubscription<List<TaskActivity>>>
  _activitySubscriptions = {};

  final Map<String, List<TaskComment>> _commentsByCard = {};

  final Map<String, List<TaskActivity>> _activitiesByCard = {};

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

  // =====================================
  // PUBLIC GETTERS
  // =====================================

  String? get errorMessage => _errorMessage;

  // FIXED: Required by MyTasksProvider.
  String get currentUserId => _currentUserId;

  Set<String> get accessibleBoardIds {
    return _boardProvider.boards
        .where((board) => _hasBoardAccess(board.id))
        .map((board) => board.id)
        .toSet();
  }

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

  bool _success() {
    _errorMessage = null;
    _notify();
    return true;
  }

  // =====================================
  // LIVE MEMBERSHIP VALIDATION
  // =====================================

  Board? _findBoard(String boardId) {
    if (_disposed || _currentUserId.isEmpty) return null;

    if (_auth.currentUser?.uid != _currentUserId) {
      return null;
    }

    for (final board in _boardProvider.boards) {
      if (board.id == boardId && board.memberIds.contains(_currentUserId)) {
        return board;
      }
    }

    return null;
  }

  bool _hasBoardAccess(String boardId) {
    return _findBoard(boardId) != null;
  }

  bool _isBoardOwner(String boardId) {
    final board = _findBoard(boardId);

    return board != null && board.ownerId == _currentUserId;
  }

  // =====================================
  // REMOVE OLD LISTENERS
  // =====================================

  void _removeInteractionWatchers(String cardId) {
    _interactionTokens.remove(cardId);

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

  void _removeBoard(String boardId) {
    _boardWatchTokens.remove(boardId);

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

  // =====================================
  // SYNCHRONIZE ACCESSIBLE BOARDS
  // =====================================

  void _syncBoards() {
    if (_disposed) return;

    final userId = _boardProvider.currentUserId;

    // Clear previous account data.
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
        : _boardProvider.boards
              .where((board) => board.memberIds.contains(userId))
              .map((board) => board.id)
              .toSet();

    // Stop listeners for inaccessible boards.
    for (final boardId in _subscriptions.keys.toList()) {
      if (!allowedBoardIds.contains(boardId)) {
        _removeBoard(boardId);
      }
    }

    // Listen to newly accessible boards.
    for (final boardId in allowedBoardIds) {
      if (_subscriptions.containsKey(boardId)) continue;

      final listeningUserId = _currentUserId;
      final token = Object();

      _boardWatchTokens[boardId] = token;

      _subscriptions[boardId] = _service
          .watchCards(boardId)
          .listen(
            (cards) {
              if (_disposed ||
                  _currentUserId != listeningUserId ||
                  _boardWatchTokens[boardId] != token ||
                  !_hasBoardAccess(boardId)) {
                return;
              }

              _cardsByBoard[boardId] = cards;

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
                  _boardWatchTokens[boardId] != token) {
                return;
              }

              debugPrint('Card loading error: $error');

              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                _removeBoard(boardId);
              }

              _errorMessage = 'Unable to load tasks from Firestore.';

              _notify();
            },
          );
    }

    _notify();
  }

  // =====================================
  // CARD DATA AND COUNTS
  // =====================================

  Iterable<TaskCard> get _allCards {
    return _cardsByBoard.entries
        .where((entry) => _hasBoardAccess(entry.key))
        .expand((entry) => entry.value);
  }

  int _compareCards(TaskCard a, TaskCard b) {
    final positionOrder = a.position.compareTo(b.position);

    if (positionOrder != 0) return positionOrder;

    final dateOrder = a.createdAt.compareTo(b.createdAt);

    if (dateOrder != 0) return dateOrder;

    return a.id.compareTo(b.id);
  }

  List<TaskCard> cardsForColumn(String boardId, String columnId) {
    if (!_hasBoardAccess(boardId)) return const [];

    final cards = (_cardsByBoard[boardId] ?? const <TaskCard>[])
        .where((card) => card.columnId == columnId && !card.archived)
        .toList();

    cards.sort(_compareCards);

    return List.unmodifiable(cards);
  }

  TaskCard? getCard(String cardId) {
    for (final card in _allCards) {
      if (card.id == cardId) return card;
    }

    return null;
  }

  bool hasCardsInColumn(String boardId, String columnId) {
    if (!_hasBoardAccess(boardId)) return false;

    return (_cardsByBoard[boardId] ?? const <TaskCard>[]).any(
      (card) => card.columnId == columnId,
    );
  }

  int openCardCount(String boardId) {
    if (!_hasBoardAccess(boardId)) return 0;

    return (_cardsByBoard[boardId] ?? const <TaskCard>[])
        .where((card) => !card.completed && !card.archived)
        .length;
  }

  bool _isActiveAssignee(TaskCard card, String userId) {
    final board = _findBoard(card.boardId);

    return board != null &&
        board.memberIds.contains(userId) &&
        card.assigneeIds.contains(userId);
  }

  List<TaskCard> assignedCardsFor(String userId) {
    final tasks = _allCards
        .where(
          (card) =>
              _isActiveAssignee(card, userId) &&
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
        .where((card) => _isActiveAssignee(card, userId) && card.completed)
        .length;
  }

  // =====================================
  // COMMENTS AND ACTIVITY LISTENERS
  // =====================================

  void _ensureInteractionListeners(String cardId) {
    if (_disposed || _currentUserId.isEmpty) return;

    final card = getCard(cardId);

    if (card == null) return;

    if (_interactionBoardIds.containsKey(cardId)) return;

    final boardId = card.boardId;
    final listeningUserId = _currentUserId;
    final token = Object();

    _interactionBoardIds[cardId] = boardId;
    _interactionTokens[cardId] = token;

    bool isCurrentListener() {
      return !_disposed &&
          _currentUserId == listeningUserId &&
          _interactionTokens[cardId] == token &&
          _hasBoardAccess(boardId);
    }

    _commentSubscriptions[cardId] = _interactionService
        .watchComments(boardId: boardId, cardId: cardId)
        .listen(
          (comments) {
            if (!isCurrentListener()) return;

            _commentsByCard[cardId] = comments;
            _notify();
          },
          onError: (Object error) {
            if (!isCurrentListener()) return;

            debugPrint('Comment loading error: $error');

            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              _removeInteractionWatchers(cardId);
            }

            _errorMessage = 'Unable to load comments.';
            _notify();
          },
        );

    _activitySubscriptions[cardId] = _interactionService
        .watchActivities(boardId: boardId, cardId: cardId)
        .listen(
          (activities) {
            if (!isCurrentListener()) return;

            _activitiesByCard[cardId] = activities;
            _notify();
          },
          onError: (Object error) {
            if (!isCurrentListener()) return;

            debugPrint('Activity loading error: $error');

            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              _removeInteractionWatchers(cardId);
            }

            _errorMessage = 'Unable to load activity history.';

            _notify();
          },
        );
  }

  List<TaskComment> commentsForCard(String cardId) {
    if (getCard(cardId) == null) return const [];

    _ensureInteractionListeners(cardId);

    return List.unmodifiable(_commentsByCard[cardId] ?? const <TaskComment>[]);
  }

  List<TaskActivity> activitiesForCard(String cardId) {
    if (getCard(cardId) == null) return const [];

    _ensureInteractionListeners(cardId);

    return List.unmodifiable(
      _activitiesByCard[cardId] ?? const <TaskActivity>[],
    );
  }

  Future<void> _recordActivity(
    TaskCard card,
    String action,
    String message,
    String actorId,
  ) async {
    if (_auth.currentUser?.uid != actorId || !_hasBoardAccess(card.boardId)) {
      return;
    }

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

  // =====================================
  // ADD COMMENT
  // =====================================

  Future<bool> addComment({
    required String cardId,
    required String text,
    String userId = 'user1',
  }) async {
    final card = getCard(cardId);

    if (card == null) {
      return _fail('Task not found or access removed.');
    }

    if (card.archived) {
      return _fail('Cannot comment on an archived task.');
    }

    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return _fail('Comment cannot be empty.');
    }

    if (cleanText.length > 2000) {
      return _fail('Comment is too long.');
    }

    final actorId = _currentUserId;

    try {
      await _interactionService.postComment(
        boardId: card.boardId,
        cardId: card.id,
        text: cleanText,
      );

      unawaited(
        _recordActivity(card, 'comment_added', 'Added a comment', actorId),
      );

      return _success();
    } catch (error) {
      debugPrint('Save comment error: $error');

      return _fail('Unable to save comment.');
    }
  }

  // =====================================
  // CREATE TASK
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

    if (!_hasBoardAccess(boardId)) {
      return _fail('You cannot access this board.');
    }

    if (title.trim().isEmpty || title.trim().length > 120) {
      return _fail('Enter a valid task title.');
    }

    if (description.length > 5000) {
      return _fail('Description is too long.');
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

      unawaited(
        _recordActivity(newCard, 'task_created', 'Task created', user.uid),
      );

      return _success();
    } catch (error) {
      debugPrint('Create task error: $error');

      return _fail('Unable to create task. Check Firestore permissions.');
    }
  }

  // =====================================
  // UPDATE TASK
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
      return _fail('Task not found or access removed.');
    }

    final board = _findBoard(card.boardId);

    if (board == null) {
      return _fail('You cannot access this board.');
    }

    if (title != null && (title.trim().isEmpty || title.trim().length > 120)) {
      return _fail('Enter a valid task title.');
    }

    if (description != null && description.length > 5000) {
      return _fail('Description is too long.');
    }

    if (checklist != null && checklist.length > 100) {
      return _fail('Maximum 100 checklist items allowed.');
    }

    final validAssignees = assigneeIds
        ?.where((id) => board.memberIds.contains(id))
        .toSet()
        .toList();

    final actorId = _currentUserId;

    try {
      await _service.updateCard(
        boardId: card.boardId,
        cardId: card.id,
        title: title?.trim(),
        description: description,
        assigneeIds: validAssignees,
        labels: labels,
        dueDate: dueDate,
        clearDueDate: clearDueDate,
        checklist: checklist,
      );

      unawaited(
        _recordActivity(card, 'task_updated', 'Updated task details', actorId),
      );

      return _success();
    } catch (error) {
      debugPrint('Update task error: $error');

      return _fail('Unable to update task.');
    }
  }

  // =====================================
  // LIVE ASSIGNEE MANAGEMENT
  // =====================================

  Future<bool> setTaskAssignee(String cardId, String memberId, bool selected) {
    return _changeTaskAssignees(cardId, memberId: memberId, selected: selected);
  }

  Future<bool> cleanTaskAssignees(String cardId) {
    return _changeTaskAssignees(cardId);
  }

  Future<bool> _changeTaskAssignees(
    String cardId, {
    String? memberId,
    bool selected = false,
  }) async {
    final card = getCard(cardId);

    if (card == null) {
      return _fail('Task not found or access removed.');
    }

    final user = _auth.currentUser;

    if (user == null) {
      return _fail('Please sign in first.');
    }

    final boardRef = _firestore.collection('boards').doc(card.boardId);

    final cardRef = boardRef.collection('cards').doc(card.id);

    try {
      final changed = await _firestore.runTransaction<bool>((
        transaction,
      ) async {
        final boardSnapshot = await transaction.get(boardRef);

        final cardSnapshot = await transaction.get(cardRef);

        if (!boardSnapshot.exists || !cardSnapshot.exists) {
          throw StateError('Board or task no longer exists.');
        }

        final boardData = boardSnapshot.data()!;
        final cardData = cardSnapshot.data()!;

        final members = List<String>.from(boardData['memberIds'] ?? []);

        if (!members.contains(user.uid)) {
          throw StateError('Board access removed.');
        }

        if (boardData['deleting'] == true) {
          throw StateError('Board is being deleted.');
        }

        final previous = List<String>.from(cardData['assigneeIds'] ?? []);

        // Remove assignments from former members.
        final updated = previous.where((id) => members.contains(id)).toSet();

        if (memberId != null) {
          if (selected) {
            if (!members.contains(memberId)) {
              throw StateError('This user is no longer a board member.');
            }

            updated.add(memberId);
          } else {
            updated.remove(memberId);
          }
        }

        if (updated.length > 100) {
          throw StateError('Maximum 100 assignees allowed.');
        }

        final updatedList = updated.toList();

        if (listEquals(previous, updatedList)) {
          return false;
        }

        transaction.update(cardRef, {'assigneeIds': updatedList});

        return true;
      });

      if (changed) {
        unawaited(
          _recordActivity(
            card,
            'task_updated',
            memberId == null
                ? 'Cleared former member assignments'
                : 'Updated task assignments',
            user.uid,
          ),
        );
      }

      return _success();
    } catch (error) {
      debugPrint('Task assignment error: $error');

      return _fail('Unable to update task assignments.');
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

    final actorId = _currentUserId;

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
      final needsRebalance =
          (before != null && after != null && after - before < 0.000001) ||
          position <= -1000000000 ||
          position >= 1000000000;

      if (needsRebalance) {
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
        // Normal movement updates only one document.
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
          actorId,
        ),
      );

      return _success();
    } catch (error) {
      debugPrint('Move task error: $error');

      return _fail('Unable to move task.');
    }
  }

  // =====================================
  // TASK COMPLETION
  // =====================================

  Future<bool> setCompleted(String cardId, bool completed) async {
    final card = getCard(cardId);

    if (card == null) {
      return _fail('Task not found or access removed.');
    }

    if (card.completed == completed) return true;

    final actorId = _currentUserId;

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
          actorId,
        ),
      );

      return _success();
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
      return _fail('Task not found or access removed.');
    }

    final hasItem = card.checklist.any((item) => item.id == itemId);

    if (!hasItem) {
      return _fail('Checklist item not found.');
    }

    final checklist = card.checklist.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isChecked: !item.isChecked);
      }

      return item;
    }).toList();

    final actorId = _currentUserId;

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
          actorId,
        ),
      );

      return _success();
    } catch (error) {
      debugPrint('Checklist error: $error');

      return _fail('Unable to update checklist.');
    }
  }

  // =====================================
  // ARCHIVE AND RESTORE
  // =====================================

  Future<bool> setArchived(String cardId, bool archived) async {
    final card = getCard(cardId);

    if (card == null) {
      return _fail('Task not found or access removed.');
    }

    final actorId = _currentUserId;

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
          actorId,
        ),
      );

      return _success();
    } catch (error) {
      debugPrint('Archive task error: $error');

      return _fail('Unable to archive or restore task.');
    }
  }

  // =====================================
  // PERMANENT TASK DELETION
  // =====================================

  Future<bool> deleteCard(String cardId) async {
    final card = getCard(cardId);

    if (card == null) {
      return _fail('Task not found or access removed.');
    }

    if (!_isBoardOwner(card.boardId)) {
      return _fail('Only the board owner can delete tasks.');
    }

    try {
      await _deletionService.deleteTask(boardId: card.boardId, cardId: card.id);

      return _success();
    } catch (error) {
      debugPrint('Delete task error: $error');

      return _fail(
        'Unable to delete task. '
        'Check your connection and permissions.',
      );
    }
  }

  // =====================================
  // CLEANUP
  // =====================================

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

    _boardWatchTokens.clear();
    _interactionTokens.clear();

    _cardsByBoard.clear();
    _commentsByCard.clear();
    _activitiesByCard.clear();
    _interactionBoardIds.clear();

    super.dispose();
  }
}
