# Kapowarr Add-on Documentation

## What is Kapowarr?

Kapowarr is a comic book library manager that fits in the *arr suite of software. It allows you to build and manage a digital library of comics with automated downloading, renaming, and conversion.

## Installation

1. Add this repository to your Home Assistant instance via the Add-on Store
2. Install the **Kapowarr** add-on
3. Configure the add-on options (see [Configuration](#configuration) below)
4. Start the add-on
5. Access Kapowarr via the Home Assistant sidebar or the Open Web UI button

## Configuration

### Add-on Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `log_level` | string | `info` | Log verbosity: `trace`, `debug`, `info`, `warning`, `error` |
| `timezone` | string | `UTC` | Timezone string (e.g., `America/New_York`) |

### Storage

The add-on maps the following directories:

| Container Path | Host Path | Description |
|----------------|-----------|-------------|
| `/config` | `/addon_configs/kapowarr/` | Persistent configuration and database |
| `/share` | `/share/` | Shared storage accessible by other add-ons |

## Ingress

This add-on supports **Home Assistant Ingress**, allowing you to access Kapowarr
directly from the Home Assistant sidebar without exposing any additional ports.

The embedded web UI is accessible by clicking the add-on tile in the sidebar.

## First-Time Setup

1. Start the add-on
2. Click the **Open Web UI** button (or navigate to it in the sidebar)
3. Add comic volumes using the Comic Vine search
4. Map folders to volumes to import your existing library
5. Configure download settings in the Settings panel

## Upgrade Notes

When upgrading the add-on, your configuration data in `/config` is preserved.

## Troubleshooting

### Add-on fails to start

Check the add-on logs for error messages. Common causes:

- **Port conflict** — another service is using the same port.
- **Permission error** — the `/config` directory has incorrect ownership.

### Web interface shows 502 Bad Gateway

The nginx proxy cannot reach the backend application. Wait 10–20 seconds for
the application to fully start, then refresh. If the error persists, check
the add-on logs for application startup errors.

### Application is slow or unresponsive

- Increase `log_level` to `debug` to see detailed request logs
- Check the host system for resource pressure (CPU, memory, disk I/O)

## Support

- Add-on issues: [GitHub Issues](https://github.com/rigerc/ha-apps/issues)
- Application issues: [Upstream GitHub](https://github.com/Casvt/Kapowarr/issues)

## Resources

- [Kapowarr Documentation](https://casvt.github.io/Kapowarr/)
- [Kapowarr GitHub](https://github.com/Casvt/Kapowarr)
- [Kapowarr Discord](https://discord.gg/nMNdgG7vsE)
- [Kapowarr Subreddit](https://www.reddit.com/r/kapowarr/)
- [Home Assistant Add-on Documentation](https://developers.home-assistant.io/docs/add-ons)
