import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/board.dart';
import '../../models/board_column.dart';
import '../../models/task_card.dart';

import '../../providers/board_provider.dart';
import '../../providers/column_provider.dart';
import '../../providers/card_provider.dart';

import '../../core/widgets/kanban_column_widget.dart';
import '../../core/widgets/task_card_widget.dart';

import 'task_details_screen.dart';
import 'board_members_screen.dart';

class KanbanBoardScreen extends StatefulWidget {
  final Board selectedBoard;

  const KanbanBoardScreen({super.key, required this.selectedBoard});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  // Task filters.
  String? _selectedAssigneeId;
  String? _selectedLabel;
  bool _dueSoonOnly = false;

  // =====================================
  // LIVE BOARD MEMBERSHIP
  // =====================================

  Board? _findCurrentBoard(BoardProvider provider) {
    for (final board in provider.boards) {
      if (board.id == widget.selectedBoard.id &&
          board.memberIds.contains(provider.currentUserId)) {
        return board;
      }
    }

    return null;
  }

  Board? _getCurrentBoard() {
    return _findCurrentBoard(context.read<BoardProvider>());
  }

  bool _hasBoardAccess() {
    return _getCurrentBoard() != null;
  }

  // =====================================
  // TASK FILTERS
  // =====================================

  bool _matchesFilters(TaskCard task) {
    if (_selectedAssigneeId != null &&
        !task.assigneeIds.contains(_selectedAssigneeId)) {
      return false;
    }

    if (_selectedLabel != null &&
        !task.labels.any((label) => label.name == _selectedLabel)) {
      return false;
    }

    if (_dueSoonOnly) {
      if (task.dueDate == null || task.completed) {
        return false;
      }

      final today = DateUtils.dateOnly(DateTime.now());
      final lastDay = today.add(const Duration(days: 7));
      final dueDate = DateUtils.dateOnly(task.dueDate!);

      if (dueDate.isBefore(today) || dueDate.isAfter(lastDay)) {
        return false;
      }
    }

    return true;
  }

  void _clearFilters() {
    setState(() {
      _selectedAssigneeId = null;
      _selectedLabel = null;
      _dueSoonOnly = false;
    });
  }

  @override
  void initState() {
    super.initState();

    // Create default columns for new boards.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasBoardAccess()) return;

      context.read<ColumnProvider>().ensureDefaultColumns(
        widget.selectedBoard.id,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // =====================================
  // BOARD MEMBERS
  // =====================================

  void _openBoardMembers() {
    final board = _getCurrentBoard();

    if (board == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BoardMembersScreen(board: board)),
    );
  }

  // =====================================
  // HORIZONTAL AUTO SCROLL
  // =====================================

  void _autoScroll(DragUpdateDetails details) {
    if (!_scrollController.hasClients) return;

    final renderObject = _viewportKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox) return;

    final localPosition = renderObject.globalToLocal(details.globalPosition);

    final width = renderObject.size.width;

    const edge = 60.0;
    const speed = 18.0;

    double change = 0;

    if (localPosition.dx >= 0 && localPosition.dx < edge) {
      change = -speed;
    } else if (localPosition.dx > width - edge && localPosition.dx <= width) {
      change = speed;
    }

    if (change == 0) return;

    final position = _scrollController.position;

    final newOffset = (_scrollController.offset + change)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    _scrollController.jumpTo(newOffset);
  }

  // =====================================
  // OPEN TASK DETAILS
  // =====================================

