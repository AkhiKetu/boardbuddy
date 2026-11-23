import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskDeletionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TaskDeletionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Delete documents in small batches.
  // Each batch is saved before loading the next.
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection
          .limit(100)
          .get(const GetOptions(source: Source.server));

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();
    }
  }

  // Delete a task and its known subcollections.
  Future<void> deleteTask({
    required String boardId,
    required String cardId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final boardRef = _firestore.collection('boards').doc(boardId);

    // Check ownership before starting cleanup.
    // Firestore Security Rules enforce this too.
    final boardSnapshot = await boardRef.get(
      const GetOptions(source: Source.server),
    );

    if (!boardSnapshot.exists) {
      throw StateError('Board no longer exists.');
    }

    final ownerId = boardSnapshot.data()?['ownerId'];

    if (ownerId != user.uid) {
      throw StateError('Only the board owner can permanently delete tasks.');
    }

    final cardRef = boardRef.collection('cards').doc(cardId);

    final cardSnapshot = await cardRef.get(
      const GetOptions(source: Source.server),
    );

    if (!cardSnapshot.exists) {
      throw StateError('Task no longer exists.');
    }

    // First delete the task's comments.
    await _deleteCollection(cardRef.collection('comments'));

    // Then delete its activity history.
    await _deleteCollection(cardRef.collection('activity'));

    // Delete the parent card LAST.
    await cardRef.delete();
  }
}
