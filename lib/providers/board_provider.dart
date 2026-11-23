import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/board.dart';
import '../services/board_service.dart';

class BoardProvider extends ChangeNotifier {
  final FirebaseAuth _auth;
  final BoardService _boardService;

  late final StreamSubscription<User?> _authSubscription;
  StreamSubscription<List<Board>>? _boardSubscription;

  List<Board> _boards = [];

  String _currentUserId = '';
  String? _errorMessage;

  bool _isLoading = false;
  bool _isCreating = false;
  bool _disposed = false;

  int _streamVersion = 0;

  BoardProvider({FirebaseAuth? auth, BoardService? boardService})
    : _auth = auth ?? FirebaseAuth.instance,
      _boardService = boardService ?? BoardService() {
    // Automatically respond to login and logout.
    _authSubscription = _auth.authStateChanges().listen(
      _onAuthChanged,
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Unable to check login status.';
        _notify();
      },
    );
  }

  // Current real Firebase user ID
  String get currentUserId => _currentUserId;

  // Boards accessible to the logged-in user
  List<Board> get boards => List.unmodifiable(_boards);

  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;

  String? get errorMessage => _errorMessage;

  // Notify safely
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // Listen to the correct user's boards
  void _onAuthChanged(User? user) {
    final newUserId = user?.uid ?? '';

    if (_currentUserId == newUserId) {
      return;
    }

    // Prevent results from an old user appearing
    // after the account changes.
    final version = ++_streamVersion;

    if (_boardSubscription != null) {
      unawaited(_boardSubscription!.cancel());
      _boardSubscription = null;
    }

    _currentUserId = newUserId;
    _boards = [];
    _errorMessage = null;
    _isLoading = newUserId.isNotEmpty;

    _notify();

    // No user means no boards.
    if (newUserId.isEmpty) {
      return;
    }

    // Firestore pushes updates in real time.
    _boardSubscription = _boardService
        .watchBoardsForUser(newUserId)
        .listen(
          (updatedBoards) {
            if (_disposed || version != _streamVersion) {
              return;
            }

            _boards = updatedBoards;
            _isLoading = false;
            _errorMessage = null;

            _notify();
          },
          onError: (Object error) {
            if (_disposed || version != _streamVersion) {
              return;
            }

            debugPrint('Board loading error: $error');

            _isLoading = false;
            _errorMessage =
                'Unable to load boards. Check your connection '
                'and Firestore permissions.';

            _notify();
          },
        );
  }

  // Create and save a board in Firestore
  Future<String?> createBoard(String title, String colorHex) async {
    if (_isCreating) return null;

    if (_currentUserId.isEmpty) {
      _errorMessage = 'Please sign in first.';
      _notify();
      return null;
    }

    if (title.trim().isEmpty) {
      _errorMessage = 'Board title is required.';
      _notify();
      return null;
    }

    _isCreating = true;
    _errorMessage = null;
    _notify();

    try {
      final boardId = await _boardService.createBoard(
        title: title.trim(),
        colorHex: colorHex,
      );

      // The Firestore stream automatically adds
      // the board to the local list.
      return boardId;
    } catch (error) {
      debugPrint('Board creation error: $error');

      _errorMessage =
          'Unable to create board. '
          'Check your connection and permissions.';

      return null;
    } finally {
      _isCreating = false;
      _notify();
    }
  }

  // Update an existing board in Firestore
  Future<bool> updateBoard(
    String boardId,
    String newTitle,
    String newColorHex,
  ) async {
    final boardIndex = _boards.indexWhere((board) => board.id == boardId);

    if (boardIndex == -1) {
      _errorMessage = 'Board not found.';
      _notify();
      return false;
    }

    // Owner-only board editing
    if (_boards[boardIndex].ownerId != _currentUserId) {
      _errorMessage = 'Only the board owner can edit it.';
      _notify();
      return false;
    }

    try {
      _errorMessage = null;

      await _boardService.updateBoard(
        boardId: boardId,
        title: newTitle.trim(),
        colorHex: newColorHex,
      );

      // Firestore stream handles the UI refresh.
      return true;
    } catch (error) {
      debugPrint('Board update error: $error');

      _errorMessage = 'Unable to update the board.';
      _notify();

      return false;
    }
  }

  // Board deletion is intentionally disabled
  // until columns and cards have been migrated.
  // Deleting a Firestore board document alone
  // does NOT delete its subcollections.
  void deleteBoard(String boardId) {
    _errorMessage =
        'Board deletion will be available after '
        'safe Firestore deletion is implemented.';

    _notify();
  }

  // Clear an old error
  void clearError() {
    _errorMessage = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _streamVersion++;

    _authSubscription.cancel();
    _boardSubscription?.cancel();

    super.dispose();
  }
}
