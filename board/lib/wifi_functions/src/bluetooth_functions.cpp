#include "bluetooth_functions.h"
#include "wifi_buffer/wifi_buffer.h"
#include <board_settings.h>

#include <BLEDevice.h>
#include <BLEAdvertisedDevice.h>
#include <BLEScan.h>
#include <crypto_functions.h>
#include "log.h"

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
  LOG("BLE", "Scanning for %u s", (unsigned)scanDuration);

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

      // hash the address like the WiFi path does, so no raw MAC is stored
      g_clientsBuffer->addClient(hash_64_fnv1a(addressBytes, 6));
      devicesCounted++;
    }

    LOG("BLE", "Scan done: %d devices seen, %d counted (RSSI >= %d)",
        scanResults->getCount(), devicesCounted, g_boardSettings->minRSSIBLE);
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