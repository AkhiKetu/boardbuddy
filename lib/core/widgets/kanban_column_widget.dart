import 'package:flutter/material.dart';

import '../../models/board_column.dart';

// Reusable Kanban column widget
class KanbanColumnWidget extends StatelessWidget {
  final BoardColumn column;
  final List<Widget> cards;
  final VoidCallback? onAddCard;

  const KanbanColumnWidget({
    super.key,
    required this.column,
    this.cards = const [],
    this.onAddCard,
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
          // Column title and card count
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    column.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Chip(label: Text('${cards.length}')),
              ],
            ),
          ),

          const Divider(height: 1),

          // Vertical task area
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

          // Button will be enabled when CardProvider is ready
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
