#!/usr/bin/with-contenv bashio
bashio::log.info "Starting Kapowarr add-on..."

bashio::log.info "Ensuring data directories exist..."
mkdir -p /data/kapowarr

bashio::log.info "Initialization complete."
