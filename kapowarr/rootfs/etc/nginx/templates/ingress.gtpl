# ==============================================================================
# ingress.gtpl — nginx server block Go template
#
# Rendered at container start by cont-init.d/20-nginx.sh using tempio.
# Output is written to /etc/nginx/servers/ingress.conf.
#
# Template variables (supplied by 20-nginx.sh via bashio::var.json):
#   .ingress_interface — container IP address
#   .ingress_port      — dynamically assigned ingress port
#   .app_port          — internal port the application listens on (default 5656)
# ==============================================================================

server {
    listen {{ .ingress_interface }}:{{ .ingress_port }} default_server;

    # Common server parameters
    include /etc/nginx/includes/server_params.conf;

    # Common proxy parameters
    include /etc/nginx/includes/proxy_params.conf;

    client_max_body_size 0;

    # Security headers
    add_header X-Frame-Options    "SAMEORIGIN"  always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection   "1; mode=block" always;
    add_header Referrer-Policy    "no-referrer"  always;

    # ------------------------------------------------------------------
    # Main proxy location
    # ------------------------------------------------------------------
    location / {
        # Restrict access to the HA ingress subnet only
        allow 172.30.32.2;
        deny  all;

        # Forward to the backend application
        proxy_pass http://127.0.0.1:{{ .app_port }};

        # Disable response buffering for streaming
        proxy_buffering off;

        proxy_pass_request_headers on;

        # WebSocket upgrade support (Flask-SocketIO)
        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection $connection_upgrade;

        # Generous timeouts for long-running operations
        proxy_connect_timeout 600s;
        proxy_send_timeout    600s;
        proxy_read_timeout    600s;
    }

    # ------------------------------------------------------------------
    # Health check endpoint
    # ------------------------------------------------------------------
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
