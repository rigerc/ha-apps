# ==============================================================================
# ingress.gtpl — nginx server block Go template
#
# Rendered at container start by cont-init.d/20-nginx.sh using tempio.
# Output is written to /etc/nginx/servers/ingress.conf.
#
# Template variables (supplied by 20-nginx.sh via bashio::var.json):
#   .ingress_interface — container IP address (from bashio::addon.ip_address)
#   .ingress_port      — dynamically assigned ingress port (from bashio::addon.ingress_port)
#   .app_port          — internal port the application listens on (from $APP_PORT env var)
#
# CUSTOMIZE: No manual edits needed here.
#   - To change the backend port, update ENV APP_PORT in the Dockerfile.
#   - For base-path rewriting, uncomment the sub_filter block in the location below.
# ==============================================================================

server {
    # HA ingress traffic arrives on the dynamically assigned port at the
    # container's IP address. Both values are injected at runtime by 20-nginx.sh.
    listen {{ .ingress_interface }}:{{ .ingress_port }} default_server;

    # Common server parameters (security headers, server_name)
    include /etc/nginx/includes/server_params.conf;

    # Common proxy parameters (headers forwarded to the upstream application)
    include /etc/nginx/includes/proxy_params.conf;

    # Do not impose a body size limit here (it is set globally in nginx.conf).
    client_max_body_size 0;

    # Security headers — these supplement the headers in server_params.conf
    add_header X-Frame-Options    "SAMEORIGIN"  always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection   "1; mode=block" always;
    add_header Referrer-Policy    "no-referrer"  always;

    # ------------------------------------------------------------------
    # Main proxy location
    # ------------------------------------------------------------------
    location / {
        # Restrict access to the HA ingress subnet only.
        # 172.30.32.2 is the fixed IP of the HA supervisor ingress proxy.
        # Any request that does not originate from it is denied.
        allow 172.30.32.2;
        deny  all;

        # Forward to the backend application.
        proxy_pass http://127.0.0.1:{{ .app_port }};

        # Disable response buffering so streaming responses (e.g., log tails,
        # SSE, chunked JSON) are delivered immediately to the client.
        proxy_buffering off;

        # Pass all request headers through to the backend.
        proxy_pass_request_headers on;

        # WebSocket upgrade support (needed by apps that use WebSockets)
        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection $connection_upgrade;

        # Generous timeouts for long-running operations (e.g., file imports)
        proxy_connect_timeout 600s;
        proxy_send_timeout    600s;
        proxy_read_timeout    600s;

        # CUSTOMIZE: Handling apps that embed absolute paths in HTML responses
        #
        # HA ingress mounts the add-on under a dynamic path prefix
        # (e.g. /api/hassio_ingress/<token>/).  The prefix is available in two ways:
        #
        #   1. X-Ingress-Path header (preferred) — forwarded by proxy_params.conf.
        #      Configure the app to read this header or the APP_BASE_URL env var
        #      (set by 10-app-setup.sh) to construct correct absolute URLs itself.
        #      Most modern frameworks support a ROOT_PATH / BASE_URL setting.
        #
        #   2. nginx sub_filter rewriting (fallback) — uncomment the block below
        #      only when the app cannot be configured to use a base path at all.
        #      nginx rewrites absolute paths in HTML/CSS/JS responses on the fly.
        #      Note: sub_filter rewrites are CPU-intensive and may miss dynamic JS.
        #
        # sub_filter_types *;
        # sub_filter_once  off;
        # sub_filter 'href="/'   'href="$http_x_ingress_path/';
        # sub_filter 'src="/'    'src="$http_x_ingress_path/';
        # sub_filter 'action="/' 'action="$http_x_ingress_path/';
        # proxy_redirect / $http_x_ingress_path/;
        # absolute_redirect off;
    }

    # ------------------------------------------------------------------
    # Health check endpoint — used by the Dockerfile HEALTHCHECK instruction
    # Returns a plain-text "healthy" response without hitting the backend.
    # ------------------------------------------------------------------
    location /health {
        access_log off;   # suppress health check noise in the access log
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
