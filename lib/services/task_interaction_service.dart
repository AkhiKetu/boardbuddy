import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_interaction.dart';

class TaskInteractionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TaskInteractionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Board reference.
  DocumentReference<Map<String, dynamic>> _boardRef(String boardId) {
    return _firestore.collection('boards').doc(boardId);
  }

  // Card reference.
  DocumentReference<Map<String, dynamic>> _cardRef(
    String boardId,
    String cardId,
  ) {
    return _boardRef(boardId).collection('cards').doc(cardId);
  }

  // Comments reference.
  CollectionReference<Map<String, dynamic>> _commentsRef(
    String boardId,
    String cardId,
  ) {
    return _cardRef(boardId, cardId).collection('comments');
  }

  // Activity reference.
  CollectionReference<Map<String, dynamic>> _activityRef(
    String boardId,
    String cardId,
  ) {
    return _cardRef(boardId, cardId).collection('activity');
  }

  // Get the authenticated member's name from the board.
  Future<String> _getMemberName(String boardId, String userId) async {
    final board = await _boardRef(boardId)
        .get(const GetOptions(source: Source.server));

    if (!board.exists) {
      throw StateError('Board not found.');
    }

    final data = board.data()!;

    final members = List<String>.from(data['memberIds'] ?? []);

    if (!members.contains(userId)) {
      throw StateError('You cannot access this board.');
    }

    if (data['deleting'] == true) {
      throw StateError('This board is being deleted.');
    }

    final names = Map<String, dynamic>.from(data['memberNames'] ?? {});

    final name = names[userId];

    if (name is! String || name.trim().isEmpty || name.length > 100) {
      throw StateError('Member name not available.');
    }

    if (_auth.currentUser?.uid != userId) {
      throw StateError('Your account has changed.');
    }

    return name;
  }

  // =====================================
  // CONVERT COMMENT DOCUMENT
  // =====================================

  TaskComment _commentFromDocument(
    String boardId,
    String cardId,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    final timestamp = data['createdAt'];

    return TaskComment(
      id: document.id,
      boardId: boardId,
      cardId: cardId,

      // Support old and new comment documents.
      userId: (data['authorId'] ?? data['userId'] ?? '') as String,

      authorName: (data['authorName'] ?? '') as String,

      text: data['text'] as String,

      createdAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  // =====================================
  // CONVERT ACTIVITY DOCUMENT
  // =====================================

  TaskActivity _activityFromDocument(
    String boardId,
    String cardId,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    final timestamp = data['createdAt'];

    return TaskActivity(
      id: document.id,
      boardId: boardId,
      cardId: cardId,

      actorId: (data['actorId'] ?? '') as String,

      actorName: (data['actorName'] ?? '') as String,

      action: data['action'] as String,

      message: (data['message'] ?? data['action']) as String,

      createdAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  // =====================================
  // REAL-TIME COMMENTS
  // =====================================

  Stream<List<TaskComment>> watchComments({
    required String boardId,
    required String cardId,
  }) {
    return _commentsRef(
      boardId,
      cardId,
    ).orderBy('createdAt', descending: true).limit(100).snapshots().map((
      snapshot,
    ) {
      final comments = snapshot.docs
          .map((document) => _commentFromDocument(boardId, cardId, document))
          .toList();

      // Display oldest comments first.
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return List<TaskComment>.unmodifiable(comments);
    });
  }

  // =====================================
  // REAL-TIME ACTIVITY HISTORY
  // =====================================

  Stream<List<TaskActivity>> watchActivities({
    required String boardId,
    required String cardId,
  }) {
    return _activityRef(
      boardId,
      cardId,
    ).orderBy('createdAt', descending: true).limit(200).snapshots().map((
      snapshot,
    ) {
      final activities = snapshot.docs
          .map((document) => _activityFromDocument(boardId, cardId, document))
          .toList();

      // Latest activity first.
      activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return List<TaskActivity>.unmodifiable(activities);
    });
  }

  // =====================================
  // POST COMMENT
  // =====================================

  Future<void> postComment({
    required String boardId,
    required String cardId,
    required String text,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to comment.');
    }

    final cleanText = text.trim();

    if (cleanText.isEmpty || cleanText.length > 2000) {
      throw ArgumentError('Comment must contain 1–2000 characters.');
    }

    final authorName = await _getMemberName(boardId, user.uid);

    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('Your account has changed.');
    }

    await _commentsRef(boardId, cardId).add({
      'authorId': user.uid,
      'authorName': authorName,
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // =====================================
  // RECORD ACTIVITY
  // =====================================

  Future<void> recordActivity({
    required String boardId,
    required String cardId,
    required String action,
    required String message,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    const allowedActions = <String>{
      'task_created',
      'task_updated',
      'task_moved',
      'task_completed',
      'task_reopened',
      'checklist_updated',
      'task_archived',
      'task_restored',
      'comment_added',
    };

    if (!allowedActions.contains(action)) {
      throw ArgumentError('Invalid activity action.');
    }

    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty || cleanMessage.length > 300) {
      throw ArgumentError('Invalid activity message.');
    }

    final actorName = await _getMemberName(boardId, user.uid);

    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('Your account has changed.');
    }

    await _activityRef(boardId, cardId).add({
      'actorId': user.uid,
      'actorName': actorName,
      'action': action,
      'message': cleanMessage,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
