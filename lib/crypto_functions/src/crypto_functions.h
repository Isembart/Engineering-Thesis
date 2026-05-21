// credit:
// https://gist.github.com/ruby0x1/81308642d0325fd386237cfa3b44785c
#pragma once
#include <cstdint>

inline const uint64_t hash_64_fnv1a(const void *key, const uint64_t len)
{

    const char *data = (char *)key;
    uint64_t hash = 0xcbf29ce484222325;
    uint64_t prime = 0x100000001b3;

    for (int i = 0; i < len; ++i)
    {
        uint8_t value = data[i];
        hash = hash ^ value;
        hash *= prime;
    }

    return hash;

} // hash_64_fnv1a