#include "wifi_functions.h"
#include <Arduino.h>
#include <WiFi.h>
#include <esp_wifi.h>
#include <esp_mac.h>
#include "wifi_buffer/wifi_buffer.h"
#include <stdio.h>
#include <crypto_functions.h>
#include <HTTPClient.h>
#include <board_settings.h>
#include <Update.h>
#include <Preferences.h>
#include <esp_ota_ops.h>
#include "log.h"

#include "../include/ArduinoJson-v7.4.3.h"

// How many times a single published firmware version may be downloaded and tried
#define OTA_MAX_TRIES 3

namespace
{
    ClientsBuffer *g_clientsBuffer = nullptr;
    bool g_wifiInitialized = false;
    BoardSettings *g_boardSettings = nullptr;

    // Every server route a board uses requires the board token. Call after http.begin().
    void add_board_token(HTTPClient &http)
    {
        http.addHeader("Authorization", "Bearer " + g_boardSettings->boardToken);
    }
}

uint64_t get_mac_address()
{
    uint8_t macBytes[6];
    esp_read_mac(macBytes, ESP_MAC_WIFI_STA);
    return convert_mac_bytes_to_int(macBytes);
}

uint64_t convert_mac_bytes_to_int(const uint8_t *macBytes)
{

    uint64_t macAddressValue = 0;
    for (uint8_t i = 0; i < 6; ++i)
    {
        macAddressValue = (macAddressValue << 8) | macBytes[i];
    }

    return macAddressValue;
}

String get_mac_address_str()
{
    return String((unsigned long long)get_mac_address());
}

void init_wifi_sniffer(ClientsBuffer *clientsBuffer, BoardSettings *boardSettings)
{
    g_clientsBuffer = clientsBuffer;
    g_boardSettings = boardSettings;
}

void start_wifi_sniffer()
{

    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    delay(100);

    ESP_ERROR_CHECK(esp_wifi_set_promiscuous(false));

    wifi_promiscuous_filter_t filter;
    filter.filter_mask = WIFI_PROMIS_FILTER_MASK_MGMT;
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous_filter(&filter));

    ESP_ERROR_CHECK(esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE));
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous_rx_cb(wifi_packet_handler));
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous(true));

    LOG("SCAN", "WiFi sniffer started");
}

void hop_wifi_channel()
{
    uint8_t current_channel;
    wifi_second_chan_t second_channel;

    ESP_ERROR_CHECK(esp_wifi_get_channel(&current_channel, &second_channel));
    uint8_t new_channel = current_channel + 1;
    if (new_channel > 13)
    {
        new_channel = 1; // Wrap around to channel 1 after channel 13
    }

    esp_err_t set_channel_result = esp_wifi_set_channel(new_channel, WIFI_SECOND_CHAN_NONE);
    if (set_channel_result != ESP_OK)
    {
        LOG("SCAN", "Failed to switch WiFi channel, err=%d", (int)set_channel_result);
        return;
    }

    // Serial.print("Switched to channel: ");
    // Serial.println(new_channel);

    // clientsBuffer.printClients();
}

void wifi_packet_handler(void *buffer, wifi_promiscuous_pkt_type_t type)
{
    wifi_promiscuous_pkt_t *pkt = (wifi_promiscuous_pkt_t *)buffer;

    if (type != WIFI_PKT_MGMT)
    {
        return; // ignore non-management frames
    }

    if (pkt->rx_ctrl.rssi < g_boardSettings->minRSSI)
    {
        return; // ignore weak signals to reduce noise
    }

    uint8_t *payload = pkt->payload;
    // Frame Control: first byte holds subtype (high 4 bits) and type (low 2 bits of next nibble)
    uint8_t fc0 = payload[0];
    uint8_t subtype = (fc0 & 0xF0) >> 4;
    const uint8_t PROBE_REQUEST_SUBTYPE = 4; // 802.11 probe request

    if (subtype != PROBE_REQUEST_SUBTYPE)
    {
        return; // ignore beacons, probe responses, etc.
    }

    // uint8_t *src_mac = payload + 10; // source MAC is at offset 10 in management frames
    uint8_t src_mac_bytes[6] = {0};
    memcpy(src_mac_bytes, payload + 10, 6);

    uint64_t macHash = hash_64_fnv1a(src_mac_bytes, 6);

    // override the stored MAC address to anonymize it
    memset(src_mac_bytes, 0, sizeof(src_mac_bytes));

    if (g_clientsBuffer)
    {
        g_clientsBuffer->addClient(macHash);
        // g_clientsBuffer->addClient(String(macStr));
    }
}

