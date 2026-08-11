class BoardDataRecord {
  final int id;
  /// FK to [Board.id] (not the MAC address).
  final int boardId;
  final DateTime timestamp;
  final int clientsCount;

  BoardDataRecord({
    required this.id,
    required this.boardId,
    required this.timestamp,
    required this.clientsCount,
  });

  factory BoardDataRecord.fromJson(Map<String, dynamic> json) {
    return BoardDataRecord(
      id: json['id'] as int,
      boardId: json['board_id'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      clientsCount: json['clients_count'] as int,
    );
  }
}
