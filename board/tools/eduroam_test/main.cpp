// Standalone eduroam check: no sniffer, no BLE, just "join, get an IP, reach the server".
// Uses the credentials already provisioned into NVS by provision.py.
//   pio run -e eduroam_test -t upload && pio device monitor
// Flash the normal firmware back afterwards with plain `pio run -t upload`.
#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>

String ssid, identity, username, password, endpoint;
bool externalAntenna;

void setup()
{
    Serial.begin(115200);
    delay(2000); // let USB serial attach

    Preferences prefs;
    prefs.begin("prov", true);
    ssid = prefs.getString("ssid");
    identity = prefs.getString("peap_id");
    username = prefs.getString("peap_user");
    password = prefs.getString("peap_pass");
    endpoint = prefs.getString("endpoint");
    externalAntenna = prefs.getBool("antenna", false);
    prefs.end();

    Serial.printf("\n=== eduroam test ===\nssid=%s identity=%s username=%s password=<%u chars> antenna=%s\n",
                  ssid.c_str(), identity.c_str(), username.c_str(), password.length(),
                  externalAntenna ? "external" : "internal");

    // GPIO3 is already LOW (RF switch on) from the board variant, GPIO14 picks the antenna
    digitalWrite(WIFI_ANT_CONFIG, externalAntenna ? HIGH : LOW);

    WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info)
                 {
        Serial.printf("\n[event %d] %s", event, WiFi.eventName(event));
        if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED)
            Serial.printf(" reason %u (%s)", info.wifi_sta_disconnected.reason,
                          WiFi.disconnectReasonName((wifi_err_reason_t)info.wifi_sta_disconnected.reason));
        Serial.println(); });
}

void loop()
{
    WiFi.mode(WIFI_STA);
    unsigned long start = millis();
    WiFi.begin(ssid.c_str(), WPA2_AUTH_PEAP, identity.c_str(), username.c_str(), password.c_str());

    while (WiFi.status() != WL_CONNECTED && millis() - start < 60000)
    {
        delay(500);
        Serial.print(".");
    }

    if (WiFi.status() == WL_CONNECTED)
    {
        Serial.printf("\nOK after %lu ms: ip=%s gw=%s dns=%s rssi=%d channel=%d\n", millis() - start,
                      WiFi.localIP().toString().c_str(), WiFi.gatewayIP().toString().c_str(),
                      WiFi.dnsIP().toString().c_str(), WiFi.RSSI(), WiFi.channel());
        HTTPClient http;
        http.begin(endpoint + "/get-all-boards");
        Serial.printf("GET %s/get-all-boards -> HTTP %d\n", endpoint.c_str(), http.GET());
        http.end();
    }
    else
    {
        Serial.printf("\nFAILED after 60 s, status=%d, rssi=%d channel=%d\n",
                      WiFi.status(), WiFi.RSSI(), WiFi.channel());
    }

    WiFi.disconnect(true);
    Serial.println("Retrying in 10 s");
    delay(10000);
}
