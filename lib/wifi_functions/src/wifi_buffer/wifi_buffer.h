#pragma once
#include <map>
#include <mutex>
#include <shared_mutex>
#include <WString.h>

class ClientsBuffer
{
private:
    std::map<String, int> clients;
    std::shared_mutex mutex;

public:
    void addClient(const String &macAddress);
    void printClients();
};