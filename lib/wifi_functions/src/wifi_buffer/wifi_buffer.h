#pragma once
#include <map>
#include <mutex>
#include <shared_mutex>
#include <WString.h>

#define MAC_TYPE String

class ClientsBuffer
{
private:
    // std::map<uint64_t, int> clients;
    std::map<MAC_TYPE, int> clients;
    std::shared_mutex mutex;

public:
    void addClient(const MAC_TYPE &macAddress);
    std::map<MAC_TYPE, int> getFilteredClients(uint8_t minEncounterCount);
    void printClients();
};