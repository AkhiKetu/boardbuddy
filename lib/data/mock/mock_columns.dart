import 'package:boardbuddy/models/board_column.dart';
import 'package:boardbuddy/data/mock/mock_boards.dart';

// Create default columns for a board
List<BoardColumn> createDefaultColumns(String boardId) {
  final now = DateTime.now();

  return [
    // First column
    BoardColumn(
      id: '${boardId}_todo',
      boardId: boardId,
      title: 'To Do',
      position: 1000.0,
      createdAt: now,
    ),

    // Second column
    BoardColumn(
      id: '${boardId}_doing',
      boardId: boardId,
      title: 'Doing',
      position: 2000.0,
      createdAt: now,
    ),

    // Third column
    BoardColumn(
      id: '${boardId}_done',
      boardId: boardId,
      title: 'Done',
      position: 3000.0,
      createdAt: now,
    ),
  ];
}

// Sample columns for all existing mock boards
final List<BoardColumn> mockColumns = [];

void initializeMockColumns() {
  mockColumns.clear();

  for (final board in mockBoards) {
    mockColumns.addAll(createDefaultColumns(board.id));
  }
}
