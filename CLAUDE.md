# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Engineering thesis: a system estimating how many people are in a room by passively sniffing WiFi and Bluetooth. Three independent projects in one repo, with no shared build:

- `board/` — ESP32 firmware (PlatformIO, Arduino framework, Seeed Studio XIAO ESP32-C6)
- `server/` — Rust HTTP API (axum 0.8 + SeaORM 2.0 + SQLite)
- `app/` — Flutter client (`crowdness_app`)

`README.md` is in Polish and encoded as **UTF-16 LE with CRLF** — keep that encoding when editing it (plain `cat`/grep output looks garbled; use `iconv -f UTF-16`).

## Commands

Run each from its own subdirectory.

### server/
```sh
cp .env.example .env        # DATABASE_URL, SERVER_ADDRESS, ADMIN_TOKEN, BOARD_TOKEN, optional CORS_ORIGINS
cargo run                   # runs pending migrations on startup, then serves
cargo check
cargo test                  # a few unit tests next to the code they cover
```
- The server refuses to start without `ADMIN_TOKEN` and `BOARD_TOKEN` (32+ characters each, `openssl rand -base64 32`). On every start it prints the admin token as text and as a QR code.
- API requests live in `server/EngineeringThesis - API tests/` as a Bruno (OpenCollection YAML) collection; its `local` environment points `host` at the deployed server `https://inzynierka.bieda.it`, not localhost, and has empty `admin_token` / `board_token` variables to fill in locally (do not commit real tokens).
- New migration: `cd migration && cargo run -- generate NAME`, then register it in `migration/src/lib.rs`. Other migrator subcommands (`up`, `down`, `fresh`, `status`) are in `migration/README.md`.
- `./generate_model.sh` regenerates `src/model/*` from the live database with `sea-orm-cli` — those files are generated, so change the schema via a migration and regenerate rather than hand-editing.

### board/
```sh
pio run                                # build
pio run -t upload                      # build + flash
pio device monitor                     # serial, 115200 baud
~/.platformio/penv/bin/python provision.py provision/<place>.json [port]   # write a board's config over USB
```
- Nothing secret is compiled in. WiFi credentials, the server endpoint, the board token and the antenna choice are written over USB serial by `provision.py` (see `provision/example.json`; other files there are gitignored) and stored in NVS. A board missing any of endpoint, SSID or token waits for provisioning and does not run.
- Setting `external_antenna` to true without an antenna physically attached can damage the board.
- `peap: true` switches to WPA2-Enterprise (Eduroam) instead of plain WPA2.

### app/
```sh
flutter pub get
flutter run
flutter analyze                         # flutter_lints
flutter test                            # all tests
flutter test test/widget_test.dart      # single file
flutter test --plain-name 'app starts'  # single test
```
The server URL has a compiled default (`ApiService._defaultUrl`) and can be changed in the in-app settings screen; it is stored in `shared_preferences`. The Linux desktop build needs `libsecret-devel` (for `flutter_secure_storage`), and QR scanning exists only on Android and iOS.

## Architecture

### Data flow

1. **Board** (`board/src/main.cpp` `loop()`): promiscuous WiFi sniffing while hopping channels 1–13, then a passive BLE scan, repeated `ScansPerSend` times. Every device seen goes into `ClientsBuffer` (map of id → encounter count). Then it leaves promiscuous mode, joins WiFi as a station, and POSTs one number — the count of devices seen at least `MinimalEncounterCount` times — to `/upload-board-data`. It then pushes its settings (`POST /board-settings`), pulls settings (`GET /board-settings`), clears the buffer and turns WiFi off. The radio cannot sniff and be connected at once, which is why the loop is strictly scan → connect → send → disconnect.
2. **Server** stores one `board_data_records` row per upload, timestamped on arrival in UTC (`+00:00`). Timestamps are TEXT in SQLite and the `start`/`end` filters compare them as strings, so every row must use the same offset; the app converts to local time for display.
3. **App** lists boards, charts `/get-board-data` against `/get-board-prediction` (typical range + usual count, a week heatmap, and a busier/quieter-than-usual label), renames boards and edits their settings. Domain terms are in `GLOSSARY.md`.

Only counts leave the board. WiFi source MACs (probe requests only, above `minRSSI`) and BLE addresses (above `minRSSIBLE`) are hashed with FNV-1a 64 (`crypto_functions.h`) before being stored in the buffer.

### Access control

One server serves one institution; servers know nothing about each other and there are no user accounts. Two shared secrets from the server's `.env` are sent as `Authorization: Bearer <token>` and checked in `server/src/auth.rs`; `routes/mod.rs` groups routes by who may call them:

- **Guest (no token):** `GET /get-all-boards`, `/get-board`, `/get-board-data`, `/get-board-prediction`.
- **Admin token:** `PUT /rename-board`, `PUT /board-settings` (also creates missing settings).
- **Board token:** `POST /upload-board-data`, `POST /board-settings`, `/firmware/*`.
- **Either token:** `GET /board-settings`.

A missing or wrong token is 401. The app is in admin mode only while it holds a token the current server accepted (`ApiService.isAdmin`, token in `flutter_secure_storage`, entered or scanned in Settings → Admin access). It drops the token when the server URL changes or an admin request returns 401. In guest mode the rename and board-settings buttons are not built at all; that is cosmetic, the server is what enforces the split.

### Board identity

A board is identified everywhere by its WiFi STA MAC packed into an integer and sent as a decimal number (`mac_address`, `i64` on the server, `int` in Dart). The database uses a separate surrogate `boards.id`; `board_data_records.board_id` and `board_settings.board_id` reference that, not the MAC. `/upload-board-data` auto-creates an unnamed board on first contact.

### Server layering

`routes/*` (axum handlers + request DTOs) → `model_operations/*` (SeaORM queries) → `model/*` (generated entities). `routes/mod.rs` is the full route table. Handlers return `Result<Json<_>, AppError>`; `error.rs` maps `DbErr` to HTTP status, and notably maps **every `DbErr::Query` to 409 Conflict** — the board firmware relies on 409 from `POST /board-settings` to mean "settings already exist".

`/get-board-data` buckets in SQL (`board_data_records_operations.rs`) using raw `strftime` expressions, so it is SQLite-specific. Buckets are a fixed 1 hour (`start`/`end` filter raw rows before bucketing), epoch-aligned and returned as UTC; the app (`DataAggregator`) re-derives the same epoch-aligned boundaries and marks hours with no row as offline (null, drawn as a gap in the line; 0 means an empty room), so the two must stay aligned.

### Board settings span four places

A settings field exists in: the migration + `model/board_settings.rs`, `BoardSettingsDTO` in `routes/board_settings_routes.rs`, the firmware (`BoardSettings` class and the JSON (de)serialization in `wifi_functions.cpp`), and `app/lib/models/board_settings.dart`. JSON keys are snake_case with an `_ms` suffix for durations. WiFi credentials, PEAP, antenna, `ServerEndpoint` and the board token are deliberately board-only (provisioning config in NVS) and never sent to the server as settings. The tunable defaults live in the `BoardSettings` class, not in a config header.

### Dead code

`server/src/routes/example_route.rs` (not declared in `routes/mod.rs`) and the app's `Place` / `PlaceCard` / `MockDataService` are leftovers not wired into anything.
