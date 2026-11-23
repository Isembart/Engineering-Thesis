# App redesign: build plan

## Decisions

- Audience: students at an institution (university) checking a cafeteria, library, study space or gym on their phone. The one question the app answers is "should I go there now?". Admins come second.
- Phone only (Android tested, iOS untested, Linux build only for testing on a PC). Light mode only. UI in Polish only.
- Scope: new look and new layout inside the existing screens. Same screens, same navigation, same API calls. `ApiService` and the models stay as they are. The only logic change is the offline state (step 2).
- No new pub packages. `flutter_localizations` ships with the SDK.
- Direction: **campus signage**. Each place gets a solid status block that reads at a glance. The status color is the one bold element; everything else stays quiet: flat white panels on a cool grey background, no shadows, no gradients, small radii.
- The status leads, the count comes second as a whole number. With no history (no prediction), the count leads instead.
- Offline (nothing in the last 15 min) is its own state, never shown as 0.

## Tokens

**File (new):** `lib/theme.dart`. Every screen takes its colors, text styles and spacing from here. No hard-coded colors anywhere else.

| Name | Hex | Use |
| --- | --- | --- |
| `bg` | `#EFF4FF` | screen background |
| `panel` | `#FFFFFF` | cards, chart, heatmap |
| `ink` | `#17202B` | text, actual line in the chart |
| `muted` | `#5E6A7A` | secondary text, axis labels |
| `line` | `#D5DBE2` | borders, grid |
| `quieter` | `#2B6FD6` | "Luźniej niż zwykle" block (white text) |
| `usual` | `#DCE1E7` | "Jak zwykle" block (ink text) |
| `busier` | `#F0782E` | "Tłoczniej niż zwykle" block (ink text, check contrast) |
| `offline` | `#C5CBD3` + diagonal hatch | "Brak sygnału" block |

Heatmap ramp: `#E4E8ED` to `ink`. It's neutral on purpose, because blue already means "quieter".

Type: **Archivo** (via `google_fonts`, already installed). Place names in 800 weight with slight negative tracking; status words in 700; body text in 400/500; every number with `FontFeature.tabularFigures()`. Sentence case everywhere, no all-caps labels.

Radii: panels 6, buttons and inputs 6, status block 0 (it runs the full width of its panel). No shadows.

Wide screens (the Linux build): content sits in a centered column, max 560 px.

## Copy (Polish)

- Statuses: "Luźniej niż zwykle", "Jak zwykle", "Tłoczniej niż zwykle".
- Count: "ok. 8 osób" with correct plurals (1 osoba, 2–4 osoby, 5+ osób, 22–24 osoby), using `Intl.plural` with locale `pl`.
- Range: "zwykle 7–13 o tej porze".
- Offline: "Brak sygnału", with "czujnik milczy od ponad 15 min" underneath.
- No history: the count becomes the big text in a neutral block, with "jeszcze uczymy się tego miejsca" underneath.
- Error: "Nie udało się połączyć z serwerem." plus a "Spróbuj ponownie" button.
- Empty list: "Na tym serwerze nie ma jeszcze żadnych miejsc."
- Dates: Polish ("środa, 28 paź"), weeks start on Monday.

## 1. Theme, locale, app shell
**File:** [main.dart](lib/main.dart)
- Use the theme from `lib/theme.dart`.
- Set `locale: Locale('pl')`, add `flutter_localizations` delegates and call `initializeDateFormatting('pl')` before `runApp`.
- No app title shown anywhere.

## 2. Offline state
**File:** [data_aggregator.dart](lib/services/data_aggregator.dart)
- `getCurrentCrowdLevel` returns `double?`: `null` when there are no records.
- Update its two callers (board card, details screen).

## 3. Status block
**File (new):** `lib/widgets/status_block.dart`. It replaces [crowd_comparison_row.dart](lib/widgets/crowd_comparison_row.dart), which gets deleted.
- Input: current count (`double?`) and the hour's `HourPrediction?`. Four states: quieter, usual, busier, offline, plus the no-history variant.
- A `large` flag for the details screen.
- The color change animates (`AnimatedContainer`, 200 ms, ease-out) when a refresh changes the status.

## 4. Home screen
**Files:** [home_screen.dart](lib/screens/home_screen.dart), [board_card.dart](lib/widgets/board_card.dart)
- No `AppBar`. At the top: the day and time, large ("środa, 14:20"), plus a small gear icon that opens settings.
- Refresh only by pulling down. The refresh button goes.
- Card: place name, status block, count and usual range. The firmware line stays admin-only.
- Offline places move to the bottom and are greyed out. Sort after the cards' data has loaded.
- Loading: grey placeholder shapes that fade into the content (`AnimatedSwitcher`), replacing the spinner over a dimmed screen.
- Pressing a card scales it to 0.98 (120 ms).

## 5. Details screen
**File:** [details_screen.dart](lib/screens/details_screen.dart)
- Slim top bar with only a back arrow. Rename and board settings go into a "⋮" menu that is built only in admin mode.
- Order: place name, large status block, "Dziś" (chart), "Typowy tydzień" (heatmap).
- Date navigation: ‹ date ›; tapping the date opens the picker. The timeframe dropdown becomes a two-option `SegmentedButton`: "6–23" or "Cała doba".
- Delete `_MondayFirstLocalizations` / `_MondayFirstDelegate`; the Polish locale already starts weeks on Monday.
- Chart: `isCurved: false`, a dot on each hour, the actual line in `ink`, the typical range as a light band, the usual line dashed in `muted`, a vertical "now" marker when the day is today. Y-axis labels only at grid lines, so the top label no longer overlaps. `fl_chart`'s built-in transition (about 250 ms) when the day changes.

## 6. Week heatmap
**File:** [week_heatmap.dart](lib/widgets/week_heatmap.dart)
- Flip it: 7 day columns (pn–nd), hours run down the rows.
- Neutral ramp from `#E4E8ED` to `ink`, scaled from 0 to the week's highest value.
- Outline the current hour.
- Tapping a cell shows its value (tooltip on tap instead of long press).

## 7. Settings, admin access, board settings
**Files:** [settings_screen.dart](lib/screens/settings_screen.dart), [admin_access_screen.dart](lib/screens/admin_access_screen.dart), [board_settings_screen.dart](lib/screens/board_settings_screen.dart)
- The theme handles colors, type and input styles. Translate all text to Polish. Layouts stay the same.

## 8. Tests
**File:** [widget_test.dart](test/widget_test.dart)
- "app starts": stop looking for "Crowdness Tracker".
- Admin controls: check that the "⋮" menu exists only in admin mode.
- Run `flutter analyze` and `flutter test`, then screenshot every screen on Linux against the deployed server.

## Out of scope

- Upcoming hours on the home cards (they're on the details screen).
- Dark mode, English text.
- Bundling the font files (`google_fonts` downloads them at runtime, as now).
- The dead `Place` / `PlaceCard` / `MockDataService` code.
