import 'package:flutter/material.dart';

import '../../models/board_column.dart';

class KanbanColumnWidget extends StatelessWidget {
  final BoardColumn column;
  final List<Widget> cards;

  final VoidCallback? onAddCard;
  final VoidCallback? onRename;
  final VoidCallback? onMoveLeft;
  final VoidCallback? onMoveRight;
  final VoidCallback? onDelete;

  const KanbanColumnWidget({
    super.key,
    required this.column,
    this.cards = const [],
    this.onAddCard,
    this.onRename,
    this.onMoveLeft,
    this.onMoveRight,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Column heading
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    column.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Card count
                Chip(
                  label: Text('${cards.length}'),
                  visualDensity: VisualDensity.compact,
                ),

                // Column actions
                PopupMenuButton<String>(
                  tooltip: 'Column Options',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        onRename?.call();
                        break;
                      case 'left':
                        onMoveLeft?.call();
                        break;
                      case 'right':
                        onMoveRight?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      enabled: onRename != null,
                      child: const Text('Rename'),
                    ),
                    PopupMenuItem(
                      value: 'left',
                      enabled: onMoveLeft != null,
                      child: const Text('Move Left'),
                    ),
                    PopupMenuItem(
                      value: 'right',
                      enabled: onMoveRight != null,
                      child: const Text('Move Right'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: onDelete != null,
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Task cards area
          Expanded(
            child: cards.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 36,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No cards yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cards.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) => cards[index],
                  ),
          ),

          // Existing Add Card button
          if (onAddCard != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddCard,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Card'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
