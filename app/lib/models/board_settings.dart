class BoardSettings {
  final int? boardId;
  final int scansPerSend;
  final int wifiScanTimeMs;
  final int bluetoothScanTimeMs;
  final int wifiChannelScanTimeMs;
  final int minimalEncounterCount;
  final int minRssi;
  final int minRssiBle;

  const BoardSettings({
    this.boardId,
    required this.scansPerSend,
    required this.wifiScanTimeMs,
    required this.bluetoothScanTimeMs,
    required this.wifiChannelScanTimeMs,
    required this.minimalEncounterCount,
    required this.minRssi,
    required this.minRssiBle,
  });

  /// Defaults from `board/src/config.h.example` / migration defaults.
  factory BoardSettings.defaults() {
    return const BoardSettings(
      scansPerSend: 1,
      wifiScanTimeMs: 40 * 1000, // WIFI_SCAN_TIME_MS
      bluetoothScanTimeMs: 12 * 1000, // BLUETOOTH_SCAN_TIME_MS
      wifiChannelScanTimeMs: 200, // CHANNEL_SCAN_TIME_MS
      minimalEncounterCount: 2,
      minRssi: -75,
      minRssiBle: -85,
    );
  }

  factory BoardSettings.fromJson(Map<String, dynamic> json) {
    return BoardSettings(
      boardId: json['board_id'] as int?,
      scansPerSend: json['scans_per_send'] as int,
      wifiScanTimeMs: json['wifi_scan_time_ms'] as int,
      bluetoothScanTimeMs: json['bluetooth_scan_time_ms'] as int,
      wifiChannelScanTimeMs: json['wifi_channel_scan_time_ms'] as int,
      minimalEncounterCount: json['minimal_encounter_count'] as int,
      minRssi: json['min_rssi'] as int,
      minRssiBle: json['min_rssi_ble'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scans_per_send': scansPerSend,
      'wifi_scan_time_ms': wifiScanTimeMs,
      'bluetooth_scan_time_ms': bluetoothScanTimeMs,
      'wifi_channel_scan_time_ms': wifiChannelScanTimeMs,
      'minimal_encounter_count': minimalEncounterCount,
      'min_rssi': minRssi,
      'min_rssi_ble': minRssiBle,
    };
  }
}
