
#  <img src="./icon.png" width="24" height="24" style="margin-right: 4px;"> Huntarr

[![Version](https://img.shields.io/badge/ha%20app%20version-1.0.0-blue?style=flat-square&logo=homeassistant&logoColor=white)](https://github.com/rigerc/ha-apps/tree/main/huntarr)
&nbsp; [![Current](https://img.shields.io/badge/image%20version-9.1.1-blue?style=flat-square&logo=docker&logoColor=white)](https://github.com/plexguide/Huntarr.io)&nbsp; [![Out of Date](https://img.shields.io/badge/upstream-out%20of%20date-yellow?style=flat-square)](https://github.com/plexguide/Huntarr.io)
&nbsp; [![amd64](https://img.shields.io/badge/platform-amd64-informational?style=flat-square&logo=linux&logoColor=white)]()
&nbsp; [![aarch64](https://img.shields.io/badge/platform-aarch64-informational?style=flat-square&logo=linux&logoColor=white)]()
&nbsp; [![Ingress](https://img.shields.io/badge/ingress-enabled-green?style=flat-square&logo=homeassistant&logoColor=white)]()

Automatic missing content hunter for Sonarr, Radarr, Lidarr, Readarr, and Whisparr. Continuously searches your media libraries for missing content and quality upgrades below your cutoff. Runs continuously while being gentle on your indexers, filling the gap that *arr apps don't cover by finding content not actively searched through RSS feeds.

## Documentation

For full documentation, see [DOCS.md](./DOCS.md).

## Configuration

This add-on provides the following configuration options:

| Option | Description |
|--------|-------------|
| **Log Level** | Controls the verbosity of log output. Use 'info' for normal operation, 'debug' for troubleshooting. |
| **Timezone** | Set the timezone for Huntarr operations. |

## Project
This add-on is a wrapper for the [Huntarr project](https://github.com/plexguide/Huntarr.io).
