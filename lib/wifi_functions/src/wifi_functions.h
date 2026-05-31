#pragma once
#include <esp_wifi_types_generic.h>

class ClientsBuffer;

void init_wifi_sniffer(ClientsBuffer *clientsBuffer);
void hop_wifi_channel();
bool connect_to_wifi(const char *ssid, const char *password);
bool connect_to_wifi_peap(const char *ssid, const char *identity, const char *username, const char *password);
bool send_data_to_server(const char *url, ClientsBuffer &clientsBuffer);

void wifi_packet_handler(void *buffer, wifi_promiscuous_pkt_type_t type);
