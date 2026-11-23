# App redesign: what was changed

Log of the redesign done on 2026-10-28/29, so each part can be kept or removed on its own. Nothing is committed: every change is in the working tree on top of commit `df59fc9`. [REDESIGN_PLAN.md](REDESIGN_PLAN.md) holds the original plan; this file describes what was actually built, including the later changes.

## How to undo

- **Everything:** `git checkout -- lib test pubspec.yaml pubspec.lock && git restore --staged --worktree lib/widgets/crowd_comparison_row.dart`, then delete the new files `lib/theme.dart`, `lib/utils/plural.dart`, `lib/widgets/status_block.dart`, `REDESIGN_PLAN.md` and this file.
- **One file:** `git checkout -- <file>`. Most files depend on `lib/theme.dart` and `lib/widgets/status_block.dart`, so if you keep any changed screen, keep those two as well.
- `git diff -- <file>` shows the exact change in any file.

## Behavior changes (not just looks)

These change what the app shows or does, so check them first if something feels off.

1. **Offline is no longer shown as 0.** `DataAggregator.getCurrentCrowdLevel` ([data_aggregator.dart](lib/services/data_aggregator.dart)) returns `double?`: `null` when no records came in the last 15 minutes. Before, it returned `0.0`, so an offline board looked like an empty room. A test covers this.
2. **The home screen loads all data itself.** Before, each `BoardCard` fetched its own data and filled in on its own. Now [home_screen.dart](lib/screens/home_screen.dart) fetches every board's last 15 minutes and current-hour prediction, then shows the whole list at once. This made it possible to sort offline boards to the bottom. Downside: the list waits for the slowest board. A failed request for one board shows that board as offline.
3. **Offline boards are sorted last** on the home screen. Otherwise the server's order is kept.
4. **The app runs in Polish only.** `main.dart` sets `Locale('pl')`, `Intl.defaultLocale = 'pl'` and calls `initializeDateFormatting('pl')`. Dates show as "czwartek, 29 paź", and the date picker starts weeks on Monday because of the locale.
5. **The Monday-first date picker workaround was removed** (`_MondayFirstLocalizations` / `_MondayFirstDelegate` in the details screen). The Polish locale already starts weeks on Monday. If you go back to English, put it back.
6. **The details screen keeps old content during reloads.** Changing the day or timeframe no longer clears the screen to a spinner. The old content stays and a thin progress bar shows under the top bar. Only the first load shows placeholders.
7. **The refresh button on the home screen is gone.** Pull down to refresh.
8. **On wide windows** (Linux build) all screens sit in a centered column, max 560 px (`builder` in `main.dart`).

## New files

| File | What it is |
| --- | --- |
| [lib/theme.dart](lib/theme.dart) | `Palette` (all colors), `archivo()` / `heading()` text styles (Archivo font from `google_fonts`, tabular numbers), `buildTheme()` (Material theme for buttons, inputs, segmented button, snackbars, tooltips, dialogs), `panelDecoration()` (white panel with a thin border, radius 6), `Skeleton` (grey loading placeholder). |
| [lib/widgets/status_block.dart](lib/widgets/status_block.dart) | `statusInfo()` turns the current count and prediction into a status (title, color, text color, caption lines). `StatusBlock` is the large colored band on the details screen. `StatusTag` is the small colored label on home cards. Offline gets diagonal hatching. Color changes fade over 200 ms. Also `countText()` ("ok. 8 osób" / "pusto"). |
| [lib/utils/plural.dart](lib/utils/plural.dart) | `people(n)` gives Polish plurals ("1 osoba", "3 osoby", "5 osób") and `weeksGenitive(n)` gives "1 tygodnia" / "3 tygodni". A test covers this. |
| [REDESIGN_PLAN.md](REDESIGN_PLAN.md) | The plan agreed before building. Parts of it were changed later (see "Changes after the first version"). |

## Deleted files

- `lib/widgets/crowd_comparison_row.dart`: the "Busier than usual" pill with "Usually ~X at this hour". Replaced by `status_block.dart`.

## Changes per file

### pubspec.yaml / pubspec.lock
- Added `flutter_localizations` (part of the Flutter SDK, not a pub package), needed for the Polish locale.

### lib/main.dart
- Uses `buildTheme()` instead of the inline blue theme with Inter.
- Polish locale setup (see behavior change 4).
- Removed the app title "Crowdness Tracker".
- Centered max-width column (behavior change 8).

### lib/screens/home_screen.dart
- No `AppBar`. At the top, the day and time of the last load in large type ("Czwartek, 00:20") and a gear icon that opens settings.
- Data loading moved here from the card (behavior changes 2 and 3).
- Loading shows 3 grey placeholder cards that fade into the list (`AnimatedSwitcher`, 200 ms), instead of a spinner over a dimmed screen.
- Error text "Nie udało się połączyć z serwerem." with a "Spróbuj ponownie" button. Empty text "Na tym serwerze nie ma jeszcze żadnych miejsc."
- After returning from the details screen, the list always reloads.

