import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ColumnDeletionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> deleteEmptyColumn({
    required String boardId,
    required String columnId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return false;

    final boardRef = _db.collection('boards').doc(boardId);

    final board = await boardRef.get(const GetOptions(source: Source.server));

    // Only the board owner can delete columns.
    if (!board.exists || board.data()?['ownerId'] != user.uid) {
      return false;
    }

    final columnRef = boardRef.collection('columns').doc(columnId);

    bool locked = false;
    bool deleted = false;

    try {
      // Step 1: Acquire the deletion lock.
      locked = await _db.runTransaction<bool>((transaction) async {
        final column = await transaction.get(columnRef);

        if (!column.exists) return false;

        if (column.data()?['deleting'] == true) {
          return false;
        }

        transaction.update(columnRef, {'deleting': true});

        return true;
      });

      if (!locked) return false;

      // Step 2: Check Firestore for all cards,
      // including archived cards.
      final cards = await boardRef
          .collection('cards')
          .where('columnId', isEqualTo: columnId)
          .limit(1)
          .get(const GetOptions(source: Source.server));

      // Do not delete a nonempty column.
      if (cards.docs.isNotEmpty) {
        return false;
      }

      // Step 3: Delete the empty locked column.
      await columnRef.delete();

      deleted = true;

      return true;
    } finally {
      // Release the lock if deletion did not finish.
      if (locked && !deleted) {
        try {
          await _db.runTransaction((transaction) async {
            final column = await transaction.get(columnRef);

            if (column.exists && column.data()?['deleting'] == true) {
              transaction.update(columnRef, {'deleting': false});
            }
          });
        } catch (error) {
          debugPrint('Column unlock error: $error');
        }
      }
    }
  }
}
