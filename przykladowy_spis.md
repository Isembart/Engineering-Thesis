# Przykładowy spis treści

Proponowany tytuł: **System oceny względnego obłożenia pomieszczeń oparty na pasywnym nasłuchu WiFi i Bluetooth**


## Wstęp
- Geneza: zadanie „kiedy na siłowni jest najmniej osób?”
- Cel i zakres pracy
- Przyjęte założenie: miara względna zamiast liczby osób
- Struktura pracy

## 1. Analiza problemu i wymagań
1.1. Sformułowanie problemu: trend i porównanie godzin, a nie dokładna liczba
1.2. Użytkownicy systemu: gość, administrator, instytucja
1.3. Wymagania funkcjonalne
1.4. Wymagania niefunkcjonalne: koszt, prywatność, brak ingerencji w budynek, łatwy montaż, zdalne utrzymanie
1.5. Ograniczenia środowiska: brak dostępu do infrastruktury sieciowej instytucji, sieć Eduroam (WPA2-Enterprise)

## 2. Przegląd istniejących rozwiązań
2.1. Rozwiązania komercyjne: Google „Popularne godziny”, systemy kart wejściowych na siłowniach, liczniki osób (np. Xovis), analityka obecności w sieciach WiFi (Cisco Meraki, Aruba)
2.2. Metody pomiaru obecności:
- kamery i wizja komputerowa
- bramki i czujniki na wejściu i wyjściu (IR, laser)
- czujniki PIR, CO₂, termowizja, radar mmWave
- logi punktów dostępowych WiFi
- WiFi CSI
- pasywny nasłuch probe requestów i reklam BLE

2.3. Przegląd literatury o zliczaniu urządzeń i wpływie randomizacji adresów MAC

## 3. Wybór metody pomiaru
3.1. Kryteria porównania
3.2. Tabela porównawcza metod
3.3. Dlaczego nie kamera: RODO, podstawa prawna monitoringu wizyjnego, koszt obliczeń, montaż, akceptacja użytkowników
3.4. Dlaczego nie bramka wejście/wyjście: kilka wejść, błędy kumulujące się w ciągu dnia, ingerencja w budynek, zgoda zarządcy
3.5. Dlaczego nie logi AP: brak dostępu do infrastruktury instytucji
3.6. Świadomie przyjęte ograniczenia nasłuchu: urządzenie to nie osoba, randomizacja MAC, urządzenia stacjonarne, sygnał zza ściany. Właśnie z tego wynika miara względna.

## 4. Architektura systemu
4.1. Komponenty i przepływ danych (płytka, serwer, aplikacja)
4.2. Prywatność wbudowana w projekt: z płytki wychodzi tylko liczba
4.3. Jeden serwer na instytucję, brak kont, dwa tokeny (decyzja i jej konsekwencje)
4.4. Tożsamość płytki: adres MAC, a w bazie osobny klucz zastępczy

## 5. Warstwa sprzętowa
5.1. Kryteria wyboru: tryb promiscuous, BLE, WPA2-Enterprise, cena, rozmiar, złącze anteny
5.2. Porównanie kandydatów: ESP8266, ESP32, ESP32-S3, ESP32-C6, Raspberry Pi Zero 2 W, Pico W, nRF52
5.3. Uzasadnienie wyboru XIAO ESP32-C6
5.4. Antena zewnętrzna i przełącznik RF
5.5. Koszt jednego węzła (zestawienie elementów)

## 6. Oprogramowanie mikrokontrolera
6.1. Wybór frameworka: Arduino i PlatformIO zamiast czystego ESP-IDF
6.2. Cykl pracy: skan, połączenie, wysyłka, rozłączenie, wymuszony tym, że jedno radio nie może naraz nasłuchiwać i być połączone
6.3. Skan WiFi: przeskakiwanie kanałów 1–13, filtrowanie probe requestów, próg RSSI
6.4. Skan BLE
6.5. Haszowanie FNV-1a i próg liczby wykryć (`MinimalEncounterCount`)
6.6. Konfiguracja przez USB i NVS: dlaczego żadnych sekretów w obrazie firmware
6.7. Aktualizacje OTA z automatycznym wycofaniem i wersjonowanie liczbą commitów
6.8. Zdalnie zmieniane ustawienia

