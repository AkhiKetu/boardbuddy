import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardbuddy/models/task_card.dart';
import 'package:boardbuddy/core/widgets/task_card_widget.dart';

void main() {
  testWidgets('Task card displays title and responds to tapping', (
    WidgetTester tester,
  ) async {
    // Create a sample task for testing.
    final task = TaskCard(
      id: 'test_task_1',
      boardId: 'test_board_1',
      columnId: 'test_column_1',
      title: 'Test Task',
      description: 'BoardBuddy task testing',
      position: 1000.0,
      createdBy: 'test_user',
      createdAt: DateTime(2026, 11, 23),
    );

    bool wasTapped = false;

    // Display the task card.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              child: TaskCardWidget(
                task: task,
                onTap: () {
                  wasTapped = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    // Verify that the task title appears.
    expect(find.text('Test Task'), findsOneWidget);

    // Verify the description appears.
    expect(find.text('BoardBuddy task testing'), findsOneWidget);

    // Tap the task.
    await tester.tap(find.text('Test Task'));

    // Check that the tap callback executed.
    expect(wasTapped, isTrue);
  });
}