bool connect_to_wifi(const char *ssid, const char *password)
{
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous(false));
    esp_wifi_set_promiscuous_rx_cb(NULL);
    WiFi.disconnect(false);
    WiFi.mode(WIFI_STA);

    LOG_PREFIX("WIFI");
    Serial.printf("Connecting to %s ", ssid);

    WiFi.begin(ssid, password); // last parameter is to enable fast reconnection
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20)
    {
        delay(1000);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED)
    {
        Serial.println();
        LOG("WIFI", "Connected to %s", ssid);
        return true;
    }

    Serial.println();
    LOG("WIFI", "Connection to %s timed out", ssid);
    return false;
}

bool connect_to_wifi_peap(const char *ssid, const char *identity, const char *username, const char *password)
{
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous(false));
    esp_wifi_set_promiscuous_rx_cb(NULL);
    WiFi.disconnect(false);
    WiFi.mode(WIFI_STA);
    LOG_PREFIX("WIFI");
    Serial.printf("Connecting to %s (PEAP) ", ssid);
    WiFi.begin(ssid, WPA2_AUTH_PEAP, identity, username, password);
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20)
    {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED)
    {
        Serial.println();
        LOG("WIFI", "Connected to %s", ssid);
        return true;
    }

    Serial.println();
    LOG("WIFI", "Connection to %s timed out", ssid);
    return false;
}

bool send_data_to_server(ClientsBuffer &clientsBuffer)
{
    const auto filteredClients = clientsBuffer.getFilteredClients(g_boardSettings->MinimalEncounterCount);

    String jsonBody = String("{\"mac_address\":") + get_mac_address_str() + String(",\"clients_count\":") + String(filteredClients.size()) + String("}");

    // --- Arduino HTTP Client approach ---
    HTTPClient http;

    // Increase timeout to 10 seconds for slow PEAP networks
    http.setTimeout(10000);

    String url = String(g_boardSettings->ServerEndpoint) + "/upload-board-data";

    if (!http.begin(url.c_str()))
    {
        LOG("HTTP", "Invalid server URL: %s", url.c_str());
        http.end();
        return false;
    }

    http.addHeader("Content-Type", "application/json");
    add_board_token(http);

    int httpResponseCode = http.POST(jsonBody);
    bool success = (httpResponseCode >= 200 && httpResponseCode < 300);

    if (success)
    {
        LOG("DATA", "Reported %u devices (HTTP %d)", (unsigned)filteredClients.size(), httpResponseCode);
    }
    else
    {
        LOG("DATA", "Failed to report devices (HTTP %d)", httpResponseCode);
    }

    http.end();
    return success;
}

