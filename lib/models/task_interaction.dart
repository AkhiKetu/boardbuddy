// A comment written on a task card
class TaskComment {
  final String id;
  final String boardId;
  final String cardId;
  final String userId;
  final String text;
  final DateTime createdAt;

  const TaskComment({
    required this.id,
    required this.boardId,
    required this.cardId,
    required this.userId,
    required this.text,
    required this.createdAt,
  });
}

// An activity recorded when a task changes
class TaskActivity {
  final String id;
  final String boardId;
  final String cardId;
  final String actorId;
  final String action;
  final String message;
  final DateTime createdAt;

  const TaskActivity({
    required this.id,
    required this.boardId,
    required this.cardId,
    required this.actorId,
    required this.action,
    required this.message,
    required this.createdAt,
  });
}
