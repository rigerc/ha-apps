# Bashio Logging Functions Reference

Complete reference for all bashio logging functions and patterns.

## Log Levels

Bashio supports hierarchical log levels. Set the level via the `log_level` option in `config.yaml`:

- **trace** - Extremely verbose, shows all function calls
- **debug** - Diagnostic messages, development use
- **info** - Normal operational messages (default)
- **warning** - Non-fatal issues, warnings
- **error** - Fatal errors, service failures

Messages below the current level are silently filtered.

## Core Logging Functions

### bashio::log.info

Log at info level (default):

```bash
bashio::log.info "Starting application..."
bashio::log.info "Configuration loaded successfully"
bashio::log.info "Server listening on port 8080"
```

### bashio::log.debug

Log at debug level (only shown when log_level is debug/trace):

```bash
bashio::log.debug "API endpoint: ${api_url}"
bashio::log.debug "Response: ${response}"
```

### bashio::log.warning / bashio::log.warn

Log at warning level:

```bash
bashio::log.warning "SSL certificate expires in 7 days"
bashio::log.warn "Using deprecated configuration option"
```

### bashio::log.error

Log at error level:

```bash
bashio::log.error "Failed to connect to database"
bashio::log.error "Configuration file not found"
```

### bashio::log.fatal

Log at fatal level (highest severity):

```bash
bashio::log.fatal "Required configuration missing!"
```

### bashio::log.trace

Log at trace level (most verbose):

```bash
bashio::log.trace "Entering function process_data"
bashio::log.trace "Variable value: ${my_var}"
```

## Log Level Control

### bashio::log.level

Change the log level at runtime:

```bash
# Set from configuration
bashio::log.level "$(bashio::config 'log_level' 'info')"

# Set dynamically
bashio::log.level "debug"
```

## Common Patterns

### Startup Banner

```bash
bashio::log.info "---"
bashio::log.info "My Add-on v1.0.0"
bashio::log.info "Starting initialization..."
bashio::log.info "---"
```

### Conditional Debugging

```bash
# Always show this
bashio::log.info "Loading configuration..."

# Only show in debug/trace mode
bashio::log.debug "Config file path: /data/options.json"

# Always show this
bashio::log.info "Configuration loaded"
```

### Error with Context

```bash
if ! connect_to_database; then
    bashio::log.error "Failed to connect to database"
    bashio::log.error "  Host: ${db_host}"
    bashio::log.error "  Port: ${db_port}"
fi
```

## Best Practices

1. Use appropriate levels (info for normal, debug for development, warning for issues, error for failures)
2. Keep messages concise and actionable
3. Log significant events (startup, shutdown, connections)
4. Use debug for technical details
5. Avoid spam in loops

For complete integration with examples, see the main SKILL.md file.
