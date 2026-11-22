import '../../models/task_card.dart';

// Create sample tasks for testing
List<TaskCard> createMockTasks() {
  final now = DateTime.now();

  return [
    // BOARD 1: MOBILE APP PROJECT

    // Task 1: To Do
    TaskCard(
      id: 'task1',
      boardId: 'board1',
      columnId: 'board1_todo',
      title: 'Design Login UI',
      description: 'Create login and signup screens.',
      position: 1000.0,
      assigneeIds: ['user1'],
      labels: const [TaskLabel(name: 'UI Design', colorHex: '#6759E8')],
      dueDate: now.add(const Duration(days: 3)),
      checklist: const [
        ChecklistItem(id: 'check1', text: 'Design login form', isChecked: true),
        ChecklistItem(id: 'check2', text: 'Design signup form'),
        ChecklistItem(id: 'check3', text: 'Add validation'),
      ],
      createdBy: 'user1',
      createdAt: now,
    ),

    // Task 2: Doing
    TaskCard(
      id: 'task2',
      boardId: 'board1',
      columnId: 'board1_doing',
      title: 'Build Task Cards',
      description: 'Implement Kanban task cards.',
      position: 1000.0,
      assigneeIds: ['user1', 'user2'],
      labels: const [TaskLabel(name: 'Development', colorHex: '#23A68F')],
      dueDate: now.add(const Duration(days: 5)),
      createdBy: 'user1',
      createdAt: now,
    ),

    // Task 3: Done
    TaskCard(
      id: 'task3',
      boardId: 'board1',
      columnId: 'board1_done',
      title: 'GitHub Setup',
      description: 'Initialize and configure GitHub.',
      position: 1000.0,
      assigneeIds: ['user1'],
      completed: true,
      createdBy: 'user1',
      createdAt: now,
    ),

    // BOARD 2: NUMERICAL METHODS
    TaskCard(
      id: 'task4',
      boardId: 'board2',
      columnId: 'board2_todo',
      title: 'Complete LU Decomposition',
      description: 'Practice LU factorization problems.',
      position: 1000.0,
      assigneeIds: ['user1'],
      dueDate: now.add(const Duration(days: 2)),
      createdBy: 'user1',
      createdAt: now,
    ),

    // BOARD 3: GROUP PRESENTATION
    TaskCard(
      id: 'task5',
      boardId: 'board3',
      columnId: 'board3_todo',
      title: 'Prepare Presentation Slides',
      description: 'Create slides for the presentation.',
      position: 1000.0,
      assigneeIds: ['user1'],
      dueDate: now.add(const Duration(days: 7)),
      createdBy: 'user1',
      createdAt: now,
    ),
  ];
}

// List used by CardProvider later
final List<TaskCard> mockTasks = createMockTasks();
