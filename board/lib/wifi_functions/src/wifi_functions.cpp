#include "wifi_functions.h"
#include <Arduino.h>
#include <WiFi.h>
#include <esp_wifi.h>
#include <esp_event.h>
#include <esp_netif.h>
#include <esp_http_client.h>
#include <esp_wpa2.h>
#include <esp_mac.h>
#include "config.h"
#include "wifi_buffer/wifi_buffer.h"
#include <HardwareSerial.h>
#include <stdio.h>
#include <crypto_functions.h>
#include <HTTPClient.h>

namespace
{
    ClientsBuffer *g_clientsBuffer = nullptr;
    bool g_wifiInitialized = false;
}

void init_wifi_sniffer(ClientsBuffer *clientsBuffer)
{
    g_clientsBuffer = clientsBuffer;

    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    delay(100);

    // if (!g_wifiInitialized)
    // {
    //     ESP_ERROR_CHECK(esp_netif_init());
    //     ESP_ERROR_CHECK(esp_event_loop_create_default());

    //     wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    //     ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    //     ESP_ERROR_CHECK(esp_wifi_start());

    //     g_wifiInitialized = true;
    // }
    // ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));

    ESP_ERROR_CHECK(esp_wifi_set_promiscuous(false));

    wifi_promiscuous_filter_t filter;
    filter.filter_mask = WIFI_PROMIS_FILTER_MASK_MGMT;
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous_filter(&filter));

    ESP_ERROR_CHECK(esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE));
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous_rx_cb(wifi_packet_handler));
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous(true));
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
        Serial.print("Failed to switch WiFi channel, err=");
        Serial.println((int)set_channel_result);
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

    if (pkt->rx_ctrl.rssi < -75)
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

    uint8_t *src_mac = payload + 10; // source MAC is at offset 10 in management frames
    char macStr[18];
    sprintf(macStr, "%02X:%02X:%02X:%02X:%02X:%02X",
            src_mac[0], src_mac[1], src_mac[2], src_mac[3], src_mac[4], src_mac[5]);

    uint64_t macHash = hash_64_fnv1a(src_mac, 6);
    // delete the stack declared macStr to save memory, we only need the hash for tracking
    memset(macStr, 0, sizeof(macStr));

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
    Serial.print(F("Connecting to WiFi .."));
    WiFi.begin(ssid, password);
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
        Serial.print(F("Connected to "));
        Serial.println(ssid);
        return true;
    }

    Serial.println(F("WiFi connection timed out"));
    return false;
}

bool connect_to_wifi_peap(const char *ssid, const char *identity, const char *username, const char *password)
{
    ESP_ERROR_CHECK(esp_wifi_set_promiscuous(false));
    esp_wifi_set_promiscuous_rx_cb(NULL);
    WiFi.disconnect(false);
    WiFi.mode(WIFI_STA);
    Serial.print(F("Connecting to PEAP WiFi .."));
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
        Serial.print(F("Connected to "));
        Serial.println(ssid);
        return true;
    }

    Serial.println(F("WiFi connection timed out"));
    return false;
}

// bool send_data_to_server(const char *url, ClientsBuffer &clientsBuffer)
// {
//     const auto filteredClients = clientsBuffer.getFilteredClients(MINIMAL_ENCOUNTER_COUNT);
//     uint8_t macBytes[6];
//     esp_read_mac(macBytes, ESP_MAC_WIFI_STA);

//     uint64_t macAddressValue = 0;
//     for (uint8_t i = 0; i < 6; ++i)
//     {
//         macAddressValue = (macAddressValue << 8) | macBytes[i];
//     }

//     char macAddress[21];
//     snprintf(macAddress, sizeof(macAddress), "%llu", (unsigned long long)macAddressValue);

//     String jsonBody = String("{\"mac_address\":") + macAddress + String(",\"clients_count\":") + String(filteredClients.size()) + String("}");

//     esp_http_client_config_t config = {
//         .url = url,
//         .method = HTTP_METHOD_POST,
//     };

//     esp_http_client_handle_t client = esp_http_client_init(&config);
//     if (client == nullptr)
//     {
//         Serial.println("Failed to initialize HTTP client");
//         return false;
//     }

//     esp_http_client_set_header(client, "Content-Type", "application/json");
//     esp_http_client_set_post_field(client, jsonBody.c_str(), jsonBody.length());

//     esp_err_t result = esp_http_client_perform(client);
//     bool success = result == ESP_OK && esp_http_client_get_status_code(client) >= 200 && esp_http_client_get_status_code(client) < 300;
//     if (!success)
//     {
//         Serial.print("Failed to send data to server, err=");
//         Serial.println((int)result);
//     }

//     esp_http_client_cleanup(client);
//     return success;
// }

bool send_data_to_server(const char *url, ClientsBuffer &clientsBuffer)
{
    const auto filteredClients = clientsBuffer.getFilteredClients(MINIMAL_ENCOUNTER_COUNT);
    uint8_t macBytes[6];
    esp_read_mac(macBytes, ESP_MAC_WIFI_STA);

    uint64_t macAddressValue = 0;
    for (uint8_t i = 0; i < 6; ++i)
    {
        macAddressValue = (macAddressValue << 8) | macBytes[i];
    }

    char macAddress[21];
    snprintf(macAddress, sizeof(macAddress), "%llu", (unsigned long long)macAddressValue);

    String jsonBody = String("{\"mac_address\":") + macAddress + String(",\"clients_count\":") + String(filteredClients.size()) + String("}");

    // --- Arduino HTTP Client approach ---
    HTTPClient http;

    // Increase timeout to 10 seconds for slow PEAP networks
    http.setTimeout(10000);

    if (!http.begin(url))
    {
        Serial.println("Failed to parse URL");
        return false;
    }

    http.addHeader("Content-Type", "application/json");

    int httpResponseCode = http.POST(jsonBody);
    bool success = (httpResponseCode >= 200 && httpResponseCode < 300);

    if (success)
    {
        Serial.print("Data sent successfully. HTTP Response code: ");
        Serial.println(httpResponseCode);
    }
    else
    {
        Serial.print("Failed to send data to server, HTTP code: ");
        Serial.println(httpResponseCode);
    }

    http.end();
    return success;
}