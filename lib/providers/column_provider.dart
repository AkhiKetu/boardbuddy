
import 'package:flutter/foundation.dart';

import '../models/board_column.dart';
import '../data/mock/mock_columns.dart';

// Manages all board columns
class ColumnProvider extends ChangeNotifier {
  // Private list of columns
  final List<BoardColumn> _columns = [];

  // Load sample columns when Provider is created
  ColumnProvider() {
    initializeMockColumns();
    _columns.addAll(mockColumns);
  }

  // Get columns belonging to a particular board
  List<BoardColumn> columnsForBoard(String boardId) {
    final result = _columns
        .where((column) => column.boardId == boardId)
        .toList();

    // Display columns in numeric position order
    result.sort((a, b) {
      final order = a.position.compareTo(b.position);

      if (order != 0) return order;

      final time = a.createdAt.compareTo(b.createdAt);
      if (time != 0) return time;

      return a.id.compareTo(b.id);
    });

    return List.unmodifiable(result);
  }

  // Create default columns for a newly created board
  void ensureDefaultColumns(String boardId) {
    final exists = _columns.any(
      (column) => column.boardId == boardId,
    );

    if (exists) return;

    _columns.addAll(createDefaultColumns(boardId));
    notifyListeners();
  }

  // Add a new custom column
  void addColumn(String boardId, String title) {
    if (title.trim().isEmpty) return;

    final existing = columnsForBoard(boardId);

    final newPosition = existing.isEmpty
        ? 1000.0
        : existing.last.position + 1000.0;

    final column = BoardColumn(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      boardId: boardId,
      title: title.trim(),
      position: newPosition,
      createdAt: DateTime.now(),
    );

    _columns.add(column);
    notifyListeners();
  }

  // Rename an existing column
  void renameColumn(String columnId, String newTitle) {
    if (newTitle.trim().isEmpty) return;

    final index = _columns.indexWhere(
      (column) => column.id == columnId,
    );

    if (index == -1) return;

    _columns[index] = _columns[index].copyWith(
      title: newTitle.trim(),
    );

    notifyListeners();
  }

  // Reorder a column to a new index
  void reorderColumn(
    String boardId,
    String columnId,
    int newIndex,
  ) {
    final ordered = columnsForBoard(boardId).toList();

    final oldIndex = ordered.indexWhere(
      (column) => column.id == columnId,
    );

    if (oldIndex == -1) return;

    final movingColumn = ordered.removeAt(oldIndex);

    final targetIndex =
        newIndex.clamp(0, ordered.length).toInt();

    if (oldIndex == targetIndex) return;

    ordered.insert(targetIndex, movingColumn);

    // Calculate a position between neighbours
    final double? before = targetIndex > 0
        ? ordered[targetIndex - 1].position
        : null;

    final double? after = targetIndex < ordered.length - 1
        ? ordered[targetIndex + 1].position
        : null;

    double newPosition;

    if (before == null && after == null) {
      newPosition = 1000.0;
    } else if (before == null) {
      newPosition = after! - 1000.0;
    } else if (after == null) {
      newPosition = before + 1000.0;
    } else {
      newPosition = (before + after) / 2;
    }

    // Rebalance if positions become too close
    if (before != null &&
        after != null &&
        after - before < 0.000001) {
      for (int i = 0; i < ordered.length; i++) {
        final index = _columns.indexWhere(
          (column) => column.id == ordered[i].id,
        );

        _columns[index] = ordered[i].copyWith(
          position: (i + 1) * 1000.0,
        );
      }
    } else {
      final index = _columns.indexWhere(
        (column) => column.id == columnId,
      );

      _columns[index] = movingColumn.copyWith(
        position: newPosition,
      );
    }

    notifyListeners();
  }

  // Delete a column only when it has no cards
  bool deleteColumn(
    String boardId,
    String columnId, {
    required bool hasCards,
  }) {
    if (hasCards) return false;

    final before = _columns.length;

    _columns.removeWhere(
      (column) =>
          column.id == columnId &&
          column.boardId == boardId,
    );

    if (_columns.length == before) return false;

    notifyListeners();
    return true;
  }

  // Remove columns when their parent board is deleted
  void removeBoardColumns(String boardId) {
    _columns.removeWhere(
      (column) => column.boardId == boardId,
    );

    notifyListeners();
  }
}
