class BoardSettings {
  final int? boardId;
  final int scansPerSend;
  final int wifiScanTime;
  final int bluetoothScanTime;
  final int wifiChannelScanTime;
  final int bluetoothChannelScanTime;
  final int minimalEncounterCount;
  final int minRssi;

  const BoardSettings({
    this.boardId,
    required this.scansPerSend,
    required this.wifiScanTime,
    required this.bluetoothScanTime,
    required this.wifiChannelScanTime,
    required this.bluetoothChannelScanTime,
    required this.minimalEncounterCount,
    required this.minRssi,
  });

  /// Defaults from `board/src/config.h.example`.
  factory BoardSettings.defaults() {
    return const BoardSettings(
      scansPerSend: 1,
      wifiScanTime: 40 * 1000, // WIFI_SCAN_TIME_MS
      bluetoothScanTime: 12 * 1000, // BLUETOOTH_SCAN_TIME_MS
      wifiChannelScanTime: 200, // CHANNEL_SCAN_TIME_MS
      bluetoothChannelScanTime: 200, // CHANNEL_SCAN_TIME_MS
      minimalEncounterCount: 2,
      minRssi: -75,
    );
  }

  factory BoardSettings.fromJson(Map<String, dynamic> json) {
    return BoardSettings(
      boardId: json['board_id'] as int?,
      scansPerSend: json['scans_per_send'] as int,
      wifiScanTime: json['wifi_scan_time'] as int,
      bluetoothScanTime: json['bluetooth_scan_time'] as int,
      wifiChannelScanTime: json['wifi_channel_scan_time'] as int,
      bluetoothChannelScanTime: json['bluetooth_channel_scan_time'] as int,
      minimalEncounterCount: json['minimal_encounter_count'] as int,
      minRssi: json['min_rssi'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scans_per_send': scansPerSend,
      'wifi_scan_time': wifiScanTime,
      'bluetooth_scan_time': bluetoothScanTime,
      'wifi_channel_scan_time': wifiChannelScanTime,
      'bluetooth_channel_scan_time': bluetoothChannelScanTime,
      'minimal_encounter_count': minimalEncounterCount,
      'min_rssi': minRssi,
    };
  }
}
