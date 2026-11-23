import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_card.dart';

class CardService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CardService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _cardsRef(String boardId) {
    return _firestore.collection('boards').doc(boardId).collection('cards');
  }

  // Convert a Firestore document into a TaskCard.
  TaskCard _fromDocument(
    String boardId,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;

    final rawLabels = data['labels'] as List<dynamic>;
    final labels = rawLabels.map((item) {
      final label = Map<String, dynamic>.from(item as Map);

      return TaskLabel(
        name: label['name'] as String,
        colorHex: label['colorHex'] as String,
      );
    }).toList();

    final rawChecklist = data['checklist'] as List<dynamic>;
    final checklist = rawChecklist.map((item) {
      final entry = Map<String, dynamic>.from(item as Map);

      return ChecklistItem(
        id: entry['id'] as String,
        text: entry['text'] as String,
        isChecked: entry['isChecked'] as bool,
      );
    }).toList();

    final rawDueDate = data['dueDate'];
    final rawCreatedAt = data['createdAt'];

    return TaskCard(
      id: document.id,
      boardId: boardId,
      columnId: data['columnId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      position: (data['position'] as num).toDouble(),
      assigneeIds: List<String>.from(data['assigneeIds'] as List),
      labels: labels,
      dueDate: rawDueDate is Timestamp ? rawDueDate.toDate() : null,
      checklist: checklist,
      completed: data['completed'] as bool,
      archived: data['archived'] as bool,
      createdBy: data['createdBy'] as String,
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : DateTime.now(),
    );
  }

  // Listen for all cards belonging to one board.
  Stream<List<TaskCard>> watchCards(String boardId) {
    return _cardsRef(boardId).snapshots().map((snapshot) {
      final cards = snapshot.docs
          .map((doc) => _fromDocument(boardId, doc))
          .toList();

      cards.sort((a, b) {
        final order = a.position.compareTo(b.position);
        if (order != 0) return order;

        final dateOrder = a.createdAt.compareTo(b.createdAt);
        if (dateOrder != 0) return dateOrder;

        return a.id.compareTo(b.id);
      });

      return List.unmodifiable(cards);
    });
  }

  // Create a new task.
  Future<String> addCard({
    required String boardId,
    required String columnId,
    required String title,
    required double position,
    String description = '',
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty || cleanTitle.length > 120) {
      throw ArgumentError('Invalid task title.');
    }

    if (!position.isFinite) {
      throw ArgumentError('Invalid task position.');
    }

    final reference = _cardsRef(boardId).doc();

    await reference.set({
      'columnId': columnId,
      'title': cleanTitle,
      'description': description.trim(),
      'position': position,
      'assigneeIds': <String>[],
      'labels': <Map<String, dynamic>>[],
      'dueDate': null,
      'checklist': <Map<String, dynamic>>[],
      'completed': false,
      'archived': false,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return reference.id;
  }

  // Update title, description, assignees,
  // labels, due date or checklist.
  Future<void> updateCard({
    required String boardId,
    required String cardId,
    String? title,
    String? description,
    List<String>? assigneeIds,
    List<TaskLabel>? labels,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<ChecklistItem>? checklist,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) {
      final cleanTitle = title.trim();

      if (cleanTitle.isEmpty || cleanTitle.length > 120) {
        throw ArgumentError('Invalid task title.');
      }

      updates['title'] = cleanTitle;
    }

    if (description != null) {
      updates['description'] = description;
    }

    if (assigneeIds != null) {
      updates['assigneeIds'] = assigneeIds;
    }

    if (labels != null) {
      updates['labels'] = labels
          .map((label) => {'name': label.name, 'colorHex': label.colorHex})
          .toList();
    }

    if (clearDueDate) {
      updates['dueDate'] = null;
    } else if (dueDate != null) {
      updates['dueDate'] = Timestamp.fromDate(dueDate);
    }

    if (checklist != null) {
      updates['checklist'] = checklist
          .map(
            (item) => {
              'id': item.id,
              'text': item.text,
              'isChecked': item.isChecked,
            },
          )
          .toList();
    }

    if (updates.isEmpty) return;

    await _cardsRef(boardId).doc(cardId).update(updates);
  }

  // Move a card to another column or position.
  Future<void> moveCard({
    required String boardId,
    required String cardId,
    required String columnId,
    required double position,
  }) async {
    if (!position.isFinite) {
      throw ArgumentError('Invalid task position.');
    }

    await _cardsRef(boardId)
        .doc(cardId)
        .update({'columnId': columnId, 'position': position});
  }

  // Mark a task as completed or incomplete.
  Future<void> setCompleted({
    required String boardId,
    required String cardId,
    required bool completed,
  }) async {
    await _cardsRef(boardId).doc(cardId).update({'completed': completed});
  }

  // Archive or restore a task.
  Future<void> setArchived({
    required String boardId,
    required String cardId,
    required bool archived,
  }) async {
    await _cardsRef(boardId).doc(cardId).update({'archived': archived});
  }
}
