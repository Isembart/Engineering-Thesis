#include <WString.h>

class BoardSettings
{
public:
    BoardSettings(unsigned int scansPerSend,
                  unsigned int wifiScanTime,
                  unsigned int bluetoothScanTime,
                  unsigned int wifiChannelScanTime,
                  unsigned int bluetoothChannelScanTime,
                  unsigned int minimalEncounterCount,
                  String serverEndpoint,
                  bool externalAntenna,
                  const char *wifiSSID,
                  const char *wifiPassword,
                  bool peap,
                  const char *peapIdentity,
                  const char *peapUsername,
                  const char *peapPassword,
                  signed int minRSSI)
        : ScansPerSend(scansPerSend),
          WifiScanTimeMS(wifiScanTime),
          BluetoothScanTimeMS(bluetoothScanTime),
          WifiChannelScanTimeMS(wifiChannelScanTime),
          BluetoothChannelScanTimeMS(bluetoothChannelScanTime),
          MinimalEncounterCount(minimalEncounterCount),
          ServerEndpoint(serverEndpoint),
          externalAntenna(externalAntenna),
          wifiSSID(wifiSSID),
          wifiPassword(wifiPassword),
          peap(peap),
          peapIdentity(peapIdentity),
          peapUsername(peapUsername),
          peapPassword(peapPassword),
          minRSSI(minRSSI) {}

    unsigned int ScansPerSend;
    // Time in milliseconds
    unsigned int WifiScanTimeMS;
    // Time in milliseconds
    unsigned int BluetoothScanTimeMS;
    // Time in milliseconds
    unsigned int WifiChannelScanTimeMS;
    // Time in milliseconds
    unsigned int BluetoothChannelScanTimeMS;
    unsigned int MinimalEncounterCount;
    String ServerEndpoint;
    bool externalAntenna;

    const char *wifiSSID;
    const char *wifiPassword;
    bool peap;
    const char *peapIdentity;
    const char *peapUsername;
    const char *peapPassword;

    signed int minRSSI;

    // Load default settings from config.h
    static BoardSettings loadDefaultSettings();
};
