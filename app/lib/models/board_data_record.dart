class BoardDataRecord {
  final int boardId;
  final DateTime timestamp;
  final int clientsCount;

  BoardDataRecord({
    required this.boardId,
    required this.timestamp,
    required this.clientsCount,
  });

  factory BoardDataRecord.fromJson(Map<String, dynamic> json) {
    return BoardDataRecord(
      boardId: json['board_id'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      clientsCount: json['clients_count'] as int,
    );
  }
}
