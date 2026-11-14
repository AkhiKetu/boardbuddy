import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/board.dart';
import '../../providers/column_provider.dart';
import '../../core/widgets/kanban_column_widget.dart';

class KanbanBoardScreen extends StatefulWidget {
  final Board selectedBoard;

  const KanbanBoardScreen({super.key, required this.selectedBoard});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
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

  // Add a custom Kanban column
  Future<void> _addNewColumn() async {
    String columnName = '';

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add New Column'),

          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter column name'),
            onChanged: (value) {
              columnName = value;
            },
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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

  @override
  Widget build(BuildContext context) {
    // Get selected board columns
    final columns = context.watch<ColumnProvider>().columnsForBoard(
      widget.selectedBoard.id,
    );

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
              'Swipe horizontally to view columns',
              style: TextStyle(color: Colors.grey),
            ),
          ),

          // Horizontal Kanban layout
          Expanded(
            child: ListView.builder(
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

                // Reuse the column widget
                return KanbanColumnWidget(column: columns[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