### lib/widgets/board_card.dart
- Now a display-only widget: it receives `current` and `prediction` and fetches nothing.
- Layout: the place name and a colored `StatusTag` in one row, then one grey line, "ok. 9 osób, zwykle 3–8 o tej porze". Offline cards show only the name (greyed) and a hatched "Brak sygnału" tag.
- The firmware version ("v57") is shown for admins at the end of the second line.
- Pressing a card scales it to 0.98 for 120 ms.
- New helper `boardDisplayName(board, [name])` (name or formatted MAC), also used by the details and board settings screens.

### lib/screens/details_screen.dart
- Top bar has only the back arrow. Rename and board settings moved into a "⋮" menu (`PopupMenuButton`), built only in admin mode. The old `Icons.tune` / `Icons.edit` buttons are gone.
- Order: place name (large), `StatusBlock` in a white panel, the day section, then "Typowy tydzień" with the heatmap.
- Day section: the date as a heading ("Dziś" or "Środa, 28 paź"; tap opens the date picker) with ‹ › arrows. The "6:00-23:00 / Full Day" dropdown became a `SegmentedButton` with "6–23" and "Cała doba".
- Chart:
  - straight lines instead of curves (`isCurved: false`), with a dot on every measured hour
  - a dashed vertical "teraz" line at the current time
  - y-axis steps from a fixed list (1, 2, 5, 10, 20, 25, 50…) via `_yScale()`, so the top label always sits on a grid line (fixes "17" overlapping "16")
  - bottom labels every 3 hours ("6:00", "9:00")
  - a 250 ms transition when the data changes
  - tooltip and legend in Polish ("zmierzono", "zwykle", "typowy zakres", "na podstawie 3 z 4 tygodni")
- The `_records` field was removed (it was stored but never used).
- Rename dialog in Polish. The text field also saves on Enter.
- Behavior changes 5 and 6.

### lib/widgets/week_heatmap.dart
- **Flipped:** 7 weekday columns (pn…nd), hours run down the rows. Hour labels every 3 hours, and today's weekday header in bold.
- Color ramp from light blue through vivid blue to navy (`_heat()`), scaled from 0 to the week's highest value. The old green/amber/red `heatColor()` is gone.
- Hours with no data are white with a thin border.
- The current hour has a dark ring with a white gap.
- Tooltip on **tap** instead of long press, in Polish ("śr 14:00 / zwykle ok. 8 (5–12) / na podstawie 3 tygodni").
- Legend "mniej osób ▭ więcej osób".

### lib/screens/settings_screen.dart
- Polish text ("Ustawienia", "Serwer", "Adres serwera", "Zapisz", "Dostęp administratora"). Hard-coded colors removed; the theme styles it. URL keyboard, no autocorrect.

### lib/screens/admin_access_screen.dart
- Polish text. Hard-coded colors and input styles removed. Logic unchanged.

### lib/screens/board_settings_screen.dart
- Polish labels, helper text ("od 1 do 10") and validation messages. Hard-coded button and input styles removed. Title "Ustawienia: <name>". Logic and bounds unchanged.

### test/widget_test.dart
- "app starts" looks for the settings gear (tooltip "Ustawienia") instead of the text "Crowdness Tracker".
- The admin test looks for the "⋮" icon (`Icons.more_vert`) instead of `Icons.tune` / `Icons.edit`.

### test/prediction_test.dart
- Switches the timeframe by tapping "Cała doba" instead of using the dropdown.
- Expects Polish strings ("na podstawie 3 z 4 tygodni", "Tłoczniej niż zwykle", "ok. 9 osób").
- Removed the check that the date picker starts on Monday (the locale handles it now, and the test app is not in Polish).
- New tests: offline returns `null`, and Polish plurals.

## Changes after the first version

1. **Compact home cards** (asked for after the first version). The large full-width status band on each card was replaced by a small `StatusTag` on the same line as the name, and the caption "czujnik milczy od ponad 15 min" was removed everywhere. Offline now shows just "Brak sygnału".
2. **Brighter colors** (asked for because the greys looked sad). This is the current palette in `Palette`:

| Name | First version | Now |
| --- | --- | --- |
| background `bg` | `#EEF1F4` grey | `#EFF4FF` light blue |
| text `ink` | `#17202B` | `#14213D` navy |
| quieter than usual | `#2B6FD6` blue | `#22C55E` green, dark text |
| as usual | `#DCE1E7` grey | `#2563EB` blue, white text |
| busier than usual | `#F0782E` orange | `#DC2626` red, white text |
| no history yet | grey (same as usual) | `#DCE7FF` light blue (`learning`) |
| buttons, selection, measured line | ink | `#2563EB` blue (`accent`) |
| chart range band | grey | `#DCE7FF` light blue |
| heatmap | grey to ink | `#DBEAFE` → `#3B82F6` → `#1E3A8A` |

The loading placeholders were also reshaped to match the compact cards.

## Not finished / not checked

- The last home screenshot with the bright palette never came through (the screenshot window came out the wrong size), so the bright home screen was not checked visually. The details screen was.
- Not tested on a real Android phone.
- `flutter analyze` is clean apart from an existing note in the unused `lib/widgets/place_card.dart`; all 7 tests pass.
