#pragma once

class ClientsBuffer;
class BoardSettings;

void init_bluetooth_sniffer(ClientsBuffer *clientsBuffer, BoardSettings *boardSettings);
void scan_bluetooth_devices();