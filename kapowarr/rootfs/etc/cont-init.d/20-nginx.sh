#!/usr/bin/with-contenv bashio

INGRESS_PORT=$(bashio::addon.ingress_port)
bashio::log.info "Configuring nginx for ingress on port ${INGRESS_PORT}..."

sed -i "s/%%port%%/${INGRESS_PORT}/g" /etc/nginx/servers/ingress.conf
sed -i "s/%%interface%%/127.0.0.1/g" /etc/nginx/servers/ingress.conf

bashio::log.info "Nginx configuration complete."
