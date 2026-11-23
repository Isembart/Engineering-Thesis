# Prediction endpoint: build plan

## Decisions

- New guest endpoint `GET /get-board-prediction?mac_address&start&end`. Access will be revisited later, when the actual counts become admin-only.
- For each hour, the prediction looks at the **same hour on the same weekday, 1–4 weeks back**. The current day is never included.
- Statistics: take each week's hourly average (the existing 1 h buckets), then compute min, max and mean over those (up to 4 values).
- Missing weeks are skipped, never counted as 0: an empty room uploads `0`, so a missing bucket means the board was offline.
- `samples` (0–4) per hour tells the frontend how many weeks went into it. The frontend decides what counts as "still learning".
- Storage, buckets and the API stay in UTC. Only the lookback uses `chrono::Local` (the server OS's timezone), so "same hour last week" survives DST changes. There's no config variable.
- Validation: `start` and `end` are required, `start` is floored to the hour, `end` is exclusive, the range is at most 31 days (otherwise 400), and an unknown board returns 404.
- The response has one entry for every hour in [start, end), including hours with `samples == 0`.
- The app is out of scope. It gets adapted to this JSON later.

## 0. Check the server's timezone
Run `timedatectl` on the Finland box. It should print `Europe/Helsinki`. If it prints `UTC`, the feature still works, just without DST correction.

## 1. Response type
**File:** [board_data_records_operations.rs](src/model_operations/board_data_records_operations.rs)

Add a struct `HourPrediction` deriving `Serialize`, with these fields:
- `timestamp`: `DateTime<Utc>`
- `samples`: `u8`
- `mean`: `Option<f64>`
- `min`: `Option<i64>`
- `max`: `Option<i64>`

## 2. Lookback helper
**Same file.** Write `weeks_ago(t: DateTime<Utc>, weeks: u64) -> Option<DateTime<Utc>>`:
1. Convert with `t.with_timezone(&Local)`, then take `.naive_local()`.
2. Subtract with `.checked_sub_days(Days::new(7 * weeks))`.
3. Go back to an aware time with `Local.from_local_datetime(&naive).single()`. This returns `None` when the local time doesn't exist or happens twice (the 02:00–03:00 hour on DST nights). Return `None` in that case and the week gets skipped.
4. Convert with `.with_timezone(&Utc)`.

Add a `// ponytail:` comment saying it assumes the server's OS timezone has the same DST rules as the rooms, and that the upgrade path is a `TIMEZONE` env var plus `chrono-tz`.

## 3. Pure `predict` function
**Same file.** Write `predict(buckets: &HashMap<i64, i64>, start: DateTime<Utc>, end: DateTime<Utc>) -> Vec<HourPrediction>`.
- The map key is the bucket's epoch seconds (`.timestamp()`) and the value is `clients_count`. An `i64` key avoids any offset-equality surprises.
- Loop `t` from `start` while `t < end`, adding `TimeDelta::hours(1)` each step.
- For `k in 1..=4`, call `weeks_ago(t, k)` and look up `.timestamp()` in the map. Collect the values that exist into a small `Vec`. That's where missing weeks get skipped.
- Then set:
  - `samples = vec.len()`
  - `min` and `max` from `iter().min()` / `.max()`, which already return `Option`
  - `mean = sum as f64 / len`, only when `len > 0`; otherwise `None`.

## 4. DB wrapper
**Same file.** Write `async fn get_board_prediction(board_id, start: DateTime<Utc>, end: DateTime<Utc>, db) -> Result<Vec<HourPrediction>, DbErr>`:
- Call the existing `get_board_data_records_bucketed` with:
  - `start - 28 days - 1 hour`. The extra hour covers a DST shift.
  - `end - 1 second`, because that function's `end` is inclusive (`lte`).
  - Both converted with `.fixed_offset()`.
- Build the HashMap from the records (`rec.timestamp.timestamp()` → `rec.clients_count`), then return `predict(...)`.

## 5. Route handler
**File:** [board_routes.rs](src/routes/board_routes.rs)
- Add a `GetBoardPredictionRequest` struct: `mac_address: i64`, `start` and `end` as `DateTime<FixedOffset>`, **not** `Option`. Axum's `Query` then returns 400 by itself when they're missing.
- In the handler:
  1. Convert both to `Utc`.
  2. Floor `start` to the hour with `.duration_trunc(TimeDelta::hours(1))`, which needs the `chrono::DurationRound` trait.
  3. Validate: if `end <= start` or `end - start > TimeDelta::days(31)`, return `AppError::BadRequest`.
  4. Look up the board the same way `get_board_data` does, returning `NotFound` if it's missing.
  5. Call the operation and return `Json(Vec<HourPrediction>)`.

## 6. Register the route
**File:** [routes/mod.rs](src/routes/mod.rs). Add `.route("/get-board-prediction", get(...))` to the `guest` group.

## 7. Unit tests
**Location:** a `#[cfg(test)] mod tests` block at the bottom of the operations file. Use **July dates**, so no DST change falls inside the 4-week window whatever the machine's timezone. Write these cases:
- **All 4 weeks present:** data at the same hour 1–4 weeks back. Expect `samples == 4` with the correct min, max and mean.
- **One week missing:** expect `samples == 3` with stats over 3 values.
- **No data:** expect `samples == 0` and every stat `None`.
- **No leakage:** data at the same hour but 1 day back, or 1 hour off, must not be counted.
- **Shape:** a 24 h range gives 24 entries, hour-aligned and ascending.

**DST check, done by hand:** pick a bucket the week after 25.10.2026 and run `TZ=Europe/Warsaw cargo test` with a case expecting the lookback to land 1 UTC hour later. If that test only passes with `TZ` set, mark it `#[ignore]` with a note on how to run it.

## 8. Finishing touches
- Add a request to the Bruno collection (`EngineeringThesis - API tests/`) with no token, since it's a guest route.
- Add `/get-board-prediction` to the guest list in `CLAUDE.md`.
- Run `cargo check` and `cargo test`.
