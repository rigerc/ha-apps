
#  <img src="./icon.png" width="24" height="24" style="margin-right: 4px;"> Profilarr

[![Version](https://img.shields.io/badge/ha%20app%20version-1.0.0-blue)](https://github.com/rigerc/ha-apps/tree/main/profilarr)
&nbsp; [![Current](https://img.shields.io/badge/image%20version-v1.1.3-blue)](https://github.com/Dictionarry-Hub/profilarr)&nbsp; [![Out of Date](https://img.shields.io/badge/upstream-out%20of%20date-yellow)](https://github.com/Dictionarry-Hub/profilarr)
&nbsp; [![aarch64](https://img.shields.io/badge/platform-aarch64-informational)]()
&nbsp; [![amd64](https://img.shields.io/badge/platform-amd64-informational)]()
&nbsp; [![Ingress](https://img.shields.io/badge/ingress-enabled-green)]()

Profile manager for Radarr and Sonarr instances.
Centrally manage quality profiles, custom formats, and
release profiles with Git-backed configuration storage!

## Documentation

For full documentation, see [DOCS.md](./DOCS.md).

## Configuration

This add-on provides the following configuration options:

| Option | Description |
|--------|-------------|
| **Authentication Mode** | Authentication mode for Profilarr: 'on' (full auth), 'local' (no auth on local network), 'oidc' (OpenID Connect), 'off' (no authentication). |
| **Git User Email** | Email used for Git commits. Default is 'profilarr@homeassistant.local'. |
| **Git User Name** | Name used for Git commits. Default is 'Profilarr'. |
| **Log Level** | Controls the verbosity of log output. Use 'info' for normal operation, 'debug' for troubleshooting. |

## Project
This add-on is a wrapper for the [Profilarr project](https://github.com/Dictionarry-Hub/profilarr).