  void _openTaskDetails(String cardId) {
    // Always use the latest board membership.
    final board = _getCurrentBoard();

    if (board == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You no longer have access to this board.'),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(board: board, cardId: cardId),
      ),
    );
  }

  // =====================================
  // MOVE TASK TO COLUMN END
  // =====================================

  void _moveToColumnEnd(TaskCard movingTask, String columnId) {
    if (!_hasBoardAccess()) return;

    final provider = context.read<CardProvider>();

    final current = provider.getCard(movingTask.id);

    if (current == null || current.archived) return;

    if (current.boardId != widget.selectedBoard.id) {
      return;
    }

    final tasks = provider.cardsForColumn(widget.selectedBoard.id, columnId);

    if (current.columnId == columnId &&
        tasks.isNotEmpty &&
        tasks.last.id == current.id) {
      return;
    }

    provider.moveCard(
      cardId: current.id,
      targetColumnId: columnId,
      newIndex: tasks.length,
    );
  }

  // =====================================
  // MOVE TASK BEFORE ANOTHER TASK
  // =====================================

  void _moveBeforeTask(TaskCard movingTask, TaskCard targetTask) {
    if (!_hasBoardAccess()) return;

    final provider = context.read<CardProvider>();

    final moving = provider.getCard(movingTask.id);
    final target = provider.getCard(targetTask.id);

    if (moving == null || target == null) return;
    if (moving.id == target.id) return;

    if (moving.boardId != widget.selectedBoard.id ||
        target.boardId != widget.selectedBoard.id) {
      return;
    }

    final destinationTasks = provider.cardsForColumn(
      widget.selectedBoard.id,
      target.columnId,
    );

    final targetIndex = destinationTasks.indexWhere(
      (task) => task.id == target.id,
    );

    if (targetIndex == -1) return;

    int insertIndex = targetIndex;

    // Adjust position within the same column.
    if (moving.columnId == target.columnId) {
      final oldIndex = destinationTasks.indexWhere(
        (task) => task.id == moving.id,
      );

      if (oldIndex < targetIndex) {
        insertIndex--;
      }
    }

    provider.moveCard(
      cardId: moving.id,
      targetColumnId: target.columnId,
      newIndex: insertIndex,
    );
  }

  // =====================================
  // DRAGGABLE TASK
  // =====================================

  Widget _buildDraggableTask(TaskCard task) {
    return DragTarget<TaskCard>(
      onWillAcceptWithDetails: (details) {
        return _hasBoardAccess() &&
            details.data.boardId == widget.selectedBoard.id &&
            details.data.id != task.id;
      },

      onAcceptWithDetails: (details) {
        _moveBeforeTask(details.data, task);
      },

      builder: (context, candidates, rejected) {
        final isTarget = candidates.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),

            border: Border.all(
              color: isTarget
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),

          child: LongPressDraggable<TaskCard>(
            data: task,

            onDragUpdate: _autoScroll,

            feedback: Material(
              color: Colors.transparent,

              child: SizedBox(width: 240, child: TaskCardWidget(task: task)),
            ),

            childWhenDragging: Opacity(
              opacity: 0.25,
              child: TaskCardWidget(task: task),
            ),

            child: TaskCardWidget(
              task: task,

              onTap: () {
                _openTaskDetails(task.id);
              },
            ),
          ),
        );
      },
    );
  }

  // =====================================
  // ADD COLUMN
  // =====================================

  Future<void> _addNewColumn() async {
    if (!_hasBoardAccess()) return;

    String columnName = '';

    final title = await showDialog<String>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add New Column'),

          content: TextField(
            autofocus: true,

            decoration: const InputDecoration(
              hintText: 'Enter column name',
              border: OutlineInputBorder(),
            ),

            onChanged: (value) {
              columnName = value;
            },
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, columnName.trim());
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (!mounted || title == null || title.isEmpty || !_hasBoardAccess()) {
      return;
    }

    context.read<ColumnProvider>().addColumn(widget.selectedBoard.id, title);
  }

  // =====================================
  // RENAME COLUMN
  // =====================================

  Future<void> _renameColumn(BoardColumn column) async {
    if (!_hasBoardAccess()) return;

    final formKey = GlobalKey<FormState>();

    String newTitle = column.title;

    final title = await showDialog<String>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Column'),

          content: Form(
            key: formKey,

            child: TextFormField(
              initialValue: column.title,
              autofocus: true,

              decoration: const InputDecoration(
                labelText: 'Column Name',
                border: OutlineInputBorder(),
              ),

              onChanged: (value) {
                newTitle = value;
              },

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Column name is required';
                }

                return null;
              },
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, newTitle.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        title == null ||
        title.isEmpty ||
        title == column.title ||
        !_hasBoardAccess()) {
      return;
    }

    context.read<ColumnProvider>().renameColumn(column.id, title);
  }

  // =====================================
  // SAFE COLUMN DELETION
  // =====================================

  Future<void> _deleteColumn(BoardColumn column) async {
    final board = _getCurrentBoard();

    if (board == null) return;

    final currentUserId = context.read<BoardProvider>().currentUserId;

    // Only the board owner can delete columns.
    if (board.ownerId != currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the board owner can delete columns.'),
        ),
      );

      return;
    }

    final cardProvider = context.read<CardProvider>();

    final hasCards = cardProvider.hasCardsInColumn(
      widget.selectedBoard.id,
      column.id,
    );

    // Block deletion if any task exists.
    if (hasCards) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This column contains tasks. '
            'Move or delete its tasks first.',
          ),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Column?'),

          content: Text(
            'Are you sure you want to delete '
            '"${column.title}"?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || !_hasBoardAccess()) {
      return;
    }

    // Check again before deletion.
    final stillHasCards = context.read<CardProvider>().hasCardsInColumn(
      widget.selectedBoard.id,
      column.id,
    );

    final columnProvider = context.read<ColumnProvider>();

    final deleted = await columnProvider.deleteColumn(
      widget.selectedBoard.id,
      column.id,
      hasCards: stillHasCards,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Column deleted successfully'
              : columnProvider.errorMessage ?? 'Cannot delete this column',
        ),
      ),
    );
  }

  // =====================================
  // CREATE TASK
  // =====================================

  Future<void> _showAddCardDialog(String columnId) async {
    if (!_hasBoardAccess()) return;

    final formKey = GlobalKey<FormState>();

    String taskTitle = '';
    String taskDescription = '';

    final shouldCreate = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create New Task'),

          content: SingleChildScrollView(
            child: Form(
              key: formKey,

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  TextFormField(
                    autofocus: true,

                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'Enter task title',
                      border: OutlineInputBorder(),
                    ),

                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a task title';
                      }

                      return null;
                    },

                    onChanged: (value) {
                      taskTitle = value;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    maxLines: 3,

                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter task description',
                      border: OutlineInputBorder(),
                    ),

                    onChanged: (value) {
                      taskDescription = value;
                    },
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Create Task'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldCreate != true || !_hasBoardAccess()) {
      return;
    }

    context.read<CardProvider>().addCard(
      boardId: widget.selectedBoard.id,
      columnId: columnId,
      title: taskTitle.trim(),
      description: taskDescription.trim(),
    );
  }

  // =====================================
  // BOARD ACCESS REMOVED SCREEN
  // =====================================

  Widget _buildUnavailableScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Board Unavailable')),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(Icons.lock_outline, size: 70, color: Colors.grey),

              const SizedBox(height: 16),

              const Text(
                'Board Access Removed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              const Text(
                'You no longer have access to this board.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },

                icon: const Icon(Icons.arrow_back),

                label: const Text('Back to Boards'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // BUILD KANBAN SCREEN
  // =====================================

  @override
  Widget build(BuildContext context) {
    // Watch live board membership from Firestore.
    final boardProvider = context.watch<BoardProvider>();

    final board = _findCurrentBoard(boardProvider);

    // Handle the initial loading state.
    if (board == null && boardProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Board')),

        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Block access after removal or leaving.
    if (board == null) {
      return _buildUnavailableScreen();
    }

    // Reset the selected member if they were removed.
    if (_selectedAssigneeId != null &&
        !board.memberIds.contains(_selectedAssigneeId)) {
      _selectedAssigneeId = null;
    }

    final columns = context.watch<ColumnProvider>().columnsForBoard(board.id);

    final cardProvider = context.watch<CardProvider>();

    // Gather labels from visible non-archived tasks.
    final labelNames = <String>{};

    for (final column in columns) {
      for (final task in cardProvider.cardsForColumn(board.id, column.id)) {
        for (final label in task.labels) {
          labelNames.add(label.name);
        }
      }
    }

    // Keep selected label in the dropdown.
    if (_selectedLabel != null) {
      labelNames.add(_selectedLabel!);
    }

    final availableLabels = labelNames.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        // Use the latest board title.
        title: Text(board.title),

        actions: [
          // Board Members button.
          IconButton(
            tooltip: 'Board Members',
            onPressed: _openBoardMembers,
            icon: const Icon(Icons.people_outline),
          ),

          // Add Column button.
          IconButton(
            tooltip: 'Add Column',
            onPressed: _addNewColumn,
            icon: const Icon(Icons.add),
          ),
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Padding(
            padding: EdgeInsets.all(16),

            child: Text(
              'Long press a task to drag it. '
              'Swipe horizontally to view columns.',

              style: TextStyle(color: Colors.grey),
            ),
          ),

          // =====================================
          // TASK FILTERS
          // =====================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,

              child: Row(
                children: [
                  // Live member filter.
                  DropdownButton<String?>(
                    value: _selectedAssigneeId,

                    hint: const Text('All members'),

                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All members'),
                      ),

                      // Use current Firestore membership.
                      ...board.memberIds.map(
                        (memberId) => DropdownMenuItem<String?>(
                          value: memberId,

                          child: Text(board.memberNames[memberId] ?? memberId),
                        ),
                      ),
                    ],

                    onChanged: (value) {
                      setState(() {
                        _selectedAssigneeId = value;
                      });
                    },
                  ),

                  const SizedBox(width: 16),

                  // Label filter.
                  DropdownButton<String?>(
                    value: _selectedLabel,

                    hint: const Text('All labels'),

                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All labels'),
                      ),

                      ...availableLabels.map(
                        (labelName) => DropdownMenuItem<String?>(
                          value: labelName,
                          child: Text(labelName),
                        ),
                      ),
                    ],

                    onChanged: (value) {
                      setState(() {
                        _selectedLabel = value;
                      });
                    },
                  ),

                  const SizedBox(width: 12),

                  // Due soon filter.
                  FilterChip(
                    label: const Text('Due soon'),

                    selected: _dueSoonOnly,

                    onSelected: (selected) {
                      setState(() {
                        _dueSoonOnly = selected;
                      });
                    },
                  ),

                  const SizedBox(width: 8),

                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),

          // =====================================
          // HORIZONTAL KANBAN WORKSPACE
          // =====================================
          Expanded(
            child: ListView.builder(
              key: _viewportKey,

              controller: _scrollController,

              scrollDirection: Axis.horizontal,

              padding: const EdgeInsets.all(16),

              itemCount: columns.length + 1,

              itemBuilder: (context, index) {
                // Add Column button at the end.
                if (index == columns.length) {
                  return SizedBox(
                    width: 200,

                    child: Align(
                      alignment: Alignment.topCenter,

                      child: OutlinedButton.icon(
                        onPressed: _addNewColumn,

                        icon: const Icon(Icons.add),

                        label: const Text('Add Column'),
                      ),
                    ),
                  );
                }

                final currentColumn = columns[index];

                // Filter displayed cards.
                final tasks = cardProvider
                    .cardsForColumn(board.id, currentColumn.id)
                    .where(_matchesFilters)
                    .toList();

                final taskWidgets = tasks.map((task) {
                  return _buildDraggableTask(task);
                }).toList();

                // Accept drag-and-drop into a column.
                return DragTarget<TaskCard>(
                  onWillAcceptWithDetails: (details) {
                    return _hasBoardAccess() &&
                        details.data.boardId == board.id;
                  },

                  onAcceptWithDetails: (details) {
                    _moveToColumnEnd(details.data, currentColumn.id);
                  },

                  builder: (context, candidates, rejected) {
                    final isTarget = candidates.isNotEmpty;

                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),

                        border: Border.all(
                          color: isTarget
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),

                      child: KanbanColumnWidget(
                        key: ValueKey(currentColumn.id),

                        column: currentColumn,

                        cards: taskWidgets,

                        // Add card.
                        onAddCard: () {
                          _showAddCardDialog(currentColumn.id);
                        },

                        // Rename column.
                        onRename: () {
                          _renameColumn(currentColumn);
                        },

                        // Move column left.
                        onMoveLeft: index > 0
                            ? () {
                                if (!_hasBoardAccess()) {
                                  return;
                                }

                                context.read<ColumnProvider>().reorderColumn(
                                  board.id,
                                  currentColumn.id,
                                  index - 1,
                                );
                              }
                            : null,

                        // Move column right.
                        onMoveRight: index < columns.length - 1
                            ? () {
                                if (!_hasBoardAccess()) {
                                  return;
                                }

                                context.read<ColumnProvider>().reorderColumn(
                                  board.id,
                                  currentColumn.id,
                                  index + 1,
                                );
                              }
                            : null,

                        // Delete column.
                        onDelete: () {
                          _deleteColumn(currentColumn);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
