# Bashio Configuration Functions Reference

Quick reference for reading and validating add-on configuration options.

## Key Functions

### bashio::config

Get a configuration value by key:

```bash
value=$(bashio::config 'my_option')
port=$(bashio::config 'port' '8080')
```

### bashio::config.true / bashio::config.false

Check boolean values:

```bash
if bashio::config.true 'ssl'; then
    bashio::log.info "SSL is enabled"
fi
```

### bashio::config.has_value

Check if a key exists and has a non-empty value:

```bash
if bashio::config.has_value 'api_key'; then
    api_key=$(bashio::config 'api_key')
fi
```

### bashio::config.require

Require an option or exit with fatal error:

```bash
bashio::config.require 'database_url'
bashio::config.require.username
bashio::config.require.password
```

### bashio::config.require.ssl

Validate SSL certificates when SSL is enabled:

```bash
if bashio::config.true 'ssl'; then
    bashio::config.require.ssl
fi
```

For complete details, see the main SKILL.md file.
