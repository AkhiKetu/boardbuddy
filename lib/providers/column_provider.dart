import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/board_column.dart';
import '../services/column_service.dart';
import '../services/column_deletion_service.dart';

class ColumnProvider extends ChangeNotifier {
  final ColumnService _service = ColumnService();
  final ColumnDeletionService _deletionService = ColumnDeletionService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, List<BoardColumn>> _columns = {};
  final Map<String, StreamSubscription<List<BoardColumn>>> _listeners = {};
  final Set<String> _initializingBoards = {};

  StreamSubscription<User?>? _authSubscription;
  String? _activeUserId;
  String? _errorMessage;
  bool _disposed = false;

  ColumnProvider() {
    _activeUserId = _auth.currentUser?.uid;

    _authSubscription = _auth.authStateChanges().listen((user) {
      final uid = user?.uid;

      if (uid == _activeUserId) return;

      _activeUserId = uid;

      // Clear the previous user's column data.
      for (final listener in _listeners.values) {
        unawaited(listener.cancel());
      }

      _listeners.clear();
      _columns.clear();
      _initializingBoards.clear();
      _errorMessage = null;

      _notify();
    });
  }

  String? get errorMessage => _errorMessage;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // Get all columns belonging to a board.
  List<BoardColumn> columnsForBoard(String boardId) {
    return List.unmodifiable(_columns[boardId] ?? []);
  }

  // Start listening for real-time column changes.
  void _watchColumns(String boardId) {
    if (_listeners.containsKey(boardId)) return;

    _listeners[boardId] = _service
        .watchColumns(boardId)
        .listen(
          (updatedColumns) {
            _columns[boardId] = updatedColumns;
            _errorMessage = null;
            _notify();
          },
          onError: (Object error) {
            debugPrint('Column loading error: $error');
            _errorMessage = 'Unable to load columns.';
            _notify();
          },
        );
  }

  // Create default columns only when a board
  // has no columns saved in Firestore.
  void ensureDefaultColumns(String boardId) {
    if (_auth.currentUser == null) return;

    _watchColumns(boardId);

    if (!_initializingBoards.add(boardId)) return;

    unawaited(_createDefaultColumns(boardId));
  }

