
#  <img src="https://raw.githubusercontent.com/rigerc/ha-apps/main/cleanuparr/icon.png" width="24" height="24" style="margin-right: 4px;"> Cleanuparr

[![Version](https://img.shields.io/badge/ha%20app%20version-1.1.0-blue?style=flat-square&logo=homeassistant&logoColor=white)](https://github.com/rigerc/ha-apps/tree/main/cleanuparr)
&nbsp; [![Current](https://img.shields.io/badge/image%20version-2.5.1-blue?style=flat-square&logo=docker&logoColor=white)](https://github.com/Cleanuparr/Cleanuparr)
&nbsp; [![aarch64](https://img.shields.io/badge/platform-aarch64-informational?style=flat-square&logo=linux&logoColor=white)]()
&nbsp; [![amd64](https://img.shields.io/badge/platform-amd64-informational?style=flat-square&logo=linux&logoColor=white)]()

Automated cleanup tool for Sonarr, Radarr, Lidarr, Readarr, and Whisparr
plus qBittorrent, Transmission, Deluge, and µTorrent. Removes unwanted or
blocked files, manages stalled downloads, enforces blacklists/whitelists,
includes malware detection for *.lnk and *.zipx files, and automatically
triggers searches to replace removed content. Features strike system and
notification support.

## Documentation

For full documentation, see [DOCS.md](./DOCS.md).

## Changelog

For version history and release notes, see [CHANGELOG.md](./CHANGELOG.md).

## Configuration

This add-on provides the following configuration options:

| Option | Description |
|--------|-------------|
| **Dry Run** | When enabled, Cleanuparr simulates operations without making actual changes. Useful for testing cleanup rules. |
| **Log Level** | Controls the verbosity of log output. Higher levels provide more detail for troubleshooting. |

## Project
This add-on is a wrapper for the [Cleanuparr project](https://github.com/Cleanuparr/Cleanuparr).
