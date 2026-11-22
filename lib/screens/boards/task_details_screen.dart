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

  // Format comment and activity timestamps
  String _formatDateTime(BuildContext context, DateTime date) {
    final dateText = MaterialLocalizations.of(context)
        .formatMediumDate(date.toLocal());

    final timeText = TimeOfDay.fromDateTime(date.toLocal()).format(context);

    return '$dateText, $timeText';
  }

  // Get user display name from board members
  String _userName(String userId) {
    return widget.board.memberNames[userId] ?? userId;
  }

  // Edit task title and description
  Future<void> _editTask(TaskCard task) async {
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

    context.read<CardProvider>().updateCard(
      widget.cardId,
      title: title,
      description: description,
    );
  }

  // Add a checklist item
  Future<void> _addChecklistItem() async {
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

    if (!mounted || result == null || result.isEmpty) {
      return;
    }

    final provider = context.read<CardProvider>();
    final task = provider.getCard(widget.cardId);

    if (task == null) return;

    provider.updateCard(
      widget.cardId,
      checklist: [
        ...task.checklist,
        ChecklistItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: result,
        ),
      ],
    );
  }

  // Select due date
  Future<void> _selectDueDate(TaskCard task) async {
    final date = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted || date == null) return;

    context.read<CardProvider>().updateCard(widget.cardId, dueDate: date);
  }

  // Post a new comment
  void _postComment() {
    final text = _commentController.text.trim();

    if (text.isEmpty) return;

    final currentUserId = context.read<BoardProvider>().currentUserId;

    context.read<CardProvider>().addComment(
      cardId: widget.cardId,
      text: text,
      userId: currentUserId,
    );

    _commentController.clear();

    // Hide the keyboard after posting
    FocusScope.of(context).unfocus();
  }

  // Confirm task deletion
  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('This task will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    context.read<CardProvider>().deleteCard(widget.cardId);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CardProvider>();
    final task = provider.getCard(widget.cardId);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Details')),
        body: const Center(child: Text('Task no longer exists')),
      );
    }

    // NEW: Read comments and activity history
    final comments = provider.commentsForCard(widget.cardId);

    final activities = provider.activitiesForCard(widget.cardId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'archive') {
                context.read<CardProvider>().setArchived(widget.cardId, true);
                Navigator.pop(context);
              } else if (value == 'delete') {
                _deleteTask();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'archive', child: Text('Archive Task')),
              PopupMenuItem(value: 'delete', child: Text('Delete Task')),
            ],
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Task title and edit action
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
                onPressed: () => _editTask(task),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            task.description.isEmpty ? 'No description yet' : task.description,
            style: const TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 16),

          // Task completion
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Completed'),
            value: task.completed,
            onChanged: (value) {
              context.read<CardProvider>().setCompleted(widget.cardId, value);
            },
          ),

          const Divider(),

          // Due date
          const SizedBox(height: 12),
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
            onTap: () => _selectDueDate(task),
            trailing: task.dueDate == null
                ? null
                : IconButton(
                    tooltip: 'Clear due date',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      context.read<CardProvider>().updateCard(
                        widget.cardId,
                        clearDueDate: true,
                      );
                    },
                  ),
          ),

          const Divider(),
          const SizedBox(height: 12),

          // Multiple assignees
          const Text(
            'Assigned Members',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.board.memberIds.map((memberId) {
              final selected = task.assigneeIds.contains(memberId);

              return FilterChip(
                label: Text(_userName(memberId)),
                selected: selected,
                onSelected: (isSelected) {
                  final updated = List<String>.from(task.assigneeIds);

                  if (isSelected) {
                    if (!updated.contains(memberId)) {
                      updated.add(memberId);
                    }
                  } else {
                    updated.remove(memberId);
                  }

                  context.read<CardProvider>().updateCard(
                    widget.cardId,
                    assigneeIds: updated,
                  );
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Colored labels
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
                onSelected: (isSelected) {
                  final updated = List<TaskLabel>.from(task.labels);

                  if (isSelected) {
                    if (!selected) updated.add(label);
                  } else {
                    updated.removeWhere((item) => item.name == label.name);
                  }

                  context.read<CardProvider>().updateCard(
                    widget.cardId,
                    labels: updated,
                  );
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 12),

          // Checklist heading
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Checklist',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Add checklist item',
                onPressed: _addChecklistItem,
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
                    onChanged: (_) {
                      context.read<CardProvider>().toggleChecklistItem(
                        widget.cardId,
                        item.id,
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Delete checklist item',
                  onPressed: () {
                    context.read<CardProvider>().updateCard(
                      widget.cardId,
                      checklist: task.checklist
                          .where((entry) => entry.id != item.id)
                          .toList(),
                    );
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            );
          }),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // NEW: Comments section
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

          // Display existing comments
          ...comments.map((comment) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName(comment.userId),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(comment.text),
                    const SizedBox(height: 6),
                    Text(
                      _formatDateTime(context, comment.createdAt),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // Enter new comment
          TextField(
            controller: _commentController,
            maxLines: 3,
            minLines: 1,
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
              onPressed: _postComment,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Post Comment'),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // NEW: Activity History section
          Row(
            children: [
              const Icon(Icons.history, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Activity History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (activities.isEmpty)
            const Text('No activity yet', style: TextStyle(color: Colors.grey)),

          // Show newest activity first
          ...activities.map((activity) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.history, size: 18)),
              title: Text(activity.message),
              subtitle: Text(
                '${_userName(activity.actorId)} • '
                '${_formatDateTime(context, activity.createdAt)}',
                style: const TextStyle(fontSize: 12),
              ),
            );
          }),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
