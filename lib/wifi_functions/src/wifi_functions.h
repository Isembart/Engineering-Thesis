#pragma once
#include <esp_wifi_types_generic.h>

class ClientsBuffer;

void init_wifi_sniffer(ClientsBuffer *clientsBuffer);
void hop_wifi_channel();

void wifi_packet_handler(void *buffer, wifi_promiscuous_pkt_type_t type);
