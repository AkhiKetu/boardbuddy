import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:boardbuddy/core/widgets/board_title.dart';
import 'package:boardbuddy/models/board.dart';
import 'package:boardbuddy/providers/board_provider.dart';
import 'package:boardbuddy/providers/card_provider.dart';

import 'create_board_screen.dart';
import 'kanban_board_screen.dart';
import 'board_invitations_screen.dart';

class BoardsScreen extends StatelessWidget {
  const BoardsScreen({super.key});

  // =====================================
  // BOARD INVITATIONS
  // =====================================

  void _openInvitations(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BoardInvitationsScreen()),
    );
  }

  // =====================================
  // SAFE BOARD DELETION
  // =====================================

  Future<void> _deleteBoard(BuildContext context, Board board) async {
    final boardProvider = context.read<BoardProvider>();

    if (boardProvider.isDeleting) return;

    // Only the board owner can delete it.
    if (board.ownerId != boardProvider.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the board owner can delete this board.'),
        ),
      );

      return;
    }

    // Ask for confirmation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Board?'),

          content: Text(
            'Are you sure you want to permanently delete '
            '"${board.title}"?\n\n'
            'All columns, tasks, comments and activity '
            'history will be deleted.\n\n'
            'This action cannot be undone.',
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
              child: const Text('Delete Board'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) return;

    // Wait for Firestore deletion to finish.
    final deleted = await boardProvider.deleteBoard(board.id);

    if (!context.mounted) return;

    // Show deletion result.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Board deleted successfully.'
              : boardProvider.errorMessage ?? 'Unable to delete board.',
        ),
      ),
    );
  }

  // =====================================
  // BUILD BOARDS SCREEN
  // =====================================

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BoardProvider>();

    final cardProvider = context.watch<CardProvider>();

    final boards = boardProvider.boards;

    return Scaffold(
      body: Column(
        children: [
          // Show progress while deleting a board.
          if (boardProvider.isDeleting) const LinearProgressIndicator(),

          if (boardProvider.isDeleting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Deleting board and its tasks...',
                style: TextStyle(color: Colors.grey),
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),

              itemCount: boards.isEmpty ? 2 : boards.length + 1,

              itemBuilder: (context, index) {
                // =====================================
                // SCREEN HEADING
                // =====================================

                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Boards',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: 6),

                              Text(
                                'Manage your team projects '
                                'in one place.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),

                        // NEW: Received board invitations.
                        IconButton(
                          tooltip: 'Board Invitations',
                          onPressed: boardProvider.isDeleting
                              ? null
                              : () {
                                  _openInvitations(context);
                                },
                          icon: const Icon(Icons.mail_outline, size: 28),
                        ),
                      ],
                    ),
                  );
                }

                // =====================================
                // LOADING STATE
                // =====================================

                if (boardProvider.isLoading && boards.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // Error state.
                if (boards.isEmpty && boardProvider.errorMessage != null) {
                  return Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(
                      boardProvider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                // Empty boards message.
                if (boards.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'No boards yet. '
                        'Create your first board!',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // =====================================
                // DISPLAY BOARD
                // =====================================

                final board = boards[index - 1];

                final boardColor = Color(
                  int.parse(board.colorHex.replaceFirst('#', '0xFF')),
                );

                // Check board ownership.
                final isOwner = board.ownerId == boardProvider.currentUserId;

                // Actual open task count.
                final openCards = cardProvider.openCardCount(board.id);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: BoardTile(
                        title: board.title,
                        color: boardColor,
                        openCards: openCards,
                        memberCount: board.memberCount,

                        // Open Kanban workspace.
                        onTap: () {
                          if (boardProvider.isDeleting) {
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  KanbanBoardScreen(selectedBoard: board),
                            ),
                          );
                        },
                      ),
                    ),

                    // Only owners can delete boards.
                    if (isOwner)
                      PopupMenuButton<String>(
                        tooltip: 'Board Options',

                        enabled: !boardProvider.isDeleting,

                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteBoard(context, board);
                          }
                        },

                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red),

                                SizedBox(width: 10),

                                Text(
                                  'Delete Board',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      // =====================================
      // CREATE NEW BOARD
      // =====================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: boardProvider.isDeleting
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateBoardScreen(),
                  ),
                );
              },

        icon: const Icon(Icons.add),

        label: const Text('New Board'),
      ),
    );
  }
}
