# Kapowarr Add-on Documentation

## What is Kapowarr?

Kapowarr is a software to build and manage a comic book library, fitting in the \*arr suite of software. It allows you to build a digital library of comics with automated downloading, renaming, and conversion.

## Installation

1. Add this repository to your Home Assistant instance
2. Install the Kapowarr add-on
3. Configure the add-on options (optional)
4. Start the add-on
5. Access Kapowarr via the sidebar or the web interface

## Configuration

### Add-on Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `log_level` | string | `info` | Controls the verbosity of log output. Options: `trace`, `debug`, `info`, `warning`, `error` |

### Volumes

The add-on maps the following directories:

| Container Path | Description |
|---------------|-------------|
| `/data` | Kapowarr database and configuration storage |
| `/share` | Shared storage accessible by other add-ons |

## Usage

### First-Time Setup

1. Start the add-on
2. Access Kapowarr through the Home Assistant sidebar or via the web interface
3. Follow the initial setup wizard to configure your library paths
4. Add your comic book folders to the library

### Library Management

- **Add Volumes**: Search for comics and add them to your library
- **Import Existing**: Import your current comic collection
- **Download**: Automatically download missing issues
- **Rename**: Rename files according to your preferred format
- **Convert**: Convert between different comic archive formats

### Supported Services

Kapowarr supports downloading from:
- Direct downloads
- MediaFire
- Mega
- And many other file hosting services

## Ingress Access

This add-on supports Home Assistant Ingress, allowing you to access Kapowarr directly from the Home Assistant sidebar without exposing additional ports.

## Tips

1. **Library Paths**: Map your comic collection folders through the `/share` directory
2. **API Keys**: Get a Comic Vine API key for better metadata retrieval
3. **Naming Convention**: Set up your preferred naming convention in settings
4. **Quality Profiles**: Configure quality profiles for automatic downloads

## Troubleshooting

### Common Issues

**Add-on won't start:**
- Check the add-on logs for error messages
- Ensure no other service is using the same port

**Can't access web interface:**
- Wait a few seconds for the service to fully start
- Try refreshing the page

**Downloads not working:**
- Check your download client configuration
- Verify your indexers are properly configured

## Support

For issues with this add-on:
- Check the [GitHub Issues](https://github.com/rigerc/ha-apps/issues)

For issues with Kapowarr itself:
- [Kapowarr GitHub](https://github.com/Casvt/Kapowarr)
- [Discord Server](https://discord.gg/nMNdgG7vsE)
- [Reddit Community](https://www.reddit.com/r/kapowarr/)

## Resources

- [Kapowarr Documentation](https://casvt.github.io/Kapowarr/)
- [Kapowarr GitHub](https://github.com/Casvt/Kapowarr)
- [Home Assistant Add-on Documentation](https://developers.home-assistant.io/docs/add-ons)
