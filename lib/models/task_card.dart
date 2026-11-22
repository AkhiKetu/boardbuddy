class TaskLabel {
  final String name;
  final String colorHex;

  const TaskLabel({required this.name, required this.colorHex});
}

// One checklist item inside a task
class ChecklistItem {
  final String id;
  final String text;
  final bool isChecked;

  const ChecklistItem({
    required this.id,
    required this.text,
    this.isChecked = false,
  });

  ChecklistItem copyWith({String? text, bool? isChecked}) {
    return ChecklistItem(
      id: id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

// Main task card model
class TaskCard {
  final String id;
  final String boardId;
  final String columnId;

  final String title;
  final String description;
  final double position;

  final List<String> assigneeIds;
  final List<TaskLabel> labels;
  final DateTime? dueDate;
  final List<ChecklistItem> checklist;

  final bool completed;
  final bool archived;

  final String createdBy;
  final DateTime createdAt;

  const TaskCard({
    required this.id,
    required this.boardId,
    required this.columnId,
    required this.title,
    required this.position,
    required this.createdBy,
    required this.createdAt,
    this.description = '',
    this.assigneeIds = const [],
    this.labels = const [],
    this.dueDate,
    this.checklist = const [],
    this.completed = false,
    this.archived = false,
  });

  // Count completed checklist items
  int get completedChecklistItems {
    return checklist.where((item) => item.isChecked).length;
  }

  // Calculate checklist progress
  double get checklistProgress {
    if (checklist.isEmpty) return 0.0;

    return completedChecklistItems / checklist.length;
  }

  // Create an updated copy of the task
  TaskCard copyWith({
    String? columnId,
    String? title,
    String? description,
    double? position,
    List<String>? assigneeIds,
    List<TaskLabel>? labels,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<ChecklistItem>? checklist,
    bool? completed,
    bool? archived,
  }) {
    return TaskCard(
      id: id,
      boardId: boardId,
      columnId: columnId ?? this.columnId,
      title: title ?? this.title,
      description: description ?? this.description,
      position: position ?? this.position,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      labels: labels ?? this.labels,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      checklist: checklist ?? this.checklist,
      completed: completed ?? this.completed,
      archived: archived ?? this.archived,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}
