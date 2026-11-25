import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/board.dart';
import '../../models/task_card.dart';
import '../../providers/board_provider.dart';
import '../../providers/card_provider.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Board board;
  final String cardId;
  const TaskDetailsScreen({
    super.key,
    required this.board,
    required this.cardId,
  });
  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isProcessing = false;
  static const availableLabels = [
    TaskLabel(name: 'UI Design', colorHex: '#6759E8'),
    TaskLabel(name: 'Development', colorHex: '#23A68F'),
    TaskLabel(name: 'Urgent', colorHex: '#E05252'),
    TaskLabel(name: 'Testing', colorHex: '#E7A14C'),
  ];
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Get the latest board membership.
  Board? _findBoard(BoardProvider provider) {
    for (final board in provider.boards) {
      if (board.id == widget.board.id &&
          board.memberIds.contains(provider.currentUserId)) {
        return board;
      }
    }
    return null;
  }

  Board? _getCurrentBoard() {
    return _findBoard(context.read<BoardProvider>());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Execute an operation and check its actual result.
  Future<bool> _runAction(
    Future<bool> Function(CardProvider provider) action,
  ) async {
    if (_isProcessing) return false;
    if (_getCurrentBoard() == null) {
      _showMessage('You no longer have access to this board.');
      return false;
    }
    final provider = context.read<CardProvider>();
    setState(() => _isProcessing = true);
    try {
      final success = await action(provider);
      if (!mounted) return false;
      if (!success) {
        _showMessage(provider.errorMessage ?? 'Unable to update task.');
      }
      return success;
    } catch (error) {
      debugPrint('Task operation error: $error');
      _showMessage('Unable to complete the operation.');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // Format comment and activity timestamps.
  String _formatDateTime(BuildContext context, DateTime date) {
    final dateText = MaterialLocalizations.of(context)
        .formatMediumDate(date.toLocal());
    final timeText = TimeOfDay.fromDateTime(date.toLocal()).format(context);
    return '$dateText, $timeText';
  }

  String _userName(Board board, String userId) {
    return board.memberNames[userId] ??
        widget.board.memberNames[userId] ??
        'Former member';
  }

  // =====================================
  // EDIT TASK
  // =====================================
  Future<void> _editTask(TaskCard task) async {
    if (_isProcessing || _getCurrentBoard() == null) return;
    final formKey = GlobalKey<FormState>();
    String title = task.title;
    String description = task.description;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Task'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: description,
                  maxLines: 3,
                  maxLength: 5000,
                  decoration: const InputDecoration(labelText: 'Description'),
                  onChanged: (value) => description = value,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || saved != true) return;
    await _runAction(
      (provider) => provider.updateCard(
        widget.cardId,
        title: title.trim(),
        description: description.trim(),
      ),
    );
  }

  // =====================================
  // CHECKLIST
  // =====================================
  Future<void> _addChecklistItem() async {
    if (_isProcessing || _getCurrentBoard() == null) return;
    String itemText = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Checklist Item'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter checklist item'),
          onChanged: (value) => itemText = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, itemText.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result.isEmpty) return;
    await _runAction((provider) async {
      final task = provider.getCard(widget.cardId);
      if (task == null) return false;
      return provider.updateCard(
        widget.cardId,
        checklist: [
          ...task.checklist,
          ChecklistItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: result,
          ),
        ],
      );
    });
  }

  // =====================================
  // DUE DATE
  // =====================================
  Future<void> _selectDueDate(TaskCard task) async {
    if (_isProcessing || _getCurrentBoard() == null) return;
    final date = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return;
    await _runAction(
      (provider) => provider.updateCard(widget.cardId, dueDate: date),
    );
  }

  // =====================================
  // POST COMMENT
  // =====================================
  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isProcessing) return;
    final currentUserId = context.read<BoardProvider>().currentUserId;
    final success = await _runAction(
      (provider) => provider.addComment(
        cardId: widget.cardId,
        text: text,
        userId: currentUserId,
      ),
    );
    if (!mounted || !success) return;
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  // =====================================
  // DELETE TASK - OWNER ONLY
  // =====================================
  Future<void> _deleteTask() async {
    final board = _getCurrentBoard();
    if (board == null || _isProcessing) return;
    final userId = context.read<BoardProvider>().currentUserId;
    if (board.ownerId != userId) {
      _showMessage('Only the board owner can delete tasks.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text(
          'This task, its comments and activity history '
          'will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final deleted = await _runAction(
      (provider) => provider.deleteCard(widget.cardId),
    );
    if (!mounted || !deleted) return;
    _showMessage('Task deleted successfully.');
    Navigator.pop(context);
  }

  // =====================================
  // ARCHIVE TASK
  // =====================================
  Future<void> _archiveTask(TaskCard task) async {
    final success = await _runAction(
      (provider) => provider.setArchived(widget.cardId, !task.archived),
    );
    if (!mounted || !success) return;
    _showMessage(task.archived ? 'Task restored.' : 'Task archived.');
    Navigator.pop(context);
  }

  // =====================================
  // ACCESS REMOVED SCREEN
  // =====================================
  Widget _unavailableScreen(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 65, color: Colors.grey),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // BUILD TASK DETAILS
  // =====================================
  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BoardProvider>();
    final board = _findBoard(boardProvider);
    if (board == null) {
      if (boardProvider.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return _unavailableScreen('You no longer have access to this board.');
    }
    final provider = context.watch<CardProvider>();
    final task = provider.getCard(widget.cardId);
    if (task == null || task.boardId != board.id) {
      return _unavailableScreen('Task no longer exists.');
    }
    final isOwner = board.ownerId == boardProvider.currentUserId;
    final comments = provider.commentsForCard(widget.cardId);
    final activities = provider.activitiesForCard(widget.cardId);
    final hasFormerAssignees = task.assigneeIds.any(
      (id) => !board.memberIds.contains(id),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          PopupMenuButton<String>(
            enabled: !_isProcessing,
            onSelected: (value) {
              if (value == 'archive') {
                _archiveTask(task);
              } else if (value == 'delete' && isOwner) {
                _deleteTask();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(task.archived ? 'Restore Task' : 'Archive Task'),
              ),
              if (isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Task'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isProcessing) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Task title and edit action.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit task',
                      onPressed: _isProcessing ? null : () => _editTask(task),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.description.isEmpty
                      ? 'No description yet'
                      : task.description,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                // Completion.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Completed'),
                  value: task.completed,
                  onChanged: _isProcessing
                      ? null
                      : (value) {
                          _runAction(
                            (p) => p.setCompleted(widget.cardId, value),
                          );
                        },
                ),
                const Divider(),
                const SizedBox(height: 12),
                // Due date.
                const Text(
                  'Due Date',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    task.dueDate == null
                        ? 'Set due date'
                        : MaterialLocalizations.of(context)
                              .formatMediumDate(task.dueDate!),
                  ),
                  onTap: _isProcessing ? null : () => _selectDueDate(task),
                  trailing: task.dueDate == null
                      ? null
                      : IconButton(
                          tooltip: 'Clear due date',
                          icon: const Icon(Icons.close),
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  _runAction(
                                    (p) => p.updateCard(
                                      widget.cardId,
                                      clearDueDate: true,
                                    ),
                                  );
                                },
                        ),
                ),
                const Divider(),
                const SizedBox(height: 12),
                // =====================================
                // LIVE TASK ASSIGNEES
                // =====================================
                const Text(
                  'Assigned Members',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: board.memberIds.map((memberId) {
                    final selected = task.assigneeIds.contains(memberId);
                    return FilterChip(
                      label: Text(_userName(board, memberId)),
                      selected: selected,
                      onSelected: _isProcessing
                          ? null
                          : (isSelected) {
                              _runAction(
                                (p) => p.setTaskAssignee(
                                  widget.cardId,
                                  memberId,
                                  isSelected,
                                ),
                              );
                            },
                    );
                  }).toList(),
                ),
                // Clean up assignments from former members.
                if (hasFormerAssignees)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () {
                              _runAction(
                                (p) => p.cleanTaskAssignees(widget.cardId),
                              );
                            },
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Clear former member assignments'),
                    ),
                  ),
                const SizedBox(height: 22),
                // Colored labels.
                const Text(
                  'Labels',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: availableLabels.map((label) {
                    final selected = task.labels.any(
                      (item) => item.name == label.name,
                    );
                    final color = Color(
                      int.parse(label.colorHex.replaceFirst('#', '0xFF')),
                    );
                    return FilterChip(
                      label: Text(label.name),
                      selected: selected,
                      selectedColor: color.withValues(alpha: 0.20),
                      onSelected: _isProcessing
                          ? null
                          : (isSelected) {
                              _runAction((p) async {
                                final latest = p.getCard(widget.cardId);
                                if (latest == null) return false;
                                final updated = List<TaskLabel>.from(
                                  latest.labels,
                                );
                                updated.removeWhere(
                                  (item) => item.name == label.name,
                                );
                                if (isSelected) updated.add(label);
                                return p.updateCard(
                                  widget.cardId,
                                  labels: updated,
                                );
                              });
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 12),
                // Checklist heading.
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Checklist',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add checklist item',
                      onPressed: _isProcessing ? null : _addChecklistItem,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (task.checklist.isNotEmpty) ...[
                  Text(
                    '${task.completedChecklistItems}'
                    '/${task.checklist.length} completed',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: task.checklistProgress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 10),
                ],
                if (task.checklist.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No checklist items yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ...task.checklist.map((item) {
                  return Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(item.text),
                          value: item.isChecked,
                          onChanged: _isProcessing
                              ? null
                              : (_) {
                                  _runAction(
                                    (p) => p.toggleChecklistItem(
                                      widget.cardId,
                                      item.id,
                                    ),
                                  );
                                },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete checklist item',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _isProcessing
                            ? null
                            : () {
                                _runAction((p) async {
                                  final latest = p.getCard(widget.cardId);
                                  if (latest == null) return false;
                                  return p.updateCard(
                                    widget.cardId,
                                    checklist: latest.checklist
                                        .where((entry) => entry.id != item.id)
                                        .toList(),
                                  );
                                });
                              },
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                // =====================================
                // COMMENTS
                // =====================================
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Chip(label: Text('${comments.length}')),
                  ],
                ),
                const SizedBox(height: 12),
                if (comments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ...comments.map((comment) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.authorName.isNotEmpty
                                ? comment.authorName
                                : _userName(board, comment.userId),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(comment.text),
                          const SizedBox(height: 6),
                          Text(
                            _formatDateTime(context, comment.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                if (!task.archived) ...[
                  TextField(
                    controller: _commentController,
                    enabled: !_isProcessing,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Write a comment',
                      hintText: 'Enter your comment...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _postComment,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Post Comment'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                // =====================================
                // ACTIVITY HISTORY
                // =====================================
                const Row(
                  children: [
                    Icon(Icons.history, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Activity History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (activities.isEmpty)
                  const Text(
                    'No activity yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ...activities.map((activity) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.history, size: 18),
                    ),
                    title: Text(activity.message),
                    subtitle: Text(
                      '${activity.actorName.isNotEmpty ? activity.actorName : _userName(board, activity.actorId)} • '
                      '${_formatDateTime(context, activity.createdAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
