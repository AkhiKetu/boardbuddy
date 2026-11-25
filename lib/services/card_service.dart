import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_card.dart';

class CardService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CardService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Get cards collection for a board.
  CollectionReference<Map<String, dynamic>> _cardsRef(String boardId) {
    return _firestore.collection('boards').doc(boardId).collection('cards');
  }

  // =====================================
  // CONVERT FIRESTORE DOCUMENT
  // =====================================

  TaskCard _fromDocument(
    String boardId,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;

    // Load colored labels.
    final rawLabels = data['labels'] as List<dynamic>;

    final labels = rawLabels.map((item) {
      final label = Map<String, dynamic>.from(item as Map);

      return TaskLabel(
        name: label['name'] as String,
        colorHex: label['colorHex'] as String,
      );
    }).toList();

    // Load checklist items.
    final rawChecklist = data['checklist'] as List<dynamic>;

    final checklist = rawChecklist.map((item) {
      final entry = Map<String, dynamic>.from(item as Map);

      return ChecklistItem(
        id: entry['id'] as String,
        text: entry['text'] as String,

        // Support both new and old Firestore data.
        isChecked: (entry['done'] ?? entry['isChecked'] ?? false) as bool,
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
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  // =====================================
  // REAL-TIME CARD STREAM
  // =====================================

  Stream<List<TaskCard>> watchCards(String boardId) {
    return _cardsRef(boardId).snapshots().map((snapshot) {
      final cards = snapshot.docs
          .map((doc) => _fromDocument(boardId, doc))
          .toList();

      cards.sort((a, b) {
        // Primary ordering: numeric position.
        final order = a.position.compareTo(b.position);

        if (order != 0) return order;

        // Resolve position ties using createdAt.
        final dateOrder = a.createdAt.compareTo(b.createdAt);

        if (dateOrder != 0) return dateOrder;

        // Final deterministic tie-breaker.
        return a.id.compareTo(b.id);
      });

      return List.unmodifiable(cards);
    });
  }

  // =====================================
  // CREATE TASK
  // =====================================

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
    final cleanDescription = description.trim();

    if (cleanTitle.isEmpty || cleanTitle.length > 120) {
      throw ArgumentError('Invalid task title.');
    }

    if (cleanDescription.length > 5000) {
      throw ArgumentError('Description is too long.');
    }

    if (!position.isFinite ||
        position <= -1000000000 ||
        position >= 1000000000) {
      throw ArgumentError('Invalid task position.');
    }

    final reference = _cardsRef(boardId).doc();

    await reference.set({
      // Required for My Tasks collection-group queries.
      'boardId': boardId,

      'columnId': columnId,
      'title': cleanTitle,
      'description': cleanDescription,

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

  // =====================================
  // UPDATE TASK DETAILS
  // =====================================

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

    // Update task title.
    if (title != null) {
      final cleanTitle = title.trim();

      if (cleanTitle.isEmpty || cleanTitle.length > 120) {
        throw ArgumentError('Invalid task title.');
      }

      updates['title'] = cleanTitle;
    }

    // Update description.
    if (description != null) {
      if (description.length > 5000) {
        throw ArgumentError('Description is too long.');
      }

      updates['description'] = description;
    }

    // Update assigned members.
    if (assigneeIds != null) {
      final uniqueAssignees = assigneeIds.toSet().toList();

      if (uniqueAssignees.length > 100) {
        throw ArgumentError('Maximum 100 assignees allowed.');
      }

      updates['assigneeIds'] = uniqueAssignees;
    }

    // Update colored labels.
    if (labels != null) {
      if (labels.length > 20) {
        throw ArgumentError('Maximum 20 labels allowed.');
      }

      updates['labels'] = labels
          .map((label) => {'name': label.name, 'colorHex': label.colorHex})
          .toList();
    }

    // Update or clear due date.
    // Past due dates are allowed.
    if (clearDueDate) {
      updates['dueDate'] = null;
    } else if (dueDate != null) {
      updates['dueDate'] = Timestamp.fromDate(dueDate);
    }

    // Update checklist.
    if (checklist != null) {
      if (checklist.length > 100) {
        throw ArgumentError('Maximum 100 checklist items allowed.');
      }

      updates['checklist'] = checklist
          .map(
            (item) => {
              'id': item.id,
              'text': item.text,

              // Required assignment data model.
              'done': item.isChecked,
            },
          )
          .toList();
    }

    // Avoid unnecessary writes.
    if (updates.isEmpty) return;

    await _cardsRef(boardId).doc(cardId).update(updates);
  }

  // =====================================
  // MOVE TASK - DRAG AND DROP
  // =====================================

  Future<void> moveCard({
    required String boardId,
    required String cardId,
    required String columnId,
    required double position,
  }) async {
    if (!position.isFinite ||
        position <= -1000000000 ||
        position >= 1000000000) {
      throw ArgumentError('Invalid task position.');
    }

    // Normal drag updates only one card document.
    await _cardsRef(boardId)
        .doc(cardId)
        .update({'columnId': columnId, 'position': position});
  }

  // =====================================
  // COMPLETE OR REOPEN TASK
  // =====================================

  Future<void> setCompleted({
    required String boardId,
    required String cardId,
    required bool completed,
  }) async {
    await _cardsRef(boardId).doc(cardId).update({'completed': completed});
  }

  // =====================================
  // ARCHIVE OR RESTORE TASK
  // =====================================

  Future<void> setArchived({
    required String boardId,
    required String cardId,
    required bool archived,
  }) async {
    await _cardsRef(boardId).doc(cardId).update({'archived': archived});
  }
}