bool send_settings_to_server()
{
    HTTPClient http;
    http.setTimeout(10000);

    String url = String(g_boardSettings->ServerEndpoint) +
                 "/board-settings" +
                 "?mac_address=" + get_mac_address_str();

    if (!http.begin(url.c_str()))
    {
        LOG("HTTP", "Invalid server URL: %s", url.c_str());
        return false;
    }

    http.addHeader("Content-Type", "application/json");
    add_board_token(http);

    // serialize the settings to JSON
    JsonDocument doc;
    doc["scans_per_send"] = g_boardSettings->ScansPerSend;
    doc["wifi_scan_time_ms"] = g_boardSettings->WifiScanTimeMS;
    doc["bluetooth_scan_time_ms"] = g_boardSettings->BluetoothScanTimeMS;
    doc["wifi_channel_scan_time_ms"] = g_boardSettings->WifiChannelScanTimeMS;
    doc["minimal_encounter_count"] = g_boardSettings->MinimalEncounterCount;
    doc["min_rssi"] = g_boardSettings->minRSSI;
    doc["min_rssi_ble"] = g_boardSettings->minRSSIBLE;
    // Sensitve fields, not supported by backend
    // doc["externalAntenna"] = g_boardSettings->externalAntenna;
    // doc["wifiSSID"] = g_boardSettings->wifiSSID;
    // doc["wifiPassword"] = g_boardSettings->wifiPassword;
    // doc["peap"] = g_boardSettings->peap;
    // doc["peapIdentity"] = g_boardSettings->peapIdentity;
    // doc["peapUsername"] = g_boardSettings->peapUsername;
    // doc["peapPassword"] = g_boardSettings->peapPassword;

    String jsonBody;
    serializeJson(doc, jsonBody);
    int httpResponseCode = http.POST(jsonBody);

    bool success = (httpResponseCode >= 200 && httpResponseCode < 300);
    if (httpResponseCode == 200)
    {
        LOG("CONF", "Default settings uploaded to the server (HTTP %d)", httpResponseCode);
    }
    else if (httpResponseCode == 409)
    {
        // expected on every cycle but the first, nothing worth printing
    }
    else
    {
        LOG("CONF", "Failed to upload settings (HTTP %d)", httpResponseCode);
    }

    http.end();
    return success;
};

bool get_settings_from_server()
{
    HTTPClient http;
    http.setTimeout(10000);

    String url = String(g_boardSettings->ServerEndpoint) +
                 "/board-settings" +
                 "?mac_address=" + get_mac_address_str();

    if (!http.begin(url.c_str()))
    {
        LOG("HTTP", "Invalid server URL: %s", url.c_str());
        return false;
    }

    add_board_token(http);
    int httpResponseCode = http.GET();

    bool success = (httpResponseCode >= 200 && httpResponseCode < 300);
    if (httpResponseCode == 200)
    {
        String payload = http.getString();
        JsonDocument doc;
        DeserializationError error = deserializeJson(doc, payload);

        BoardSettings updated = *g_boardSettings;
        updated.ScansPerSend = doc["scans_per_send"] | g_boardSettings->ScansPerSend;
        updated.WifiScanTimeMS = doc["wifi_scan_time_ms"] | g_boardSettings->WifiScanTimeMS;
        updated.BluetoothScanTimeMS = doc["bluetooth_scan_time_ms"] | g_boardSettings->BluetoothScanTimeMS;
        updated.WifiChannelScanTimeMS = doc["wifi_channel_scan_time_ms"] | g_boardSettings->WifiChannelScanTimeMS;
        updated.MinimalEncounterCount = doc["minimal_encounter_count"] | g_boardSettings->MinimalEncounterCount;
        updated.minRSSI = doc["min_rssi"] | g_boardSettings->minRSSI;
        updated.minRSSIBLE = doc["min_rssi_ble"] | g_boardSettings->minRSSIBLE;

        // Settings now survive a reboot, so a bad value must never be accepted
        if (!error && updated.tunablesInBounds())
        {
            *g_boardSettings = updated;
            g_boardSettings->saveTunables();
            LOG("CONF", "scans=%u wifi=%ums ble=%ums channel=%ums min_encounters=%u rssi=%d rssi_ble=%d",
                updated.ScansPerSend, updated.WifiScanTimeMS, updated.BluetoothScanTimeMS,
                updated.WifiChannelScanTimeMS, updated.MinimalEncounterCount, updated.minRSSI, updated.minRSSIBLE);
        }
        else
        {
            LOG("CONF", "Settings from server are invalid or out of bounds, keeping the current ones");
        }
    }
    else if (httpResponseCode == 404)
    {
        LOG("CONF", "No settings on the server yet (HTTP %d)", httpResponseCode);
    }
    else
    {
        LOG("CONF", "Failed to download settings (HTTP %d)", httpResponseCode);
    }

    http.end();
    return success;
};

