import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_interaction.dart';

class TaskInteractionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TaskInteractionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Reference to one task card.
  DocumentReference<Map<String, dynamic>> _cardRef(
    String boardId,
    String cardId,
  ) {
    return _firestore
        .collection('boards')
        .doc(boardId)
        .collection('cards')
        .doc(cardId);
  }

  // Reference to a task's comments.
  CollectionReference<Map<String, dynamic>> _commentsRef(
    String boardId,
    String cardId,
  ) {
    return _cardRef(boardId, cardId).collection('comments');
  }

  // Reference to a task's activity history.
  CollectionReference<Map<String, dynamic>> _activityRef(
    String boardId,
    String cardId,
  ) {
    return _cardRef(boardId, cardId).collection('activity');
  }

  // Convert a Firestore comment into a model.
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
      userId: data['userId'] as String,
      text: data['text'] as String,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  // Convert a Firestore activity entry into a model.
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
      actorId: data['actorId'] as String,
      action: data['action'] as String,
      message: data['message'] as String,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  // Listen to the latest comments in real time.
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

      // Show comments oldest first in the UI.
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return List<TaskComment>.unmodifiable(comments);
    });
  }

  // Listen to the latest activity in real time.
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

      activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return List<TaskActivity>.unmodifiable(activities);
    });
  }

  // Save a new comment in Firestore.
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

    await _commentsRef(boardId, cardId).add({
      'userId': user.uid,
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Save a task activity entry in Firestore.
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

    await _activityRef(boardId, cardId).add({
      'actorId': user.uid,
      'action': action,
      'message': cleanMessage,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
