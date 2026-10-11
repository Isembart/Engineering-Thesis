#pragma once
#include <Arduino.h>

// Serial output helpers, plain text so they read the same in any serial monitor.
//
//   [WIFI ] Connected to MyNetwork        <- LOG("WIFI", "Connected to %s", ssid)
//
//   ----- Cycle 3 -----                   <- LOG_SECTION("Cycle %lu", n)
//
//   ==================================================
//     INSTALLING FIRMWARE v3              <- LOG_BANNER("INSTALLING FIRMWARE v%ld", v)
//   ==================================================

// Start of a tagged line, for lines that are finished with further Serial.print calls
#define LOG_PREFIX(tag) Serial.printf("[%-5s] ", tag)

#define LOG(tag, ...)               \
    do                              \
    {                               \
        LOG_PREFIX(tag);            \
        Serial.printf(__VA_ARGS__); \
        Serial.println();           \
    } while (0)

// Separates the repeating phases of the main loop
#define LOG_SECTION(...)            \
    do                              \
    {                               \
        Serial.println();           \
        Serial.print("----- ");     \
        Serial.printf(__VA_ARGS__); \
        Serial.println(" -----");   \
    } while (0)

// Rare events that must not be missed: boot, firmware install, rollback
#define LOG_BANNER(...)                                                       \
    do                                                                        \
    {                                                                         \
        Serial.println();                                                     \
        Serial.println("=================================================="); \
        Serial.print("  ");                                                   \
        Serial.printf(__VA_ARGS__);                                           \
        Serial.println();                                                     \
        Serial.println("=================================================="); \
    } while (0)
