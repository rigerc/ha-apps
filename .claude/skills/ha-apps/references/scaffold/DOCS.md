# APP_NAME Add-on Documentation

<!-- CUSTOMIZE: Replace APP_NAME with your application's name throughout this file. -->

## What is APP_NAME?

<!-- CUSTOMIZE: Write a 2-4 sentence description of the application. -->

APP_NAME is a [brief description of what the application does].

## Installation

1. Add this repository to your Home Assistant instance via the Add-on Store
2. Install the **APP_NAME** add-on
3. Configure the add-on options (see [Configuration](#configuration) below)
4. Start the add-on
5. Access APP_NAME via the Home Assistant sidebar or the Open Web UI button

## Configuration

### Add-on Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `log_level` | string | `info` | Log verbosity: `trace`, `debug`, `info`, `warning`, `error` |
| `timezone` | string | `UTC` | Timezone string (e.g., `America/New_York`) |

<!-- CUSTOMIZE: Add rows for each option defined in config.yaml -->

### Storage

The add-on maps the following directories:

| Container Path | Host Path | Description |
|----------------|-----------|-------------|
| `/config` | `/addon_configs/<slug>/` | Persistent configuration and data |
| `/share` | `/share/` | Shared storage accessible by other add-ons |

<!-- CUSTOMIZE: Update the table to reflect the actual volume mounts used -->

## Ingress

This add-on supports **Home Assistant Ingress**, allowing you to access APP_NAME
directly from the Home Assistant sidebar without exposing any additional ports.

The embedded web UI is accessible by clicking the add-on tile in the sidebar.

## First-Time Setup

1. Start the add-on
2. Click the **Open Web UI** button (or navigate to it in the sidebar)
3. <!-- CUSTOMIZE: describe the first-time setup wizard or initial configuration steps -->

## Upgrade Notes

When upgrading the add-on, your configuration data in `/config` is preserved.
<!-- CUSTOMIZE: note any migration steps or breaking changes -->

## Troubleshooting

### Add-on fails to start

Check the add-on logs for error messages.  Common causes:

- **Port conflict** — another service is using the same port.
- **Permission error** — the `/config` directory has incorrect ownership.

### Web interface shows 502 Bad Gateway

The nginx proxy cannot reach the backend application.  Wait 10–20 seconds for
the application to fully start, then refresh.  If the error persists, check
the add-on logs for application startup errors.

### Application is slow or unresponsive

- Increase `log_level` to `debug` to see detailed request logs
- Check the host system for resource pressure (CPU, memory, disk I/O)

## Support

- Add-on issues: [GitHub Issues](https://github.com/YOUR_ORG/YOUR_REPO/issues)
- Application issues: [Upstream GitHub](https://github.com/UPSTREAM_OWNER/UPSTREAM_REPO/issues)

## Resources

- [APP_NAME Documentation](https://upstream-docs-url)
- [APP_NAME GitHub](https://github.com/UPSTREAM_OWNER/UPSTREAM_REPO)
- [Home Assistant Add-on Documentation](https://developers.home-assistant.io/docs/add-ons)
