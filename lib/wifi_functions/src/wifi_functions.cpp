#include "wifi_functions.h"
#include <esp_wifi.h>
#include <esp_event.h>
#include <esp_netif.h>
#include "wifi_buffer/wifi_buffer.h"
#include <HardwareSerial.h>
#include <stdio.h>

ClientsBuffer clientsBuffer;

void init_wifi_sniffer()
{
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());

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

    Serial.print("Switched to channel: ");
    Serial.println(new_channel);

    clientsBuffer.printClients();
}

void wifi_packet_handler(void *buffer, wifi_promiscuous_pkt_type_t type)
{
    wifi_promiscuous_pkt_t *pkt = (wifi_promiscuous_pkt_t *)buffer;

    if (type != WIFI_PKT_MGMT)
    {
        return; // ignore non-management frames
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

    clientsBuffer.addClient(String(macStr));
}