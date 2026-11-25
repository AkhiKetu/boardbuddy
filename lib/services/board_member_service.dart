import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardMemberService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Remove another member - owner only.
  Future<void> removeMember({
    required String boardId,
    required String memberId,
  }) async {
    await _removeMembership(
      boardId: boardId,
      memberId: memberId,
      ownerOnly: true,
    );
  }

  // Leave a board - regular members only.
  Future<void> leaveBoard({required String boardId}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    await _removeMembership(
      boardId: boardId,
      memberId: user.uid,
      ownerOnly: false,
    );
  }

  // =====================================
  // MEMBERSHIP REMOVAL
  // =====================================

  Future<void> _removeMembership({
    required String boardId,
    required String memberId,
    required bool ownerOnly,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final boardRef = _db.collection('boards').doc(boardId);

    void checkAccount() {
      if (_auth.currentUser?.uid != user.uid) {
        throw StateError('Your account has changed.');
      }
    }

    // STEP 1: Validate permissions and lock assignments.
    await _db.runTransaction((transaction) async {
      checkAccount();

      final board = await transaction.get(boardRef);

      if (!board.exists) {
        throw StateError('Board not found.');
      }

      final data = board.data()!;

      final ownerId = data['ownerId'];

      if (ownerOnly && ownerId != user.uid) {
        throw StateError('Only the board owner can remove members.');
      }

      if (!ownerOnly && memberId != user.uid) {
        throw StateError('You can only remove yourself.');
      }

      if (memberId == ownerId) {
        throw StateError('The board owner cannot be removed.');
      }

      if (data['deleting'] == true) {
        throw StateError('This board is being deleted.');
      }

      final memberIds = List<String>.from(data['memberIds'] ?? []);

      if (!memberIds.contains(memberId)) {
        throw StateError('This user is not a board member.');
      }

      final pendingMember = data['removingMemberId'];

      if (pendingMember != null && pendingMember != memberId) {
        throw StateError('Another member removal is in progress.');
      }

      // Resume an interrupted removal if necessary.
      if (pendingMember != memberId) {
        transaction.update(boardRef, {'removingMemberId': memberId});
      }
    });

    // STEP 2: Remove the departing member from all tasks.
    // Includes active, completed and archived tasks.
    while (true) {
      checkAccount();

      final snapshot = await boardRef
          .collection('cards')
          .where('assigneeIds', arrayContains: memberId)
          .limit(10)
          .get(const GetOptions(source: Source.server));

      if (snapshot.docs.isEmpty) break;

      for (final card in snapshot.docs) {
        checkAccount();

        final active = await _db.runTransaction<bool>((transaction) async {
          checkAccount();

          final board = await transaction.get(boardRef);
          final latestCard = await transaction.get(card.reference);

          if (!board.exists) {
            throw StateError('Board not found.');
          }

          final boardData = board.data()!;

          if (boardData['deleting'] == true) {
            throw StateError('This board is being deleted.');
          }

          if (boardData['removingMemberId'] != memberId) {
            return false;
          }

          if (!latestCard.exists) return true;

          final assigneeIds = List<String>.from(
            latestCard.data()?['assigneeIds'] ?? [],
          );

          if (assigneeIds.contains(memberId)) {
            transaction.update(card.reference, {
              'assigneeIds': FieldValue.arrayRemove([memberId]),
            });
          }

          return true;
        });

        if (!active) {
          throw StateError(
            'Membership removal has changed. Refresh and retry.',
          );
        }
      }
    }

    // STEP 3: Permanently remove board membership.
    checkAccount();

    await _db.runTransaction((transaction) async {
      checkAccount();

      final board = await transaction.get(boardRef);

      if (!board.exists) {
        throw StateError('Board not found.');
      }

      final data = board.data()!;

      if (data['deleting'] == true) {
        throw StateError('This board is being deleted.');
      }

      final memberIds = List<String>.from(data['memberIds'] ?? []);

      final memberNames = Map<String, dynamic>.from(data['memberNames'] ?? {});

      if (!memberIds.contains(memberId)) return;

      if (data['removingMemberId'] != memberId) {
        throw StateError('Membership removal lock changed.');
      }

      if (data['ownerId'] == memberId) {
        throw StateError('The board owner cannot be removed.');
      }

      if (ownerOnly && data['ownerId'] != user.uid) {
        throw StateError('Only the owner can remove members.');
      }

      // Remove the member ID and display name.
      memberIds.remove(memberId);
      memberNames.remove(memberId);

      // Save membership and clear the temporary lock.
      transaction.update(boardRef, {
        'memberIds': memberIds,
        'memberNames': memberNames,
        'removingMemberId': FieldValue.delete(),
      });
    });
  }
}
