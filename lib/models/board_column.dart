class BoardColumn {
  // Unique ID of the column
  final String id;

  // ID of the board this column belongs to
  final String boardId;

  // Column name: To Do, Doing, Done, etc.
  final String title;

  // Numeric position for column ordering
  final double position;

  // Time when the column was created
  final DateTime createdAt;

  // Constructor
  const BoardColumn({
    required this.id,
    required this.boardId,
    required this.title,
    required this.position,
    required this.createdAt,
  });

  // Create a modified copy of a column
  BoardColumn copyWith({String? title, double? position}) {
    return BoardColumn(
      id: id,
      boardId: boardId,
      title: title ?? this.title,
      position: position ?? this.position,
      createdAt: createdAt,
    );
  }
}
