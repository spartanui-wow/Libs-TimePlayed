# Lib's TimePlayed

[![Discord](https://img.shields.io/discord/265564257347829771.svg?logo=discord)](https://discord.gg/Qc9TRBv)

Track `/played` time across all your characters with account-wide statistics, class/realm/faction grouping, and **instant data import** from AltVault or Altoholic.

## 🚀 Quick Start: One-Click Import

**New to Lib's TimePlayed?** If you have AltVault or Altoholic installed, you'll see this on first login:

<img width="420" height="222" alt="image" src="https://github.com/user-attachments/assets/afef8399-6a63-483e-b59c-c3a7222f0f56" />

**Click "Import Now"** and instantly see all your characters' played time—no need to log into each one!

## Features

### Time Tracking

- **Account-wide**: Automatically tracks played time for every character you log into
- **Multiple formats**: View total played, session time, or current level time
- **Auto-update**: Refreshes on login and level up
- 
<img width="648" height="394" alt="image" src="https://github.com/user-attachments/assets/3c8c6d3e-838e-48ac-9dbc-e57b65b6b508" />

### Display Options

- **Minimap button**: Quick access via left/right click
- **Data Broker**: Works with any LDB display addon (like Libs-DataBar)
- **Popup window**: Standalone window with collapsible groups, status bars, and scroll support
- **Rich tooltip**: Detailed breakdown with class colors, group totals, and milestones

### Grouping

View your characters organized by:

- **Class** - Color-coded by class
- **Realm** - Grouped by server
- **Faction** - Alliance vs Horde

### Time Formats

- **Smart**: Auto-scales (`2y 45d`, `5d 3h`, `45m`, `< 1m`)
- **Full**: All units shown (`5d 3h 30m`)
- **Hours**: Decimal hours (`123.5h`)

### Milestones

Fun achievements based on your playtime: total hours played, number of characters tracked, most-played character, and more.

### Instant Data Import ⚡

**Never log into each alt again!** Import your entire character roster instantly:

- **🎯 Auto-Import**: First-time users are automatically offered import on login
- **📊 Smart Detection**: Automatically selects the source with the most data
- **🔄 AltVault Support**: Direct import from AltVault database
- **📚 Altoholic Support**: Parsed from DataStore with full metadata
- **⚙️ Merge Strategies**:
  - Newest Wins (default) - Use most recent data
  - Prefer Imported - Always use import data
  - Prefer Existing - Keep current data
  - Max Values - Use highest time values

**Manual Import**: Can also import anytime from `/libstp` → Import Data section

## Commands

| Command | Action |
|---------|--------|
| `/libstp` | Open options |
| `/timeplayed` | Open options |
| `/libstp played` | Request fresh `/played` data |
| `/libstp popup` | Toggle popup window |

### Click Actions

| Input | Action |
|-------|--------|
| Left Click | Cycle display (total/session/level) |
| Shift + Left Click | Toggle popup window |
| Right Click | Open options |
| Middle Click | Refresh `/played` |

## Support

- [Discord](https://discord.gg/Qc9TRBv)

