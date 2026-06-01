/*
 *  This sketch demonstrates how to scan WiFi networks.
 *  The API is almost the same as with the WiFi Shield library,
 *  the most obvious difference being the different file you need to include:
 */
#include "WiFi.h"
#include <map>
#include <wifi_functions.h>
#include <wifi_buffer/wifi_buffer.h>
#include "config.h"

const char *ssid = WIFI_SSID;
const char *password = WIFI_PASSWORD;
const unsigned long WIFI_SCAN_TIME = WIFI_SCAN_TIME_S * 1000UL;
const unsigned long CHANNEL_SCAN_TIME = CHANNEL_SCAN_TIME_MS;

ClientsBuffer clientsBuffer;

void setup()
{
    pinMode(LED_BUILTIN, OUTPUT);
    Serial.begin(115200);
    delay(1000);
    // while (!Serial)
    // {
    //     delay(500);
    //     digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
    // }
    Serial.println("Serial connected");

    if (EXTERNAL_ANTENNA)
    {
        digitalWrite(14, HIGH); // Set GPIO14 high to use the external antenna
        Serial.println("External antenna enabled");
    }

    init_wifi_sniffer(&clientsBuffer);
    Serial.println("Promiscuous sniffer started");
}

void loop()
{
    for (uint8_t scan = 0; scan < SCANS_PER_SEND; ++scan)
    {
        const unsigned long wifiScanStart = millis();
        while (millis() - wifiScanStart < WIFI_SCAN_TIME)
        {
            delay(CHANNEL_SCAN_TIME);
            hop_wifi_channel();
        }
        Serial.println("WiFi scan completed");

        // bluetooth scan will use BLUETOOTH_SCAN_TIME_S here
    }

    // SEND DATA
    bool connected = false;
    if (PEAP)
    {
        connected = connect_to_wifi_peap(WIFI_SSID, PEAP_IDENTITY, PEAP_USERNAME, PEAP_PASSWORD);
    }
    else
    {
        connected = connect_to_wifi(WIFI_SSID, WIFI_PASSWORD);
    }

    const auto reportedDevices = clientsBuffer.getFilteredClients(MINIMAL_ENCOUNTER_COUNT).size();

    if (!connected)
    {
        Serial.println("Skipping upload because WiFi is not connected");
        WiFi.disconnect();
        init_wifi_sniffer(&clientsBuffer);
        return;
    }

    if (send_data_to_server(SERVER_ENDPOINT, clientsBuffer))
    {
        Serial.print("Reported devices: ");
        Serial.println(reportedDevices);
        clientsBuffer.clear();
    }
    else
    {
        Serial.println("Failed to send data to server");
    }

    WiFi.disconnect();
    init_wifi_sniffer(&clientsBuffer);

    // Serial.println("\nFiltered clients:");
    // for (const auto &[mac, count] : clientsBuffer.getFilteredClients(3))
    // {
    //     Serial.print(mac);
    //     Serial.print(": ");
    //     Serial.println(count);
    // }

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