// Asks the server for the latest firmware version and reports the running one.
// Returns true when the server answered, which is the proof that this firmware can reach
// the server and so can still be updated: only then is a freshly installed firmware confirmed.
// When a newer version is published it is installed and the board restarts.
bool check_firmware_update()
{
    HTTPClient http;
    http.setTimeout(10000);

    String url = g_boardSettings->ServerEndpoint +
                 "/firmware/latest" +
                 "?mac_address=" + get_mac_address_str() +
                 "&version=" + String(FIRMWARE_VERSION);

    if (!http.begin(url.c_str()))
    {
        LOG("HTTP", "Invalid server URL: %s", url.c_str());
        return false;
    }

    add_board_token(http);
    int httpResponseCode = http.GET();
    JsonDocument doc;
    // Require our own JSON, a captive portal answering 200 must not count as the server
    bool answered = httpResponseCode == 200 &&
                    !deserializeJson(doc, http.getString()) &&
                    doc["version"].is<long>();
    http.end();

    if (!answered)
    {
        LOG("OTA", "Firmware check failed (HTTP %d)", httpResponseCode);
        return false;
    }

    // No-op unless this firmware was just installed and is still pending verification
    esp_ota_img_states_t state;
    if (esp_ota_get_state_partition(esp_ota_get_running_partition(), &state) == ESP_OK &&
        state == ESP_OTA_IMG_PENDING_VERIFY)
    {
        LOG_BANNER("FIRMWARE v%d CONFIRMED, server reached", FIRMWARE_VERSION);
    }
    esp_ota_mark_app_valid_cancel_rollback();

    const long latestVersion = doc["version"];
    if (latestVersion <= FIRMWARE_VERSION)
    {
        LOG("OTA", "Firmware v%d is up to date", FIRMWARE_VERSION);
        return true;
    }

    // A version that keeps failing (rolled back, corrupt, mislabeled file) must not be
    // re-downloaded and re-flashed every cycle forever.
    Preferences prefs;
    prefs.begin("ota", false);
    int tries = prefs.getLong("version", 0) == latestVersion ? prefs.getInt("tries", 0) : 0;
    if (tries >= OTA_MAX_TRIES)
    {
        prefs.end();
        LOG("OTA", "Firmware v%ld is published but failed %d times, staying on v%d", latestVersion, OTA_MAX_TRIES, FIRMWARE_VERSION);
        return true;
    }
    prefs.putLong("version", latestVersion);
    prefs.putInt("tries", tries + 1);
    prefs.end();

    LOG_BANNER("INSTALLING FIRMWARE v%ld (running v%d, attempt %d of %d)", latestVersion, FIRMWARE_VERSION, tries + 1, OTA_MAX_TRIES);

    // ponytail: the image is only as trustworthy as the connection to ServerEndpoint (use https),
    // switch to signed images / secure boot if the boards ever leave a trusted setup.
    url = g_boardSettings->ServerEndpoint + "/firmware/bin/" + String(latestVersion) + ".bin";
    if (!http.begin(url.c_str()))
    {
        LOG("HTTP", "Invalid server URL: %s", url.c_str());
        return true;
    }

    add_board_token(http);
    httpResponseCode = http.GET();
    const int size = http.getSize();
    LOG("OTA", "Downloading %d bytes, do not power off", size);
    if (httpResponseCode != 200 || size <= 0)
    {
        LOG_BANNER("FIRMWARE UPDATE FAILED: download error (HTTP %d)", httpResponseCode);
        http.end();
        return true;
    }

    // Update.end() verifies the image, so a truncated or corrupt download is never booted
    bool installed = Update.begin(size) &&
                     Update.writeStream(http.getStream()) == (size_t)size &&
                     Update.end();
    http.end();

    if (!installed)
    {
        LOG_BANNER("FIRMWARE UPDATE FAILED: %s", Update.errorString());
        Update.abort();
        return true;
    }

    LOG_BANNER("FIRMWARE v%ld INSTALLED, restarting", latestVersion);
    Serial.flush();
    ESP.restart();
    return true;
};
