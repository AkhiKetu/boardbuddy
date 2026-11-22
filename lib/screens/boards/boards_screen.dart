import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:boardbuddy/core/widgets/board_title.dart';
import 'package:boardbuddy/providers/board_provider.dart';

import 'create_board_screen.dart';
import 'kanban_board_screen.dart';

class BoardsScreen extends StatelessWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get board data from Provider
    final boardProvider = context.watch<BoardProvider>();
    final boards = boardProvider.boards;

    // Temporary open-card counts
    // Later calculated using CardProvider
    const mockOpenCounts = {'board1': 8, 'board2': 5, 'board3': 4};

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(20),

        // Heading + board items
        itemCount: boards.isEmpty ? 2 : boards.length + 1,

        itemBuilder: (context, index) {
          // Screen heading
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Boards',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage your team projects in one place.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Empty boards message
          if (boards.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'No boards yet. Create your first board!',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Get each board from Provider
          final board = boards[index - 1];

          // Convert HEX string to Flutter Color
          final boardColor = Color(
            int.parse(board.colorHex.replaceFirst('#', '0xFF')),
          );

          // Display reusable BoardTile
          return BoardTile(
            title: board.title,
            color: boardColor,
            openCards: mockOpenCounts[board.id] ?? 0,
            memberCount: board.memberCount,

            // Open Kanban Workspace when board is clicked
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => KanbanBoardScreen(selectedBoard: board),
                ),
              );
            },
          );
        },
      ),

      // New Board button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateBoardScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Board'),
      ),
    );
  }
}