## 7. Serwer
7.1. Wybór języka i frameworka: Rust i axum na tle Node, Python/FastAPI, Go
7.2. Baza danych: SQLite zamiast PostgreSQL, SeaORM, migracje
7.3. Projekt API i kontrola dostępu
7.4. Obsługa błędów (np. 409 jako sygnał „ustawienia już istnieją”)
7.5. Czas: dlaczego wszystko w UTC
7.6. Agregacja godzinowa w SQL
7.7. Wdrożenie: VPS, HTTPS, udostępnianie firmware

## 8. Model przewidywania obłożenia
8.1. Ta sama godzina tego samego dnia tygodnia, 1–4 tygodnie wstecz
8.2. Dlaczego prosta statystyka zamiast uczenia maszynowego: mało danych, wyjaśnialność
8.3. Godzina offline to nie zero
8.4. Zmiana czasu (DST)

## 9. Aplikacja kliencka
9.1. Wybór technologii: Flutter na tle aplikacji natywnej, React Native i strony WWW
9.2. Ekrany i tryb gościa / administratora
9.3. Prezentacja danych: wykres z przewidywaniem, mapa cieplna tygodnia, etykieta „bardziej/mniej tłoczno niż zwykle”
9.4. Bezpieczne przechowywanie tokenu i skanowanie kodu QR

## 10. Testy i ewaluacja
10.1. Testy jednostkowe i testy API (Bruno)
10.2. Metodyka weryfikacji w terenie
10.3. Wyniki: korelacja z ręcznymi zliczeniami
10.4. Stabilność: czas pracy, skuteczność OTA, przerwy w łączności
10.5. Wpływ progów RSSI i anteny na wyniki

## 11. Aspekty prawne i etyczne
11.1. Adres MAC jako dana osobowa (RODO)
11.2. Pseudonimizacja a anonimizacja
11.3. Minimalizacja danych w projekcie systemu

## 12. Ewolucja projektu i wnioski
12.1. Przebieg prac na podstawie historii repozytorium
12.2. Decyzje zmienione w trakcie i dlaczego

## Podsumowanie
- Realizacja celów
- Ograniczenia
- Kierunki rozwoju: kalibracja do liczby osób, łączenie danych z kilku płytek w jednym pomieszczeniu, zasilanie bateryjne, ograniczenie surowych liczb do administratora

## Bibliografia, spis rysunków, spis tabel

## Załączniki
- Instrukcja wdrożenia
- Specyfikacja API
- Schemat bazy danych

---

# Co jeszcze warto dodać

1. **Ewaluacja (10.2–10.3).** Recenzent na pewno zapyta, skąd wiadomo, że system działa. Nie trzeba udowadniać liczby osób, wystarczy pokazać, że system dobrze układa godziny od najspokojniejszej do najbardziej tłocznej: kilka sesji ręcznego liczenia i współczynnik korelacji Spearmana.
2. **Zmienione decyzje (12.2).** Historia gita to gotowy materiał. Każdą decyzję opisać krótko: kontekst, decyzja, konsekwencje. Przykłady:
   - przejście z ręcznego schematu bazy na migracje (sierpień)
   - przeniesienie danych do UTC (20.10)
   - usunięcie parametru rozmiaru kubełka
   - wyjęcie `server_endpoint` i sekretów z ustawień trzymanych na serwerze
   - przełącznik RF, bez którego antena zewnętrzna nie działała
3. **Model zagrożeń.** Wyciek tokenu płytki, fałszywa płytka wysyłająca dane, przechwycenie ruchu.
4. **Uczciwy opis prywatności.** FNV-1a nie jest funkcją kryptograficzną, a hash adresu MAC bez soli da się odwrócić, przeglądając wszystkie adresy. Mocny argument jest inny: hashe nigdy nie opuszczają płytki, na serwer trafia tylko liczba. To minimalizacja danych i pseudonimizacja, nie anonimizacja.
5. **Koszt całego systemu** (sprzęt, serwer, czas wdrożenia) w porównaniu z kamerą lub bramką. Wzmacnia rozdział 3.
