---
name: bashio
description: This skill should be used when the user asks to "use bashio", "read config with bashio", "log messages in an add-on", "call the Supervisor API", or mentions bashio functions, Home Assistant add-on development, or s6-overlay scripts.
---

# Bashio for Home Assistant Add-ons

Bashio provides a function library for accessing Home Assistant Supervisor features from shell scripts within add-ons. Use bashio to read configuration, log messages, interact with services, and control the Supervisor.

## Purpose

Simplify Home Assistant add-on development by providing tested, documented functions for common operations. Avoid reinventing wheels for configuration access, logging, API calls, and service discovery.

## When to Use This Skill

Use this skill when:
- Creating new Home Assistant add-ons
- Adding configuration reading to scripts
- Implementing logging in add-on services
- Calling Supervisor or Home Assistant APIs
- Setting up s6-overlay service scripts
- Checking service availability (Mariana Board, MySQL, etc.)
- Debugging add-on initialization or runtime issues

## Core Concepts

### Script Shebang

Always use bashio's shebang to ensure the library loads:

```bash
#!/usr/bin/with-contenv bashio
```

This automatically sources bashio and provides access to all functions.

### Log Levels

Bashio supports hierarchical log levels controlled by the `log_level` add-on option:
- **trace** - Extremely verbose, every function call
- **debug** - Diagnostic messages for development
- **info** - Normal operational messages (default)
- **warning** - Non-fatal issues needing attention
- **error** - Fatal errors, service will likely stop

## Core Workflow

### Step 1: Read Add-on Configuration

Access options from `config.yaml` using `bashio::config`:

```bash
# Read a string value
app_port=$(bashio::config 'port')

# Read with default value if not set
log_level=$(bashio::config 'log_level' 'info')

# Check if a boolean option is true
if bashio::config.true 'ssl'; then
    bashio::log.info "SSL is enabled"
fi

# Check if option has a value
if bashio::config.has_value 'api_key'; then
    api_key=$(bashio::config 'api_key')
fi

# Require an option or exit with error
bashio::config.require 'username'
```

**Common config functions:**
- `bashio::config <key>` - Get value (returns `null` if not set)
- `bashio::config <key> <default>` - Get with default
- `bashio::config.true <key>` - Check if boolean is true
- `bashio::config.false <key>` - Check if boolean is false
- `bashio::config.has_value <key>` - Check if has non-empty value
- `bashio::config.require <key>` - Require or exit fatal
- `bashio::config.require.username` - Require username
- `bashio::config.require.password` - Require password

### Step 2: Log Messages

Use structured logging with proper severity levels:

```bash
# Basic logging (colors automatically applied)
bashio::log.info "Starting application..."
bashio::log.notice "Configuration loaded"
bashio::log.warning "Using default values"
bashio::log.error "Failed to connect to database"

# Debug logging (only shown when log_level is debug/trace)
bashio::log.debug "API endpoint: ${api_url}"

# Fatal error (stops service)
bashio::log.fatal "Required configuration missing!"

# Colored messages (rarely needed, levels are preferred)
bashio::log.green "Success!"
bashio::log.red "Critical error!"
```

### Step 3: Access Supervisor API

Call Supervisor endpoints without manual authentication:

```bash
# Restart Home Assistant
bashio::core.restart

# Get Home Assistant version
ha_version=$(bashio::core.version)

# Check for updates
if bashio::core.update_available; then
    bashio::log.notice "Home Assistant update available"
fi

# Get add-on info
my_version=$(bashio::addon.version 'self')
addon_name=$(bashio::addon.name)

# Get ingress URL
ingress_url=$(bashio::addon.ingress_url)

# Check if a service is available
if bashio::services.available 'mysql'; then
    bashio::log.info "MySQL service is running"
fi

# Get service configuration
mysql_host=$(bashio::services 'mysql' 'host')
mysql_port=$(bashio::services 'mysql' 'port')
```

### Step 4: Network Operations

Wait for services or ports to be ready:

```bash
# Wait for a TCP port (default: localhost, 60s timeout)
bashio::net.wait_for 8080

# Wait for specific host
bashio::net.wait_for db.example.com 5432 120

# Wait before starting dependent service
bashio::log.info "Waiting for database..."
bashio::net.wait_for "${db_host}" "${db_port}"
```

### Step 5: File System Operations

Create directories with proper ownership:

