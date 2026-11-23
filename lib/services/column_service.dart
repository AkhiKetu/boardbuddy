import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/board_column.dart';

class ColumnService {
  final FirebaseFirestore _firestore;

  ColumnService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Reference to a board's columns.
  CollectionReference<Map<String, dynamic>> _columnsRef(String boardId) {
    return _firestore.collection('boards').doc(boardId).collection('columns');
  }

  // Convert Firestore data into BoardColumn.
  BoardColumn _columnFromDocument(
    String boardId,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;

    final timestamp = data['createdAt'];

    return BoardColumn(
      id: document.id,
      boardId: boardId,
      title: data['title'] as String,
      position: (data['position'] as num).toDouble(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  // Listen to columns in real time.
  Stream<List<BoardColumn>> watchColumns(String boardId) {
    return _columnsRef(boardId).orderBy('position').snapshots().map((snapshot) {
      final columns = snapshot.docs
          .map((doc) => _columnFromDocument(boardId, doc))
          .toList();

      // Stable order if numeric positions match.
      columns.sort((a, b) {
        final positionOrder = a.position.compareTo(b.position);

        if (positionOrder != 0) {
          return positionOrder;
        }

        final dateOrder = a.createdAt.compareTo(b.createdAt);

        if (dateOrder != 0) {
          return dateOrder;
        }

        return a.id.compareTo(b.id);
      });

      return List.unmodifiable(columns);
    });
  }

  // Create a column in Firestore.
  Future<String> addColumn({
    required String boardId,
    required String title,
    required double position,
  }) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty || cleanTitle.length > 100) {
      throw ArgumentError('Column title must contain 1–100 characters.');
    }

    if (!position.isFinite) {
      throw ArgumentError('Invalid column position.');
    }

    final doc = _columnsRef(boardId).doc();

    await doc.set({
      'title': cleanTitle,
      'position': position,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // Rename a column.
  Future<void> renameColumn({
    required String boardId,
    required String columnId,
    required String title,
  }) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty || cleanTitle.length > 100) {
      throw ArgumentError('Invalid column title.');
    }

    await _columnsRef(boardId).doc(columnId).update({'title': cleanTitle});
  }

  // Change a column's numeric position.
  Future<void> updatePosition({
    required String boardId,
    required String columnId,
    required double position,
  }) async {
    if (!position.isFinite) {
      throw ArgumentError('Invalid column position.');
    }

    await _columnsRef(boardId).doc(columnId).update({'position': position});
  }
}
