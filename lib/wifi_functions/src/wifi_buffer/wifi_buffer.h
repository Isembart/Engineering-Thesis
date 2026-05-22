#pragma once
#include <map>
#include <mutex>
#include <shared_mutex>
#include <WString.h>

class ClientsBuffer
{
private:
    std::map<uint64_t, int> clients;
    std::shared_mutex mutex;

public:
    void addClient(const uint64_t &macAddress);
    std::map<uint64_t, int> getFilteredClients(uint8_t minEncounterCount);
    void printClients();
};