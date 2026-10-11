#include <WString.h>

class BoardSettings
{
public:
    BoardSettings(unsigned int scansPerSend,
                  unsigned int wifiScanTime,
                  unsigned int bluetoothScanTime,
                  unsigned int wifiChannelScanTime,
                  unsigned int minimalEncounterCount,
                  String serverEndpoint,
                  bool externalAntenna,
                  const char *wifiSSID,
                  const char *wifiPassword,
                  bool peap,
                  const char *peapIdentity,
                  const char *peapUsername,
                  const char *peapPassword,
                  signed int minRSSI,
                  signed int minRSSIBLE)
        : ScansPerSend(scansPerSend),
          WifiScanTimeMS(wifiScanTime),
          BluetoothScanTimeMS(bluetoothScanTime),
          WifiChannelScanTimeMS(wifiChannelScanTime),
          MinimalEncounterCount(minimalEncounterCount),
          ServerEndpoint(serverEndpoint),
          externalAntenna(externalAntenna),
          wifiSSID(wifiSSID),
          wifiPassword(wifiPassword),
          peap(peap),
          peapIdentity(peapIdentity),
          peapUsername(peapUsername),
          peapPassword(peapPassword),
          minRSSI(minRSSI),
          minRSSIBLE(minRSSIBLE)
    {
    }

    unsigned int ScansPerSend;
    // Time in milliseconds
    unsigned int WifiScanTimeMS;
    // Time in milliseconds
    unsigned int BluetoothScanTimeMS;
    // Time in milliseconds
    unsigned int WifiChannelScanTimeMS;
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
    signed int minRSSIBLE;

    // Load default settings from config.h
    static BoardSettings loadDefaultSettings();
};
