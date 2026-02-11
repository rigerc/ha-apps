#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Example: Service discovery and optional dependencies

# ==============================================================================
# Database service discovery
# ==============================================================================

bashio::log.info "Checking for database services..."

# MariaDB/MySQL
if bashio::services.available 'mariadb'; then
    db_type="mariadb"
    db_host=$(bashio::services 'mariadb' 'host')
    db_port=$(bashio::services 'mariadb' 'port')
    db_user=$(bashio::services 'mariadb' 'username')
    db_pass=$(bashio::services 'mariadb' 'password')
    db_database=$(bashio::services 'mariadb' 'database')
    bashio::log.info "Found MariaDB service"
    bashio::log.info "  Host: ${db_host}"
    bashio::log.info "  Port: ${db_port}"
    bashio::log.info "  Database: ${db_database}"

# PostgreSQL
elif bashio::services.available 'postgres'; then
    db_type="postgresql"
    db_host=$(bashio::services 'postgres' 'host')
    db_port=$(bashio::services 'postgres' 'port')
    db_user=$(bashio::services 'postgres' 'username')
    db_pass=$(bashio::services 'postgres' 'password')
    db_database=$(bashio::services 'postgres' 'database')
    bashio::log.info "Found PostgreSQL service"
    bashio::log.info "  Host: ${db_host}"
    bashio::log.info "  Port: ${db_port}"
    bashio::log.info "  Database: ${db_database}"

# No database service found
else
    db_type="sqlite"
    db_path="/data/database.db"
    bashio::log.notice "No database service found"
    bashio::log.info "Using internal SQLite database: ${db_path}"
fi

# ==============================================================================
# Redis cache discovery
# ==============================================================================

if bashio::services.available 'redis'; then
    redis_host=$(bashio::services 'redis' 'host')
    redis_port=$(bashio::services 'redis' 'port')
    redis_password=$(bashio::services 'redis' 'password')

    bashio::log.info "Found Redis cache service"
    bashio::log.info "  Host: ${redis_host}"
    bashio::log.info "  Port: ${redis_port}"

    # Wait for Redis
    bashio::log.info "Waiting for Redis..."
    bashio::net.wait_for "${redis_host}" "${redis_port}"

    use_redis="true"
else
    bashio::log.notice "Redis not found, using internal cache"
    use_redis="false"
fi

# ==============================================================================
# MQTT discovery
# ==============================================================================

if bashio::services.available 'mqtt'; then
    mqtt_host=$(bashio::services 'mqtt' 'host')
    mqtt_port=$(bashio::services 'mqtt' 'port')
    mqtt_user=$(bashio::services 'mqtt' 'username')
    mqtt_password=$(bashio::services 'mqtt' 'password')

    bashio::log.info "Found MQTT broker"
    bashio::log.info "  Host: ${mqtt_host}"
    bashio::log.info "  Port: ${mqtt_port}"
    enable_mqtt="true"
else
    enable_mqtt="false"
fi

# ==============================================================================
# Configure application based on discovered services
# ==============================================================================

# Generate database connection string
case "${db_type}" in
    mariadb)
        db_connection="mysql://${db_user}:${db_pass}@${db_host}:${db_port}/${db_database}"
        ;;
    postgresql)
        db_connection="postgres://${db_user}:${db_pass}@${db_host}:${db_port}/${db_database}"
        ;;
    sqlite)
        db_connection="sqlite:/${db_path}"
        ;;
esac

# Start application with discovered services
bashio::log.info "Database: ${db_connection}"
bashio::log.info "Redis: ${use_redis}"
bashio::log.info "MQTT: ${enable_mqtt}"

exec /app/my-application \
    --database "${db_connection}" \
    --redis "${use_redis}" \
    --mqtt "${enable_mqtt}"
