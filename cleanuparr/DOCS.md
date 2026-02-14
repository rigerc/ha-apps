# Cleanuparr Add-on Documentation

## About

This add-on wraps [Cleanuparr](https://github.com/Cleanuparr/Cleanuparr) for Home Assistant. Cleanuparr automates the cleanup of unwanted or blocked files in Sonarr, Radarr, and download clients.

## Quick Start

1. Install the add-on from the Home Assistant add-on store
2. Click "Start"
3. Open Cleanuparr via the sidebar panel (recommended) or at `http://<home-assistant>:11011`
4. Configure your applications through the web UI

> **Note**: The add-on supports ingress for embedded sidebar panel access. Click "Open Web UI" in the add-on settings to launch the panel.

## Configuration Options

### Log Level
Controls logging verbosity.
**Options**: Trace, Debug, Information, Warning, Error, Fatal
**Default**: Information

### Dry Run
When enabled, logs all operations without making changes. Useful for testing your configuration before enabling live deletions.
**Default**: false

## Data Persistence

All configuration files (`settings.json`) are stored persistently in `/config`, which is mapped to the add-on's configuration directory. Your settings persist across restarts and updates.

## Accessing Cleanuparr

### Ingress (Recommended)
Click "Open Web UI" in the add-on settings. Cleanuparr opens in the Home Assistant sidebar panel.

### Direct Port Access
Access via `http://<home-assistant>:11011` if port exposure is enabled.

## Troubleshooting

### Add-on won't start
- Check the add-on logs in Home Assistant Supervisor
- Try setting "Dry Run" to true to test configuration
- Verify the add-on has sufficient resources

### Can't access web UI
- Verify the add-on is running
- Try the "Open Web UI" button in add-on settings
- Check Home Assistant Supervisor logs
- Ensure port 11011 is available (when not using ingress)

### Configuration not saving
- Your settings are automatically persisted to `/config`
- If settings disappear, check the Supervisor logs for errors
- Restart the add-on to ensure proper initialization

### Downloads not being cleaned
- Verify your *arr app API keys are correct
- Ensure download client connection works
- Check Cleanuparr logs in the add-on
- Verify the feature is enabled in Cleanuparr web UI

## Support

For Cleanuparr-specific issues, see:
- [Official Documentation](https://cleanuparr.github.io/Cleanuparr/)
- [GitHub Issues](https://github.com/Cleanuparr/Cleanuparr/issues)
- [Discord](https://discord.gg/SCtMCgtsc4)
