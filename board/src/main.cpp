/*
 *  This sketch demonstrates how to scan WiFi networks.
 *  The API is almost the same as with the WiFi Shield library,
 *  the most obvious difference being the different file you need to include:
 */
#include "WiFi.h"
#include <map>
#include <wifi_functions.h>
#include <wifi_buffer/wifi_buffer.h>
#include <board_settings.h>
#include <string.h>
#include <bluetooth_functions.h>
#include <esp_ota_ops.h>
#include "version.h"

ClientsBuffer clientsBuffer;

BoardSettings boardSettings;

#define EXTERNAL_ANTENNA_PIN 14

// How long a provisioned board waits for a "PROVISION {json}" line after boot
#define PROVISIONING_WINDOW_MS 3000
// A freshly updated firmware that cannot reach the server for this many cycles reverts itself
#define MAX_UNCONFIRMED_CYCLES 3

// Arduino core hook: keep a freshly updated firmware in the "pending verify" state instead of
// confirming it at boot. check_firmware_update() confirms it once the server has been reached;
// any reset before that makes the bootloader boot the previous firmware again.
extern "C" bool verifyRollbackLater()
{
    return true;
}

static bool firmware_pending_verify()
{
    esp_ota_img_states_t state;
    return esp_ota_get_state_partition(esp_ota_get_running_partition(), &state) == ESP_OK &&
           state == ESP_OTA_IMG_PENDING_VERIFY;
}

// The only place the provisioning config (WiFi, server endpoint, antenna) can be written.
// Listens for PROVISIONING_WINDOW_MS on a provisioned board and forever on a blank one.
static void provisioning_window()
{
    const unsigned long start = millis();
    unsigned long lastNotice = 0;
    while (!boardSettings.provisioned || millis() - start < PROVISIONING_WINDOW_MS)
    {
        if (!boardSettings.provisioned && millis() - lastNotice > 2000)
        {
            lastNotice = millis();
            digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
            Serial.println("UNPROVISIONED: waiting for config, run provision.py");
        }
        if (!Serial.available())
        {
            delay(10);
            continue;
        }

        String line = Serial.readStringUntil('\n');
        line.trim();
        if (!line.startsWith("PROVISION "))
        {
            continue;
        }

        const char *error = BoardSettings::provision(line.substring(strlen("PROVISION ")));
        if (error)
        {
            Serial.print("PROVISION_ERROR ");
            Serial.println(error);
            continue;
        }

        boardSettings.load();
        Serial.print("PROVISIONED endpoint=");
        Serial.print(boardSettings.ServerEndpoint);
        Serial.print(" ssid=");
        Serial.print(boardSettings.wifiSSID);
        Serial.print(" peap=");
        Serial.print(boardSettings.peap);
        Serial.print(" peap_identity=");
        Serial.print(boardSettings.peapIdentity);
        Serial.print(" external_antenna=");
        Serial.println(boardSettings.externalAntenna);
        Serial.flush();
        delay(500);
        ESP.restart();
    }
}

void setup()
{
    pinMode(LED_BUILTIN, OUTPUT);
    pinMode(EXTERNAL_ANTENNA_PIN, OUTPUT);
    digitalWrite(EXTERNAL_ANTENNA_PIN, LOW); // internal antenna until the stored config says otherwise
    Serial.setRxBufferSize(2048);            // a provisioning line is longer than the default buffer
    Serial.begin(115200);

    boardSettings.load();
    provisioning_window();

    Serial.print("Firmware version: ");
    Serial.println(FIRMWARE_VERSION);

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
        connected = connect_to_wifi_peap(boardSettings.wifiSSID.c_str(), boardSettings.peapIdentity.c_str(), boardSettings.peapUsername.c_str(), boardSettings.peapPassword.c_str());
    }
    else
    {
        connected = connect_to_wifi(boardSettings.wifiSSID.c_str(), boardSettings.wifiPassword.c_str());
    }

    const auto reportedDevices = clientsBuffer.getFilteredClients(boardSettings.MinimalEncounterCount).size();

    bool serverReached = false;
    if (connected)
    {
        send_data_to_server(clientsBuffer);
        Serial.print("Reported devices: ");
        Serial.println(reportedDevices);

        // Confirms this firmware and, when a newer one is published, installs it and restarts
        serverReached = check_firmware_update();
    }
    else
    {
        Serial.println("Skipping upload because WiFi is not connected");
    }

    static uint8_t unconfirmedCycles = 0;
    if (!serverReached && firmware_pending_verify() && ++unconfirmedCycles >= MAX_UNCONFIRMED_CYCLES)
    {
        Serial.println("Updated firmware could not reach the server, rolling back");
        Serial.flush();
        esp_ota_mark_app_invalid_rollback_and_reboot();
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
