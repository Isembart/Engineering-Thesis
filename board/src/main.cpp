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
#include <board_settings.h>
#include <string.h>
#include <bluetooth_functions.h>

ClientsBuffer clientsBuffer;

BoardSettings boardSettings = BoardSettings::loadDefaultSettings();

#define EXTERNAL_ANTENNA_PIN 14

void setup()
{
    pinMode(LED_BUILTIN, OUTPUT);
    pinMode(EXTERNAL_ANTENNA_PIN, OUTPUT);
    Serial.begin(115200);
    delay(3000);
    // while (!Serial)
    // {
    //     delay(500);
    //     digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
    // }
    Serial.println("Serial connected");

    init_bluetooth_sniffer(&clientsBuffer, &boardSettings);
    init_wifi_sniffer(&clientsBuffer, &boardSettings);

    if (boardSettings.externalAntenna)
    {
        digitalWrite(EXTERNAL_ANTENNA_PIN, HIGH); // Set GPIO14 high to use the external antenna
        Serial.println("External antenna enabled");
    }
}

void loop()
{

    start_wifi_sniffer();

    for (uint8_t scan = 0; scan < boardSettings.ScansPerSend; ++scan)
    {
        int lastDeviceCount = clientsBuffer.getClientCount();
        const unsigned long wifiScanStart = millis();
        while (millis() - wifiScanStart < boardSettings.WifiScanTimeMS)
        {
            delay(boardSettings.WifiChannelScanTimeMS);
            hop_wifi_channel();
        }
        Serial.print("WiFi scan completed, devices seen: ");
        Serial.println(clientsBuffer.getClientCount() - lastDeviceCount);

        scan_bluetooth_devices();
    }

    // SEND DATA
    bool connected = false;
    if (boardSettings.peap)
    {
        connected = connect_to_wifi_peap(boardSettings.wifiSSID, boardSettings.peapIdentity, boardSettings.peapUsername, boardSettings.peapPassword);
    }
    else
    {
        connected = connect_to_wifi(boardSettings.wifiSSID, boardSettings.wifiPassword);
    }

    const auto reportedDevices = clientsBuffer.getFilteredClients(boardSettings.MinimalEncounterCount).size();

    if (connected)
    {
        send_data_to_server(clientsBuffer);
        Serial.print("Reported devices: ");
        Serial.println(reportedDevices);
    }
    else
    {
        Serial.println("Skipping upload because WiFi is not connected");
    }

    clientsBuffer.clear();
    send_settings_to_server();
    get_settings_from_server();

    WiFi.disconnect();
    WiFi.mode(WIFI_OFF);

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
