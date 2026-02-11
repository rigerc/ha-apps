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

        # ------------------------------------------------------------------
        # Rewrite absolute paths for HA ingress
        # ------------------------------------------------------------------
        # HA ingress mounts the add-on under /api/hassio_ingress/<token>/.
        # Kapowarr's Flask app uses absolute paths (/static/..., /api/...)
        # which break when accessed via ingress. Use sub_filter to rewrite
        # these paths to include the ingress prefix.
        #
        # Rewrite HTML, CSS, and JavaScript responses
        sub_filter_types text/html text/css application/javascript;
        sub_filter_once off;

        # Rewrite the url_base meta tag: data-value="" -> data-value="/api/hassio_ingress/XXX"
        # Kapowarr's JavaScript reads this to construct API URLs
        sub_filter '<meta id="url_base" data-value=""'  '<meta id="url_base" data-value="$http_x_ingress_path"';

        # Rewrite static asset paths: /static/... -> /api/hassio_ingress/XXX/static/...
        sub_filter 'href="/static/'  'href="$http_x_ingress_path/static/';
        sub_filter 'src="/static/'   'src="$http_x_ingress_path/static/';
        # Rewrite API paths: /api/... -> /api/hassio_ingress/XXX/api/...
        sub_filter '"/api/'          '"$http_x_ingress_path/api/';
        sub_filter "'/api/'          "'$http_x_ingress_path/api/';
        sub_filter 'url:/api/'       'url:$http_x_ingress_path/api/';
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
