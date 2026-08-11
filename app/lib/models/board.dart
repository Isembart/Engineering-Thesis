class Board {
  final int id;
  final int boardMac;
  final String? name;

  Board({
    required this.id,
    required this.boardMac,
    this.name,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as int,
      boardMac: json['board_mac'] as int,
      name: json['name'] as String?,
    );
  }
}
