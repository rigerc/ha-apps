# Source Code Analysis for Home Assistant Add-ons

After initial discovery, analyze upstream source code to understand how the application works internally. This deeper analysis reveals runtime requirements, configuration patterns, and integration points that automated discovery cannot detect.

## When to Perform Source Code Analysis

Perform source code analysis when:
- The application has complex startup sequences or initialization requirements
- The upstream documentation is incomplete or unclear
- The app requires specific environment variables or configuration files
- Need to understand how to app handles data persistence, logging, or networking
- The app has multiple processes, services, or background workers

## Source Code Analysis Checklist

### 1. Locate and Read Main Entry Point

Find `main()`, `app.py`, `index.js`, `Go()` function, or equivalent entry point.

**What to look for:**
- Command-line flags, environment variable parsing, and config file loading
- Required vs optional configuration parameters
- Default values and sensible fallbacks

**Example locations:**
- Go: `main.go`
- Python: `app.py`, `main.py`, `__main__.py`
- Node.js: `index.js`, `main.js`, `app.js`
- Rust: `main.rs`, `lib.rs`

### 2. Understand Configuration Loading

Search for `config`, `settings`, `env`, `getenv` patterns in codebase.

**Identify:**
- Configuration file formats (YAML, JSON, TOML, INI, environment-only)
- Map config keys to code paths that use them
- Check for config validation and error handling

**Common patterns by language:**
```bash
# Search for configuration patterns
grep -r "getenv\|getenv\|os.Getenv" --include="*.py" --include="*.go" .
grep -r "config\|settings" --include="*.yaml" --include="*.json" .
```

### 3. Trace Data Storage Patterns

Search for database connections, file I/O, volume mount points.

**Identify:**
- Where app stores persistent data (`/data`, `/config`, `/var/lib`)
- Database migrations or schema initialization
- Required directory structures and permissions

**Key directories to map:**
- `/config` — configuration files (map to `addon_config` mount)
- `/data` — persistent application data
- `/media` — media files or exports (map to `share` mount)
- `/cache` — temporary caches (no persistence needed)

### 4. Examine Logging and Monitoring

Find log output statements (`print`, `log.Info`, `console.log`, etc.)

**Identify:**
- Log levels and destinations (stdout, file, syslog)
- Health check endpoints (`/health`, `/ping`, `/status`)
- Metrics or monitoring integration points

**For HA add-ons, prefer stdout logging** — s6-overlay captures all output and displays it in the HA add-on log panel.

### 5. Analyze Networking and Ports

Find port binding or server start code.

**Identify:**
- Port binding or server start code
- Multiple ports (UI port, API port, metrics port)
- Hostname/interface binding (0.0.0.0, 127.0.0.1, localhost)
- WebSocket, SSE, or other protocol-specific requirements

**Important:** Note the difference between:
- **Listen port** — what the app binds to internally
- **Expose port** — what Docker makes available (for `ports` in config.yaml)

### 6. Identify Background Processes

Search for thread spawning, goroutines, child processes, or cron jobs.

**Identify:**
- Separate worker processes or services
- Process supervision requirements and restart policies
- Inter-process communication mechanisms

## Common Implementation Patterns by Language

### Go Applications

**CLI and config:**
- `cobra` — command-line interface framework
- `viper` — configuration management
- `flag` — standard library flag parsing

**Service initialization:**
- `main.go` for service initialization sequence
- `http.ListenAndServe` or similar for web server start
- `context` usage for graceful shutdown patterns

**Data storage:**
- `bolt.DB`, `badger.DB`, `sql.Open` — database connections
- `os.MkdirAll` — directory creation
- `ioutil.WriteFile` — file I/O

### Python Applications

**CLI and config:**
- `click` — command-line interface framework
- `argparse` — standard library argument parsing
- `typer` — modern CLI framework with type hints

**Configuration:**
- `python-dotenv` — environment variable loading
- `pydantic` — configuration validation
- `configparser` — INI file parsing

**Server startup:**
- `uvicorn` — ASGI server (FastAPI)
- `gunicorn` — WSGI server (Django, Flask)
- `Flask.run()` — development server

**Dependencies:**
- Check `requirements.txt` or `pyproject.toml`

### Node.js Applications

**CLI and config:**
- `commander` — command-line interface framework
- `yargs` — argument parsing
- `minimist` — minimal argument parser

**Configuration:**
- `dotenv` — environment variable loading
- `config` — configuration file management
- `convict` — schema-based configuration

**Server startup:**
- `express.listen()` — Express.js
- `http.createServer` — Node.js built-in
- Framework startup (koa, fastify, etc.)

**Dependencies:**
- Check `package.json` for scripts and dependencies

### Rust Applications

**CLI and config:**
- `clap` — command-line argument parser
- `structopt` — struct-based option parsing

**Configuration:**
- `config` crate — configuration management
- `dotenv` — environment variable loading
- `serde` — serialization framework

**Async runtime:**
- `tokio::runtime` — async runtime
- `actix_web::HttpServer` — web server

**Dependencies:**
- Check `Cargo.toml` for features and dependencies

## Mapping Analysis to Scaffold Configuration

### config.yaml options/schema

After completing source code analysis, add entries for:
- Each required environment variable
- Sensible defaults matching application's built-in defaults
- Group related options logically (database, logging, networking)
- Validation for required vs optional values

### 10-app-setup.sh

Export discovered environment variables to `/var/run/s6/container_environment/`:
```bash
printf '%s\n' "${my_option}" > /var/run/s6/container_environment/MY_OPTION
```

