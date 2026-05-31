class Board {
  final int boardMac;
  final String name;

  Board({
    required this.boardMac,
    required this.name,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      boardMac: json['board_mac'] as int,
      name: json['name'] as String,
    );
  }
}
