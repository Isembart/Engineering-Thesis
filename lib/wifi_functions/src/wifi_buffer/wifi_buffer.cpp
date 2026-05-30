#include "wifi_buffer.h"
#include <HardwareSerial.h>

void ClientsBuffer::addClient(const MAC_TYPE &macAddress)
{
    std::unique_lock lock(mutex);
    clients[macAddress]++;
}

std::map<MAC_TYPE, int> ClientsBuffer::getFilteredClients(uint8_t minEncounterCount)
{
    std::unique_lock lock(mutex);
    // std::map<uint64_t, int> filteredClients;
    std::map<MAC_TYPE, int> filteredClients;
    for (const auto &[mac, count] : clients)
    {
        if (count >= minEncounterCount)
        {
            filteredClients[mac] = count;
        }
    }
    return filteredClients;
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