Create required directories with proper ownership:
```bash
bashio::log.info "Creating data directories..."
mkdir -p /data/app/{cache,exports}
chown -R abc:abc /data/app
```

Generate configuration files from templates if needed:
```bash
# Using tempio (Go template engine pre-installed in HA base images)
tempio --template /etc/templates/config.yaml.gtpl \
    --output /config/app.yaml \
    --data /data/options.json
```

Validate configuration before services start:
```bash
if ! validate-config; then
    bashio::log.error "Configuration validation failed"
    exit 1
fi
```

### myapp/run script

Construct command-line arguments based on analysis:
```bash
exec /app/myapp \
    --host "${APP_HOST}" \
    --port "${APP_PORT}" \
    --config /config/app.yaml \
    --log-level "${LOG_LEVEL:-info}"
```

Set required environment variables before exec:
```bash
export DATABASE_PATH=/data/app/db.sqlite
export LOG_OUTPUT=stdout
```

Configure logging output for capture by s6:
```bash
# Most frameworks respect these
export LOG_FORMAT=json
export LOG_LEVEL=info

# For apps that only log to file, redirect
exec /app/myapp --log-file /dev/stdout
```

Ensure app runs in foreground (no daemon mode):
```bash
# BAD - app backgrounds itself
exec /app/myapp --daemon

# GOOD - app stays in foreground
exec /app/myapp --foreground
```

### Dockerfile

Install runtime dependencies discovered during analysis:
```dockerfile
# For Python apps
RUN apk add --no-cache py3-pip gcc musl-dev \
    && pip install --no-cache-dir \
        sqlalchemy \
        requests \
        aiohttp

# For Node apps
RUN apk add --no-cache nodejs npm
COPY package.json package-lock.json /app/
RUN npm ci --production
```

Copy configuration templates or default files:
```dockerfile
COPY rootfs/etc/templates /etc/templates
COPY rootfs/etc/defaults /etc/defaults
```

Set build-time `ARG` values for version tracking:
```dockerfile
ARG UPSTREAM_VERSION=latest
ARG BUILD_VERSION
LABEL io.hass.version="${BUILD_VERSION}"
```

Configure health checks based on discovered endpoints:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8099/health || exit 1
```

## Analysis Tools and Techniques

### Static Analysis Without Cloning

- Use GitHub's code search (`code?q=repo:user/repo+main`)
- Browse key files directly on GitHub web interface
- Review CI/CD workflows (`.github/workflows/`) for runtime commands
- Check Dockerfiles or docker-compose for environment patterns

### Local Cloning When Needed

```bash
git clone --depth 1 https://github.com/user/repo.git /tmp/repo-analysis
cd /tmp/repo-analysis

# Search for configuration patterns
grep -r "getenv\|getenv\|os.Getenv" --include="*.py" --include="*.go" .
grep -r "config\|settings" --include="*.yaml" --include="*.json" .

# Find main entry point
find . -name "main.go" -o -name "app.py" -o -name "index.js" -o -name "main.rs"
```

### Container Inspection

```bash
# Run upstream image and explore
docker run --rm --entrypoint sh UPSTREAM_IMAGE:TAG

# Inside container: inspect /app, examine processes, check environment
ls -la /app
ps aux
env | sort
```

### Dockerfile Analysis

```bash
# Extract base image
grep "^FROM" Dockerfile

# Find exposed ports
grep "^EXPOSE" Dockerfile

# Find volumes
grep "^VOLUME" Dockerfile

# Find environment variables
grep "^ENV" Dockerfile

# Find entrypoint/CMD
grep -E "^ENTRYPOINT|^CMD" Dockerfile
```

## Common Application Types

### Web Applications (HTTP API)

**Typical characteristics:**
- Single exposed port (8080, 3000, 5000)
- Configuration for CORS, rate limiting, authentication
- Static assets for frontend
- Health check endpoint

**Key configuration:**
- `bind_address` — usually 0.0.0.0 for container exposure
- `base_url` or `root_path` — for ingress sub-path support
- `log_level` — controls verbosity
- `database_url` — connection string for data storage

### Worker/Background Services

**Typical characteristics:**
- No HTTP interface
- Long-running processes (cron jobs, queue workers)
- Log output to stdout/stderr
- Configuration for intervals, endpoints, credentials

**Key configuration:**
- `schedule` or `interval` — how often to run
- `api_endpoint` — external service to call
- `api_key` or `token` — authentication
- `log_level` — verbosity control

### Database-Backed Applications

**Typical characteristics:**
- Database initialization on first run
- Migration scripts for schema updates
- Connection pooling configuration
- Backup/restore mechanisms

**Key configuration:**
- `database_path` — where to store SQLite file
- `database_url` — PostgreSQL/MySQL connection string
- `migrations_path` — location of migration files
- `backup_interval` — automatic backup frequency

## Mapping Analysis Results to Add-on Structure

| Discovery Finding | Add-on Configuration |
|-----------------|----------------------|
| App listens on port 8080 | Set `ENV APP_PORT=8080` in Dockerfile; nginx proxies to this |
| Config file at `/etc/app/config.yaml` | Export `CONFIG_PATH=/etc/app/config.yaml` in 10-app-setup.sh |
| Data stored in `/var/lib/app/data` | Add `map: - config:rw` to mount `/config`; create symlink in 10-app-setup.sh |
| Requires `API_KEY` environment variable | Add `api_key` option to config.yaml schema; export in 10-app-setup.sh |
| Health check at `/api/health` | Add `HEALTHCHECK` to Dockerfile pointing to `http://localhost:8080/api/health` |
| Writes logs to `/var/log/app.log` | Redirect or configure app to log to stdout; no file mount needed |
