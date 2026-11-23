import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/board.dart';

class BoardService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  BoardService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Convert a Firestore document into a Board model.
  Board _boardFromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;

    final timestamp = data['createdAt'];

    return Board(
      id: document.id,
      title: data['title'] as String,
      colorHex: data['colorHex'] as String,
      ownerId: data['ownerId'] as String,
      memberIds: List<String>.from(data['memberIds'] as List),
      memberNames: Map<String, String>.from(data['memberNames'] as Map),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  // Watch boards that belong to a particular user.
  // Firestore sends updates automatically.
  Stream<List<Board>> watchBoardsForUser(String userId) {
    return _firestore
        .collection('boards')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final boards = snapshot.docs.map(_boardFromDocument).toList();

          // Sort newest boards first.
          boards.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return boards;
        });
  }

  // Create a new board owned by the current user.
  Future<String> createBoard({
    required String title,
    required String colorHex,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before creating a board.');
    }

    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty || cleanTitle.length > 100) {
      throw ArgumentError('Board title must contain 1–100 characters.');
    }

    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(colorHex)) {
      throw ArgumentError('Invalid board color.');
    }

    final displayName = user.displayName?.trim();

    final ownerName = displayName != null && displayName.length >= 2
        ? displayName
        : 'BoardBuddy User';

    final safeOwnerName = ownerName.length > 100
        ? ownerName.substring(0, 100)
        : ownerName;

    final boardRef = _firestore.collection('boards').doc();

    await boardRef.set({
      'title': cleanTitle,
      'colorHex': colorHex,
      'ownerId': user.uid,
      'memberIds': [user.uid],
      'memberNames': {user.uid: safeOwnerName},
      'createdAt': FieldValue.serverTimestamp(),
    });

    return boardRef.id;
  }

  // Rename a board or update its color.
  Future<void> updateBoard({
    required String boardId,
    String? title,
    String? colorHex,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) {
      final cleanTitle = title.trim();

      if (cleanTitle.isEmpty || cleanTitle.length > 100) {
        throw ArgumentError('Invalid board title.');
      }

      updates['title'] = cleanTitle;
    }

    if (colorHex != null) {
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(colorHex)) {
        throw ArgumentError('Invalid board color.');
      }

      updates['colorHex'] = colorHex;
    }

    if (updates.isEmpty) return;

    await _firestore.collection('boards').doc(boardId).update(updates);
  }
}
