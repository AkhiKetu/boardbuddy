import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/board_provider.dart';

class CreateBoardScreen extends StatefulWidget {
  const CreateBoardScreen({super.key});

  @override
  State<CreateBoardScreen> createState() => _CreateBoardScreenState();
}

class _CreateBoardScreenState extends State<CreateBoardScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controller for board title
  final _titleController = TextEditingController();

  // Default board color
  String selectedColor = '#6759E8';

  // Available board colors
  final List<String> colors = [
    '#6759E8',
    '#1BA995',
    '#E7A14C',
    '#E45D75',
    '#3689DB',
  ];

  // Convert HEX string to Color
  Color hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  // Create board using Provider
  void createBoard() {
    if (_formKey.currentState!.validate()) {
      context.read<BoardProvider>().createBoard(
        _titleController.text.trim(),
        selectedColor,
      );

      // Return to Boards screen
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              decoration: const InputDecoration(
                hintText: 'Enter board title',
                prefixIcon: Icon(Icons.dashboard),
              ),

              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a board title';
                }
                return null;
              },
            ),

            const SizedBox(height: 30),

            // Board colors
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
                  onTap: () {
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
              child: ElevatedButton.icon(
                onPressed: createBoard,
                icon: const Icon(Icons.add),
                label: const Text('Create Board'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
