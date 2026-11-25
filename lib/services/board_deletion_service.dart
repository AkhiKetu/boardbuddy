import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardDeletionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Delete documents in small batches.
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection
          .limit(5)
          .get(const GetOptions(source: Source.server));

      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();
    }
  }

  // =====================================
  // SAFE BOARD DELETION
  // =====================================

  Future<bool> deleteBoard({required String boardId}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final boardRef = _db.collection('boards').doc(boardId);

    // STEP 1: Verify ownership and lock the board.
    await _db.runTransaction((transaction) async {
      final board = await transaction.get(boardRef);

      if (!board.exists) {
        throw StateError('Board does not exist.');
      }

      if (board.data()?['ownerId'] != user.uid) {
        throw StateError('Only the board owner can delete this board.');
      }

      if (board.data()?['deleting'] != true) {
        transaction.update(boardRef, {'deleting': true});
      }
    });

    // STEP 2: Delete all pending board invitations.
    await _deleteCollection(boardRef.collection('invitations'));

    // STEP 3: Delete all tasks and their subcollections.
    while (true) {
      final cards = await boardRef
          .collection('cards')
          .limit(10)
          .get(const GetOptions(source: Source.server));

      if (cards.docs.isEmpty) break;

      for (final card in cards.docs) {
        // Delete task comments.
        await _deleteCollection(card.reference.collection('comments'));

        // Delete task activity history.
        await _deleteCollection(card.reference.collection('activity'));

        // Delete the task itself.
        await card.reference.delete();
      }
    }

    // STEP 4: Delete all Kanban columns.
    await _deleteCollection(boardRef.collection('columns'));

    // STEP 5: Finally delete the board itself.
    await boardRef.delete();

    return true;
  }
}
