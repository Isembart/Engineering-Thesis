#include "board_settings.h"
#include <Preferences.h>

#include "../../wifi_functions/include/ArduinoJson-v7.4.3.h"

namespace
{
    const char *NVS_PROVISIONING = "prov";
    const char *NVS_TUNABLES = "settings";
    const char *NVS_OTA = "ota";

    // JSON key in the provisioning file -> NVS key (NVS keys are limited to 15 characters)
    struct ProvisioningKey
    {
        const char *json;
        const char *nvs;
    };
    const ProvisioningKey STRING_KEYS[] = {
        {"wifi_ssid", "ssid"},
        {"wifi_password", "pass"},
        {"peap_identity", "peap_id"},
        {"peap_username", "peap_user"},
        {"peap_password", "peap_pass"},
        {"server_endpoint", "endpoint"},
    };
    const ProvisioningKey BOOL_KEYS[] = {
        {"peap", "peap"},
        {"external_antenna", "antenna"},
    };

    // Skip the flash write when nothing changed, settings are re-fetched every cycle
    void putIfChanged(Preferences &prefs, const char *key, int32_t value)
    {
        if (!prefs.isKey(key) || prefs.getInt(key) != value)
        {
            prefs.putInt(key, value);
        }
    }
}

void BoardSettings::load()
{
    Preferences prefs;

    // begin() fails when the namespace was never written, the defaults stay in place then
    if (prefs.begin(NVS_TUNABLES, true))
    {
        BoardSettings stored = *this;
        stored.ScansPerSend = prefs.getInt("scans", ScansPerSend);
        stored.WifiScanTimeMS = prefs.getInt("wifi_ms", WifiScanTimeMS);
        stored.BluetoothScanTimeMS = prefs.getInt("bt_ms", BluetoothScanTimeMS);
        stored.WifiChannelScanTimeMS = prefs.getInt("chan_ms", WifiChannelScanTimeMS);
        stored.MinimalEncounterCount = prefs.getInt("min_enc", MinimalEncounterCount);
        stored.minRSSI = prefs.getInt("rssi", minRSSI);
        stored.minRSSIBLE = prefs.getInt("rssi_ble", minRSSIBLE);
        prefs.end();
        if (stored.tunablesInBounds())
        {
            *this = stored;
        }
    }

    provisioned = false;
    if (prefs.begin(NVS_PROVISIONING, true))
    {
        wifiSSID = prefs.getString("ssid");
        wifiPassword = prefs.getString("pass");
        peap = prefs.getBool("peap", false);
        peapIdentity = prefs.getString("peap_id");
        peapUsername = prefs.getString("peap_user");
        peapPassword = prefs.getString("peap_pass");
        ServerEndpoint = prefs.getString("endpoint");
        externalAntenna = prefs.getBool("antenna", false);
        prefs.end();
        provisioned = ServerEndpoint.length() > 0 && wifiSSID.length() > 0;
    }
}

bool BoardSettings::tunablesInBounds() const
{
    // Worst case cycle: 10 * (5 min + 1 min) = 1 hour between check-ins
    return ScansPerSend >= 1 && ScansPerSend <= 10 &&
           WifiScanTimeMS >= 1000 && WifiScanTimeMS <= 5 * 60 * 1000 &&
           BluetoothScanTimeMS >= 1000 && BluetoothScanTimeMS <= 60 * 1000 &&
           WifiChannelScanTimeMS >= 50 && WifiChannelScanTimeMS <= 5000 &&
           MinimalEncounterCount >= 1 && MinimalEncounterCount <= 100 &&
           minRSSI >= -100 && minRSSI <= 0 &&
           minRSSIBLE >= -100 && minRSSIBLE <= 0;
}

void BoardSettings::saveTunables() const
{
    Preferences prefs;
    if (!prefs.begin(NVS_TUNABLES, false))
    {
        return;
    }
    putIfChanged(prefs, "scans", ScansPerSend);
    putIfChanged(prefs, "wifi_ms", WifiScanTimeMS);
    putIfChanged(prefs, "bt_ms", BluetoothScanTimeMS);
    putIfChanged(prefs, "chan_ms", WifiChannelScanTimeMS);
    putIfChanged(prefs, "min_enc", MinimalEncounterCount);
    putIfChanged(prefs, "rssi", minRSSI);
    putIfChanged(prefs, "rssi_ble", minRSSIBLE);
    prefs.end();
}

const char *BoardSettings::provision(const String &json)
{
    JsonDocument doc;
    if (deserializeJson(doc, json))
    {
        return "invalid JSON";
    }

    // Validate everything before touching the stored config
    for (const auto &key : STRING_KEYS)
    {
        if (!doc[key.json].is<const char *>())
        {
            return "missing or non-string key";
        }
    }
    for (const auto &key : BOOL_KEYS)
    {
        if (!doc[key.json].is<bool>())
        {
            return "missing or non-boolean key";
        }
    }
    if (!String(doc["server_endpoint"].as<const char *>()).startsWith("http") ||
        strlen(doc["wifi_ssid"].as<const char *>()) == 0)
    {
        return "server_endpoint must be an http(s) URL and wifi_ssid must not be empty";
    }

    Preferences prefs;
    for (const char *ns : {NVS_TUNABLES, NVS_OTA, NVS_PROVISIONING})
    {
        if (!prefs.begin(ns, false))
        {
            return "cannot open NVS";
        }
        prefs.clear();
        prefs.end();
    }

    prefs.begin(NVS_PROVISIONING, false);
    for (const auto &key : STRING_KEYS)
    {
        prefs.putString(key.nvs, doc[key.json].as<const char *>());
    }
    for (const auto &key : BOOL_KEYS)
    {
        prefs.putBool(key.nvs, doc[key.json].as<bool>());
    }
    prefs.end();
    return nullptr;
}
