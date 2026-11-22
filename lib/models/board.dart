class Board {
  // Attributes
  final String id;
  final String title;
  final String colorHex;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final DateTime createdAt;

  // Constructor
  Board({
    required this.id,
    required this.title,
    required this.colorHex,
    required this.ownerId,
    required this.memberIds,
    required this.memberNames,
    required this.createdAt,
  });

  // Getter: Total board members
  int get memberCount => memberIds.length;
}
