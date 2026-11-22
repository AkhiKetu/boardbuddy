import 'package:boardbuddy/models/board.dart';

// Temporary board data before Firebase integration
final List<Board> mockBoards = [
  Board(
    id: 'board1',
    title: 'Mobile App Project',
    colorHex: '#6759E8',
    ownerId: 'user1',
    memberIds: ['user1', 'user2', 'user3'],
    memberNames: {'user1': 'Akhi', 'user2': 'Nila', 'user3': 'Rafi'},
    createdAt: DateTime.now(),
  ),

  Board(
    id: 'board2',
    title: 'Numerical Methods',
    colorHex: '#1BA995',
    ownerId: 'user1',
    memberIds: ['user1', 'user2'],
    memberNames: {'user1': 'Akhi', 'user2': 'Nila'},
    createdAt: DateTime.now(),
  ),

  Board(
    id: 'board3',
    title: 'Group Presentation',
    colorHex: '#E7A14C',
    ownerId: 'user1',
    memberIds: ['user1', 'user3'],
    memberNames: {'user1': 'Akhi', 'user3': 'Rafi'},
    createdAt: DateTime.now(),
  ),
];
