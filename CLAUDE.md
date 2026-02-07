# CLAUDE.md - Lib's TimePlayed

This file provides guidance to Claude Code when working with the Libs-TimePlayed addon.

## Project Overview

**Lib's TimePlayed** is a standalone WoW addon that tracks `/played` time across all characters on the account. It stores data persistently via global SavedVariables and displays a class-grouped breakdown in its tooltip. Registers as a LibDataBroker data source.

## Architecture

```
Libs-TimePlayed/
├── Libs-TimePlayed.toc          # Interface 120000, SavedVariables: LibsTimePlayedDB
├── Libs-TimePlayed.lua          # AceAddon main + LibAT Logger
├── .pkgmeta                     # BigWigs packager config (externals for Ace3, LDB, LibDBIcon)
├── Core/
│   ├── Database.lua             # AceDB with global (characters) + profile (display prefs)
│   ├── PlayedTracker.lua        # TIME_PLAYED_MSG handler, session tracking, account data
│   └── TimeFormatter.lua        # FormatTime() — smart/full/hours formats
├── UI/
│   ├── DataBroker.lua           # LDB data source, display format cycling
│   ├── Tooltip.lua              # Current char + account summary grouped by class
│   ├── Options.lua              # AceConfig with display format, time format, purge button
│   └── MinimapButton.lua        # LibDBIcon registration
└── libs/                        # Populated by packager (Ace3, LDB, LibDBIcon)
```

## Key Design Decisions

### Account-Wide Data (Global SavedVariables)
- Character data stored in `dbobj.global.characters` — shared across all characters
- Key format: `"RealmName-CharacterName"`
- Each entry: `{ name, realm, class, classFile, level, totalPlayed, levelPlayed, lastUpdated }`
- Updated every time `TIME_PLAYED_MSG` fires

### Time Formatting
`LibsTimePlayed.FormatTime(seconds, format)` is a **static function** (no `self`) for reuse:
- `'smart'`: Auto-scales — `2y 45d`, `5d 3h`, `2h 30m`, `45m`, `< 1m`
- `'full'`: Always shows all units — `5d 3h 30m`
- `'hours'`: Decimal hours — `123.5h`

### Tooltip Structure
1. Current character: total, this level, session (with class-colored name)
2. Account Total line
3. Classes sorted by total played time descending
4. Under each class: individual characters sorted by played time

### Session Tracking
- Session start time captured at addon load
- Session duration = `time() - sessionStartTime`
- No persistence for session (resets each login, intentional)

### Played Data Request
- Requests `/played` data 2 seconds after init (avoids chat spam suppression)
- Also requests after PLAYER_LEVEL_UP
- Display updates every 60 seconds for session time

## Display Formats

Cycleable via left-click: `total` | `session` | `level`

## Click Behaviors

| Button | Action |
|--------|--------|
| Left Click | Cycle display format |
| Shift+Left | Open Options |
| Right Click | Open Options |
| Middle Click | Request /played refresh |

## Character Data Purge

Options panel includes a "Purge Old Characters" button that removes entries not updated in 90+ days. Useful for cleaning up deleted alts.

## Slash Commands

- `/libstp` or `/timeplayed` — Open options
- `/libstp played` — Request /played data

## Testing

1. Login on character → verify played time appears after ~2 seconds
2. Switch characters → verify both characters appear in tooltip
3. Test format cycling (total/session/level)
4. Test purge: Manually set an old `lastUpdated` in SavedVariables, run purge
5. Test with Libs-DataBar: Verify plugin appears on the databar
