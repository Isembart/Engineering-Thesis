#include "wifi_functions.h"
#include <esp_wifi.h>
#include <WiFi.h>
#include "wifi_buffer/wifi_buffer.h"
#include <HardwareSerial.h>

ClientsBuffer clientsBuffer;

void init_wifi_sniffer()
{
    // Arduino WiFi.mode() already initializes the driver, so we avoid manual esp_wifi_init().
    // Force STA + fixed channel before re-enabling promiscuous mode for stable hopping.
    WiFi.mode(WIFI_MODE_STA);
    WiFi.disconnect(true, false);

    esp_wifi_set_promiscuous(false);

    wifi_promiscuous_filter_t filter;
    filter.filter_mask = WIFI_PROMIS_FILTER_MASK_MGMT;
    esp_wifi_set_promiscuous_filter(&filter);

    esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);

    esp_wifi_set_promiscuous_rx_cb(wifi_packet_handler);
    esp_wifi_set_promiscuous(true);
}

void hop_wifi_channel()
{
    uint8_t current_channel;
    if (esp_wifi_get_channel(&current_channel, nullptr) != ESP_OK)
    {
        Serial.println("Failed to read current WiFi channel");
        return;
    }

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

    Serial.print("Switched to channel: ");
    Serial.println(new_channel);

    clientsBuffer.printClients();
}

void wifi_packet_handler(void *buffer, wifi_promiscuous_pkt_type_t type)
{
    wifi_promiscuous_pkt_t *pkt = (wifi_promiscuous_pkt_t *)buffer;

    if (type != WIFI_PKT_MGMT)
    {
        Serial.println("Received non-management packet, ignoring.");
        return;
    }

    String macAddress = String(pkt->payload + 10, 6); // Extract source MAC address from the packet
    String macAddressStr = String(macAddress[0], HEX) + ":" + String(macAddress[1], HEX) + ":" + String(macAddress[2], HEX) + ":" +
                           String(macAddress[3], HEX) + ":" + String(macAddress[4], HEX) + ":" + String(macAddress[5], HEX);
    clientsBuffer.addClient(macAddressStr);
}