  Future<void> _createDefaultColumns(String boardId) async {
    try {
      final collection = _firestore
          .collection('boards')
          .doc(boardId)
          .collection('columns');

      // Check the server, not just the local cache.
      final existing = await collection.get(
        const GetOptions(source: Source.server),
      );

      if (existing.docs.isNotEmpty) return;

      // Stable IDs prevent duplicate default columns.
      final refs = [
        collection.doc('${boardId}_todo'),
        collection.doc('${boardId}_doing'),
        collection.doc('${boardId}_done'),
      ];

      const titles = ['To Do', 'Doing', 'Done'];
      const positions = [1000.0, 2000.0, 3000.0];

      // Prevent duplicate default columns when
      // multiple devices initialize the board.
      await _firestore.runTransaction((transaction) async {
        final snapshots = [];

        for (final ref in refs) {
          snapshots.add(await transaction.get(ref));
        }

        for (int i = 0; i < refs.length; i++) {
          if (snapshots[i].exists) continue;

          transaction.set(refs[i], {
            'title': titles[i],
            'position': positions[i],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (error) {
      debugPrint('Default column creation error: $error');
      _errorMessage = 'Unable to initialize board columns.';
      _notify();
    } finally {
      _initializingBoards.remove(boardId);
    }
  }

  // Add a new column and save it to Firestore.
  Future<bool> addColumn(String boardId, String title) async {
    if (title.trim().isEmpty) return false;

    ensureDefaultColumns(boardId);

    try {
      final existing = columnsForBoard(boardId);

      final position = existing.isEmpty
          ? 1000.0
          : existing.last.position + 1000.0;

      await _service.addColumn(
        boardId: boardId,
        title: title.trim(),
        position: position,
      );

      _errorMessage = null;
      return true;
    } catch (error) {
      debugPrint('Add column error: $error');
      _errorMessage = 'Unable to add column.';
      _notify();
      return false;
    }
  }

  // Rename a column in Firestore.
  Future<bool> renameColumn(String columnId, String title) async {
    if (title.trim().isEmpty) return false;

    String? boardId;

    for (final entry in _columns.entries) {
      if (entry.value.any((column) => column.id == columnId)) {
        boardId = entry.key;
        break;
      }
    }

    if (boardId == null) return false;

    try {
      await _service.renameColumn(
        boardId: boardId,
        columnId: columnId,
        title: title.trim(),
      );

      _errorMessage = null;
      return true;
    } catch (error) {
      debugPrint('Rename column error: $error');
      _errorMessage = 'Unable to rename column.';
      _notify();
      return false;
    }
  }

  // Move a column left or right.
  Future<bool> reorderColumn(
    String boardId,
    String columnId,
    int newIndex,
  ) async {
    final columns = List<BoardColumn>.from(columnsForBoard(boardId));

    final oldIndex = columns.indexWhere((column) => column.id == columnId);

    if (oldIndex == -1) return false;

    final movingColumn = columns.removeAt(oldIndex);

    final targetIndex = newIndex.clamp(0, columns.length).toInt();

    if (oldIndex == targetIndex) return true;

    columns.insert(targetIndex, movingColumn);

    final double? before = targetIndex > 0
        ? columns[targetIndex - 1].position
        : null;

    final double? after = targetIndex < columns.length - 1
        ? columns[targetIndex + 1].position
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
      // Rebalance when the numeric gap is too small.
      if (before != null && after != null && after - before < 0.000001) {
        final batch = _firestore.batch();

        for (int i = 0; i < columns.length; i++) {
          final ref = _firestore
              .collection('boards')
              .doc(boardId)
              .collection('columns')
              .doc(columns[i].id);

          batch.update(ref, {'position': (i + 1) * 1000.0});
        }

        await batch.commit();
      } else {
        await _service.updatePosition(
          boardId: boardId,
          columnId: columnId,
          position: position,
        );
      }

      _errorMessage = null;
      return true;
    } catch (error) {
      debugPrint('Reorder column error: $error');
      _errorMessage = 'Unable to reorder column.';
      _notify();
      return false;
    }
  }

  // =====================================
  // COLUMN DELETION
  // =====================================

  Future<bool> deleteColumn(
    String boardId,
    String columnId, {
    required bool hasCards,
  }) async {
    if (_auth.currentUser == null) {
      _errorMessage = 'Please sign in first.';
      _notify();
      return false;
    }

    // Prevent deletion when the local card list
    // contains tasks in this column.
    if (hasCards) {
      _errorMessage = 'Move or delete the cards before removing this column.';
      _notify();
      return false;
    }

    try {
      // Check ownership and existing cards
      // directly from Firestore.
      final deleted = await _deletionService.deleteEmptyColumn(
        boardId: boardId,
        columnId: columnId,
      );

      if (!deleted) {
        _errorMessage = 'Only the board owner can delete an empty column.';
        _notify();
        return false;
      }

      _errorMessage = null;

      // The Firestore listener updates the Kanban board.
      _notify();

      return true;
    } catch (error) {
      debugPrint('Column deletion error: $error');

      _errorMessage = 'Unable to delete column. Check Firestore permissions.';

      _notify();
      return false;
    }
  }

  // Clear the local column cache for a board.
  // Does not delete any Firestore documents.
  void removeBoardColumns(String boardId) {
    final listener = _listeners.remove(boardId);

    if (listener != null) {
      unawaited(listener.cancel());
    }

    _columns.remove(boardId);
    _initializingBoards.remove(boardId);

    _notify();
  }

  @override
  void dispose() {
    _disposed = true;

    _authSubscription?.cancel();

    for (final listener in _listeners.values) {
      unawaited(listener.cancel());
    }

    _listeners.clear();

    super.dispose();
  }
}
