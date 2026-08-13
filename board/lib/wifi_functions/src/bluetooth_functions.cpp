#include "bluetooth_functions.h"
#include "wifi_buffer/wifi_buffer.h"
#include <board_settings.h>

#include <BLEDevice.h>
#include <BLEAdvertisedDevice.h>
#include <BLEScan.h>
#include "wifi_functions.h"

namespace
{
  ClientsBuffer *g_clientsBuffer = nullptr;
  BoardSettings *g_boardSettings = nullptr;
  BLEScan *g_bleScan = nullptr;
}

void scan_bluetooth_devices()
{
  if (!g_bleScan || !g_boardSettings)
  {
    return;
  }

  const uint32_t durationSeconds = g_boardSettings->BluetoothScanTimeMS / 1000;
  // ensure the minimum scan duration is 1 second
  const uint32_t scanDuration = durationSeconds == 0 ? 1 : durationSeconds;

  g_bleScan->clearResults();
  Serial.print("Starting BLE scan for ");
  Serial.print(scanDuration);
  Serial.println(" seconds");

  BLEScanResults *scanResults = g_bleScan->start(scanDuration, false);
  if (scanResults)
  {
    int devicesCounted = 0;
    for (int i = 0; i < scanResults->getCount(); ++i)
    {
      const String deviceDescription = scanResults->getDevice(i).toString();
      BLEAddress address = scanResults->getDevice(i).getAddress();
      uint8_t *addressBytes = address.getNative();

      // Serial.println("Device description: " + deviceDescription);

      if (scanResults->getDevice(i).getRSSI() < g_boardSettings->minRSSIBLE)
      {
        continue; // Skip devices with RSSI below the threshold
      }

      g_clientsBuffer->addClient(convert_mac_bytes_to_int(addressBytes));
      devicesCounted++;
    }

    Serial.print("BLE scan completed, devices seen: ");
    Serial.print(scanResults->getCount());
    Serial.print(", devices counted (RSSI >= ");
    Serial.print(g_boardSettings->minRSSIBLE);
    Serial.print("): ");
    Serial.println(devicesCounted);
  }

  g_bleScan->clearResults();
}

void init_bluetooth_sniffer(ClientsBuffer *clientsBuffer, BoardSettings *boardSettings)
{
  g_clientsBuffer = clientsBuffer;
  g_boardSettings = boardSettings;

  BLEDevice::init("CrowdMonitor Edge");
  g_bleScan = BLEDevice::getScan();
  g_bleScan->setActiveScan(false);
  g_bleScan->setDuplicateFilter(true);

  return;
}