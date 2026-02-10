# <img src="https://raw.githubusercontent.com/rigerc/ha-apps/main/kapowarr/icon.png" width="24" height="24" style="margin-right: 4px;"> Kapowarr

[![Version](https://img.shields.io/badge/ha%20app%20version-1.0.0-blue?style=flat-square&logo=homeassistant&logoColor=white)](https://github.com/rigerc/ha-apps/tree/main/kapowarr)
&nbsp; [![Current](https://img.shields.io/badge/image%20version-v1.2.0-blue?style=flat-square&logo=docker&logoColor=white)](https://github.com/Casvt/Kapowarr)&nbsp; [![Up to Date](https://img.shields.io/badge/upstream-up%20to%20date-green?style=flat-square)](https://github.com/Casvt/Kapowarr)
&nbsp; [![aarch64](https://img.shields.io/badge/platform-aarch64-informational?style=flat-square&logo=linux&logoColor=white)]()
&nbsp; [![amd64](https://img.shields.io/badge/platform-amd64-informational?style=flat-square&logo=linux&logoColor=white)]()
&nbsp; [![Ingress](https://img.shields.io/badge/ingress-enabled-green?style=flat-square&logo=homeassistant&logoColor=white)]()

Kapowarr is a software to build and manage a comic book library, fitting in
the \*arr suite of software. Build a digital library of comics with automated
downloading, renaming, and conversion.

## Features

- Support for all major OS'es
- Import your current library right into Kapowarr
- Get loads of metadata about the volumes and issues in your library
- Run a "Search Monitored" to download whole volumes with one click
- Or use "Manual Search" to decide yourself what to download
- Support for downloading directly, or via MediaFire, Mega and many other services
- Downloaded files automatically get moved wherever you want and renamed in the format you desire
- Archive files can be extracted and it's contents renamed after downloading or with a single click
- The recognisable UI from the \*arr suite of software

## Documentation

For full documentation, see [DOCS.md](./DOCS.md).

## Changelog

For version history and release notes, see [CHANGELOG.md](./CHANGELOG.md).

## Configuration

This add-on provides the following configuration options:

| Option | Description |
|--------|-------------|
| **Log Level** | Controls the verbosity of log output. Use 'info' for normal operation, 'debug' for troubleshooting. |

## Volumes

The add-on maps the following directories:

| Path | Description |
|------|-------------|
| `/data` | Kapowarr database and configuration |
| `/share` | Shared storage for media files |

## Project

This add-on is a wrapper for the [Kapowarr project](https://github.com/Casvt/Kapowarr).