```bash
# Create directory in /data (persistent)
bashio::fs.mkdir '/data/config'

# Create directory in /tmp (ephemeral)
bashio::fs.mkdir '/tmp/cache'

# Check if file exists
if bashio::fs.file_exists '/ssl/fullchain.pem'; then
    bashio::log.info "SSL certificate found"
fi

# Copy file with bashio (preserves permissions)
bashio::fs.cp '/tmp/config.yaml' '/data/config.yaml'
```

### Step 6: JSON Parsing with jq

Parse JSON responses from APIs:

```bash
# Get add-on info as JSON
addon_info=$(bashio::api.supervisor GET '/addons/self/info' false)

# Extract specific field using bashio's jq wrapper
name=$(bashio::jq "${addon_info}" '.name')
version=$(bashio::jq "${addon_info}" '.version')

# Check if path exists in JSON
if bashio::jq.exists "${response}" '.data.config'; then
    config=$(bashio::jq "${response}" '.data.config')
fi
```

## Common Patterns

### Reading All Options at Once

Load configuration into variables:

```bash
#!/usr/bin/with-contenv bashio

# Read all configuration
server_port=$(bashio::config 'port' '8095')
ssl_enabled=$(bashio::config 'ssl' 'false')
certfile=$(bashio::config 'certfile')
log_level=$(bashio::config 'log_level' 'info')

# Use the values
bashio::log.info "Starting on port ${server_port}"
if bashio::config.true 'ssl'; then
    bashio::log.info "SSL enabled with ${certfile}"
fi
```

### Service Discovery Pattern

Check for optional dependencies:

```bash
# MariaDB is optional
if bashio::services.available 'mariadb'; then
    db_host=$(bashio::services 'mariadb' 'host')
    db_port=$(bashio::services 'mariadb' 'port')
    db_user=$(bashio::services 'mariadb' 'username')
    db_pass=$(bashio::services 'mariadb' 'password')
    bashio::log.info "Using MariaDB service"
else
    # Use internal SQLite
    bashio::log.notice "No MariaDB service found, using SQLite"
fi
```

### Conditional SSL Certificate Validation

Validate SSL configuration only when enabled:

```bash
if bashio::config.true 'ssl'; then
    bashio::config.require.ssl 'ssl' 'certfile' 'keyfile'
    cert_path="/ssl/$(bashio::config 'certfile')"
    key_path="/ssl/$(bashio::config 'keyfile')"
    bashio::log.info "Using SSL: ${cert_path}"
fi
```

### Log Level Control

Set log level dynamically:

```bash
# Read log level from config or default to info
log_level=$(bashio::config 'log_level' 'info')

# Set bashio's internal log level
bashio::log.level "${log_level}"

# Now debug/trace logs only show when configured
bashio::log.debug "This only shows if log_level is debug or trace"
```

## s6-Overlay Integration

### Initialization Scripts (cont-init.d)

Create scripts in `/etc/cont-init.d/` for one-time setup:

```bash
#!/usr/bin/with-contenv bashio
# /etc/cont-init.d/01-setup.sh

bashio::log.info "Setting up configuration..."

# Create directories
bashio::fs.mkdir '/data/config'
bashio::fs.mkdir '/data/cache'

# Generate config from template
# (use bashio to read options and generate file)
```

### Service Scripts (services.d)

Create run and finish scripts for services:

```bash
#!/usr/bin/with-contenv bashio
# /etc/services.d/myapp/run

# Wait for dependencies
bashio::net.wait_for 8080

# Start the application
bashio::log.info "Starting application..."
exec /app/myapp --config /data/config.yaml
```

```bash
#!/usr/bin/with-contenv bashio
# /etc/services.d/myapp/finish

# Cleanup when service stops
bashio::log.info "Stopping application..."
```

## Error Handling

### Graceful Exits

Use bashio exit functions for proper error codes:

```bash
# Successful exit
bashio::exit.ok

# Exit with error message
bashio::exit.nok "Failed to start service"

# Require specific conditions
if ! bashio::fs.file_exists '/data/config.yaml'; then
    bashio::log.fatal "Configuration file not found!"
    bashio::exit.nok
fi
```

### Config Validation

Validate required options before starting:

```bash
#!/usr/bin/with-contenv bashio

# Require authentication
bashio::config.require.username 'username'
bashio::config.require.password 'password'

# Require SSL if enabled
if bashio::config.true 'ssl'; then
    bashio::config.require.ssl
fi

bashio::log.info "Configuration validated successfully"
```

