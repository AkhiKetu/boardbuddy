import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/board.dart';
import '../../providers/board_provider.dart';

class BoardMembersScreen extends StatefulWidget {
  final Board board;

  const BoardMembersScreen({super.key, required this.board});

  @override
  State<BoardMembersScreen> createState() => _BoardMembersScreenState();
}

class _BoardMembersScreenState extends State<BoardMembersScreen> {
  final TextEditingController _emailController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isInviting = false;
  bool _isProcessing = false;

  bool get _isBusy => _isInviting || _isProcessing;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // =====================================
  // SHOW MESSAGE
  // =====================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // =====================================
  // INVITE MEMBER
  // =====================================

  Future<void> _inviteMember() async {
    if (_isBusy) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final boardProvider = context.read<BoardProvider>();

    setState(() => _isInviting = true);

    try {
      await boardProvider.inviteMember(
        boardId: widget.board.id,
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      _emailController.clear();

      _showMessage('Invitation created successfully.');
    } catch (error) {
      final message = error is StateError ? error.message : error.toString();

      _showMessage(message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  // =====================================
  // REMOVE MEMBER - OWNER ONLY
  // =====================================

  Future<void> _removeMember(
    Board board,
    String memberId,
    String memberName,
  ) async {
    if (_isBusy) return;

    final provider = context.read<BoardProvider>();

    if (board.ownerId != provider.currentUserId) {
      _showMessage('Only the board owner can remove members.', isError: true);
      return;
    }

    if (memberId == board.ownerId) {
      _showMessage('The board owner cannot be removed.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Member?'),

          content: Text(
            'Are you sure you want to remove '
            '$memberName from "${board.title}"?\n\n'
            'Their task assignments will be removed, '
            'but the tasks and history will remain.',
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

              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || _isBusy) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await provider.removeMember(boardId: board.id, memberId: memberId);

      _showMessage('$memberName removed successfully.');
    } catch (error) {
      debugPrint('Remove member error: $error');

      _showMessage(
        error is StateError
            ? error.message
            : 'Unable to remove member. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // LEAVE BOARD - REGULAR MEMBER
  // =====================================

  Future<void> _leaveBoard(Board board) async {
    if (_isBusy) return;

    final provider = context.read<BoardProvider>();

    if (board.ownerId == provider.currentUserId) {
      _showMessage('The board owner cannot leave the board.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave Board?'),

          content: Text(
            'Are you sure you want to leave '
            '"${board.title}"?\n\n'
            'You will lose access to this board and '
            'your task assignments will be removed.\n\n'
            'The owner must invite you again to rejoin.',
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

              child: const Text('Leave Board'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true || _isBusy) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await provider.leaveBoard(boardId: board.id);

      if (!mounted) return;

      _showMessage('You have left "${board.title}".');

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      debugPrint('Leave board error: $error');

      _showMessage(
        error is StateError
            ? error.message
            : 'Unable to leave board. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // =====================================
  // INVITATION FORM
  // =====================================

  Widget _buildInvitationForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Row(
                children: [
                  Icon(Icons.person_add_outlined),

                  SizedBox(width: 10),

                  Text(
                    'Invite Member',

                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                'Invite a registered and verified '
                'BoardBuddy user by email.',

                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,

                keyboardType: TextInputType.emailAddress,

                autocorrect: false,

                enabled: !_isBusy,

                decoration: const InputDecoration(
                  labelText: 'Email Address',

                  hintText: 'example@gmail.com',

                  prefixIcon: Icon(Icons.email_outlined),

                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an email address';
                  }

                  final email = value.trim();

                  final pattern = RegExp(r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$');

                  if (email.length > 254 || !pattern.hasMatch(email)) {
                    return 'Enter a valid email';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,

                child: ElevatedButton.icon(
                  onPressed: _isBusy ? null : _inviteMember,

                  icon: _isInviting
                      ? const SizedBox(
                          width: 18,
                          height: 18,

                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),

                  label: Text(_isInviting ? 'Inviting...' : 'Invite Member'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================
  // BUILD MEMBERS SCREEN
  // =====================================

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BoardProvider>();

    Board? currentBoard;

    // Get latest board data from Firestore.
    for (final board in boardProvider.boards) {
      if (board.id == widget.board.id &&
          board.memberIds.contains(boardProvider.currentUserId)) {
        currentBoard = board;
        break;
      }
    }

    if (currentBoard == null && boardProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Board Members')),

        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Access revoked or board deleted.
    if (currentBoard == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Board Members')),

        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Icon(Icons.lock_outline, size: 70, color: Colors.grey),

                const SizedBox(height: 16),

                const Text(
                  'This board is no longer available.',

                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },

                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final board = currentBoard;

    final currentUserId = boardProvider.currentUserId;

    final isOwner = board.ownerId == currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Board Members')),

      body: Column(
        children: [
          if (_isBusy) const LinearProgressIndicator(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),

              children: [
                Text(
                  board.title,

                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '${board.memberCount} member(s)',

                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 24),

                // Only owner can invite members.
                if (isOwner) ...[
                  _buildInvitationForm(),

                  const SizedBox(height: 24),
                ],

                const Text(
                  'Current Members',

                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                ...board.memberIds.map((memberId) {
                  final name = board.memberNames[memberId] ?? 'Unknown User';

                  final isBoardOwner = memberId == board.ownerId;

                  final isCurrentUser = memberId == currentUserId;

                  final canRemove = isOwner && !isBoardOwner;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),

                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          name.trim().isNotEmpty
                              ? name.trim()[0].toUpperCase()
                              : '?',
                        ),
                      ),

                      title: Text(
                        isCurrentUser ? '$name (You)' : name,

                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      subtitle: Text(isBoardOwner ? 'Board Owner' : 'Member'),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          Chip(label: Text(isBoardOwner ? 'Owner' : 'Member')),

                          if (canRemove)
                            IconButton(
                              tooltip: 'Remove Member',

                              onPressed: _isBusy
                                  ? null
                                  : () => _removeMember(board, memberId, name),

                              icon: const Icon(
                                Icons.person_remove_outlined,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                // Regular members can leave.
                if (!isOwner && board.memberIds.contains(currentUserId))
                  Padding(
                    padding: const EdgeInsets.only(top: 24),

                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : () => _leaveBoard(board),

                      icon: const Icon(Icons.logout),

                      label: const Text('Leave Board'),

                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,

                        side: const BorderSide(color: Colors.red),

                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
