import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/board.dart';

import '../services/board_service.dart';
import '../services/board_deletion_service.dart';
import '../services/board_invitation_service.dart';
import '../services/board_member_service.dart';

class BoardProvider extends ChangeNotifier {
  final FirebaseAuth _auth;
  final BoardService _boardService;

  final BoardDeletionService _deletionService = BoardDeletionService();

  final BoardInvitationService _invitationService = BoardInvitationService();

  final BoardMemberService _memberService = BoardMemberService();

  late final StreamSubscription<User?> _authSubscription;

  StreamSubscription<List<Board>>? _boardSubscription;

  List<Board> _boards = [];

  String _currentUserId = '';
  String? _errorMessage;

  bool _isLoading = false;
  bool _isCreating = false;
  bool _isDeleting = false;
  bool _disposed = false;

  int _streamVersion = 0;

  BoardProvider({FirebaseAuth? auth, BoardService? boardService})
    : _auth = auth ?? FirebaseAuth.instance,
      _boardService = boardService ?? BoardService() {
    _authSubscription = _auth.authStateChanges().listen(
      _onAuthChanged,
      onError: (Object error) {
        _isLoading = false;
        _errorMessage = 'Unable to check login status.';
        _notify();
      },
    );
  }

  // =====================================
  // PUBLIC GETTERS
  // =====================================

  String get currentUserId => _currentUserId;

  List<Board> get boards => List.unmodifiable(_boards);

  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  bool get isDeleting => _isDeleting;

  String? get errorMessage => _errorMessage;

  // Notify listeners safely.
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // =====================================
  // AUTHENTICATION AND REAL-TIME BOARDS
  // =====================================

  void _onAuthChanged(User? user) {
    final newUserId = user?.uid ?? '';

    if (_currentUserId == newUserId) {
      return;
    }

    // Prevent old account results from appearing.
    final version = ++_streamVersion;

    if (_boardSubscription != null) {
      unawaited(_boardSubscription!.cancel());
      _boardSubscription = null;
    }

    _currentUserId = newUserId;
    _boards = [];
    _errorMessage = null;
    _isLoading = newUserId.isNotEmpty;
    _isCreating = false;
    _isDeleting = false;

    _notify();

    if (newUserId.isEmpty) {
      return;
    }

    // Listen for real-time Firestore updates.
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

  // =====================================
  // CREATE BOARD
  // =====================================

  Future<String?> createBoard(String title, String colorHex) async {
    if (_isCreating) return null;

    if (_currentUserId.isEmpty) {
      _errorMessage = 'Please sign in first.';
      _notify();
      return null;
    }

    if (title.trim().isEmpty || title.trim().length > 100) {
      _errorMessage = 'Enter a valid board title.';
      _notify();
      return null;
    }

    _isCreating = true;
    _errorMessage = null;

    _notify();

    final version = _streamVersion;

    try {
      final boardId = await _boardService.createBoard(
        title: title.trim(),
        colorHex: colorHex,
      );

      if (_disposed || version != _streamVersion) {
        return null;
      }

      // Firestore automatically updates the board list.
      return boardId;
    } catch (error) {
      debugPrint('Board creation error: $error');

      if (!_disposed && version == _streamVersion) {
        _errorMessage =
            'Unable to create board. '
            'Check your connection and permissions.';
      }

      return null;
    } finally {
      if (!_disposed && version == _streamVersion) {
        _isCreating = false;
        _notify();
      }
    }
  }

  // =====================================
  // UPDATE BOARD
  // =====================================

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

    // Only owner can edit the board.
    if (_boards[boardIndex].ownerId != _currentUserId) {
      _errorMessage = 'Only the board owner can edit it.';

      _notify();
      return false;
    }

    if (newTitle.trim().isEmpty || newTitle.trim().length > 100) {
      _errorMessage = 'Enter a valid board title.';
      _notify();
      return false;
    }

    final version = _streamVersion;

    try {
      _errorMessage = null;

      await _boardService.updateBoard(
        boardId: boardId,
        title: newTitle.trim(),
        colorHex: newColorHex,
      );

      if (_disposed || version != _streamVersion) {
        return false;
      }

      return true;
    } catch (error) {
      debugPrint('Board update error: $error');

      if (!_disposed && version == _streamVersion) {
        _errorMessage = 'Unable to update the board.';
        _notify();
      }

      return false;
    }
  }

  // =====================================
  // INVITE MEMBER
  // =====================================

  Future<void> inviteMember({
    required String boardId,
    required String email,
  }) async {
    await _invitationService.inviteMember(boardId: boardId, email: email);
  }

  // =====================================
  // REMOVE MEMBER - OWNER ONLY
  // =====================================

  Future<void> removeMember({
    required String boardId,
    required String memberId,
  }) async {
    await _memberService.removeMember(boardId: boardId, memberId: memberId);
  }

  // =====================================
  // LEAVE BOARD - REGULAR MEMBER
  // =====================================

  Future<void> leaveBoard({required String boardId}) async {
    await _memberService.leaveBoard(boardId: boardId);
  }

  // =====================================
  // SAFE BOARD DELETION
  // =====================================

  Future<bool> deleteBoard(String boardId) async {
    if (_isDeleting) return false;

    if (_currentUserId.isEmpty) {
      _errorMessage = 'Please sign in first.';
      _notify();
      return false;
    }

    final boardIndex = _boards.indexWhere((board) => board.id == boardId);

    if (boardIndex == -1) {
      _errorMessage = 'Board not found.';
      _notify();
      return false;
    }

    // Only owner can permanently delete the board.
    if (_boards[boardIndex].ownerId != _currentUserId) {
      _errorMessage = 'Only the board owner can delete this board.';

      _notify();
      return false;
    }

    final version = _streamVersion;

    _isDeleting = true;
    _errorMessage = null;

    _notify();

    try {
      // Delete invitations, comments, activity,
      // cards, columns and the board itself.
      final deleted = await _deletionService.deleteBoard(boardId: boardId);

      if (_disposed || version != _streamVersion) {
        return false;
      }

      if (!deleted) {
        _errorMessage = 'Unable to delete board.';
        return false;
      }

      _errorMessage = null;

      // Firestore automatically removes the board.
      return true;
    } catch (error) {
      debugPrint('Board deletion error: $error');

      if (!_disposed && version == _streamVersion) {
        _errorMessage =
            'Unable to finish deleting the board. '
            'Check your connection and Firestore permissions, '
            'then try again.';
      }

      return false;
    } finally {
      if (!_disposed && version == _streamVersion) {
        _isDeleting = false;
        _notify();
      }
    }
  }

  // =====================================
  // CLEAR ERROR
  // =====================================

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  // =====================================
  // CLEANUP
  // =====================================

  @override
  void dispose() {
    _disposed = true;
    _streamVersion++;

    unawaited(_authSubscription.cancel());

    final subscription = _boardSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    super.dispose();
  }
}
