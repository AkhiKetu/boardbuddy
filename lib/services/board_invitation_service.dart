import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardInvitation {
  final String boardId;
  final String boardTitle;
  final String email;
  final String invitedBy;
  final DateTime? createdAt;

  const BoardInvitation({
    required this.boardId,
    required this.boardTitle,
    required this.email,
    required this.invitedBy,
    required this.createdAt,
  });

  factory BoardInvitation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    final timestamp = data['createdAt'];

    return BoardInvitation(
      boardId: data['boardId'] as String,
      boardTitle: data['boardTitle'] as String,
      email: data['email'] as String,
      invitedBy: data['invitedBy'] as String,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class BoardInvitationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  DocumentReference<Map<String, dynamic>> _boardRef(String boardId) {
    return _db.collection('boards').doc(boardId);
  }

  DocumentReference<Map<String, dynamic>> _invitationRef(
    String boardId,
    String email,
  ) {
    return _boardRef(boardId)
        .collection('invitations')
        .doc(_normalizeEmail(email));
  }

  DocumentReference<Map<String, dynamic>> _directoryRef(String email) {
    return _db.collection('emailDirectory').doc(_normalizeEmail(email));
  }

  // =====================================
  // EMAIL VERIFICATION
  // =====================================

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;

    if (user == null) return false;

    await user.reload();

    final refreshedUser = _auth.currentUser;

    if (refreshedUser == null ||
        refreshedUser.uid != user.uid ||
        !refreshedUser.emailVerified) {
      return false;
    }

    await refreshedUser.getIdToken(true);

    return true;
  }

  // =====================================
  // REGISTER VERIFIED EMAIL IN DIRECTORY
  // =====================================

  Future<void> registerVerifiedEmail() async {
    final verified = await refreshEmailVerification();

    if (!verified) {
      throw StateError('Please verify your email first.');
    }

    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      throw StateError('Account not available.');
    }

    final email = _normalizeEmail(user.email!);

    final profile = await _db
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    if (!profile.exists) {
      throw StateError('User profile not found.');
    }

    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('Your account has changed.');
    }

    final reference = _directoryRef(email);

    final existing = await reference.get(
      const GetOptions(source: Source.server),
    );

    // Avoid unnecessary writes.
    if (existing.exists && existing.data()?['uid'] == user.uid) {
      return;
    }

    // Store only the UID, not the private profile.
    await reference.set({'uid': user.uid});
  }

  // =====================================
  // INVITE MEMBER WITH VALIDATION
  // =====================================

  Future<void> inviteMember({
    required String boardId,
    required String email,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final cleanEmail = _normalizeEmail(email);

    final emailPattern = RegExp(r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$');

    if (cleanEmail.length > 254 || !emailPattern.hasMatch(cleanEmail)) {
      throw ArgumentError('Enter a valid email address.');
    }

    // Prevent self-invitation.
    if (cleanEmail == _normalizeEmail(user.email ?? '')) {
      throw StateError('You cannot invite yourself.');
    }

    final board = await _boardRef(boardId)
        .get(const GetOptions(source: Source.server));

    if (!board.exists) {
      throw StateError('Board not found.');
    }

    final data = board.data()!;

    if (data['ownerId'] != user.uid) {
      throw StateError('Only the board owner can invite members.');
    }

    if (data['deleting'] == true) {
      throw StateError('This board is being deleted.');
    }

    // Look up the registered and verified email.
    final registeredUser = await _directoryRef(cleanEmail)
        .get(const GetOptions(source: Source.server));

    if (!registeredUser.exists) {
      throw StateError(
        'No registered and verified user found. '
        'Ask the user to register, verify their email '
        'and open Board Invitations.',
      );
    }

    final recipientId = registeredUser.data()?['uid'];

    if (recipientId is! String || recipientId.isEmpty) {
      throw StateError('Invalid registered user.');
    }

    final memberIds = List<String>.from(data['memberIds'] ?? []);

    // Prevent inviting an existing board member.
    if (memberIds.contains(recipientId)) {
      throw StateError('This user is already a member of the board.');
    }

    final invitationRef = _invitationRef(boardId, cleanEmail);

    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('Your account has changed.');
    }

    // Prevent duplicate pending invitations.
    await _db.runTransaction((transaction) async {
      final latestBoard = await transaction.get(_boardRef(boardId));

      final existingInvitation = await transaction.get(invitationRef);

      if (!latestBoard.exists) {
        throw StateError('Board not found.');
      }

      final latestData = latestBoard.data()!;

      if (latestData['ownerId'] != user.uid || latestData['deleting'] == true) {
        throw StateError('Board is unavailable.');
      }

      final latestMembers = List<String>.from(latestData['memberIds'] ?? []);

      if (latestMembers.contains(recipientId)) {
        throw StateError('This user is already a member of the board.');
      }

      if (existingInvitation.exists) {
        throw StateError(
          'An invitation has already been sent '
          'to this user.',
        );
      }

      transaction.set(invitationRef, {
        'boardId': boardId,
        'boardTitle': latestData['title'],
        'email': cleanEmail,
        'invitedBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // =====================================
  // WATCH RECEIVED INVITATIONS
  // =====================================

  Stream<List<BoardInvitation>> watchInvitations() async* {
    final user = _auth.currentUser;

    if (user == null || user.email == null || !user.emailVerified) {
      yield <BoardInvitation>[];
      return;
    }

    // Automatically register verified users
    // when they open their invitation inbox.
    await registerVerifiedEmail();

    if (_auth.currentUser?.uid != user.uid) {
      yield <BoardInvitation>[];
      return;
    }

    final email = _normalizeEmail(user.email!);

    yield* _db
        .collectionGroup('invitations')
        .where('email', isEqualTo: email)
        .snapshots()
        .map((snapshot) {
          if (_auth.currentUser?.uid != user.uid) {
            return <BoardInvitation>[];
          }

          final invitations = snapshot.docs
              .map(BoardInvitation.fromDocument)
              .toList();

          invitations.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

            return bTime.compareTo(aTime);
          });

          return invitations;
        });
  }

  // =====================================
  // ACCEPT INVITATION
  // =====================================

  Future<void> acceptInvitation(BoardInvitation invitation) async {
    final verified = await refreshEmailVerification();

    if (!verified) {
      throw StateError('Verify your email before accepting invitations.');
    }

    final user = _auth.currentUser!;

    if (_normalizeEmail(user.email ?? '') != invitation.email) {
      throw StateError('This invitation belongs to another account.');
    }

    final profile = await _db
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    final name = profile.data()?['name'];

    if (name is! String || name.trim().isEmpty) {
      throw StateError('User profile not found.');
    }

    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('Your account has changed.');
    }

    final batch = _db.batch();

    batch.update(_boardRef(invitation.boardId), {
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'memberNames.${user.uid}': name,
    });

    batch.delete(_invitationRef(invitation.boardId, invitation.email));

    await batch.commit();
  }

  // =====================================
  // DECLINE INVITATION
  // =====================================

  Future<void> declineInvitation(BoardInvitation invitation) async {
    final verified = await refreshEmailVerification();

    if (!verified) {
      throw StateError('Please verify your email first.');
    }

    final user = _auth.currentUser!;

    if (_normalizeEmail(user.email ?? '') != invitation.email) {
      throw StateError('Invalid invitation.');
    }

    await _invitationRef(invitation.boardId, invitation.email).delete();
  }
}
