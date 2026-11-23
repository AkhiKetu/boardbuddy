import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/board_provider.dart';

class CreateBoardScreen extends StatefulWidget {
  const CreateBoardScreen({super.key});

  @override
  State<CreateBoardScreen> createState() => _CreateBoardScreenState();
}

class _CreateBoardScreenState extends State<CreateBoardScreen> {
  // Form validation
  final _formKey = GlobalKey<FormState>();

  // Board title
  final _titleController = TextEditingController();

  // Default board color
  String selectedColor = '#6759E8';

  // Available colors
  final List<String> colors = [
    '#6759E8',
    '#1BA995',
    '#E7A14C',
    '#E45D75',
    '#3689DB',
  ];

  // Convert HEX to Flutter Color
  Color hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  // Create board in Firebase Firestore
  Future<void> createBoard() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final boardProvider = context.read<BoardProvider>();

    if (boardProvider.isCreating) return;

    FocusScope.of(context).unfocus();

    // Wait for Firestore to save the board.
    final boardId = await boardProvider.createBoard(
      _titleController.text.trim(),
      selectedColor,
    );

    if (!mounted) return;

    // Creation failed
    if (boardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            boardProvider.errorMessage ?? 'Unable to create board.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Creation succeeded
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Board created successfully!')),
    );

    // Return to Boards screen
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for board creation progress.
    final isCreating = context.watch<BoardProvider>().isCreating;

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Board')),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Board title
            const Text(
              'Board Title',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: _titleController,
              maxLength: 100,
              enabled: !isCreating,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Enter board title',
                prefixIcon: Icon(Icons.dashboard_outlined),
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                final title = value?.trim() ?? '';

                if (title.isEmpty) {
                  return 'Please enter a board title';
                }

                if (title.length > 100) {
                  return 'Maximum 100 characters allowed';
                }

                return null;
              },
            ),

            const SizedBox(height: 25),

            // Board color selection
            const Text(
              'Choose Board Colour',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((color) {
                final isSelected = selectedColor == color;

                return InkWell(
                  onTap: isCreating
                      ? null
                      : () {
                          setState(() {
                            selectedColor = color;
                          });
                        },
                  borderRadius: BorderRadius.circular(30),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: hexToColor(color),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // Create Board button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isCreating ? null : createBoard,

                icon: isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),

                label: Text(isCreating ? 'Creating Board...' : 'Create Board'),
              ),
            ),

            const SizedBox(height: 16),

            // Firebase status information
            const Text(
              'Your board will be saved securely '
              'to Cloud Firestore.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
