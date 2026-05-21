#include "wifi_buffer.h"
#include <HardwareSerial.h>

void ClientsBuffer::addClient(const uint64_t &macAddress)
{
    std::unique_lock lock(mutex);
    clients[macAddress]++;
}

void ClientsBuffer::printClients()
{
    std::shared_lock lock(mutex);
    for (const auto &[mac, count] : clients)
    {
        Serial.print(mac);
        Serial.print(": ");
        Serial.println(count);
    }
}