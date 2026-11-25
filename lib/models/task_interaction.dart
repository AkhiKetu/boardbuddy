// A comment written on a task card.
class TaskComment {
  final String id;
  final String boardId;
  final String cardId;
  final String userId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  // Assignment-compatible author ID.
  String get authorId => userId;

  const TaskComment({
    required this.id,
    required this.boardId,
    required this.cardId,
    required this.userId,
    this.authorName = '',
    required this.text,
    required this.createdAt,
  });
}

// An activity recorded when a task changes.
class TaskActivity {
  final String id;
  final String boardId;
  final String cardId;
  final String actorId;
  final String actorName;
  final String action;
  final String message;
  final DateTime createdAt;

  const TaskActivity({
    required this.id,
    required this.boardId,
    required this.cardId,
    required this.actorId,
    this.actorName = '',
    required this.action,
    required this.message,
    required this.createdAt,
  });
}
