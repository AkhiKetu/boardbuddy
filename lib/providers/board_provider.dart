
import 'package:flutter/foundation.dart';
import 'package:boardbuddy/models/board.dart';
import 'package:boardbuddy/data/mock/mock_boards.dart';

// Manages Board data and notifies the UI
class BoardProvider extends ChangeNotifier {

  // Temporary logged-in user
  // Later this comes from Firebase Authentication
  final String currentUserId = 'user1';

  // Private list of boards
  final List<Board> _boards = List.from(mockBoards);

  // Getter: Boards owned or joined by current user
  List<Board> get boards {
    return _boards.where((board) {
      return board.ownerId == currentUserId ||
          board.memberIds.contains(currentUserId);
    }).toList();
  }

  // Create a new board
  void createBoard(String title, String colorHex) {
    if (title.trim().isEmpty) return;

    final newBoard = Board(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      colorHex: colorHex,
      ownerId: currentUserId,
      memberIds: [currentUserId],
      memberNames: {
        currentUserId: 'Akhi',
      },
      createdAt: DateTime.now(),
    );

    _boards.add(newBoard);

    // Update all listening widgets
    notifyListeners();
  }

  // Update an existing board
  void updateBoard(
    String boardId,
    String newTitle,
    String newColorHex,
  ) {
    if (newTitle.trim().isEmpty) return;

    final index = _boards.indexWhere(
      (board) =>
          board.id == boardId &&
          board.ownerId == currentUserId,
    );

    if (index == -1) return;

    final oldBoard = _boards[index];

    _boards[index] = Board(
      id: oldBoard.id,
      title: newTitle.trim(),
      colorHex: newColorHex,
      ownerId: oldBoard.ownerId,
      memberIds: oldBoard.memberIds,
      memberNames: oldBoard.memberNames,
      createdAt: oldBoard.createdAt,
    );

    notifyListeners();
  }

  // Delete a board (owner only)
  void deleteBoard(String boardId) {
    final index = _boards.indexWhere(
      (board) =>
          board.id == boardId &&
          board.ownerId == currentUserId,
    );

    if (index == -1) return;

    _boards.removeAt(index);

    notifyListeners();
  }
}
