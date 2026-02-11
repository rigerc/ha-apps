# Bashio API Functions Reference

Quick reference for calling Home Assistant Supervisor and Core APIs.

## Core API Functions

### Home Assistant Core

```bash
ha_version=$(bashio::core.version)
bashio::core.restart
if bashio::core.update_available; then
    bashio::log.notice "Home Assistant update available"
fi
```

### Add-on API

```bash
my_version=$(bashio::addon.version)
name=$(bashio::addon.name)
ingress_url=$(bashio::addon.ingress_url)
```

### Services API

```bash
if bashio::services.available 'mysql'; then
    db_host=$(bashio::services 'mysql' 'host')
    db_port=$(bashio::services 'mysql' 'port')
    db_user=$(bashio::services 'mysql' 'username')
    db_pass=$(bashio::services 'mysql' 'password')
fi
```

**Common services:** `mysql`, `mariadb`, `postgres`, `redis`, `mqtt`, `influxdb`

### Supervisor API

```bash
response=$(bashio::api.supervisor GET '/addons/self/info' false)
bashio::api.supervisor POST '/core/restart'
```

For complete details, see the main SKILL.md file.
