import 'package:flutter/material.dart';

import '../../models/task_card.dart';

// Reusable UI for one task card
class TaskCardWidget extends StatelessWidget {
  final TaskCard task;
  final VoidCallback? onTap;

  const TaskCardWidget({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Check whether the due date has passed
    final today = DateUtils.dateOnly(DateTime.now());

    final isOverdue =
        task.dueDate != null &&
        DateUtils.dateOnly(task.dueDate!).isBefore(today) &&
        !task.completed;

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE7E9F0)),
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(14),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored task labels
              if (task.labels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),

                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,

                    children: task.labels.map((label) {
                      final labelColor = Color(
                        int.parse(label.colorHex.replaceFirst('#', '0xFF')),
                      );

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),

                        decoration: BoxDecoration(
                          color: labelColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),

                        child: Text(
                          label.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Task title and completion status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),

                  if (task.completed)
                    const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.green,
                    ),
                ],
              ),

              // Task description
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 8),

                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],

              // Due date and assignees
              if (task.dueDate != null || task.assigneeIds.isNotEmpty) ...[
                const SizedBox(height: 12),

                Row(
                  children: [
                    if (task.dueDate != null) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: isOverdue ? Colors.red : Colors.grey,
                      ),

                      const SizedBox(width: 5),

                      Expanded(
                        child: Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(task.dueDate!),
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),

                    if (task.assigneeIds.isNotEmpty) ...[
                      const Icon(
                        Icons.people_outline,
                        size: 16,
                        color: Colors.grey,
                      ),

                      const SizedBox(width: 4),

                      Text(
                        '${task.assigneeIds.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // Checklist progress
              if (task.checklist.isNotEmpty) ...[
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Checklist',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),

                    Text(
                      '${task.completedChecklistItems}'
                      '/${task.checklist.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                LinearProgressIndicator(
                  value: task.checklistProgress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: const Color(0xFFEDEFF5),
                  color: const Color(0xFF6759E8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
