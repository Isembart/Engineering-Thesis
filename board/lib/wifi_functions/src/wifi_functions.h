#pragma once

class ClientsBuffer;
class BoardSettings;

#include <esp_wifi_types_generic.h> //promisc mode callback function type

void init_wifi_sniffer(ClientsBuffer *clientsBuffer, BoardSettings *boardSettings);
void start_wifi_sniffer();

void hop_wifi_channel();

bool connect_to_wifi(const char *ssid, const char *password);
bool connect_to_wifi_peap(const char *ssid, const char *identity, const char *username, const char *password);

bool send_data_to_server(ClientsBuffer &clientsBuffer);
void wifi_packet_handler(void *buffer, wifi_promiscuous_pkt_type_t type);

uint64_t convert_mac_bytes_to_int(const uint8_t *macBytes);
uint64_t get_mac_address();

bool send_settings_to_server();
bool get_settings_from_server();
