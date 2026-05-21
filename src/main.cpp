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

const char *ssid = "Rzeznia nr 7";
const char *password = "TVGRWUD57DJF";
const uint8_t NUMBER_OF_SWEEPS = 13;
const unsigned long CHANNEL_SCAN_TIME = 250;

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

    init_wifi_sniffer();
    Serial.println("Promiscuous sniffer started");
}

void loop()
{
    for (uint8_t sweep = 0; sweep < NUMBER_OF_SWEEPS; ++sweep)
    {
        delay(CHANNEL_SCAN_TIME);
        hop_wifi_channel();
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
