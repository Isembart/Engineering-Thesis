/*
 *  This sketch demonstrates how to scan WiFi networks.
 *  The API is almost the same as with the WiFi Shield library,
 *  the most obvious difference being the different file you need to include:
 */
#include "WiFi.h"
#include <map>
#include <shared_mutex>
#include <mutex>
#include <wifi_functions.h>
#include <wifi_buffer/wifi_buffer.h>

const char *ssid = "Rzeznia nr 7";
const char *password = "TVGRWUD57DJF";
const uint8_t NUMBER_OF_SWEEPS = 13;
const unsigned long CHANNEL_SCAN_TIME = 250;

ClientsBuffer clientsBuffer;

void setup()
{
    pinMode(LED_BUILTIN, OUTPUT);
    Serial.begin(115200);
    while (!Serial)
    {
        delay(500);
        digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
    }
    Serial.println("Serial connected");

***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***
***REMOVED***

    init_wifi_sniffer(&clientsBuffer);
    Serial.println("Promiscuous sniffer started");
}

void loop()
{
    for (uint8_t sweep = 0; sweep < NUMBER_OF_SWEEPS; ++sweep)
    {
        for (uint8_t i = 0; i < 13; i++)
        {
            delay(CHANNEL_SCAN_TIME);
            hop_wifi_channel();
        }
    }

    Serial.println("Filtered clients:");
    for (const auto &[mac, count] : clientsBuffer.getFilteredClients(3))
    {
        Serial.print(mac);
        Serial.print(": ");
        Serial.println(count);
    }

    // hop thruogh every channel and sniff packets
    // for every packet:
    //    hash its mac address and store it in a hashmap
    // after set time has passed switch to bluetooth scanning and do the same storing logic

    // bluetooth scan:
    // do the same as wifi but for bluetooth

    // repeat the process for a set amount of time

    // send data:
    // switch to wifi sattion mode and connect to the network
    // send the data to the server
}
