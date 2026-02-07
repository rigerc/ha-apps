
#  <img src="./icon.png" width="24" height="24" style="margin-right: 4px;"> Romm

[![Version](https://img.shields.io/badge/ha%20app%20version-1.1.0-blue?style=flat-square&logo=homeassistant&logoColor=white)](https://github.com/rigerc/ha-apps/tree/main/romm)
&nbsp; [![Current](https://img.shields.io/badge/image%20version-4.6.0-blue?style=flat-square&logo=docker&logoColor=white)](https://github.com/rommapp/romm)&nbsp; [![Out of Date](https://img.shields.io/badge/upstream-out%20of%20date-yellow?style=flat-square)](https://github.com/rommapp/romm)
&nbsp; [![aarch64](https://img.shields.io/badge/platform-aarch64-informational?style=flat-square&logo=linux&logoColor=white)]()
&nbsp; [![amd64](https://img.shields.io/badge/platform-amd64-informational?style=flat-square&logo=linux&logoColor=white)]()

A beautiful, powerful, self-hosted ROM manager and player.
Scan, enrich, browse and play your game collection with metadata from
IGDB, Screenscraper, and MobyGames. Features custom artwork from SteamGridDB,
RetroAchievements display, in-browser gameplay via EmulatorJS and RuffleRS,
support for 400+ platforms, multi-disk games, DLCs, mods, hacks, patches,
manuals, and sharing with friends.

## Documentation

For full documentation, see [DOCS.md](./DOCS.md).

## Changelog

For version history and release notes, see [CHANGELOG.md](./CHANGELOG.md).

## Configuration

This add-on provides the following configuration options:

| Option | Description |
|--------|-------------|
| **Authentication Secret Key** | Secret key for session authentication. **Required** - Generate with: openssl rand -hex 32 |
| **Database Configuration** | MariaDB/MySQL database connection settings. ROMM requires an external database. |
| **Database Host** | Hostname or IP address of your MariaDB/MySQL server (e.g., 'core-mariadb' for HA add-on). |
| **Database Name** | Name of the database to use for ROMM data. |
| **Database Password** | Password for database authentication. **Required** - must not be empty. |
| **Database Port** | Database server port (default: 3306 for MariaDB/MySQL). |
| **Database User** | Username for database authentication. |
| **Environment Variables** | Optional additional environment variables to pass to ROMM. Format: KEY=VALUE |
| **Library Path** | Path to your ROM collection directory (default: /share/roms). Organize ROMs by platform subfolder. |
| **Log Level** | Logging verbosity level. Use 'info' for normal operation, 'debug' for troubleshooting. |
| **Metadata Providers** | API credentials for game metadata sources. Configure providers to fetch game info, artwork, and achievements. |
| **Enable Hasheous** | Enable Hasheous metadata provider for ROM identification. |
| **IGDB Client ID** | Internet Game Database (IGDB) client ID. Register at https://api-docs.igdb.com/ |
| **IGDB Client Secret** | Internet Game Database (IGDB) client secret. Required for some metadata features. |
| **Enable LaunchBox** | Enable LaunchBox metadata provider for game information. |
| **MobyGames API Key** | MobyGames API key for additional game metadata. |
| **Enable Playmatch** | Enable Playmatch metadata provider. |
| **RetroAchievements API Key** | RetroAchievements API key. Get yours at https://retroachievements.org/ |
| **ScreenScraper Password** | ScreenScraper.fr account password. |
| **ScreenScraper Username** | ScreenScraper.fr account username. Register at https://www.screenscraper.fr/ |
| **SteamGridDB API Key** | SteamGridDB API key for custom artwork. Get yours at https://www.steamgriddb.com/ |
| **Scheduled Tasks** | Configure automatic background maintenance tasks. |
| **Enable Image Conversion** | Convert images to WebP format for better performance daily at 4 AM. |
| **Enable LaunchBox Metadata Updates** | Update LaunchBox metadata daily at 4 AM. |
| **Enable Scheduled Rescan** | Automatically rescan library for new ROMs daily at 3 AM. |
| **Enable RetroAchievements Sync** | Sync RetroAchievements progress daily at 4 AM. |
| **Enable Switch TitleDB Updates** | Update Nintendo Switch title database daily at 4 AM. |

## Project
This add-on is a wrapper for the [Romm project](https://github.com/rommapp/romm).
