import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/board.dart';
import '../../models/board_column.dart';
import '../../models/task_card.dart';
import '../../providers/column_provider.dart';
import '../../providers/card_provider.dart';
import '../../core/widgets/kanban_column_widget.dart';
import '../../core/widgets/task_card_widget.dart';
import 'task_details_screen.dart';

class KanbanBoardScreen extends StatefulWidget {
  final Board selectedBoard;
  const KanbanBoardScreen({super.key, required this.selectedBoard});
  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  // Horizontal scrolling
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  // Step 35: task filters (null means no restriction).
  String? _selectedAssigneeId;
  String? _selectedLabel;
  bool _dueSoonOnly = false;

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
      if (task.dueDate == null || task.completed) return false;

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
    // Create default columns for new boards
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  // Scroll horizontally when dragging near edges
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

  // Open Task Details
  void _openTaskDetails(String cardId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TaskDetailsScreen(board: widget.selectedBoard, cardId: cardId),
      ),
    );
  }

  // Move a task to the end of a column
  void _moveToColumnEnd(TaskCard movingTask, String columnId) {
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

  // Insert a dragged task before another task
  void _moveBeforeTask(TaskCard movingTask, TaskCard targetTask) {
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
    // Adjust position within the same column
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

  // Build one draggable task
  Widget _buildDraggableTask(TaskCard task) {
    return DragTarget<TaskCard>(
      onWillAcceptWithDetails: (details) {
        return details.data.boardId == widget.selectedBoard.id &&
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

  // Add a new column
  Future<void> _addNewColumn() async {
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
    if (!mounted || title == null || title.isEmpty) {
      return;
    }
    context.read<ColumnProvider>().addColumn(widget.selectedBoard.id, title);
  }

  // NEW: Rename an existing column
  Future<void> _renameColumn(BoardColumn column) async {
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
    if (!mounted || title == null || title.isEmpty || title == column.title) {
      return;
    }
    context.read<ColumnProvider>().renameColumn(column.id, title);
  }

  // NEW: Safely delete a column
  Future<void> _deleteColumn(BoardColumn column) async {
    final cardProvider = context.read<CardProvider>();
    final hasCards = cardProvider.hasCardsInColumn(
      widget.selectedBoard.id,
      column.id,
    );
    // Block deletion if any task exists
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    // Check again before deletion
    final stillHasCards = context.read<CardProvider>().hasCardsInColumn(
      widget.selectedBoard.id,
      column.id,
    );
    final deleted = context.read<ColumnProvider>().deleteColumn(
      widget.selectedBoard.id,
      column.id,
      hasCards: stillHasCards,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'Column deleted successfully' : 'Cannot delete this column',
        ),
      ),
    );
  }

  // Create a task in the selected column
  Future<void> _showAddCardDialog(String columnId) async {
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
    if (!mounted || shouldCreate != true) return;
    context.read<CardProvider>().addCard(
      boardId: widget.selectedBoard.id,
      columnId: columnId,
      title: taskTitle.trim(),
      description: taskDescription.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read Kanban columns
    final columns = context.watch<ColumnProvider>().columnsForBoard(
      widget.selectedBoard.id,
    );
    // Read task data
    final cardProvider = context.watch<CardProvider>();

    // Gather labels from visible (non-archived) tasks on this board.
    final labelNames = <String>{};
    for (final column in columns) {
      for (final task in cardProvider.cardsForColumn(
        widget.selectedBoard.id,
        column.id,
      )) {
        for (final label in task.labels) {
          labelNames.add(label.name);
        }
      }
    }

    // Keep a selected label in the dropdown even if no task uses it.
    if (_selectedLabel != null) labelNames.add(_selectedLabel!);
    final availableLabels = labelNames.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedBoard.title),
        actions: [
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
          // Task filters: member, label and due soon.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DropdownButton<String?>(
                    value: _selectedAssigneeId,
                    hint: const Text('All members'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All members'),
                      ),
                      ...widget.selectedBoard.memberIds.map(
                        (memberId) => DropdownMenuItem<String?>(
                          value: memberId,
                          child: Text(
                            widget.selectedBoard.memberNames[memberId] ??
                                memberId,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedAssigneeId = value);
                    },
                  ),
                  const SizedBox(width: 16),
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
                      setState(() => _selectedLabel = value);
                    },
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Due soon'),
                    selected: _dueSoonOnly,
                    onSelected: (selected) {
                      setState(() => _dueSoonOnly = selected);
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
          // Horizontal Kanban workspace
          Expanded(
            child: ListView.builder(
              key: _viewportKey,
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              itemCount: columns.length + 1,
              itemBuilder: (context, index) {
                // Add Column button at the end
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
                // Filter the displayed cards; source data remains intact.
                final tasks = cardProvider
                    .cardsForColumn(widget.selectedBoard.id, currentColumn.id)
                    .where(_matchesFilters)
                    .toList();
                // Build draggable task widgets
                final taskWidgets = tasks.map((task) {
                  return _buildDraggableTask(task);
                }).toList();
                // Accept drag-and-drop into the column
                return DragTarget<TaskCard>(
                  onWillAcceptWithDetails: (details) {
                    return details.data.boardId == widget.selectedBoard.id;
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
                        // Existing Add Card feature
                        onAddCard: () {
                          _showAddCardDialog(currentColumn.id);
                        },
                        // NEW: Rename column
                        onRename: () {
                          _renameColumn(currentColumn);
                        },
                        // NEW: Move left
                        onMoveLeft: index > 0
                            ? () {
                                context.read<ColumnProvider>().reorderColumn(
                                  widget.selectedBoard.id,
                                  currentColumn.id,
                                  index - 1,
                                );
                              }
                            : null,
                        // NEW: Move right
                        onMoveRight: index < columns.length - 1
                            ? () {
                                context.read<ColumnProvider>().reorderColumn(
                                  widget.selectedBoard.id,
                                  currentColumn.id,
                                  index + 1,
                                );
                              }
                            : null,
                        // NEW: Delete column
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
