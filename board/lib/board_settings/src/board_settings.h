#pragma once
#include <WString.h>

class BoardSettings
{
public:
    // --- Tunables: compiled defaults, overridden by values persisted from the server ---
    unsigned int ScansPerSend = 1;
    // Time in milliseconds
    unsigned int WifiScanTimeMS = 40 * 1000;
    // Time in milliseconds
    unsigned int BluetoothScanTimeMS = 12 * 1000;
    // Time in milliseconds
    unsigned int WifiChannelScanTimeMS = 200;
    unsigned int MinimalEncounterCount = 2;
    signed int minRSSI = -75;
    signed int minRSSIBLE = -85;

    // --- Provisioning config: lives only in NVS, written only by provision() over USB serial.
    // Never compiled into the firmware and never changed by the server or an OTA update. ---
    bool provisioned = false;
    String ServerEndpoint;
    // The server's BOARD_TOKEN, sent with every request
    String boardToken;
    bool externalAntenna = false;
    String wifiSSID;
    String wifiPassword;
    bool peap = false;
    String peapIdentity;
    String peapUsername;
    String peapPassword;

    // Load persisted tunables and provisioning config from NVS. Call from setup(), not earlier.
    void load();

    // Reject values that would stall the board, e.g. a scan lasting days.
    bool tunablesInBounds() const;
    void saveTunables() const;

    // Replace the whole stored config with the given JSON and wipe persisted tunables and
    // OTA state. Returns nullptr on success, otherwise the reason nothing was changed.
    static const char *provision(const String &json);
};
