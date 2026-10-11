class Board {
  final int id;
  final int boardMac;
  final String? name;
  /// Version the board last reported, null until it has checked for an update.
  final int? firmwareVersion;

  Board({
    required this.id,
    required this.boardMac,
    this.name,
    this.firmwareVersion,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as int,
      boardMac: json['board_mac'] as int,
      name: json['name'] as String?,
      firmwareVersion: json['firmware_version'] as int?,
    );
  }
}