## Additional Resources

### Reference Files

For comprehensive documentation of all bashio functions:
- **`references/log-functions.md`** - Complete logging reference
- **`references/config-functions.md`** - Configuration reading patterns
- **`references/api-functions.md`** - Supervisor API calls
- **`references/service-discovery.md`** - Service integration patterns

### Bashio Source Code

The complete bashio library source code is available in `references/lib/` for detailed reference:

**Core Libraries:**
- **`lib/bashio`** - Main bashio entry point
- **`lib/bashio.sh`** - Core library loader
- **`lib/const.sh`** - Constants and definitions

**Configuration & Options:**
- **`lib/config.sh`** - Configuration reading functions (`bashio::config.*`)
- **`lib/options.sh`** - Options.json parsing

**Logging:**
- **`lib/log.sh`** - All logging functions (`bashio::log.*`)
- **`lib/debug.sh`** - Debug logging helpers
- **`lib/trace.sh`** - Trace-level logging

**Add-on & Supervisor API:**
- **`lib/addons.sh`** - Add-on information functions (`bashio::addon.*`)
- **`lib/core.sh`** - Home Assistant core functions (`bashio::core.*`)
- **`lib/supervisor.sh`** - Supervisor API calls
- **`lib/api.sh`** - Generic API request helpers

**Services & Discovery:**
- **`lib/services.sh`** - Service discovery (`bashio::services.*`)
- **`lib/discovery.sh`** - Service discovery helpers

**Network & Hardware:**
- **`lib/net.sh`** - Network utilities (`bashio::net.*`)
- **`lib/network.sh`** - Network interface functions
- **`lib/dns.sh`** - DNS operations
- **`lib/hardware.sh`** - Hardware information
- **`lib/host.sh`** - Host system functions

**File System:**
- **`lib/fs.sh`** - File system operations (`bashio::fs.*`)

**Utilities:**
- **`lib/jq.sh`** - JSON parsing with jq (`bashio::jq.*`)
- **`lib/string.sh`** - String manipulation
- **`lib/color.sh`** - Terminal color codes
- **`lib/exit.sh`** - Exit code helpers
- **`lib/var.sh`** - Variable operations
- **`lib/cache.sh`** - Caching functions
- **`lib/cli.sh`** - CLI argument parsing
- **`lib/os.sh`** - Operating system detection
- **`lib/info.sh`** - System information
- **`lib/observer.sh`** - Observer pattern utilities

**Home Assistant Features:**
- **`lib/audio.sh`** - Audio subsystem functions
- **`lib/multicast.sh`** - Multicast operations
- **`lib/repositories.sh`** - Repository management

**When to consult the source:**
- Need exact parameter details for a function
- Want to understand function implementation
- Debugging unexpected behavior
- Looking for additional functions not covered in this guide
- Need to see available options for complex functions

### Example Files

Working examples in `examples/`:
- **`examples/read-config.sh`** - Configuration reading patterns
- **`examples/service-setup.sh`** - s6-overlay service script
- **`examples/with-ssl.sh`** - SSL certificate handling
- **`examples/service-discovery.sh`** - Optional dependency checks

### Official Resources

- [Bashio GitHub Repository](https://github.com/hassio-addons/bashio) - Official source and documentation
- [Home Assistant Add-ons Documentation](https://developers.home-assistant.io/docs/addons/)
- [s6-overlay Documentation](https://github.com/just-containers/s6-overlay)
- **`references/lib/`** - Complete bashio source code copied from `docs/bashio/lib/` for offline reference

## Best Practices

### DO:
- Use `#!/usr/bin/with-contenv bashio` shebang
- Source bashio at the start of scripts
- Use appropriate log levels (info for normal, debug for diagnostics)
- Require critical configuration with `bashio::config.require`
- Use `bashio::net.wait_for` for service dependencies
- Log all significant operations for debugging
- Use bashio's jq wrapper for JSON parsing

### DON'T:
- Manually parse `/data/options.json` (use `bashio::config`)
- Directly call Supervisor API without authentication (use `bashio::api.supervisor`)
- Hardcode service discovery (use `bashio::services.available`)
- Use echo for logging (use `bashio::log.info`)
- Ignore return codes from bashio functions
- Skip validating SSL when enabled
